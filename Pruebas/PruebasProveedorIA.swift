import XCTest

/// Sesión de red falsa: devuelve, en orden, las respuestas preparadas y
/// recuerda qué peticiones recibió (nunca sale a internet).
final class SesionFalsa: SesionRed {
    enum Respuesta {
        case http(Int, String)
        case falla(URLError.Code)
    }
    private var pendientes: [Respuesta]
    private(set) var peticiones: [URLRequest] = []
    private let candado = NSLock()

    init(_ respuestas: [Respuesta]) { pendientes = respuestas }

    var llamadas: Int {
        candado.lock(); defer { candado.unlock() }
        return peticiones.count
    }

    func respuesta(a peticion: URLRequest) async throws -> (Data, URLResponse) {
        candado.lock()
        peticiones.append(peticion)
        let siguiente = pendientes.isEmpty ? .http(503, "{}") : pendientes.removeFirst()
        candado.unlock()
        switch siguiente {
        case .http(let codigo, let cuerpo):
            let r = HTTPURLResponse(url: peticion.url!, statusCode: codigo, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (Data(cuerpo.utf8), r)
        case .falla(let codigo):
            throw URLError(codigo)
        }
    }
}

/// Respuestas típicas de Gemini para las pruebas.
enum RespuestasGemini {
    static func ok(_ texto: String) -> String {
        let escapado = texto.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return #"{"candidates": [{"content": {"role": "model", "parts": [{"text": ""# + escapado + #""}]}, "finishReason": "STOP"}]}"#
    }
    static let alimentos = ok(#"{"alimentos": [{"nombre": "Pan", "gramos": 60, "confianza": 0.9, "medida": "", "cantidad": 0, "gramos_por_medida": 0, "kcal_100g": 280, "proteina_100g": 8, "carbohidratos_100g": 57, "grasas_100g": 2, "gramos_min": 50, "gramos_max": 70}], "posibles_ocultos": []}"#)
}

final class PruebasProveedorGemini: XCTestCase {

    private func proveedor(_ sesion: SesionFalsa, modelo: String = "gemini-prueba") -> ProveedorGemini {
        var p = ProveedorGemini(clave: "clave-de-prueba", modelo: modelo, formato: .actual)
        p.sesion = sesion
        return p
    }

    func testRespuestaCorrectaEnUnaLlamada() async throws {
        let sesion = SesionFalsa([.http(200, RespuestasGemini.alimentos)])
        let analisis = try await proveedor(sesion).analizar(texto: "un pan")
        XCTAssertEqual(analisis.alimentos.first?.nombre, "Pan")
        XCTAssertEqual(sesion.llamadas, 1)
        let peticion = try XCTUnwrap(sesion.peticiones.first)
        XCTAssertEqual(peticion.url?.scheme, "https")
        XCTAssertTrue(peticion.url?.absoluteString.contains("gemini-prueba:generateContent") ?? false)
        XCTAssertEqual(peticion.value(forHTTPHeaderField: "x-goog-api-key"), "clave-de-prueba")
        XCTAssertFalse(peticion.url?.absoluteString.contains("clave-de-prueba") ?? true, "La clave nunca va en la URL")
    }

