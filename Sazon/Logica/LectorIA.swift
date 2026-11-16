import Foundation

/// Un alimento que la IA identificó en una foto o en un texto.
struct AlimentoIdentificado: Equatable, Identifiable {
    var id = UUID()
    var nombre: String
    /// Porción total estimada en gramos.
    var gramos: Double
    /// 0 a 1.
    var confianza: Double
    /// Medida casera sugerida por la IA (marcada como estimada).
    var medida: MedidaCasera?
    var cantidadMedida: Double?
    /// Estimación de la IA por 100 g (se usa solo si no hay coincidencia en el INS).
    var por100g: Nutrientes
    /// Rango probable de la porción (la foto no muestra el peso real).
    var gramosMin: Double? = nil
    var gramosMax: Double? = nil
    /// Dónde está en la foto (solo si Gemini devolvió una caja válida).
    var caja: CajaFoto? = nil

    static func == (a: AlimentoIdentificado, b: AlimentoIdentificado) -> Bool {
        a.gramosMin == b.gramosMin && a.gramosMax == b.gramosMax && a.caja == b.caja &&
        a.nombre == b.nombre && a.gramos == b.gramos && a.confianza == b.confianza &&
        a.medida == b.medida && a.cantidadMedida == b.cantidadMedida && a.por100g == b.por100g
    }
}

/// Resultado completo de analizar una foto o un texto.
struct AnalisisIA: Equatable {
    var alimentos: [AlimentoIdentificado]
    /// Ingredientes que suelen ir en estos platos y no se ven (aceite,
    /// mayonesa…), para preguntártelos antes de guardar.
    var posiblesOcultos: [String]
    /// Qué capa respondió (memoria, iPhone, Gemini o Groq) y en cuánto tiempo.
    var capa: CapaIA? = nil
    var segundos: Double? = nil
}

/// Quién dio la respuesta. Se muestra de forma discreta en la revisión.
enum CapaIA: Equatable {
    /// Memoria local: la misma foto o texto en las últimas 24 h.
    case memoria
    /// En el iPhone, sin red (lectura de etiquetas con Vision).
    case iPhone
    case gemini(String)
    case groq

    var nombre: String {
        switch self {
        case .memoria: return "Memoria del iPhone (sin red)"
        case .iPhone: return "Leído en tu iPhone (sin red)"
        case .gemini(let modelo): return "Gemini · \(modelo)"
        case .groq: return "Groq (respaldo)"
        }
    }

    var simbolo: String {
        switch self {
        case .memoria: return "clock.arrow.circlepath"
        case .iPhone: return "iphone"
        case .gemini, .groq: return "sparkles"
        }
    }

    /// Texto para guardar en la memoria local.
    var clave: String {
        switch self {
        case .memoria: return "memoria"
        case .iPhone: return "iphone"
        case .gemini(let m): return "gemini:" + m
        case .groq: return "groq"
        }
    }

    init?(clave: String) {
        if clave == "memoria" { self = .memoria }
        else if clave == "iphone" { self = .iPhone }
        else if clave == "groq" { self = .groq }
        else if clave.hasPrefix("gemini:") { self = .gemini(String(clave.dropFirst(7))) }
        else { return nil }
    }

    /// «Gemini · gemini-3.8-flash · 6,2 s».
    func descripcion(segundos: Double?) -> String {
        guard let segundos, segundos.isFinite, self != .memoria else { return nombre }
        return nombre + " · " + Formato.numero(segundos, decimales: 1) + " s"
    }
}

/// Errores de la IA, con un mensaje claro en español.
enum ErrorIA: Error, Equatable {
    case sinClave
    case avisoNoAceptado
    case sinInternet
    case conexionLenta
    case limiteAlcanzado
    case claveInvalida
    case modeloNoDisponible(String)
    case bloqueado(String)
    case sinAlimentos
    case sinEtiqueta
    case respuestaVacia
    case jsonInvalido(String)
    case peticionInvalida(String)
    case servidor(Int)
    case desconocido(String)
    /// Se acabó la cuota gratuita de hoy de todos los modelos que se probaron.
    case cuotaDiariaAgotada
    /// Se llegó al tope total de espera (`PoliticaIA.tiempoTotal`).
    case tiempoAgotado
    /// Groq rechazó su clave (la de Gemini puede estar bien).
    case claveGroqInvalida

    var titulo: String {
        switch self {
        case .sinClave: return "Falta tu clave de Gemini"
        case .avisoNoAceptado: return "Falta aceptar el aviso de privacidad"
        case .sinInternet: return "Sin conexión"
        case .conexionLenta: return "Gemini tardó demasiado"
        case .limiteAlcanzado: return "Llegaste al límite gratuito"
        case .claveInvalida: return "La clave no funciona"
        case .modeloNoDisponible: return "Modelo no disponible"
        case .bloqueado: return "Gemini no respondió"
        case .sinAlimentos: return "No se reconoció comida"
        case .sinEtiqueta: return "No se pudo leer la etiqueta"
        case .respuestaVacia, .jsonInvalido: return "Respuesta con errores"
        case .peticionInvalida: return "Gemini rechazó la petición"
        case .servidor: return "Gemini tuvo un problema"
        case .desconocido: return "Algo salió mal"
        case .cuotaDiariaAgotada: return "Se acabó la cuota gratuita de hoy"
        case .tiempoAgotado: return "La IA tardó demasiado"
        case .claveGroqInvalida: return "La clave de Groq no funciona"
        }
    }

