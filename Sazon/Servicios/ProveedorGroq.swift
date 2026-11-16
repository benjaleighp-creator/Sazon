import Foundation

/// Respaldo opcional: Groq con la clave que pongas en Ajustes (se guarda
/// en el Llavero, igual que la de Gemini). Solo se usa si Gemini está
/// saturado o sin cuota; sin clave de Groq, la app funciona igual.
/// Documentación (consultada el 16-nov-2026):
/// - https://console.groq.com/docs/vision — endpoint
///   `POST https://api.groq.com/openai/v1/chat/completions`, cabecera
///   `Authorization: Bearer`, imagen en base64 como `data:image/jpeg;base64,…`,
///   modelo con visión `qwen/qwen3.8-27b` (en «Preview»), hasta 20 MB.
/// - https://console.groq.com/docs/structured-outputs — `response_format`
///   con `json_schema` y `strict: true` (qwen3.8-27b lo admite).
/// - https://console.groq.com/docs/reasoning — `reasoning_effort: "none"`
///   desactiva el razonamiento en Qwen 3.8 27B.
struct ProveedorGroq: ProveedorIA {
    let clave: String
    var modelo: String = PoliticaIA.modeloGroq
    var sesion: SesionRed = RedIA.sesion

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
        let cuerpo = try LectorIA.cuerpoGroq(modelo: modelo, sistema: "Responde solo con el JSON pedido.",
                                             texto: LectorIA.instruccionesEtiqueta,
                                             imagenJPEGBase64: fotoJPEG.base64EncodedString(),
                                             esquema: LectorIA.esquemaEtiqueta, nombreEsquema: "etiqueta")
        var e = try LectorIA.etiqueta(desde: try await pedir(cuerpo, tope: PoliticaIA.tiempoTotal))
        e.capa = .groq
        return e
    }

    func conversar(mensajes: [MensajeCoach], contexto: String?) async throws -> String {
        let cuerpo = try LectorIA.cuerpoGroqCoach(modelo: modelo, mensajes: mensajes, contexto: contexto)
        return LectorIA.respuestaCoach(try await pedir(cuerpo, tope: PoliticaIA.tiempoTotal))
    }

    private func analisis(_ tipo: LectorIA.TipoAnalisis, texto: String?, imagen: String?) async throws -> AnalisisIA {
        let cuerpo = try LectorIA.cuerpoGroq(modelo: modelo, sistema: "Responde solo con el JSON pedido.",
                                             texto: LectorIA.pedido(texto: texto, tipo: tipo), imagenJPEGBase64: imagen,
                                             esquema: LectorIA.esquema(conCaja: tipo.conCaja), nombreEsquema: "alimentos")
        var a = try LectorIA.analisis(desde: try await pedir(cuerpo, tope: PoliticaIA.tiempoTotal))
        a.capa = .groq
        return a
    }

    /// Una sola llamada (sin reintentos: el presupuesto lo lleva quien la usa).
    func pedir(_ cuerpo: Data, tope: TimeInterval) async throws -> String {
        guard let url = URL(string: PoliticaIA.urlGroq), url.scheme == "https" else {
            throw ErrorIA.desconocido("Dirección de Groq no válida.")
        }
        var peticion = URLRequest(url: url)
        peticion.httpMethod = "POST"
        peticion.timeoutInterval = max(tope, 1)
        peticion.setValue("application/json", forHTTPHeaderField: "Content-Type")
        peticion.setValue("Bearer " + clave, forHTTPHeaderField: "Authorization")
        peticion.httpBody = cuerpo
        let (datos, respuesta) = try await RedIA.enviar(peticion, con: sesion)
        guard let http = respuesta as? HTTPURLResponse else {
            throw ErrorIA.desconocido("Respuesta inesperada de Groq.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LectorIA.errorHTTPGroq(codigo: http.statusCode, cuerpo: datos)
        }
        return try LectorIA.textoDeRespuestaGroq(datos)
    }
}