    func testClaveInvalidaNoSeReintenta() async {
        let sesion = SesionFalsa([.http(403, #"{"error": {"code": 403, "status": "PERMISSION_DENIED", "message": "API key not valid"}}"#)])
        do {
            _ = try await proveedor(sesion).analizar(texto: "un pan")
            XCTFail("Debía fallar")
        } catch {
            XCTAssertEqual(error as? ErrorIA, .claveInvalida)
        }
        XCTAssertEqual(sesion.llamadas, 1)
    }

    func testSinInternetNoSeReintenta() async {
        let sesion = SesionFalsa([.falla(.notConnectedToInternet)])
        do {
            _ = try await proveedor(sesion).analizar(texto: "un pan")
            XCTFail("Debía fallar")
        } catch {
            XCTAssertEqual(error as? ErrorIA, .sinInternet)
        }
        XCTAssertEqual(sesion.llamadas, 1)
    }
}

/// Respuestas de error típicas.
enum ErroresGemini {
    static let saturado = #"{"error": {"code": 503, "message": "The model is overloaded.", "status": "UNAVAILABLE"}}"#
    static let porMinuto = #"{"error": {"code": 429, "status": "RESOURCE_EXHAUSTED", "message": "Quota exceeded", "details": [{"@type": "type.googleapis.com/google.rpc.QuotaFailure", "violations": [{"quotaMetric": "generativelanguage.googleapis.com/generate_content_free_tier_requests", "quotaId": "GenerateRequestsPerMinutePerProjectPerModel-FreeTier"}]}, {"@type": "type.googleapis.com/google.rpc.RetryInfo", "retryDelay": "2s"}]}}"#
    static let porDia = #"{"error": {"code": 429, "status": "RESOURCE_EXHAUSTED", "message": "Quota exceeded", "details": [{"@type": "type.googleapis.com/google.rpc.QuotaFailure", "violations": [{"quotaId": "GenerateRequestsPerDayPerProjectPerModel-FreeTier"}]}, {"@type": "type.googleapis.com/google.rpc.RetryInfo", "retryDelay": "27s"}]}}"#
    static let sinDetalles = #"{"error": {"code": 429, "message": "Resource has been exhausted (e.g. check quota).", "status": "RESOURCE_EXHAUSTED"}}"#
    static let invalida = #"{"error": {"code": 400, "message": "Invalid JSON payload", "status": "INVALID_ARGUMENT"}}"#
}

final class PruebasPoliticaIA: XCTestCase {

    private var cuota: RegistroCuota!

    override func setUp() {
        super.setUp()
        let suite = "pruebas.cuota.\(UUID().uuidString)"
        cuota = RegistroCuota(defaults: UserDefaults(suiteName: suite)!)
    }

    private func gemini(_ sesion: SesionFalsa, modelo: String = "gemini-3.8-flash") -> ProveedorGemini {
        var p = ProveedorGemini(clave: "k", modelo: modelo, formato: .actual)
        p.sesion = sesion
        p.cuota = cuota
        p.esperar = { _ in }
        return p
    }

    private func modelos(_ sesion: SesionFalsa) -> [String] {
        sesion.peticiones.compactMap { $0.url?.path.components(separatedBy: "/").last?.replacingOccurrences(of: ":generateContent", with: "") }
    }

    func testMaximoTresLlamadasConGeminiSaturado() async {
        let sesion = SesionFalsa(Array(repeating: .http(503, ErroresGemini.saturado), count: 6))
        do {
            _ = try await gemini(sesion).analizar(texto: "pan")
            XCTFail("Debía fallar")
        } catch {
            XCTAssertEqual(error as? ErrorIA, .servidor(503))
        }
        XCTAssertEqual(sesion.llamadas, PoliticaIA.maxLlamadas, "Nunca más de 3 llamadas por registro")
        XCTAssertEqual(modelos(sesion), ["gemini-3.8-flash", "gemini-3.5-flash-lite", "gemini-3.6-flash"])
    }

    func testSaturadoYLuegoRespondeElRespaldo() async throws {
        let sesion = SesionFalsa([.http(503, ErroresGemini.saturado), .http(200, RespuestasGemini.alimentos)])
        let a = try await gemini(sesion).analizar(texto: "pan")
        XCTAssertEqual(a.capa, .gemini("gemini-3.5-flash-lite"))
        XCTAssertEqual(sesion.llamadas, 2)
    }

    func testNoSePruebanOtrosModelosTrasUn400() async {
        let sesion = SesionFalsa([.http(400, ErroresGemini.invalida), .http(200, RespuestasGemini.alimentos)])
        do {
            _ = try await gemini(sesion).analizar(texto: "pan")
            XCTFail("Debía fallar")
        } catch {
            XCTAssertEqual(error as? ErrorIA, .peticionInvalida("Invalid JSON payload"))
        }
        XCTAssertEqual(sesion.llamadas, 1)
    }

    func testCuotaDiariaMarcaElModeloYNoSeVuelveAProbar() async throws {
        let sesion = SesionFalsa([.http(429, ErroresGemini.porDia), .http(200, RespuestasGemini.alimentos)])
        let a = try await gemini(sesion).analizar(texto: "pan")
        XCTAssertEqual(a.capa, .gemini("gemini-3.5-flash-lite"))
        XCTAssertTrue(cuota.agotados().contains("gemini-3.8-flash"))
        // El siguiente registro ya no llama al modelo agotado.
        let otra = SesionFalsa([.http(200, RespuestasGemini.alimentos)])
        _ = try await gemini(otra).analizar(texto: "palta")
        XCTAssertEqual(modelos(otra), ["gemini-3.5-flash-lite"])
    }

    func testTodosSinCuotaDiaria() async {
        let sesion = SesionFalsa(Array(repeating: .http(429, ErroresGemini.porDia), count: 4))
        do {
            _ = try await gemini(sesion).analizar(texto: "pan")
            XCTFail("Debía fallar")
        } catch {
            XCTAssertEqual(error as? ErrorIA, .cuotaDiariaAgotada)
        }
        XCTAssertEqual(sesion.llamadas, 3)
        // Con todos agotados ni siquiera se llama.
        let otra = SesionFalsa([.http(200, RespuestasGemini.alimentos)])
        cuota.marcarAgotado("gemini-3.1-flash-lite")
        do {
            _ = try await gemini(otra).analizar(texto: "pan")
            XCTFail("Debía fallar")
        } catch {
            XCTAssertEqual(error as? ErrorIA, .cuotaDiariaAgotada)
        }
        XCTAssertEqual(otra.llamadas, 0)
    }

    func testLimitePorMinutoNoMarcaElDia() async throws {
        let sesion = SesionFalsa([.http(429, ErroresGemini.porMinuto), .http(200, RespuestasGemini.alimentos)])
        _ = try await gemini(sesion).analizar(texto: "pan")
        XCTAssertTrue(cuota.agotados().isEmpty)
    }

    func testInfoLimite() {
        XCTAssertEqual(LectorIA.infoLimite(Data(ErroresGemini.porDia.utf8)), InfoLimite(diario: true, espera: 27))
        XCTAssertEqual(LectorIA.infoLimite(Data(ErroresGemini.porMinuto.utf8)), InfoLimite(diario: false, espera: 2))
        XCTAssertEqual(LectorIA.infoLimite(Data(ErroresGemini.sinDetalles.utf8)), InfoLimite(diario: false, espera: nil))
        XCTAssertEqual(LectorIA.infoLimite(Data("no es json".utf8)), InfoLimite(diario: false, espera: nil))
        XCTAssertEqual(LectorIA.segundos("1.5s"), 1.5)
        XCTAssertNil(LectorIA.segundos("abc"))
    }

    func testEsperaCrecienteConAzar() {
        XCTAssertEqual(PoliticaIA.espera(intento: 1, azar: 0), 1)
        XCTAssertEqual(PoliticaIA.espera(intento: 2, azar: 0), 2)
        XCTAssertEqual(PoliticaIA.espera(intento: 3, azar: 1), 4.5)
        XCTAssertEqual(PoliticaIA.espera(intento: 9, azar: 0), 4, "Con tope")
    }

    func testCadenaSinRepetidosNiAgotados() {
        XCTAssertEqual(PoliticaIA.cadena(elegido: "gemini-3.6-flash", agotados: []),
                       ["gemini-3.6-flash", "gemini-3.5-flash-lite", "gemini-3.1-flash-lite"])
        XCTAssertEqual(PoliticaIA.cadena(elegido: " ", agotados: ["gemini-3.5-flash-lite"]).first, DatosApp.modeloPorDefecto)
    }

    func testReinicioEsMedianocheDelPacifico() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let ahora = cal.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 15))!
        let reinicio = PoliticaIA.proximoReinicio(desde: ahora)
        XCTAssertEqual(cal.dateComponents([.day, .hour, .minute], from: reinicio), DateComponents(day: 17, hour: 0, minute: 0))
    }

