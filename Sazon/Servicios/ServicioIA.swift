import Foundation

// Conexión con la IA en un solo archivo. Las pantallas solo conocen el
// protocolo `ProveedorIA`; para cambiar de proveedor en el futuro basta con
// escribir otra implementación y devolverla en `ServicioIA.proveedorActual`.

/// Lo que la app necesita de cualquier IA: convertir un texto o una foto
/// en una lista de alimentos con porciones (y posibles ingredientes ocultos).
protocol ProveedorIA {
    func analizar(texto: String) async throws -> AnalisisIA
    func analizar(fotoJPEG: Data) async throws -> AnalisisIA
    /// Lee la tabla nutricional de un envase (para productos que no están
    /// en Open Food Facts).
    func leerEtiqueta(fotoJPEG: Data) async throws -> EtiquetaLeida
    /// Conversación con el coach (texto libre).
    func conversar(mensajes: [MensajeCoach], contexto: String?) async throws -> String
}

enum ServicioIA {
    /// Proveedor que usan las pantallas. Lee la clave del Llavero y el modelo
    /// de los ajustes en el momento de cada petición.
    @MainActor
    static func proveedorActual(_ datos: DatosApp) throws -> ProveedorIA {
        guard datos.avisoIAAceptado else { throw ErrorIA.avisoNoAceptado }
        guard let clave = Llavero.leerClave() else { throw ErrorIA.sinClave }
        return ProveedorGemini(clave: clave, modelo: datos.modeloIA, formato: datos.formatoPeticionIA)
    }
}

/// API de Google Gemini (plan gratuito de Google AI Studio).
/// Documentación: https://ai.google.dev/gemini-api/docs
/// - Endpoint: POST https://generativelanguage.googleapis.com/v1beta/models/{modelo}:generateContent
/// - Autenticación: cabecera `x-goog-api-key`.
/// - Si Google está saturado (503 y otros 5xx), reintenta el mismo modelo
///   una vez y luego prueba, en orden, los modelos de respaldo gratuitos.
///   Un 429 (límite del modelo) o un 404 (modelo retirado) pasan directo
///   al siguiente modelo. Clave inválida o sin internet no se reintentan.
struct ProveedorGemini: ProveedorIA {
    let clave: String
    let modelo: String
    let formato: FormatoPeticionIA
    var sesion: URLSession = .shared

    static let base = "https://generativelanguage.googleapis.com/v1beta/models/"

    func analizar(texto: String) async throws -> AnalisisIA {
        let cuerpo = try LectorIA.cuerpoPeticion(texto: texto, imagenJPEGBase64: nil, formato: formato)
        return try await enviar(cuerpo)
    }

    func analizar(fotoJPEG: Data) async throws -> AnalisisIA {
        let cuerpo = try LectorIA.cuerpoPeticion(texto: nil, imagenJPEGBase64: fotoJPEG.base64EncodedString(), formato: formato)
        return try await enviar(cuerpo)
    }

    func leerEtiqueta(fotoJPEG: Data) async throws -> EtiquetaLeida {
        let cuerpo = try LectorIA.cuerpoPeticionEtiqueta(imagenJPEGBase64: fotoJPEG.base64EncodedString(), formato: formato)
        return try LectorIA.etiqueta(desde: try await pedirTexto(cuerpo))
    }

    func conversar(mensajes: [MensajeCoach], contexto: String?) async throws -> String {
        let cuerpo = try LectorIA.cuerpoCoach(mensajes: mensajes, contexto: contexto)
        let texto = try await pedirTexto(cuerpo)
        return texto.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func enviar(_ cuerpo: Data) async throws -> AnalisisIA {
        try LectorIA.analisis(desde: try await pedirTexto(cuerpo))
    }

    /// Modelos que se prueban si el elegido falla por saturación o límite.
    /// En noviembre de 2026 figuraban como gratuitos en
    /// https://ai.google.dev/gemini-api/docs/pricing — si Google los retira,
    /// simplemente se saltan (404) y se sigue con el siguiente.
    /// Segundos (aprox.) tras los cuales ya no se prueban más modelos.
    static let esperaMaxima: TimeInterval = 100

    static let modelosRespaldo = ["gemini-3.5-flash-lite", "gemini-3.6-flash", "gemini-3.1-flash-lite"]

    /// Prueba el modelo elegido y, si Google está saturado, los de respaldo.
    private func pedirTexto(_ cuerpo: Data) async throws -> String {
        let elegido = modelo.trimmingCharacters(in: .whitespacesAndNewlines)
        // Si el campo del modelo quedó vacío, se usa el de por defecto.
        var cadena = [elegido.isEmpty ? DatosApp.modeloPorDefecto : elegido]
        for m in Self.modelosRespaldo where !cadena.contains(m) { cadena.append(m) }

        // Tope de espera total: con Gemini saturado, probar todos los
        // modelos podía tardar varios minutos.
        let inicio = Date()
        var primerError: Error?
        recorrido: for (indice, nombre) in cadena.enumerated() {
            let intentos = indice == 0 ? 2 : 1
            for intento in 1...intentos {
                try Task.checkCancellation()
                if (indice > 0 || intento > 1), Date().timeIntervalSince(inicio) > Self.esperaMaxima {
                    break recorrido
                }
                do {
                    return try await pedirTexto(cuerpo, modelo: nombre)
                } catch let error as ErrorIA {
                    switch error {
                    case .servidor:
                        if primerError == nil { primerError = error }
                        if intento < intentos {
                            try await Task.sleep(nanoseconds: 2_000_000_000)
                        }
                        continue
                    case .conexionLenta:
                        // Ya se esperó una vez: no se repite el mismo modelo,
                        // se pasa directo al siguiente.
                        if primerError == nil { primerError = error }
                    case .limiteAlcanzado, .modeloNoDisponible, .peticionInvalida:
                        // Propio de este modelo: probar el siguiente. Si es el
                        // elegido y no hay más, se muestra este error.
                        if primerError == nil { primerError = error }
                    default:
                        throw error
                    }
                }
                break
            }
        }
        throw primerError ?? ErrorIA.servidor(503)
    }

    /// Hace una llamada a Gemini con un modelo y devuelve el texto de la respuesta.
    private func pedirTexto(_ cuerpo: Data, modelo nombre: String) async throws -> String {
        guard let ruta = nombre.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: Self.base + ruta + ":generateContent") else {
            throw ErrorIA.modeloNoDisponible(nombre)
        }
        var peticion = URLRequest(url: url)
        peticion.httpMethod = "POST"
        peticion.timeoutInterval = 45
        peticion.setValue("application/json", forHTTPHeaderField: "Content-Type")
        peticion.setValue(clave, forHTTPHeaderField: "x-goog-api-key")
        peticion.httpBody = cuerpo

        let resultado: (Data, URLResponse)
        do {
            resultado = try await sesion.data(for: peticion)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
                // El iPhone de verdad no tiene red.
                throw ErrorIA.sinInternet
            case .timedOut, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                // Hay red, pero Gemini tardó o cortó: se reintenta / se prueba otro modelo.
                throw ErrorIA.conexionLenta
            case .cancelled:
                throw CancellationError()
            default:
                throw ErrorIA.desconocido("Error de conexión: \(error.localizedDescription)")
            }
        }
        let (datos, respuesta) = resultado
        guard let http = respuesta as? HTTPURLResponse else {
            throw ErrorIA.desconocido("Respuesta inesperada del servidor.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LectorIA.errorHTTP(codigo: http.statusCode, cuerpo: datos, modelo: nombre)
        }
        return try LectorIA.textoDeRespuesta(datos)
    }
}