    var mensaje: String {
        switch self {
        case .sinClave:
            return "Pega tu clave de API en Ajustes › Inteligencia artificial. Mientras tanto puedes buscar en la tabla o escanear un código de barras."
        case .avisoNoAceptado:
            return "Antes de usar la IA tienes que leer y aceptar el aviso de privacidad."
        case .sinInternet:
            return "La IA necesita internet. Puedes seguir con la búsqueda en la tabla, que funciona sin conexión."
        case .conexionLenta:
            return "Tu conexión funciona, pero Gemini no respondió a tiempo (probablemente está saturado). Ya se probaron los modelos de respaldo. Inténtalo de nuevo en un momento."
        case .limiteAlcanzado:
            return "El plan gratuito de Gemini tiene un límite de peticiones por minuto y por día. Espera un momento o sigue con la búsqueda manual o el escáner. El límite diario se reinicia a medianoche hora del Pacífico (2:00 o 3:00 a. m. en Lima)."
        case .claveInvalida:
            return "Google rechazó la clave. Revisa que la copiaste completa en Ajustes › Inteligencia artificial."
        case .modeloNoDisponible(let modelo):
            return "Google no encontró el modelo «\(modelo)». Puede que lo hayan cambiado: revisa el nombre en Ajustes › Inteligencia artificial."
        case .bloqueado(let motivo):
            return "Gemini no devolvió una respuesta (\(motivo)). Prueba con otra foto o escribe el plato."
        case .sinAlimentos:
            return "No se encontró comida en la foto o el texto. Prueba de nuevo o agrega el alimento a mano."
        case .sinEtiqueta:
            return "No se ve una tabla de información nutricional legible. Toma la foto de frente, con buena luz y que se lea «por 100 g» o «por porción». También puedes agregarlo a mano."
        case .respuestaVacia:
            return "Gemini respondió sin contenido. Puedes intentarlo otra vez o agregar el alimento a mano."
        case .jsonInvalido(let detalle):
            return "La respuesta no tenía el formato esperado (\(detalle)). Puedes intentarlo otra vez o agregar el alimento a mano."
        case .peticionInvalida(let detalle):
            return "Gemini rechazó la petición: \(detalle). Si dice algo de «responseFormat» o de un campo desconocido, cambia el formato de petición en Ajustes › Inteligencia artificial."
        case .servidor(let codigo):
            return "El servidor de Gemini respondió con el error \(codigo). Inténtalo más tarde o sigue con la búsqueda manual."
        case .desconocido(let detalle):
            return detalle
        case .cuotaDiariaAgotada:
            return "Gemini ya no acepta más peticiones gratuitas hoy (se reinicia a medianoche hora del Pacífico, 2:00 o 3:00 a. m. en Lima). Puedes registrar ahora mismo desde la tabla o a mano. Si pones una clave de Groq en Ajustes, se usa como respaldo."
        case .tiempoAgotado:
            return "Pasaron \(Int(PoliticaIA.tiempoTotal)) segundos sin respuesta, así que se canceló para no gastar tu cuota. Puedes intentarlo más tarde o registrar desde la tabla o a mano."
        case .claveGroqInvalida:
            return "Groq rechazó la clave de respaldo. Revísala en Ajustes › Inteligencia artificial, o bórrala si no la usas."
        }
    }
}

/// Todo lo que no toca la red: el texto de las instrucciones, el esquema
/// JSON, el cuerpo de la petición y la lectura de la respuesta. Así se
/// puede probar sin internet.
enum LectorIA {

    // MARK: - Petición

    /// Reglas comunes a foto, texto y alimento propio (cortas: un prompt
    /// largo hace más lenta la respuesta).
    static let instruccionesBase = """
    App personal de registro de comidas en Perú. Para cada alimento o bebida da:
    - "nombre": corto y genérico en español de Perú, como en una tabla de composición («Pan francés», «Palta», «Arroz blanco cocido»). Un plato peruano típico que no se separa (lomo saltado, ají de gallina) va como un solo plato.
    - "gramos": porción total (bebidas: ml como gramos), y "gramos_min"/"gramos_max": rango realista que la incluya.
    - "confianza": 0 a 1.
    - "medida", "cantidad", "gramos_por_medida": medida casera en singular (unidad, taza, vaso, cucharada, rebanada, plato) si es natural; si no, medida vacía y 0.
    - "kcal_100g", "proteina_100g", "carbohidratos_100g", "grasas_100g": estimación por 100 g.
    En "posibles_ocultos": ingredientes calóricos que estos platos suelen llevar y no se ven ni se mencionan (aceite, mantequilla, mayonesa, azúcar, queso, crema, salsa), en minúsculas; si no aplica, lista vacía. No los pongas en "alimentos".
    No inventes alimentos. Si no hay comida, lista vacía. Responde solo con el JSON.
    """

    static let instruccionesFoto = instruccionesBase + """

    Es una foto. Estima la porción por lo que se ve (un plato llano mide unos 26 cm); si no se puede saber, porción estándar de Perú. No subestimes platos grandes.
    "caja": caja del alimento [ymin, xmin, ymax, xmax] de 0 a 1000; si no puedes ubicarlo, lista vacía.
    """

