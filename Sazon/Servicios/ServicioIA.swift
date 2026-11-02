import Foundation

// Conexión con la IA en un solo archivo. Las pantallas solo conocen el
// protocolo `ProveedorIA`; para cambiar de proveedor en el futuro basta con
// escribir otra implementación y devolverla en `ServicioIA.proveedorActual`.

/// Lo que la app necesita de cualquier IA: convertir un texto o una foto
/// en una lista de alimentos con porciones.
protocol ProveedorIA {
    func analizar(texto: String) async throws -> [AlimentoIdentificado]
    func analizar(fotoJPEG: Data) async throws -> [AlimentoIdentificado]
    /// Lee la tabla nutricional de un envase (para productos que no están
    /// en Open Food Facts).
    func leerEtiqueta(fotoJPEG: Data) async throws -> EtiquetaLeida
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
/// - Una sola llamada por registro y sin reintentos automáticos: si falla,
///   la app muestra el error y tú decides si vuelves a intentarlo.
struct ProveedorGemini: ProveedorIA {
    let clave: String
    let modelo: String
    let formato: FormatoPeticionIA
    var sesion: URLSession = .shared

    static let base = "https://generativelanguage.googleapis.com/v1beta/models/"

    func analizar(texto: String) async throws -> [AlimentoIdentificado] {
        let cuerpo = try LectorIA.cuerpoPeticion(texto: texto, imagenJPEGBase64: nil, formato: formato)
        return try await enviar(cuerpo)
    }

    func analizar(fotoJPEG: Data) async throws -> [AlimentoIdentificado] {
        let cuerpo = try LectorIA.cuerpoPeticion(texto: nil, imagenJPEGBase64: fotoJPEG.base64EncodedString(), formato: formato)
        return try await enviar(cuerpo)
    }

    func leerEtiqueta(fotoJPEG: Data) async throws -> EtiquetaLeida {
        let cuerpo = try LectorIA.cuerpoPeticionEtiqueta(imagenJPEGBase64: fotoJPEG.base64EncodedString(), formato: formato)
        return try LectorIA.etiqueta(desde: try await pedirTexto(cuerpo))
    }

    private func enviar(_ cuerpo: Data) async throws -> [AlimentoIdentificado] {
        try LectorIA.alimentos(desde: try await pedirTexto(cuerpo))
    }

    /// Hace la única llamada a Gemini y devuelve el texto de la respuesta.
    private func pedirTexto(_ cuerpo: Data) async throws -> String {
        let nombre = modelo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let ruta = nombre.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: Self.base + ruta + ":generateContent") else {
            throw ErrorIA.modeloNoDisponible(nombre)
        }
        var peticion = URLRequest(url: url)
        peticion.httpMethod = "POST"
        peticion.timeoutInterval = 60
        peticion.setValue("application/json", forHTTPHeaderField: "Content-Type")
        peticion.setValue(clave, forHTTPHeaderField: "x-goog-api-key")
        peticion.httpBody = cuerpo

        let resultado: (Data, URLResponse)
        do {
            resultado = try await sesion.data(for: peticion)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                 .cannotFindHost, .cannotConnectToHost, .timedOut, .internationalRoamingOff:
                throw ErrorIA.sinInternet
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