    func testPresupuestoLimitaLlamadasYTiempo() {
        var ahora = Date(timeIntervalSince1970: 1000)
        let p = PresupuestoIA(maxLlamadas: 3, segundos: 30, reloj: { ahora })
        XCTAssertTrue(p.tomarLlamada())
        XCTAssertTrue(p.tomarLlamada())
        ahora = ahora.addingTimeInterval(29.5)
        XCTAssertFalse(p.tomarLlamada(), "Sin tiempo no se hace otra llamada")
        XCTAssertEqual(p.llamadasUsadas, 2)
    }

    func testReservaParaElRespaldo() {
        let p = PresupuestoIA()
        p.reservarParaRespaldo(1)
        XCTAssertTrue(p.tomarLlamada())
        XCTAssertTrue(p.tomarLlamada())
        XCTAssertFalse(p.tomarLlamada(), "La tercera queda para el respaldo")
        XCTAssertTrue(p.tomarLlamada(paraRespaldo: true))
        XCTAssertFalse(p.tomarLlamada(paraRespaldo: true))
    }

    func testCorteTotalCancelaLaOperacion() async {
        do {
            _ = try await ServicioIA.conLimite(0.2) { () async throws -> Int in
                try await Task.sleep(nanoseconds: 5_000_000_000)
                return 1
            }
            XCTFail("Debía cortarse")
        } catch {
            XCTAssertEqual(error as? ErrorIA, .tiempoAgotado)
        }
    }

