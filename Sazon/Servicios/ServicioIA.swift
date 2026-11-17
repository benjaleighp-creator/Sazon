import Foundation

// Conexión con la IA. Las pantallas solo conocen el protocolo
// `ProveedorIA`. Capas (arquitectura aprobada en la Fase 2):
//   1. Memoria local (CacheIA): la misma foto o texto en 24 h, sin red.
//   2. En el iPhone: la etiqueta se lee con Vision antes de llamar a la nube
//      (EtiquetaView + LectorEtiquetaLocal).
//   3. Gemini con tu clave (modelo elegido y de respaldo).
//   4. Groq con tu clave opcional, solo si Gemini está saturado o sin cuota.
// Reglas (PoliticaIA): máximo 3 llamadas por registro entre todos, corte
// total a los 30 s (también de la petición en curso), espera creciente con
// azar, cuota diaria agotada = ese modelo no se vuelve a llamar hoy, y
// nunca se prueban otros modelos tras un 400.

/// Lo que la app necesita de cualquier IA: convertir un texto o una foto
/// en una lista de alimentos con porciones (y posibles ingredientes ocultos).
protocol ProveedorIA {
    func analizar(texto: String) async throws -> AnalisisIA
    func analizar(fotoJPEG: Data) async throws -> AnalisisIA
    /// Valores por 100 g de un alimento por su nombre (alimentos propios).
    func analizarAlimentoPropio(nombre: String) async throws -> AnalisisIA
    /// Lee la tabla nutricional de un envase (para productos que no están
    /// en Open Food Facts).
    func leerEtiqueta(fotoJPEG: Data) async throws -> EtiquetaLeida
    /// Conversación con el coach (texto libre).
    func conversar(mensajes: [MensajeCoach], contexto: String?) async throws -> String
}

/// Lo que pasa durante la espera, para contárselo a la persona (así una
/// espera larga no parece un cuelgue).
enum PasoIA: Equatable {
    /// El modelo elegido está saturado: se espera un poco y se reintenta.
    case reintentando
    /// Se prueba un modelo de respaldo de Gemini.
    case otroModelo(String)
    /// Gemini no pudo: se prueba Groq (si pusiste su clave).
    case respaldoGroq

    var mensaje: String {
        switch self {
        case .reintentando: return "Gemini está saturado. Lo intento de nuevo…"
        case .otroModelo(let nombre): return "Probando otro modelo (\(nombre))…"
        case .respaldoGroq: return "Gemini no pudo. Probando con el respaldo (Groq)…"
        }
    }
}

/// Lo único que la IA necesita de la red. `URLSession` lo cumple; las
/// pruebas usan una sesión falsa que responde lo que se le pida.
protocol SesionRed {
    func respuesta(a peticion: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: SesionRed {
    func respuesta(a peticion: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: peticion)
    }
}

/// Aviso de progreso. Puede llegar desde cualquier hilo.
typealias AvisoPasoIA = @Sendable (PasoIA) -> Void

enum ServicioIA {
    /// Proveedor que usan las pantallas. Lee las claves del Llavero y el
    /// modelo de los ajustes en el momento de cada petición. `alAvanzar`
    /// recibe los reintentos y cambios de modelo (para mostrarlos).
    @MainActor
    static func proveedorActual(_ datos: DatosApp, alAvanzar: AvisoPasoIA? = nil) throws -> ProveedorIA {
        guard datos.avisoIAAceptado else { throw ErrorIA.avisoNoAceptado }
        guard let clave = Llavero.leerClave() else { throw ErrorIA.sinClave }
        var gemini = ProveedorGemini(clave: clave, modelo: datos.modeloIA, formato: datos.formatoPeticionIA)
        gemini.alAvanzar = alAvanzar
        let groq = Llavero.leerClave(de: .groq).map { ProveedorGroq(clave: $0) }
        return ProveedorEnCapas(gemini: gemini, groq: groq, memoria: CacheIA.compartido, alAvanzar: alAvanzar)
    }