    static let instruccionesTexto = instruccionesBase + """

    Es un texto escrito o dictado. Respeta las cantidades que diga («2 panes»); si no da cantidad, usa una porción estándar de Perú.
    """

    static let instruccionesAlimentoPropio = """
    App de registro de comidas en Perú. Te doy el nombre de UN alimento o plato. Devuélvelo como un único elemento de "alimentos" con su porción habitual en Perú ("gramos", "gramos_min", "gramos_max"), "confianza" de 0 a 1, medida casera si aplica (si no, medida vacía y 0) y su estimación por 100 g ("kcal_100g", "proteina_100g", "carbohidratos_100g", "grasas_100g"). "posibles_ocultos" vacía. Responde solo con el JSON.
    """

    /// Qué se le pide a la IA (cada tarea con su prompt corto).
    enum TipoAnalisis: String {
        case foto, texto, alimentoPropio

        var instrucciones: String {
            switch self {
            case .foto: return LectorIA.instruccionesFoto
            case .texto: return LectorIA.instruccionesTexto
            case .alimentoPropio: return LectorIA.instruccionesAlimentoPropio
            }
        }

        /// Las cajas solo tienen sentido con foto.
        var conCaja: Bool { self == .foto }
    }

    /// Esquema JSON de la respuesta (palabras clave admitidas por Gemini:
    /// type, properties, required, items, minimum, maximum, description).
    static var esquema: [String: Any] { esquema(conCaja: true) }

    static func esquema(conCaja: Bool) -> [String: Any] {
        let numero: (String, Double, Double) -> [String: Any] = { descripcion, minimo, maximo in
            ["type": "number", "description": descripcion, "minimum": minimo, "maximum": maximo]
        }
        var propiedades: [String: Any] = [
            "nombre": ["type": "string", "description": "Nombre corto en español de Perú"],
            "gramos": numero("Porción total en gramos", 0, 5000),
            "confianza": numero("Confianza de 0 a 1", 0, 1),
            "medida": ["type": "string", "description": "Medida casera en singular o vacío"],
            "cantidad": numero("Cuántas medidas caseras (0 si no aplica)", 0, 100),
            "gramos_por_medida": numero("Gramos de una medida casera (0 si no aplica)", 0, 5000),
            "kcal_100g": numero("kcal por 100 g", 0, 900),
            "proteina_100g": numero("Proteína por 100 g", 0, 100),
            "carbohidratos_100g": numero("Carbohidratos por 100 g", 0, 100),
            "grasas_100g": numero("Grasas por 100 g", 0, 100),
            "gramos_min": numero("Mínimo probable de la porción en gramos", 0, 5000),
            "gramos_max": numero("Máximo probable de la porción en gramos", 0, 5000)
        ]
        if conCaja {
            propiedades["caja"] = [
                "type": "array",
                "description": "[ymin, xmin, ymax, xmax] de 0 a 1000, o vacía",
                "items": numero("Coordenada de 0 a 1000", 0, 1000)
            ] as [String: Any]
        }
        let alimento: [String: Any] = [
            "type": "object",
            "properties": propiedades,
            "required": ["nombre", "gramos", "confianza", "medida", "cantidad", "gramos_por_medida",
                         "kcal_100g", "proteina_100g", "carbohidratos_100g", "grasas_100g", "gramos_min", "gramos_max"]
        ]
        let ocultos: [String: Any] = [
            "type": "array",
            "description": "Ingredientes calóricos probables que no se ven (aceite, mayonesa…)",
            "items": ["type": "string"] as [String: Any]
        ]
        return [
            "type": "object",
            "properties": [
                "alimentos": ["type": "array", "items": alimento] as [String: Any],
                "posibles_ocultos": ocultos
            ] as [String: Any],
            "required": ["alimentos", "posibles_ocultos"]
        ]
    }

    /// Nivel de razonamiento («thinking») más bajo que admite cada modelo,
    /// según https://ai.google.dev/gemini-api/docs/thinking (consultada el
    /// 16-nov-2026): `minimal` en 3.6-flash, los flash-lite y 3-flash-preview;
    /// `low` en 3.8-flash y Gemini 4 (no admiten `minimal`). Para un modelo
    /// que no se conoce se devuelve nil y no se envía el campo.
    static func nivelRazonamiento(modelo: String) -> String? {
        let m = modelo.lowercased()
        if m.contains("flash-lite") || m.contains("3.6-flash") || m.contains("3-flash-preview") { return "MINIMAL" }
        if m.contains("3.8-flash") || m.hasPrefix("gemini-4") || m.contains("2.5-flash") || m.contains("2.5-pro") { return "LOW" }
        return nil
    }

    /// Cuerpo JSON para `models/{modelo}:generateContent`.
    /// - texto: lo que escribiste o dictaste (nil si es solo foto).
    /// - imagenJPEGBase64: la foto ya comprimida, en base64 (nil si es texto).
    /// - tipo: la tarea (por defecto, foto si hay imagen y texto si no).
    /// - nivelRazonamiento: `thinkingConfig.thinkingLevel` (nil: no se envía).
    static func cuerpoPeticion(texto: String?, imagenJPEGBase64: String?, formato: FormatoPeticionIA,
                               tipo: TipoAnalisis? = nil, nivelRazonamiento: String? = nil) throws -> Data {
        let tarea = tipo ?? (imagenJPEGBase64 != nil ? .foto : .texto)
        var partes: [[String: Any]] = []
        if let imagen = imagenJPEGBase64 {
            let datosImagen: [String: Any] = ["mime_type": "image/jpeg", "data": imagen]
            partes.append(["inline_data": datosImagen])
        }
        partes.append(["text": pedido(texto: texto, tipo: tarea)])
        return try cuerpo(partes: partes, esquema: esquema(conCaja: tarea.conCaja), formato: formato,
                          nivelRazonamiento: nivelRazonamiento)
    }