    func testCuerpoLlevaRazonamientoMinimoSegunModelo() throws {
        XCTAssertEqual(LectorIA.nivelRazonamiento(modelo: "gemini-3.8-flash"), "LOW")
        XCTAssertEqual(LectorIA.nivelRazonamiento(modelo: "gemini-3.5-flash-lite"), "MINIMAL")
        XCTAssertEqual(LectorIA.nivelRazonamiento(modelo: "gemini-3.6-flash"), "MINIMAL")
        XCTAssertNil(LectorIA.nivelRazonamiento(modelo: "modelo-desconocido"))
    }

    func testCadaModeloRecibeSuNivelDeRazonamiento() async throws {
        let sesion = SesionFalsa([.http(503, ErroresGemini.saturado), .http(200, RespuestasGemini.alimentos)])
        _ = try await gemini(sesion).analizar(texto: "pan")
        let cuerpos = sesion.peticiones.map { String(decoding: $0.httpBody ?? Data(), as: UTF8.self) }
        XCTAssertTrue(cuerpos[0].contains("\"thinkingLevel\":\"LOW\""), "3.8-flash no admite MINIMAL")
        XCTAssertTrue(cuerpos[1].contains("\"thinkingLevel\":\"MINIMAL\""))
    }

    func testPromptsCortosPorTarea() throws {
        XCTAssertFalse(LectorIA.instruccionesFoto.contains("paso a paso"))
        XCTAssertFalse(LectorIA.instruccionesTexto.contains("paso a paso"))
        let texto = String(decoding: try LectorIA.cuerpoPeticion(texto: "pan", imagenJPEGBase64: nil, formato: .actual,
                                                                 nivelRazonamiento: "LOW"), as: UTF8.self)
        XCTAssertFalse(texto.contains("\"caja\""), "El texto no pide cajas")
        XCTAssertTrue(texto.contains("thinkingLevel"))
        let foto = String(decoding: try LectorIA.cuerpoPeticion(texto: nil, imagenJPEGBase64: "QUJD", formato: .actual), as: UTF8.self)
        XCTAssertTrue(foto.contains("\"caja\""), "La foto sí pide cajas")
        XCTAssertFalse(foto.contains("thinkingLevel"))
        let propio = LectorIA.pedido(texto: "Granola casera", tipo: .alimentoPropio)
        XCTAssertTrue(propio.contains("Granola casera"))
        XCTAssertTrue(LectorIA.instruccionesAlimentoPropio.count < LectorIA.instruccionesFoto.count)
    }