    /// Ejecuta `operacion` con un tope de tiempo: si no termina en
    /// `segundos`, se cancela (también la petición de red en curso) y se
    /// lanza `ErrorIA.tiempoAgotado`.
    static func conLimite<T>(_ segundos: TimeInterval, _ operacion: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T?.self) { grupo in
            grupo.addTask { try await operacion() }
            grupo.addTask {
                try await Task.sleep(nanoseconds: UInt64(max(segundos, 0) * 1_000_000_000))
                return nil
            }
            defer { grupo.cancelAll() }
            guard let primero = try await grupo.next(), let valor = primero else {
                try Task.checkCancellation()
                throw ErrorIA.tiempoAgotado
            }
            return valor
        }
    }
}

// MARK: - Gemini

/// Un 429 con lo que dice Google del límite (uso interno).
struct Limite429: Error {
    let modelo: String
    let info: InfoLimite
}

/// API de Google Gemini (plan gratuito de Google AI Studio).
/// Documentación: https://ai.google.dev/gemini-api/docs
/// - Endpoint: POST https://generativelanguage.googleapis.com/v1beta/models/{modelo}:generateContent
/// - Autenticación: cabecera `x-goog-api-key` (nunca en la URL).
struct ProveedorGemini: ProveedorIA {
    let clave: String
    let modelo: String
    let formato: FormatoPeticionIA
    var sesion: SesionRed = RedIA.sesion
    /// Avisa de reintentos y cambios de modelo (no cambia cuándo se reintenta).
    var alAvanzar: AvisoPasoIA? = nil
    var cuota: RegistroCuota = .compartido
    /// Espera antes de reintentar (en las pruebas se pone en 0).
    var esperar: (TimeInterval) async throws -> Void = { s in
        try await Task.sleep(nanoseconds: UInt64(max(s, 0) * 1_000_000_000))
    }

    static let base = "https://generativelanguage.googleapis.com/v1beta/models/"

    func analizar(texto: String) async throws -> AnalisisIA {
        try await analisis(.texto, texto: texto, imagen: nil)
    }

    func analizar(fotoJPEG: Data) async throws -> AnalisisIA {
        try await analisis(.foto, texto: nil, imagen: fotoJPEG.base64EncodedString())
    }

    func analizarAlimentoPropio(nombre: String) async throws -> AnalisisIA {
        try await analisis(.alimentoPropio, texto: nombre, imagen: nil)
    }

    func leerEtiqueta(fotoJPEG: Data) async throws -> EtiquetaLeida {
        let b64 = fotoJPEG.base64EncodedString()
        let presupuesto = PresupuestoIA()
        let r = try await ServicioIA.conLimite(presupuesto.restante) {
            try await pedir(presupuesto) { m in
                try LectorIA.cuerpoPeticionEtiqueta(imagenJPEGBase64: b64, formato: formato,
                                                    nivelRazonamiento: LectorIA.nivelRazonamiento(modelo: m))
            }
        }
        var e = try LectorIA.etiqueta(desde: r.texto)
        e.capa = .gemini(r.modelo)
        return e
    }

    func conversar(mensajes: [MensajeCoach], contexto: String?) async throws -> String {
        let presupuesto = PresupuestoIA()
        let r = try await ServicioIA.conLimite(presupuesto.restante) {
            try await pedir(presupuesto) { m in
                try LectorIA.cuerpoCoach(mensajes: mensajes, contexto: contexto,
                                         nivelRazonamiento: LectorIA.nivelRazonamiento(modelo: m))
            }
        }
        return LectorIA.respuestaCoach(r.texto)
    }

    private func analisis(_ tipo: LectorIA.TipoAnalisis, texto: String?, imagen: String?) async throws -> AnalisisIA {
        let presupuesto = PresupuestoIA()
        let r = try await ServicioIA.conLimite(presupuesto.restante) {
            try await pedir(presupuesto, cuerpo: cuerpoAnalisis(tipo, texto: texto, imagen: imagen))
        }
        var a = try LectorIA.analisis(desde: r.texto)
        a.capa = .gemini(r.modelo)
        return a
    }

