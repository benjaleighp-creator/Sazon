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

    static func == (a: AlimentoIdentificado, b: AlimentoIdentificado) -> Bool {
        a.nombre == b.nombre && a.gramos == b.gramos && a.confianza == b.confianza &&
        a.medida == b.medida && a.cantidadMedida == b.cantidadMedida && a.por100g == b.por100g
    }
}

/// Errores de la IA, con un mensaje claro en español.
enum ErrorIA: Error, Equatable {
    case sinClave
    case avisoNoAceptado
    case sinInternet
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

    var titulo: String {
        switch self {
        case .sinClave: return "Falta tu clave de Gemini"
        case .avisoNoAceptado: return "Falta aceptar el aviso de privacidad"
        case .sinInternet: return "Sin conexión"
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
        }
    }
}

/// Todo lo que no toca la red: el texto de las instrucciones, el esquema
/// JSON, el cuerpo de la petición y la lectura de la respuesta. Así se
/// puede probar sin internet.
enum LectorIA {

    // MARK: - Petición

    static let instrucciones = """
    Eres el asistente de una app personal de registro de comidas en Perú. \
    Identifica cada alimento o bebida que aparece en la foto o en el texto.

    Para cada alimento da:
    - "nombre": nombre corto y genérico en español de Perú, como aparecería en una tabla de composición de alimentos (por ejemplo «Pan francés», «Palta», «Arroz blanco cocido», «Café pasado sin azúcar»). Si es un plato peruano típico que no se separa bien (por ejemplo lomo saltado o ají de gallina), dalo como un solo plato.
    - "gramos": porción total estimada en gramos (en bebidas, mililitros como gramos).
    - "confianza": de 0 a 1, qué tan seguro estás de haber identificado bien el alimento y la porción.
    - "medida", "cantidad" y "gramos_por_medida": si es natural contarlo en una medida casera (unidad, taza, vaso, cucharada, cucharadita, rebanada, plato), la medida en singular, cuántas y cuántos gramos pesa una. Si no aplica, usa medida vacía y cantidad 0.
    - "kcal_100g", "proteina_100g", "carbohidratos_100g", "grasas_100g": tu estimación por 100 g.

    Reglas: no inventes alimentos que no se ven o no se mencionan. Si el texto da cantidades («2 panes»), respétalas. \
    Si no hay comida, devuelve la lista vacía. Responde solo con el JSON pedido.
    """

    /// Esquema JSON de la respuesta (palabras clave admitidas por Gemini:
    /// type, properties, required, items, minimum, maximum, description).
    static var esquema: [String: Any] {
        let numero: (String, Double, Double) -> [String: Any] = { descripcion, minimo, maximo in
            ["type": "number", "description": descripcion, "minimum": minimo, "maximum": maximo]
        }
        let alimento: [String: Any] = [
            "type": "object",
            "properties": [
                "nombre": ["type": "string", "description": "Nombre corto en español de Perú"],
                "gramos": numero("Porción total en gramos", 0, 5000),
                "confianza": numero("Confianza de 0 a 1", 0, 1),
                "medida": ["type": "string", "description": "Medida casera en singular o vacío"],
                "cantidad": numero("Cuántas medidas caseras (0 si no aplica)", 0, 100),
                "gramos_por_medida": numero("Gramos de una medida casera (0 si no aplica)", 0, 5000),
                "kcal_100g": numero("kcal por 100 g", 0, 900),
                "proteina_100g": numero("Proteína por 100 g", 0, 100),
                "carbohidratos_100g": numero("Carbohidratos por 100 g", 0, 100),
                "grasas_100g": numero("Grasas por 100 g", 0, 100)
            ] as [String: Any],
            "required": ["nombre", "gramos", "confianza", "medida", "cantidad", "gramos_por_medida",
                         "kcal_100g", "proteina_100g", "carbohidratos_100g", "grasas_100g"]
        ]
        return [
            "type": "object",
            "properties": [
                "alimentos": ["type": "array", "items": alimento] as [String: Any]
            ] as [String: Any],
            "required": ["alimentos"]
        ]
    }

    /// Cuerpo JSON para `models/{modelo}:generateContent`.
    /// - texto: lo que escribiste o dictaste (nil si es solo foto).
    /// - imagenJPEGBase64: la foto ya comprimida, en base64 (nil si es texto).
    static func cuerpoPeticion(texto: String?, imagenJPEGBase64: String?, formato: FormatoPeticionIA) throws -> Data {
        var partes: [[String: Any]] = []
        if let imagen = imagenJPEGBase64 {
            let datosImagen: [String: Any] = ["mime_type": "image/jpeg", "data": imagen]
            partes.append(["inline_data": datosImagen])
        }
        var pedido = instrucciones
        if let texto, !texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pedido += "\n\nLo que comí: \(texto)"
        } else {
            pedido += "\n\nIdentifica los alimentos de la foto."
        }
        partes.append(["text": pedido])
        return try cuerpo(partes: partes, esquema: esquema, formato: formato)
    }

    /// Arma el cuerpo de `generateContent` con las partes y el esquema pedido.
    static func cuerpo(partes: [[String: Any]], esquema: [String: Any], formato: FormatoPeticionIA) throws -> Data {
        let configuracion: [String: Any]
        switch formato {
        case .actual:
            // Forma REST de la guía actual de salidas estructuradas.
            let formatoTexto: [String: Any] = ["mimeType": "APPLICATION_JSON", "schema": esquema]
            let formatoRespuesta: [String: Any] = ["text": formatoTexto]
            configuracion = ["responseFormat": formatoRespuesta]
        case .clasico:
            configuracion = ["responseMimeType": "application/json", "responseJsonSchema": esquema]
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
            resultado.append(AlimentoIdentificado(
                nombre: Formato.primeraMayuscula(nombre),
                gramos: gramos,
                confianza: confianza,
                medida: medida,
                cantidadMedida: cantidad,
                por100g: Nutrientes(kcal: kcal, proteina: p, carbohidratos: c, grasas: g)
            ))
        }
        return resultado
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

// MARK: - Etiqueta nutricional del envase

/// Valores leídos por la IA de la tabla nutricional de un envase.
struct EtiquetaLeida: Equatable {
    var nombre: String
    /// Siempre por 100 g (o 100 ml); la IA convierte si la etiqueta da "por porción".
    var por100g: Nutrientes
    /// Tamaño de porción del envase en gramos, si aparece.
    var porcionGramos: Double?
    var confianza: Double
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
            "confianza": numero("Confianza de 0 a 1", 0, 1)
        ]
        return [
            "type": "object",
            "properties": propiedades,
            "required": ["es_etiqueta", "nombre", "porcion_g", "kcal_100g", "proteina_100g",
                         "carbohidratos_100g", "grasas_100g", "confianza"]
        ]
    }

    static func cuerpoPeticionEtiqueta(imagenJPEGBase64: String, formato: FormatoPeticionIA) throws -> Data {
        let datosImagen: [String: Any] = ["mime_type": "image/jpeg", "data": imagenJPEGBase64]
        let partes: [[String: Any]] = [["inline_data": datosImagen], ["text": instruccionesEtiqueta]]
        return try cuerpo(partes: partes, esquema: esquemaEtiqueta, formato: formato)
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
            por100g: Nutrientes(kcal: kcal, proteina: p, carbohidratos: c, grasas: g),
            porcionGramos: porcion,
            confianza: min(max(numero(raiz["confianza"]) ?? 0.5, 0), 1)
        )
    }
}