    /// Instrucciones de la tarea más lo que escribiste.
    static func pedido(texto: String?, tipo: TipoAnalisis) -> String {
        var pedido = tipo.instrucciones
        let limpio = texto?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch tipo {
        case .foto:
            pedido += limpio.isEmpty ? "\n\nIdentifica los alimentos de la foto." : "\n\nNota: \(limpio)"
        case .texto:
            pedido += "\n\nLo que comí: \(limpio)"
        case .alimentoPropio:
            pedido += "\n\nAlimento: \(limpio)"
        }
        return pedido
    }

    /// Arma el cuerpo de `generateContent` con las partes y el esquema pedido.
    static func cuerpo(partes: [[String: Any]], esquema: [String: Any], formato: FormatoPeticionIA,
                       nivelRazonamiento: String? = nil) throws -> Data {
        var configuracion: [String: Any]
        switch formato {
        case .actual:
            // Forma REST de la guía actual de salidas estructuradas.
            let formatoTexto: [String: Any] = ["mimeType": "APPLICATION_JSON", "schema": esquema]
            let formatoRespuesta: [String: Any] = ["text": formatoTexto]
            configuracion = ["responseFormat": formatoRespuesta]
        case .clasico:
            configuracion = ["responseMimeType": "application/json", "responseJsonSchema": esquema]
        }
        if let nivelRazonamiento {
            configuracion["thinkingConfig"] = ["thinkingLevel": nivelRazonamiento]
        }
        let contenido: [String: Any] = ["role": "user", "parts": partes]
        let cuerpo: [String: Any] = [
            "contents": [contenido],
            "generationConfig": configuracion
        ]
        return try JSONSerialization.data(withJSONObject: cuerpo, options: [])
    }

    // MARK: - Respuesta