    /// Constructor del cuerpo de un análisis para cada modelo (el nivel de
    /// razonamiento depende del modelo).
    func cuerpoAnalisis(_ tipo: LectorIA.TipoAnalisis, texto: String?, imagen: String?) -> (String) throws -> Data {
        let formato = self.formato
        return { m in
            try LectorIA.cuerpoPeticion(texto: texto, imagenJPEGBase64: imagen, formato: formato, tipo: tipo,
                                        nivelRazonamiento: LectorIA.nivelRazonamiento(modelo: m))
        }
    }

    /// Prueba el modelo elegido y los de respaldo dentro del presupuesto.
    /// Devuelve el texto de la respuesta y el modelo que respondió.
    func pedir(_ presupuesto: PresupuestoIA, cuerpo: @escaping (String) throws -> Data) async throws -> (texto: String, modelo: String) {
        let cadena = PoliticaIA.cadena(elegido: modelo, agotados: cuota.agotados())
        guard !cadena.isEmpty else { throw ErrorIA.cuotaDiariaAgotada }
        var errores: [ErrorIA] = []
        var intento = 0
        for (indice, nombre) in cadena.enumerated() {
            try Task.checkCancellation()
            guard presupuesto.tomarLlamada() else { break }
            intento += 1
            if indice > 0 { alAvanzar?(.otroModelo(nombre)) }
            do {
                let tope = min(PoliticaIA.tiempoPorPeticion, presupuesto.restante)
                return (try await llamar(try cuerpo(nombre), modelo: nombre, tope: tope), nombre)
            } catch let limite as Limite429 {
                if limite.info.diario {
                    // Cuota del día agotada: este modelo no se vuelve a llamar hasta el reinicio.
                    cuota.marcarAgotado(nombre)
                    errores.append(.cuotaDiariaAgotada)
                } else {
                    errores.append(.limiteAlcanzado)
                    // Límite por minuto: si Google pide esperar poco y queda
                    // tiempo, se espera antes del siguiente intento.
                    if let s = limite.info.espera, s <= PoliticaIA.esperaMaximaReintento, presupuesto.restante > s + 3 {
                        try await esperar(s)
                    }
                }
            } catch let error as ErrorIA {
                switch error {
                case .servidor, .conexionLenta:
                    errores.append(error)
                    // Espera creciente con algo de azar antes del siguiente intento.
                    let s = PoliticaIA.espera(intento: intento)
                    if indice + 1 < cadena.count, presupuesto.restante > s + 3 {
                        alAvanzar?(.reintentando)
                        try await esperar(s)
                    }
                case .modeloNoDisponible:
                    errores.append(error)
                default:
                    // 400 (petición inválida), clave, sin internet, respuesta
                    // bloqueada…: otro modelo fallaría igual. No se reintenta.
                    throw error
                }
            }
        }
        // El error que más explica: el último que no fue de cuota diaria; si
        // todos fueron de cuota diaria, ese.
        if let e = errores.last(where: { $0 != .cuotaDiariaAgotada }) {
            // «Modelo no disponible» no explica nada si otro agotó su cuota.
            if case .modeloNoDisponible = e, errores.contains(.cuotaDiariaAgotada) { throw ErrorIA.cuotaDiariaAgotada }
            throw e
        }
        if !errores.isEmpty { throw ErrorIA.cuotaDiariaAgotada }
        throw ErrorIA.tiempoAgotado
    }

    /// Una llamada a Gemini con un modelo. Devuelve el texto de la respuesta.
    private func llamar(_ cuerpo: Data, modelo nombre: String, tope: TimeInterval) async throws -> String {
        // El nombre se puede escribir en Ajustes: solo letras, números, «.» y «-»
        // (nada de «/» que cambie la dirección a la que va la clave).
        guard PoliticaIA.nombreModeloValido(nombre),
              let ruta = nombre.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: Self.base + ruta + ":generateContent") else {
            throw ErrorIA.modeloNoDisponible(nombre)
        }
        var peticion = URLRequest(url: url)
        peticion.httpMethod = "POST"
        peticion.timeoutInterval = max(tope, 1)
        peticion.setValue("application/json", forHTTPHeaderField: "Content-Type")
        peticion.setValue(clave, forHTTPHeaderField: "x-goog-api-key")
        peticion.httpBody = cuerpo

