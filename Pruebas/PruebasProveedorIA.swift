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