    /// Saca el texto de la respuesta de `generateContent`
    /// (`candidates[0].content.parts[].text`). Si Gemini bloqueó la
    /// respuesta, lanza `.bloqueado` con el motivo.
    static func textoDeRespuesta(_ datos: Data) throws -> String {
        guard let raiz = try? JSONSerialization.jsonObject(with: datos) as? [String: Any] else {
            throw ErrorIA.jsonInvalido("la respuesta del servidor no es JSON")
        }
        if let feedback = raiz["promptFeedback"] as? [String: Any],
           let motivo = feedback["blockReason"] as? String {
            throw ErrorIA.bloqueado(motivo)
        }
        guard let candidatos = raiz["candidates"] as? [[String: Any]], let primero = candidatos.first else {
            throw ErrorIA.respuestaVacia
        }
        let partes = ((primero["content"] as? [String: Any])?["parts"] as? [[String: Any]]) ?? []
        // Algunas partes pueden ser "pensamientos" (thought: true); se ignoran.
        let texto = partes
            .filter { ($0["thought"] as? Bool) != true }
            .compactMap { $0["text"] as? String }
            .joined()
        if texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let fin = primero["finishReason"] as? String, fin != "STOP" {
                throw ErrorIA.bloqueado(fin)
            }
            throw ErrorIA.respuestaVacia
        }
        return texto
    }

    /// Quita un posible bloque ```json … ``` alrededor del JSON.
    static func limpiarBloqueCodigo(_ texto: String) -> String {
        var t = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            if let salto = t.firstIndex(of: "\n") { t = String(t[t.index(after: salto)...]) }
            if t.hasSuffix("```") { t = String(t.dropLast(3)) }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Lee y valida el JSON de alimentos. Cualquier dato fuera de rango se
    /// informa con un error claro (no se corrige en silencio), salvo la
    /// confianza, que se recorta a 0–1.
    static func alimentos(desde texto: String) throws -> [AlimentoIdentificado] {
        let limpio = limpiarBloqueCodigo(texto)
        guard let datos = limpio.data(using: .utf8),
              let raiz = try? JSONSerialization.jsonObject(with: datos) as? [String: Any] else {
            throw ErrorIA.jsonInvalido("no es un JSON válido")
        }
        guard let lista = raiz["alimentos"] as? [[String: Any]] else {
            throw ErrorIA.jsonInvalido("falta la lista «alimentos»")
        }
        if lista.isEmpty { throw ErrorIA.sinAlimentos }

        var resultado: [AlimentoIdentificado] = []
        for (i, item) in lista.enumerated() {
            let n = i + 1
            let nombre = (item["nombre"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !nombre.isEmpty else { throw ErrorIA.jsonInvalido("el alimento \(n) no tiene nombre") }
            guard let gramos = numero(item["gramos"]), Porciones.esValido(gramos) else {
                throw ErrorIA.jsonInvalido("la porción de «\(nombre)» no es válida")
            }
            let confianza = min(max(numero(item["confianza"]) ?? 0.5, 0), 1)
            guard let kcal = numero(item["kcal_100g"]), (0...900).contains(kcal),
                  let p = numero(item["proteina_100g"]), (0...100).contains(p),
                  let c = numero(item["carbohidratos_100g"]), (0...100).contains(c),
                  let g = numero(item["grasas_100g"]), (0...100).contains(g) else {
                throw ErrorIA.jsonInvalido("los valores nutricionales de «\(nombre)» no son válidos")
            }
            var medida: MedidaCasera?
            var cantidad: Double?
            let nombreMedida = (item["medida"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !nombreMedida.isEmpty,
               let cant = numero(item["cantidad"]), cant > 0,
               let porMedida = numero(item["gramos_por_medida"]), Porciones.esValido(porMedida) {
                medida = MedidaCasera(nombre: nombreMedida.lowercased(), gramos: porMedida, estimada: true)
                cantidad = cant
            }
            // El rango solo se usa si tiene sentido (mínimo ≤ porción ≤ máximo).
            var minimo: Double?
            var maximo: Double?
            if let a = numero(item["gramos_min"]), let b = numero(item["gramos_max"]),
               a > 0, a <= gramos, b >= gramos, b > a, b <= 5000 {
                minimo = a
                maximo = b
            }
            resultado.append(AlimentoIdentificado(
                nombre: Formato.primeraMayuscula(nombre),
                gramos: gramos,
                confianza: confianza,
                medida: medida,
                cantidadMedida: cantidad,
                por100g: Nutrientes(kcal: kcal, proteina: p, carbohidratos: c, grasas: g),
                gramosMin: minimo,
                gramosMax: maximo,
                caja: CajaFoto.desdeGemini(item["caja"])
            ))
        }
        return resultado
    }

    /// Alimentos y posibles ingredientes ocultos. Si la lista de ocultos
    /// falta o viene mal, se ignora (no impide guardar los alimentos).
    static func analisis(desde texto: String) throws -> AnalisisIA {
        let lista = try alimentos(desde: texto)
        var ocultos: [String] = []
        if let datos = limpiarBloqueCodigo(texto).data(using: .utf8),
           let raiz = try? JSONSerialization.jsonObject(with: datos) as? [String: Any],
           let crudos = raiz["posibles_ocultos"] as? [Any] {
            for c in crudos {
                guard let t = (c as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                      !t.isEmpty, t.count <= 40, !ocultos.contains(t) else { continue }
                ocultos.append(t)
                if ocultos.count == 6 { break }
            }
        }
        return AnalisisIA(alimentos: lista, posiblesOcultos: ocultos)
    }

    /// Acepta números o textos con números ("60", "60,5").
    static func numero(_ valor: Any?) -> Double? {
        if let n = valor as? NSNumber {
            let d = n.doubleValue
            return d.isFinite ? d : nil
        }
        if let s = valor as? String {
            return Double(s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    /// Convierte un error HTTP de Gemini en un `ErrorIA`.
    /// Cuerpo típico: {"error": {"code": 429, "message": "…", "status": "RESOURCE_EXHAUSTED"}}.
    static func errorHTTP(codigo: Int, cuerpo: Data, modelo: String) -> ErrorIA {
        let error = (try? JSONSerialization.jsonObject(with: cuerpo) as? [String: Any])?["error"] as? [String: Any]
        let mensaje = (error?["message"] as? String) ?? ""
        let estado = (error?["status"] as? String) ?? ""
        let texto = (mensaje + " " + estado + " " + String(describing: error?["details"] ?? "")).lowercased()

        if codigo == 429 || estado == "RESOURCE_EXHAUSTED" { return .limiteAlcanzado }
        if texto.contains("api key") || texto.contains("api_key") || estado == "UNAUTHENTICATED" || codigo == 401 {
            return .claveInvalida
        }
        if codigo == 404 || estado == "NOT_FOUND" { return .modeloNoDisponible(modelo) }
        if codigo == 403 || estado == "PERMISSION_DENIED" { return .claveInvalida }
        if codigo == 400 {
            let detalle = mensaje.isEmpty ? "petición no válida" : String(mensaje.prefix(180))
            return .peticionInvalida(detalle)
        }
        if codigo >= 500 { return .servidor(codigo) }
        return .desconocido("Error \(codigo) de Gemini. \(String(mensaje.prefix(180)))")
    }
}

// MARK: - Límites (429)

/// Lo que dice un 429 de Gemini sobre el límite alcanzado.
struct InfoLimite: Equatable {
    /// True si es la cuota diaria (`quotaId` con «PerDay»): no tiene sentido
    /// reintentar ese modelo hoy.
    var diario: Bool
    /// Espera sugerida por Google (`RetryInfo.retryDelay`), en segundos.
    var espera: TimeInterval?
}

extension LectorIA {
    /// Lee `error.details` de un 429: `google.rpc.QuotaFailure` (con
    /// `violations[].quotaId`) y `google.rpc.RetryInfo` (con `retryDelay`,
    /// p. ej. "27s"). Tolera un 429 sin detalles (Google a veces no los manda).
    static func infoLimite(_ cuerpo: Data) -> InfoLimite {
        let error = (try? JSONSerialization.jsonObject(with: cuerpo) as? [String: Any])?["error"] as? [String: Any]
        let detalles = (error?["details"] as? [[String: Any]]) ?? []
        var diario = false
        var espera: TimeInterval?
        for d in detalles {
            let tipo = (d["@type"] as? String) ?? ""
            if tipo.hasSuffix("RetryInfo"), let texto = d["retryDelay"] as? String {
                espera = segundos(texto)
            }
            if let violaciones = d["violations"] as? [[String: Any]] {
                for v in violaciones {
                    let id = ((v["quotaId"] as? String) ?? "") + " " + ((v["quotaMetric"] as? String) ?? "")
                    if id.lowercased().contains("perday") { diario = true }
                }
            }
        }
        return InfoLimite(diario: diario, espera: espera)
    }

    /// "27s" o "1.5s" → segundos.
    static func segundos(_ duracion: String) -> TimeInterval? {
        let limpio = duracion.trimmingCharacters(in: .whitespaces)
        guard limpio.hasSuffix("s"), let n = Double(limpio.dropLast()), n.isFinite, n >= 0 else { return nil }
        return n
    }
}

// MARK: - Groq (respaldo opcional, API compatible con OpenAI)

extension LectorIA {
    /// Convierte un esquema de Gemini al modo estricto de Groq: todos los
    /// campos obligatorios, `additionalProperties: false` y sin
    /// `minimum`/`maximum` (los rangos se validan igual al leer la respuesta).
    static func esquemaEstricto(_ esquema: [String: Any]) -> [String: Any] {
        var e = esquema
        e.removeValue(forKey: "minimum")
        e.removeValue(forKey: "maximum")
        if let propiedades = e["properties"] as? [String: Any] {
            var nuevas: [String: Any] = [:]
            for (k, v) in propiedades {
                nuevas[k] = (v as? [String: Any]).map(esquemaEstricto) ?? v
            }
            e["properties"] = nuevas
            e["required"] = nuevas.keys.sorted()
            e["additionalProperties"] = false
        }
        if let items = e["items"] as? [String: Any] {
            e["items"] = esquemaEstricto(items)
        }
        return e
    }

    /// Cuerpo para `POST https://api.groq.com/openai/v1/chat/completions`
    /// (https://console.groq.com/docs/vision y /docs/structured-outputs,
    /// consultadas el 16-nov-2026): imagen en base64 como `data:` URL,
    /// JSON Schema estricto y sin razonamiento (`reasoning_effort: none`).
    static func cuerpoGroq(modelo: String, sistema: String, texto: String, imagenJPEGBase64: String?,
                           esquema: [String: Any]?, nombreEsquema: String = "respuesta") throws -> Data {
        var contenidoUsuario: [[String: Any]] = [["type": "text", "text": texto]]
        if let imagen = imagenJPEGBase64 {
            contenidoUsuario.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64," + imagen]])
        }
        var cuerpo: [String: Any] = [
            "model": modelo,
            "messages": [
                ["role": "system", "content": sistema],
                ["role": "user", "content": contenidoUsuario]
            ] as [[String: Any]],
            "reasoning_effort": "none",
            "temperature": 0.2,
            "max_completion_tokens": 2048,
            "stream": false
        ]
        if let esquema {
            cuerpo["response_format"] = [
                "type": "json_schema",
                "json_schema": ["name": nombreEsquema, "strict": true, "schema": esquemaEstricto(esquema)] as [String: Any]
            ] as [String: Any]
        }
        return try JSONSerialization.data(withJSONObject: cuerpo, options: [])
    }

    /// Cuerpo de Groq para el coach (texto libre, sin esquema).
    static func cuerpoGroqCoach(modelo: String, mensajes: [MensajeCoach], contexto: String?) throws -> Data {
        var lista: [[String: Any]] = [["role": "system", "content": sistemaCoach(contexto: contexto)]]
        for t in turnosCoach(mensajes) {
            lista.append(["role": t.rol == "user" ? "user" : "assistant", "content": t.texto])
        }
        let cuerpo: [String: Any] = ["model": modelo, "messages": lista, "reasoning_effort": "none",
                                     "max_completion_tokens": maxTokensCoach, "stream": false]
        return try JSONSerialization.data(withJSONObject: cuerpo, options: [])
    }

    /// Texto de `choices[0].message.content` de una respuesta de Groq.
    static func textoDeRespuestaGroq(_ datos: Data) throws -> String {
        guard let raiz = try? JSONSerialization.jsonObject(with: datos) as? [String: Any] else {
            throw ErrorIA.jsonInvalido("la respuesta del servidor no es JSON")
        }
        guard let opciones = raiz["choices"] as? [[String: Any]], let primera = opciones.first,
              let mensaje = primera["message"] as? [String: Any] else {
            throw ErrorIA.respuestaVacia
        }
        let texto = (mensaje["content"] as? String) ?? ""
        if texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let fin = primera["finish_reason"] as? String, fin != "stop" { throw ErrorIA.bloqueado(fin) }
            throw ErrorIA.respuestaVacia
        }
        return texto
    }

    /// Error HTTP de Groq. Cuerpo típico: {"error": {"message": "…", "type": "…", "code": "…"}}.
    static func errorHTTPGroq(codigo: Int, cuerpo: Data) -> ErrorIA {
        let error = (try? JSONSerialization.jsonObject(with: cuerpo) as? [String: Any])?["error"] as? [String: Any]
        let mensaje = (error?["message"] as? String) ?? ""
        switch codigo {
        case 401, 403: return .claveGroqInvalida
        case 429: return .limiteAlcanzado
        case 400, 413, 422:
            return .peticionInvalida("Groq: " + (mensaje.isEmpty ? "petición no válida" : String(mensaje.prefix(180))))
        case 404: return .modeloNoDisponible(PoliticaIA.modeloGroq)
        case 500...: return .servidor(codigo)
        default: return .desconocido("Error \(codigo) de Groq. \(String(mensaje.prefix(180)))")
        }
    }
}

// MARK: - Etiqueta nutricional del envase

/// Valores leídos por la IA de la tabla nutricional de un envase.
struct EtiquetaLeida: Equatable {
    var nombre: String
    /// Siempre por 100 g (o 100 ml); la IA convierte si la etiqueta da "por porción".
    var por100g: Nutrientes
    /// Tamaño de porción del envase en gramos, si aparece.
    var porcionGramos: Double?
    var confianza: Double
    /// Quién la leyó (iPhone, memoria, Gemini o Groq).
    var capa: CapaIA? = nil
}

extension LectorIA {

    static let instruccionesEtiqueta = """
    La foto muestra la tabla de información nutricional de un producto envasado (probablemente en español, de Perú).
    Lee los valores que aparecen; no inventes ninguno.

    Devuelve:
    - "es_etiqueta": true solo si se ve una tabla nutricional legible; si no, false y el resto en 0.
    - "nombre": el nombre del producto si se ve; si no, vacío.
    - "porcion_g": el tamaño de la porción en gramos (o ml) si aparece; si no, 0.
    - "kcal_100g", "proteina_100g", "carbohidratos_100g", "grasas_100g": valores POR 100 g (o 100 ml).
      Si la tabla solo da valores por porción, conviértelos a 100 g con el tamaño de la porción.
      Si la energía solo está en kJ, divídela entre 4,184.
    - "azucares_100g", "fibra_100g" (gramos) y "sodio_mg_100g" (miligramos) por 100 g; usa 0 si no aparecen.
    - "confianza": de 0 a 1, qué tan seguro estás de haber leído bien los números.
    Responde solo con el JSON pedido.
    """

    static var esquemaEtiqueta: [String: Any] {
        let numero: (String, Double, Double) -> [String: Any] = { descripcion, minimo, maximo in
            ["type": "number", "description": descripcion, "minimum": minimo, "maximum": maximo]
        }
        let propiedades: [String: Any] = [
            "es_etiqueta": ["type": "boolean", "description": "Se ve una tabla nutricional legible"],
            "nombre": ["type": "string", "description": "Nombre del producto o vacío"],
            "porcion_g": numero("Porción en gramos (0 si no aparece)", 0, 5000),
            "kcal_100g": numero("kcal por 100 g", 0, 900),
            "proteina_100g": numero("Proteína por 100 g", 0, 100),
            "carbohidratos_100g": numero("Carbohidratos por 100 g", 0, 100),
            "grasas_100g": numero("Grasas por 100 g", 0, 100),
            "azucares_100g": numero("Azúcares por 100 g (0 si no aparece)", 0, 100),
            "fibra_100g": numero("Fibra por 100 g (0 si no aparece)", 0, 100),
            "sodio_mg_100g": numero("Sodio en mg por 100 g (0 si no aparece)", 0, 40000),
            "confianza": numero("Confianza de 0 a 1", 0, 1)
        ]
        return [
            "type": "object",
            "properties": propiedades,
            "required": ["es_etiqueta", "nombre", "porcion_g", "kcal_100g", "proteina_100g",
                         "carbohidratos_100g", "grasas_100g", "confianza"]
        ]
    }

    static func cuerpoPeticionEtiqueta(imagenJPEGBase64: String, formato: FormatoPeticionIA,
                                       nivelRazonamiento: String? = nil) throws -> Data {
        let datosImagen: [String: Any] = ["mime_type": "image/jpeg", "data": imagenJPEGBase64]
        let partes: [[String: Any]] = [["inline_data": datosImagen], ["text": instruccionesEtiqueta]]
        return try cuerpo(partes: partes, esquema: esquemaEtiqueta, formato: formato, nivelRazonamiento: nivelRazonamiento)
    }

    /// Número opcional dentro de un rango; 0 si falta o no tiene sentido.
    static func opcional(_ valor: Any?, _ rango: ClosedRange<Double>) -> Double {
        guard let v = numero(valor), rango.contains(v) else { return 0 }
        return v
    }

    /// Lee y valida el JSON de la etiqueta.
    static func etiqueta(desde texto: String) throws -> EtiquetaLeida {
        let limpio = limpiarBloqueCodigo(texto)
        guard let datos = limpio.data(using: .utf8),
              let raiz = try? JSONSerialization.jsonObject(with: datos) as? [String: Any] else {
            throw ErrorIA.jsonInvalido("no es un JSON válido")
        }
        let esEtiqueta = (raiz["es_etiqueta"] as? Bool) ?? ((raiz["es_etiqueta"] as? NSNumber)?.boolValue ?? false)
        guard esEtiqueta else { throw ErrorIA.sinEtiqueta }
        guard let kcal = numero(raiz["kcal_100g"]), (0...900).contains(kcal),
              let p = numero(raiz["proteina_100g"]), (0...100).contains(p),
              let c = numero(raiz["carbohidratos_100g"]), (0...100).contains(c),
              let g = numero(raiz["grasas_100g"]), (0...100).contains(g) else {
            throw ErrorIA.jsonInvalido("los valores de la etiqueta no son válidos")
        }
        let nombre = (raiz["nombre"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let porcion = numero(raiz["porcion_g"]).flatMap { Porciones.esValido($0) ? $0 : nil }
        return EtiquetaLeida(
            nombre: nombre.isEmpty ? "" : Formato.primeraMayuscula(nombre),
            por100g: Nutrientes(kcal: kcal, proteina: p, carbohidratos: c, grasas: g,
                                fibra: opcional(raiz["fibra_100g"], 0...100),
                                sodio: opcional(raiz["sodio_mg_100g"], 0...40000),
                                azucar: opcional(raiz["azucares_100g"], 0...100)),
            porcionGramos: porcion,
            confianza: min(max(numero(raiz["confianza"]) ?? 0.5, 0), 1)
        )
    }
}

// MARK: - Coach

extension LectorIA {

    static let instruccionesCoach = """
    Eres «Coach Sazón», un asistente de nutrición dentro de una app personal de registro de comidas en Perú.
    Respondes en español de Perú, en tono cercano y práctico, con respuestas cortas (máximo 8 líneas) y \
    sugerencias concretas con alimentos peruanos comunes cuando sirva.
    Reglas: no eres médico ni nutricionista; no diagnostiques ni indiques tratamientos. Si la persona menciona \
    síntomas, enfermedades, embarazo, trastornos de la conducta alimentaria o metas extremas, recomienda con \
    amabilidad consultar a un profesional de salud. No propongas dietas por debajo de 1200 kcal. Las calorías \
    son estimaciones. Si no sabes algo, dilo.
    """

    /// Resumen del día que se envía solo si lo permites en Ajustes (sin nombre ni datos personales).
    static func contextoCoach(consumido: Nutrientes, meta: Nutrientes?, aguaMl: Double, metaAguaMl: Double,
                              objetivo: Objetivo?, dieta: TipoDieta?) -> String {
        var lineas = ["Resumen de hoy (estimaciones):"]
        lineas.append("- Consumido: \(Formato.entero(consumido.kcal)) kcal, proteína \(Formato.entero(consumido.proteina)) g, carbohidratos \(Formato.entero(consumido.carbohidratos)) g, grasas \(Formato.entero(consumido.grasas)) g.")
        if let meta {
            lineas.append("- Meta: \(Formato.entero(meta.kcal)) kcal, proteína \(Formato.entero(meta.proteina)) g, carbohidratos \(Formato.entero(meta.carbohidratos)) g, grasas \(Formato.entero(meta.grasas)) g.")
        }
        lineas.append("- Agua: \(Formato.entero(aguaMl)) de \(Formato.entero(metaAguaMl)) ml.")
        if let objetivo { lineas.append("- Objetivo: \(objetivo.nombre.lowercased()).") }
        if let dieta { lineas.append("- Tipo de dieta: \(dieta.nombre.lowercased()).") }
        return lineas.joined(separator: "\n")
    }

    /// Tope de la respuesta del coach. Es amplio a propósito: la guía de
    /// Gemini advierte que un tope pequeño puede cortar la respuesta si el
    /// modelo razona; el razonamiento se limita aparte (`thinkingLevel`).
    static let maxTokensCoach = 1024

    /// Turnos de la conversación ya ordenados. Gemini espera que la
    /// conversación empiece con la persona y que los turnos se alternen. Si
    /// una respuesta falló, quedan dos mensajes tuyos seguidos: se unen en
    /// uno. Si el recorte deja primero al coach, ese mensaje se omite.
    static func turnosCoach(_ mensajes: [MensajeCoach], limite: Int = 12) -> [(rol: String, texto: String)] {
        var turnos: [(rol: String, texto: String)] = []
        for m in mensajes.suffix(limite) {
            let rol = m.autor == .usuario ? "user" : "model"
            if turnos.isEmpty && rol == "model" { continue }
            if let ultimo = turnos.last, ultimo.rol == rol {
                turnos[turnos.count - 1].texto += "\n\n" + m.texto
            } else {
                turnos.append((rol, m.texto))
            }
        }
        return turnos
    }

    /// Instrucciones del coach más el resumen opcional del día.
    static func sistemaCoach(contexto: String?) -> String {
        var sistema = instruccionesCoach
        if let contexto, !contexto.isEmpty { sistema += "\n\n" + contexto }
        return sistema
    }

    /// Cuerpo para conversar: instrucciones, contexto opcional y los últimos mensajes.
    static func cuerpoCoach(mensajes: [MensajeCoach], contexto: String?, limite: Int = 12,
                            nivelRazonamiento: String? = nil) throws -> Data {
        var contenidos: [[String: Any]] = []
        for t in turnosCoach(mensajes, limite: limite) {
            let parte: [String: Any] = ["text": t.texto]
            contenidos.append(["role": t.rol, "parts": [parte]])
        }
        let parteSistema: [String: Any] = ["text": sistemaCoach(contexto: contexto)]
        let instrucciones: [String: Any] = ["parts": [parteSistema]]
        var configuracion: [String: Any] = ["maxOutputTokens": maxTokensCoach]
        if let nivelRazonamiento { configuracion["thinkingConfig"] = ["thinkingLevel": nivelRazonamiento] }
        let cuerpo: [String: Any] = ["systemInstruction": instrucciones, "contents": contenidos,
                                     "generationConfig": configuracion]
        return try JSONSerialization.data(withJSONObject: cuerpo, options: [])
    }
}