        let (datos, respuesta) = try await RedIA.enviar(peticion, con: sesion)
        guard let http = respuesta as? HTTPURLResponse else {
            throw ErrorIA.desconocido("Respuesta inesperada del servidor.")
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 429 {
                throw Limite429(modelo: nombre, info: LectorIA.infoLimite(datos))
            }
            throw LectorIA.errorHTTP(codigo: http.statusCode, cuerpo: datos, modelo: nombre)
        }
        return try LectorIA.textoDeRespuesta(datos)
    }
}

/// Rechaza cualquier redirección: la respuesta 3xx llega tal cual y se
/// trata como error. Así una clave nunca viaja a otra dirección.
final class SinRedirecciones: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

/// Envío común de Gemini y Groq: traduce los errores de red.
enum RedIA {
    /// Sesión para la IA y Open Food Facts: efímera (sin caché en disco ni
    /// cookies), sin seguir redirecciones y con tope de tiempo. ATS ya exige
    /// HTTPS (no hay excepciones en el Info.plist).
    static let sesion: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.urlCache = nil
        c.httpCookieStorage = nil
        c.httpShouldSetCookies = false
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.timeoutIntervalForResource = 60
        return URLSession(configuration: c, delegate: SinRedirecciones(), delegateQueue: nil)
    }()

    static func enviar(_ peticion: URLRequest, con sesion: SesionRed) async throws -> (Data, URLResponse) {
        do {
            return try await sesion.respuesta(a: peticion)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
                // El iPhone de verdad no tiene red.
                throw ErrorIA.sinInternet
            case .timedOut, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                // Hay red, pero el servidor tardó o cortó.
                throw ErrorIA.conexionLenta
            case .cancelled:
                throw CancellationError()
            default:
                throw ErrorIA.desconocido("Error de conexión: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Varias capas

/// Proveedor que usan las pantallas: memoria local → Gemini → Groq.
struct ProveedorEnCapas: ProveedorIA {
    let gemini: ProveedorGemini
    let groq: ProveedorGroq?
    let memoria: CacheIA?
    var alAvanzar: AvisoPasoIA? = nil

    func analizar(texto: String) async throws -> AnalisisIA {
        try await analisis(.texto, texto: texto, foto: nil, clave: CacheIA.clave(tarea: "texto", texto: texto))
    }

    func analizar(fotoJPEG: Data) async throws -> AnalisisIA {
        try await analisis(.foto, texto: nil, foto: fotoJPEG, clave: CacheIA.clave(tarea: "foto", datos: fotoJPEG))
    }

    func analizarAlimentoPropio(nombre: String) async throws -> AnalisisIA {
        try await analisis(.alimentoPropio, texto: nombre, foto: nil, clave: CacheIA.clave(tarea: "propio", texto: nombre))
    }

    func leerEtiqueta(fotoJPEG: Data) async throws -> EtiquetaLeida {
        let clave = CacheIA.clave(tarea: "etiqueta", datos: fotoJPEG)
        if let e = memoria?.leer(clave), var leida = try? LectorIA.etiqueta(desde: e.respuesta) {
            leida.capa = .memoria
            return leida
        }
        let b64 = fotoJPEG.base64EncodedString()
        let formato = gemini.formato
        let r = try await resolver(
            gemini: { m in
                try LectorIA.cuerpoPeticionEtiqueta(imagenJPEGBase64: b64, formato: formato,
                                                    nivelRazonamiento: LectorIA.nivelRazonamiento(modelo: m))
            },
            groq: {
                try LectorIA.cuerpoGroq(modelo: PoliticaIA.modeloGroq, sistema: "Responde solo con el JSON pedido.",
                                        texto: LectorIA.instruccionesEtiqueta, imagenJPEGBase64: b64,
                                        esquema: LectorIA.esquemaEtiqueta, nombreEsquema: "etiqueta")
            })
        var leida = try LectorIA.etiqueta(desde: r.texto)
        leida.capa = r.capa
        memoria?.guardar(r.texto, capa: r.capa.clave, en: clave)
        return leida
    }

    func conversar(mensajes: [MensajeCoach], contexto: String?) async throws -> String {
        let r = try await resolver(
            gemini: { m in
                try LectorIA.cuerpoCoach(mensajes: mensajes, contexto: contexto,
                                         nivelRazonamiento: LectorIA.nivelRazonamiento(modelo: m))
            },
            groq: { try LectorIA.cuerpoGroqCoach(modelo: PoliticaIA.modeloGroq, mensajes: mensajes, contexto: contexto) })
        return LectorIA.respuestaCoach(r.texto)
    }

    private func analisis(_ tipo: LectorIA.TipoAnalisis, texto: String?, foto: Data?, clave: String) async throws -> AnalisisIA {
        let inicio = Date()
        if let e = memoria?.leer(clave), var a = try? LectorIA.analisis(desde: e.respuesta) {
            a.capa = .memoria
            return a
        }
        let b64 = foto?.base64EncodedString()
        let r = try await resolver(
            gemini: gemini.cuerpoAnalisis(tipo, texto: texto, imagen: b64),
            groq: {
                try LectorIA.cuerpoGroq(modelo: PoliticaIA.modeloGroq, sistema: "Responde solo con el JSON pedido.",
                                        texto: LectorIA.pedido(texto: texto, tipo: tipo), imagenJPEGBase64: b64,
                                        esquema: LectorIA.esquema(conCaja: tipo.conCaja), nombreEsquema: "alimentos")
            })
        var a = try LectorIA.analisis(desde: r.texto)
        a.capa = r.capa
        a.segundos = Date().timeIntervalSince(inicio)
        memoria?.guardar(r.texto, capa: r.capa.clave, en: clave)
        return a
    }

    /// Gemini y, si está saturado o sin cuota y hay clave de Groq, Groq.
    /// Todo dentro de un solo presupuesto (3 llamadas, 30 s).
    private func resolver(gemini cuerpoGemini: @escaping (String) throws -> Data,
                          groq cuerpoGroq: @escaping () throws -> Data) async throws -> (texto: String, capa: CapaIA) {
        let presupuesto = PresupuestoIA()
        let gemini = self.gemini
        let groq = self.groq
        // Con respaldo, Gemini usa 2 de las 3 llamadas y queda 1 para Groq.
        if groq != nil { presupuesto.reservarParaRespaldo(1) }
        let alAvanzar = self.alAvanzar
        return try await ServicioIA.conLimite(presupuesto.restante) { () async throws -> (texto: String, capa: CapaIA) in
            do {
                let r = try await gemini.pedir(presupuesto, cuerpo: cuerpoGemini)
                return (r.texto, CapaIA.gemini(r.modelo))
            } catch let error as ErrorIA {
                guard let groq, ProveedorEnCapas.pasaAGroq(error) else { throw error }
                guard presupuesto.tomarLlamada(paraRespaldo: true) else { throw error }
                alAvanzar?(.respaldoGroq)
                do {
                    let texto = try await groq.pedir(try cuerpoGroq(), tope: min(PoliticaIA.tiempoPorPeticion, presupuesto.restante))
                    return (texto, CapaIA.groq)
                } catch let errorGroq as ErrorIA {
                    // Se muestra el error de Gemini (es el principal), salvo
                    // que la clave de Groq esté mal: eso hay que contarlo.
                    throw errorGroq == .claveGroqInvalida ? errorGroq : error
                }
            }
        }
    }

    /// Errores de saturación o cuota: ahí sí vale la pena el respaldo.
    static func pasaAGroq(_ e: ErrorIA) -> Bool {
        switch e {
        case .limiteAlcanzado, .cuotaDiariaAgotada, .servidor, .conexionLenta, .modeloNoDisponible: return true
        default: return false
        }
    }
}
