import XCTest

final class PruebasLectorIA: XCTestCase {

    private let jsonBueno = """
    {"alimentos": [
      {"nombre": "pan francés", "gramos": 60, "confianza": 0.9, "medida": "unidad", "cantidad": 2,
       "gramos_por_medida": 30, "kcal_100g": 280, "proteina_100g": 8, "carbohidratos_100g": 57, "grasas_100g": 2},
      {"nombre": "Palta", "gramos": 50, "confianza": 1.4, "medida": "", "cantidad": 0,
       "gramos_por_medida": 0, "kcal_100g": 160, "proteina_100g": 2, "carbohidratos_100g": 9, "grasas_100g": 15}
    ]}
    """

    func testLeeAlimentos() throws {
        let lista = try LectorIA.alimentos(desde: jsonBueno)
        XCTAssertEqual(lista.count, 2)
        XCTAssertEqual(lista[0].nombre, "Pan francés")
        XCTAssertEqual(lista[0].gramos, 60)
        XCTAssertEqual(lista[0].medida, MedidaCasera(nombre: "unidad", gramos: 30, estimada: true))
        XCTAssertEqual(lista[0].cantidadMedida, 2)
        XCTAssertNil(lista[1].medida)
        XCTAssertEqual(lista[1].confianza, 1, "La confianza se recorta a 0–1")
        XCTAssertEqual(lista[1].por100g.grasas, 15)
    }

    func testAceptaBloqueDeCodigo() throws {
        let envuelto = "```json\n" + jsonBueno + "\n```"
        XCTAssertEqual(try LectorIA.alimentos(desde: envuelto).count, 2)
    }

    func testAceptaNumerosComoTexto() throws {
        let json = #"{"alimentos": [{"nombre": "Café", "gramos": "250", "confianza": 0.8, "medida": "", "cantidad": 0, "gramos_por_medida": 0, "kcal_100g": "2,5", "proteina_100g": 0.1, "carbohidratos_100g": 0, "grasas_100g": 0}]}"#
        let lista = try LectorIA.alimentos(desde: json)
        XCTAssertEqual(lista[0].gramos, 250)
        XCTAssertEqual(lista[0].por100g.kcal, 2.5)
    }