    func testCoachLlevaTopeDeSalida() throws {
        let datos = try LectorIA.cuerpoCoach(mensajes: [MensajeCoach(autor: .usuario, texto: "Hola")], contexto: nil,
                                             nivelRazonamiento: "LOW")
        let raiz = try XCTUnwrap(JSONSerialization.jsonObject(with: datos) as? [String: Any])
        let config = try XCTUnwrap(raiz["generationConfig"] as? [String: Any])
        XCTAssertEqual(config["maxOutputTokens"] as? Int, LectorIA.maxTokensCoach)
        XCTAssertEqual((config["thinkingConfig"] as? [String: Any])?["thinkingLevel"] as? String, "LOW")
    }
}

final class PruebasCapasIA: XCTestCase {

    private func capas(gemini sesionG: SesionFalsa, groq sesionGroq: SesionFalsa?, memoria: CacheIA? = nil) -> ProveedorEnCapas {
        var g = ProveedorGemini(clave: "k", modelo: "gemini-3.8-flash", formato: .actual)
        g.sesion = sesionG
        g.cuota = RegistroCuota(defaults: UserDefaults(suiteName: "pruebas.capas.\(UUID().uuidString)")!)
        g.esperar = { _ in }
        var groq: ProveedorGroq?
        if let sesionGroq {
            groq = ProveedorGroq(clave: "gk")
            groq?.sesion = sesionGroq
        }
        return ProveedorEnCapas(gemini: g, groq: groq, memoria: memoria)
    }

    static let respuestaGroq = #"{"choices": [{"index": 0, "message": {"role": "assistant", "content": "{\"alimentos\": [{\"nombre\": \"Arroz\", \"gramos\": 150, \"confianza\": 0.8, \"medida\": \"\", \"cantidad\": 0, \"gramos_por_medida\": 0, \"kcal_100g\": 130, \"proteina_100g\": 2.5, \"carbohidratos_100g\": 28, \"grasas_100g\": 0.3, \"gramos_min\": 120, \"gramos_max\": 180}], \"posibles_ocultos\": []}"}, "finish_reason": "stop"}]}"#

    func testGroqSoloSiGeminiEstaSaturadoYDentroDelTope() async throws {
        let g = SesionFalsa([.http(503, ErroresGemini.saturado), .http(503, ErroresGemini.saturado), .http(503, ErroresGemini.saturado)])
        let groq = SesionFalsa([.http(200, Self.respuestaGroq)])
        let a = try await capas(gemini: g, groq: groq).analizar(texto: "arroz")
        XCTAssertEqual(a.capa, .groq)
        XCTAssertEqual(g.llamadas + groq.llamadas, PoliticaIA.maxLlamadas, "El tope de 3 llamadas es entre todos los proveedores")
        let peticion = try XCTUnwrap(groq.peticiones.first)
        XCTAssertEqual(peticion.url?.absoluteString, PoliticaIA.urlGroq)
        XCTAssertEqual(g.llamadas, 2, "Con respaldo, Gemini deja una llamada para Groq")
        XCTAssertEqual(peticion.value(forHTTPHeaderField: "Authorization"), "Bearer gk")
        let cuerpo = String(decoding: peticion.httpBody ?? Data(), as: UTF8.self)
        XCTAssertTrue(cuerpo.contains("json_schema") && cuerpo.contains("\"strict\":true"))
        XCTAssertTrue(cuerpo.contains("reasoning_effort"))
    }