    func testErroresClaros() {
        XCTAssertThrowsError(try LectorIA.alimentos(desde: "hola")) {
            XCTAssertEqual($0 as? ErrorIA, .jsonInvalido("no es un JSON válido"))
        }
        XCTAssertThrowsError(try LectorIA.alimentos(desde: #"{"comida": []}"#)) {
            XCTAssertEqual($0 as? ErrorIA, .jsonInvalido("falta la lista «alimentos»"))
        }
        XCTAssertThrowsError(try LectorIA.alimentos(desde: #"{"alimentos": []}"#)) {
            XCTAssertEqual($0 as? ErrorIA, .sinAlimentos)
        }
        let sinGramos = #"{"alimentos": [{"nombre": "Pan", "gramos": 0, "confianza": 1, "kcal_100g": 1, "proteina_100g": 1, "carbohidratos_100g": 1, "grasas_100g": 1}]}"#
        XCTAssertThrowsError(try LectorIA.alimentos(desde: sinGramos)) {
            XCTAssertEqual($0 as? ErrorIA, .jsonInvalido("la porción de «Pan» no es válida"))
        }
        let kcalImposible = #"{"alimentos": [{"nombre": "Pan", "gramos": 50, "confianza": 1, "kcal_100g": 2000, "proteina_100g": 1, "carbohidratos_100g": 1, "grasas_100g": 1}]}"#
        XCTAssertThrowsError(try LectorIA.alimentos(desde: kcalImposible)) {
            XCTAssertEqual($0 as? ErrorIA, .jsonInvalido("los valores nutricionales de «Pan» no son válidos"))
        }
    }

    func testTextoDeRespuestaDeGemini() throws {
        let respuesta = #"{"candidates": [{"content": {"role": "model", "parts": [{"text": "{\"alimentos\": []}"}]}, "finishReason": "STOP"}]}"#
        XCTAssertEqual(try LectorIA.textoDeRespuesta(Data(respuesta.utf8)), #"{"alimentos": []}"#)
    }

    func testIgnoraPensamientos() throws {
        let respuesta = #"{"candidates": [{"content": {"parts": [{"text": "pensando…", "thought": true}, {"text": "{}"}]}}]}"#
        XCTAssertEqual(try LectorIA.textoDeRespuesta(Data(respuesta.utf8)), "{}")
    }

    func testRespuestaBloqueada() {
        let bloqueada = #"{"promptFeedback": {"blockReason": "SAFETY"}}"#
        XCTAssertThrowsError(try LectorIA.textoDeRespuesta(Data(bloqueada.utf8))) {
            XCTAssertEqual($0 as? ErrorIA, .bloqueado("SAFETY"))
        }
        let vacia = #"{"candidates": [{"content": {"parts": []}, "finishReason": "MAX_TOKENS"}]}"#
        XCTAssertThrowsError(try LectorIA.textoDeRespuesta(Data(vacia.utf8))) {
            XCTAssertEqual($0 as? ErrorIA, .bloqueado("MAX_TOKENS"))
        }
        XCTAssertThrowsError(try LectorIA.textoDeRespuesta(Data(#"{"candidates": []}"#.utf8))) {
            XCTAssertEqual($0 as? ErrorIA, .respuestaVacia)
        }
    }

    func testErroresHTTP() {
        let limite = #"{"error": {"code": 429, "message": "Quota exceeded", "status": "RESOURCE_EXHAUSTED"}}"#
        XCTAssertEqual(LectorIA.errorHTTP(codigo: 429, cuerpo: Data(limite.utf8), modelo: "m"), .limiteAlcanzado)
        let clave = #"{"error": {"code": 400, "message": "API key not valid. Please pass a valid API key.", "status": "INVALID_ARGUMENT"}}"#
        XCTAssertEqual(LectorIA.errorHTTP(codigo: 400, cuerpo: Data(clave.utf8), modelo: "m"), .claveInvalida)
        let modelo = #"{"error": {"code": 404, "message": "models/x is not found", "status": "NOT_FOUND"}}"#
        XCTAssertEqual(LectorIA.errorHTTP(codigo: 404, cuerpo: Data(modelo.utf8), modelo: "x"), .modeloNoDisponible("x"))
        let campo = #"{"error": {"code": 400, "message": "Unknown name \"responseFormat\"", "status": "INVALID_ARGUMENT"}}"#
        XCTAssertEqual(LectorIA.errorHTTP(codigo: 400, cuerpo: Data(campo.utf8), modelo: "m"), .peticionInvalida("Unknown name \"responseFormat\""))
        XCTAssertEqual(LectorIA.errorHTTP(codigo: 503, cuerpo: Data(), modelo: "m"), .servidor(503))
    }

    func testCuerpoDePeticionSinDatosPersonales() throws {
        let datos = try LectorIA.cuerpoPeticion(texto: "2 panes con palta", imagenJPEGBase64: nil, formato: .actual)
        let raiz = try XCTUnwrap(JSONSerialization.jsonObject(with: datos) as? [String: Any])
        let config = try XCTUnwrap(raiz["generationConfig"] as? [String: Any])
        let formato = try XCTUnwrap((config["responseFormat"] as? [String: Any])?["text"] as? [String: Any])
        XCTAssertEqual(formato["mimeType"] as? String, "APPLICATION_JSON")
        XCTAssertNotNil(formato["schema"])
        let texto = String(decoding: datos, as: UTF8.self)
        XCTAssertTrue(texto.contains("2 panes con palta"))
        // Solo instrucciones y el plato: nada de perfil, peso ni metas.
        XCTAssertFalse(texto.contains("pesoKg"))
        XCTAssertFalse(texto.contains("kcal\":"))
    }

    func testCuerpoClasicoYConFoto() throws {
        let datos = try LectorIA.cuerpoPeticion(texto: nil, imagenJPEGBase64: "QUJD", formato: .clasico)
        let raiz = try XCTUnwrap(JSONSerialization.jsonObject(with: datos) as? [String: Any])
        let config = try XCTUnwrap(raiz["generationConfig"] as? [String: Any])
        XCTAssertEqual(config["responseMimeType"] as? String, "application/json")
        XCTAssertNotNil(config["responseJsonSchema"])
        let partes = try XCTUnwrap(((raiz["contents"] as? [[String: Any]])?.first)?["parts"] as? [[String: Any]])
        let imagen = try XCTUnwrap(partes.first?["inline_data"] as? [String: Any])
        XCTAssertEqual(imagen["mime_type"] as? String, "image/jpeg")
        XCTAssertEqual(imagen["data"] as? String, "QUJD")
    }
}

final class PruebasOpenFoodFacts: XCTestCase {

    func testCodigoValido() {
        XCTAssertEqual(LectorOpenFoodFacts.codigoValido("7 750885 012928"), "7750885012928")
        XCTAssertNil(LectorOpenFoodFacts.codigoValido("123"))
        XCTAssertNil(LectorOpenFoodFacts.codigoValido("77508850129AB"))
    }

    func testLeeProducto() throws {
        let json = """
        {"code": "7750885012928", "status": 1, "product": {
          "product_name": "Galletas de soda", "product_name_es": "", "brands": "Marca A, Marca B",
          "serving_size": "30 g", "serving_quantity": 30,
          "nutriments": {"energy-kcal_100g": 450, "proteins_100g": 9, "carbohydrates_100g": 68, "fat_100g": 15.5}
        }}
        """
        let p = try LectorOpenFoodFacts.producto(desde: Data(json.utf8), codigo: "7750885012928")
        XCTAssertEqual(p.nombre, "Galletas de soda")
        XCTAssertEqual(p.marca, "Marca A")
        XCTAssertEqual(p.por100g, Nutrientes(kcal: 450, proteina: 9, carbohidratos: 68, grasas: 15.5))
        XCTAssertFalse(p.datosIncompletos)
        XCTAssertEqual(p.porcion?.gramos, 30)
        XCTAssertEqual(p.porcion?.nombre, "porción (30 g)")
    }

    func testConvierteKilojulios() throws {
        let json = #"{"status": 1, "product": {"product_name": "Jugo", "nutriments": {"energy_100g": 184.1}}}"#
        let p = try LectorOpenFoodFacts.producto(desde: Data(json.utf8), codigo: "12345678")
        XCTAssertEqual(p.por100g.kcal, 44, accuracy: 0.01)
        XCTAssertTrue(p.datosIncompletos)
    }

    func testNoEncontradoYSinDatos() {
        XCTAssertThrowsError(try LectorOpenFoodFacts.producto(desde: Data(#"{"status": 0}"#.utf8), codigo: "12345678")) {
            XCTAssertEqual($0 as? ErrorOpenFoodFacts, .noEncontrado)
        }
        let sinKcal = #"{"status": 1, "product": {"product_name": "X", "nutriments": {}}}"#
        XCTAssertThrowsError(try LectorOpenFoodFacts.producto(desde: Data(sinKcal.utf8), codigo: "12345678")) {
            XCTAssertEqual($0 as? ErrorOpenFoodFacts, .sinDatosNutricionales)
        }
    }
}

final class PruebasRevisionIA: XCTestCase {

    private func identificado(_ nombre: String, gramos: Double, medida: MedidaCasera? = nil, cantidad: Double? = nil,
                              confianza: Double = 0.9) -> AlimentoIdentificado {
        AlimentoIdentificado(nombre: nombre, gramos: gramos, confianza: confianza, medida: medida, cantidadMedida: cantidad,
                             por100g: Nutrientes(kcal: 300, proteina: 10, carbohidratos: 50, grasas: 5))
    }

    func testConCoincidenciaUsaLaTablaDelINS() {
        let pan = tablaPrueba[0]
        let item = ItemRevision(identificado: identificado("Pan francés", gramos: 60), coincidencia: pan)
        XCTAssertTrue(item.usarINS)
        XCTAssertEqual(item.origen, .ins)
        XCTAssertEqual(item.por100g, pan.por100g)
        let r = item.registro(fecha: fecha(2026, 11, 1, 8), comida: .desayuno)
        XCTAssertEqual(r.origen, .ins)
        XCTAssertEqual(r.codigoINS, "A1")
        XCTAssertEqual(r.total.kcal, 280 * 0.6, accuracy: 0.001)
        XCTAssertEqual(r.confianzaIA, 0.9)
    }

    func testSinCoincidenciaUsaEstimacionMarcada() {
        let item = ItemRevision(identificado: identificado("Lomo saltado", gramos: 350), coincidencia: nil)
        XCTAssertEqual(item.origen, .estimadoIA)
        let r = item.registro(fecha: fecha(2026, 11, 1, 13), comida: .almuerzo)
        XCTAssertTrue(r.origen.esEstimado)
        XCTAssertNil(r.codigoINS)
        XCTAssertEqual(r.total.kcal, 1050, accuracy: 0.001)
    }

    func testPuedesElegirLaEstimacionAunqueHayaCoincidencia() {
        var item = ItemRevision(identificado: identificado("Palta", gramos: 50), coincidencia: tablaPrueba[2])
        item.usarINS = false
        XCTAssertEqual(item.origen, .estimadoIA)
        XCTAssertEqual(item.por100g.kcal, 300)
    }

    func testMedidaSoloSiLosGramosCoinciden() {
        let unidad = MedidaCasera(nombre: "unidad", gramos: 30, estimada: true)
        var item = ItemRevision(identificado: identificado("Pan", gramos: 60, medida: unidad, cantidad: 2), coincidencia: nil)
        XCTAssertEqual(item.registro(fecha: fecha(2026, 11, 1), comida: .desayuno).cantidadMedida, 2)
        item.gramos = 90
        let r = item.registro(fecha: fecha(2026, 11, 1), comida: .desayuno)
        XCTAssertNil(r.medida)
        XCTAssertNil(r.cantidadMedida)
    }

    func testValidezYConfianzaBaja() {
        var item = ItemRevision(identificado: identificado("Algo", gramos: 100, confianza: 0.4), coincidencia: nil)
        XCTAssertTrue(item.confianzaEsBaja)
        XCTAssertTrue(item.esValido)
        item.nombre = "  "
        XCTAssertFalse(item.esValido)
        item.nombre = "Algo"
        item.gramos = 0
        XCTAssertFalse(item.esValido)
    }
}