    func testSinClaveDeGroqSeMuestraElErrorDeGemini() async {
        let g = SesionFalsa([.http(429, ErroresGemini.porDia), .http(429, ErroresGemini.porDia), .http(429, ErroresGemini.porDia)])
        do {
            _ = try await capas(gemini: g, groq: nil).analizar(texto: "arroz")
            XCTFail("Debía fallar")
        } catch {
            XCTAssertEqual(error as? ErrorIA, .cuotaDiariaAgotada)
        }
    }

    func testGroqNoSeUsaConClaveDeGeminiInvalida() async {
        let g = SesionFalsa([.http(403, #"{"error": {"code": 403, "status": "PERMISSION_DENIED", "message": "API key not valid"}}"#)])
        let groq = SesionFalsa([.http(200, Self.respuestaGroq)])
        do {
            _ = try await capas(gemini: g, groq: groq).analizar(texto: "arroz")
            XCTFail("Debía fallar")
        } catch {
            XCTAssertEqual(error as? ErrorIA, .claveInvalida)
        }
        XCTAssertEqual(groq.llamadas, 0)
    }

    func testMemoriaEvitaLaSegundaLlamada() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID().uuidString).json")
        let memoria = CacheIA(url: url)
        let g = SesionFalsa([.http(200, RespuestasGemini.alimentos)])
        let proveedor = capas(gemini: g, groq: nil, memoria: memoria)
        let primera = try await proveedor.analizar(texto: "Un pan")
        XCTAssertEqual(primera.capa, .gemini("gemini-3.8-flash"))
        let segunda = try await proveedor.analizar(texto: "  un   PAN ")
        XCTAssertEqual(segunda.capa, .memoria)
        XCTAssertEqual(segunda.alimentos.map(\.nombre), primera.alimentos.map(\.nombre))
        XCTAssertEqual(g.llamadas, 1)
        try? FileManager.default.removeItem(at: url)
    }
}

final class PruebasCacheIA: XCTestCase {

    func testCaducaALas24Horas() {
        var ahora = Date(timeIntervalSince1970: 0)
        let c = CacheIA(url: nil, reloj: { ahora })
        let k = CacheIA.clave(tarea: "texto", texto: "pan")
        c.guardar("{}", capa: "groq", en: k)
        XCTAssertEqual(c.leer(k)?.respuesta, "{}")
        ahora = ahora.addingTimeInterval(CacheIA.duracion + 1)
        XCTAssertNil(c.leer(k))
    }

    func testClavesDistintasPorTareaYContenido() {
        XCTAssertEqual(CacheIA.clave(tarea: "texto", texto: "Pan  con palta"), CacheIA.clave(tarea: "texto", texto: "pan con palta"))
        XCTAssertNotEqual(CacheIA.clave(tarea: "texto", texto: "pan"), CacheIA.clave(tarea: "propio", texto: "pan"))
        XCTAssertNotEqual(CacheIA.clave(tarea: "foto", datos: Data([1, 2])), CacheIA.clave(tarea: "foto", datos: Data([1, 3])))
        XCTAssertEqual(CacheIA.clave(tarea: "foto", datos: Data([1])).count, 64)
    }

    func testTopeDeEntradas() {
        var ahora = Date(timeIntervalSince1970: 0)
        let c = CacheIA(url: nil, reloj: { ahora })
        for i in 0..<(CacheIA.maxEntradas + 10) {
            ahora = ahora.addingTimeInterval(1)
            c.guardar("r\(i)", capa: "groq", en: "k\(i)")
        }
        XCTAssertEqual(c.cantidad, CacheIA.maxEntradas)
        XCTAssertNil(c.leer("k0"), "Se borran las más viejas")
        XCTAssertNotNil(c.leer("k\(CacheIA.maxEntradas + 9)"))
    }

    func testPersisteEnDisco() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID().uuidString).json")
        CacheIA(url: url).guardar("hola", capa: "iphone", en: "k")
        XCTAssertEqual(CacheIA(url: url).leer("k")?.capa, "iphone")
        try? FileManager.default.removeItem(at: url)
    }
}

final class PruebasGroq: XCTestCase {

    func testEsquemaEstricto() {
        let e = LectorIA.esquemaEstricto(LectorIA.esquema(conCaja: true))
        XCTAssertEqual(e["additionalProperties"] as? Bool, false)
        let alimento = ((e["properties"] as? [String: Any])?["alimentos"] as? [String: Any])?["items"] as? [String: Any]
        XCTAssertEqual(alimento?["additionalProperties"] as? Bool, false)
        let requeridos = Set((alimento?["required"] as? [String]) ?? [])
        XCTAssertTrue(requeridos.contains("caja"), "En modo estricto todo es obligatorio")
        let gramos = (alimento?["properties"] as? [String: Any])?["gramos"] as? [String: Any]
        XCTAssertNil(gramos?["minimum"])
    }

    func testCuerpoConImagenEnBase64() throws {
        let datos = try LectorIA.cuerpoGroq(modelo: PoliticaIA.modeloGroq, sistema: "s", texto: "t", imagenJPEGBase64: "QUJD",
                                            esquema: LectorIA.esquemaEtiqueta)
        let raiz = try XCTUnwrap(JSONSerialization.jsonObject(with: datos) as? [String: Any])
        XCTAssertEqual(raiz["model"] as? String, "qwen/qwen3.8-27b")
        XCTAssertEqual(raiz["reasoning_effort"] as? String, "none")
        let mensajes = try XCTUnwrap(raiz["messages"] as? [[String: Any]])
        let partes = try XCTUnwrap(mensajes.last?["content"] as? [[String: Any]])
        let url = (partes.last?["image_url"] as? [String: Any])?["url"] as? String
        XCTAssertEqual(url, "data:image/jpeg;base64,QUJD")
    }

    func testRespuestaYErrores() throws {
        XCTAssertTrue(try LectorIA.textoDeRespuestaGroq(Data(PruebasCapasIA.respuestaGroq.utf8)).contains("Arroz"))
        XCTAssertThrowsError(try LectorIA.textoDeRespuestaGroq(Data(#"{"choices": []}"#.utf8)))
        XCTAssertEqual(LectorIA.errorHTTPGroq(codigo: 401, cuerpo: Data()), .claveGroqInvalida)
        XCTAssertEqual(LectorIA.errorHTTPGroq(codigo: 429, cuerpo: Data()), .limiteAlcanzado)
        XCTAssertEqual(LectorIA.errorHTTPGroq(codigo: 503, cuerpo: Data()), .servidor(503))
    }

    func testCoachEnGroqAlternaRoles() throws {
        let m = [MensajeCoach(autor: .usuario, texto: "Hola"), MensajeCoach(autor: .coach, texto: "¡Hola!"), MensajeCoach(autor: .usuario, texto: "¿Qué ceno?")]
        let raiz = try XCTUnwrap(JSONSerialization.jsonObject(with: LectorIA.cuerpoGroqCoach(modelo: "m", mensajes: m, contexto: nil)) as? [String: Any])
        let roles = (raiz["messages"] as? [[String: Any]])?.map { $0["role"] as? String }
        XCTAssertEqual(roles, ["system", "user", "assistant", "user"])
    }
}

final class PruebasEtiquetaLocal: XCTestCase {

    func testTablaConDosColumnas() throws {
        let filas = [
            "INFORMACIÓN NUTRICIONAL",
            "Tamaño de porción: 30 g",
            "Por 100 g Por porción",
            "Energía 1590 kJ / 380 kcal 114 kcal",
            "Proteínas 8,0 g 2,4 g",
            "Grasa total 10 g 3 g 15%",
            "Grasa saturada 2 g 0,6 g",
            "Carbohidratos 64 g 19,2 g",
            "Azúcares 20 g 6 g",
            "Fibra 5 g 1,5 g",
            "Sodio 300 mg 90 mg"
        ]
        let e = try XCTUnwrap(ParserEtiqueta.leer(filas))
        XCTAssertEqual(e.por100g.kcal, 380)
        XCTAssertEqual(e.por100g.proteina, 8)
        XCTAssertEqual(e.por100g.grasas, 10, "No toma la grasa saturada")
        XCTAssertEqual(e.por100g.carbohidratos, 64)
        XCTAssertEqual(e.por100g.azucar, 20)
        XCTAssertEqual(e.por100g.sodio, 300)
        XCTAssertEqual(e.porcionGramos, 30)
        XCTAssertEqual(e.capa, .iPhone)
    }

    func testSoloPorPorcionSeConvierte() throws {
        let filas = ["Porción: 50 g", "Valor energético 100 kcal", "Proteína 5 g", "Grasa total 2 g", "Carbohidratos 15,5 g"]
        let e = try XCTUnwrap(ParserEtiqueta.leer(filas))
        XCTAssertEqual(e.por100g.kcal, 200)
        XCTAssertEqual(e.por100g.carbohidratos, 31)
    }

    func testIncompletaOIncoherenteVaALaNube() {
        XCTAssertNil(ParserEtiqueta.leer(["Por 100 g", "Energía 380 kcal", "Proteínas 8 g"]), "Faltan macros")
        XCTAssertNil(ParserEtiqueta.leer(["Por 100 g", "Energía 900 kcal", "Proteínas 1 g", "Grasa total 1 g", "Carbohidratos 1 g"]),
                     "Las kcal no cuadran con los macros")
        XCTAssertNil(ParserEtiqueta.leer(["Hola", "Sin números"]))
    }

    func testFilasPorAltura() {
        let piezas = [
            PiezaTexto(x: 0.6, y: 0.80, alto: 0.04, texto: "8 g"),
            PiezaTexto(x: 0.1, y: 0.81, alto: 0.04, texto: "Proteínas"),
            PiezaTexto(x: 0.1, y: 0.70, alto: 0.04, texto: "Grasa total"),
            PiezaTexto(x: 0.6, y: 0.70, alto: 0.04, texto: "10 g")
        ]
        XCTAssertEqual(ParserEtiqueta.filas(piezas), ["Proteínas 8 g", "Grasa total 10 g"])
    }
}

final class PruebasColaSinConexion: XCTestCase {
    func testAnalisisSeGuardaYSeVuelveALeer() throws {
        let original = try LectorIA.analisis(desde: #"{"alimentos": [{"nombre": "Pan", "gramos": 60, "confianza": 0.9, "medida": "unidad", "cantidad": 2, "gramos_por_medida": 30, "kcal_100g": 280, "proteina_100g": 8, "carbohidratos_100g": 57, "grasas_100g": 2, "gramos_min": 50, "gramos_max": 70}], "posibles_ocultos": ["mantequilla"]}"#)
        let json = try XCTUnwrap(LectorIA.json(de: original))
        let vuelta = try LectorIA.analisis(desde: json)
        XCTAssertEqual(vuelta.alimentos.map(\.nombre), ["Pan"])
        XCTAssertEqual(vuelta.alimentos[0].gramos, 60)
        XCTAssertEqual(vuelta.alimentos[0].medida, original.alimentos[0].medida)
        XCTAssertEqual(vuelta.alimentos[0].gramosMax, 70)
        XCTAssertEqual(vuelta.posiblesOcultos, ["mantequilla"])
    }
}
