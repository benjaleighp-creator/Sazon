import XCTest

/// Validación de entradas que vienen de fuera de la app (respaldo, IA,
/// Open Food Facts, Ajustes).
final class PruebasSeguridad: XCTestCase {

    // MARK: Respaldo

    func testNombresDeArchivoSeguros() {
        XCTAssertTrue(ValidacionRespaldo.esNombreArchivoSeguro("6F1C2A9E-1B2C-4D5E-8F90-123456789ABC.jpg"))
        XCTAssertFalse(ValidacionRespaldo.esNombreArchivoSeguro("../datos-sazon.json"))
        XCTAssertFalse(ValidacionRespaldo.esNombreArchivoSeguro("fotos/a.jpg"))
        XCTAssertFalse(ValidacionRespaldo.esNombreArchivoSeguro(".."))
        XCTAssertFalse(ValidacionRespaldo.esNombreArchivoSeguro(".oculto"))
        XCTAssertFalse(ValidacionRespaldo.esNombreArchivoSeguro(""))
        XCTAssertFalse(ValidacionRespaldo.esNombreArchivoSeguro("a\\b.jpg"))
        XCTAssertFalse(ValidacionRespaldo.esNombreArchivoSeguro("/etc/passwd"))
    }

    func testRespaldoNoImportaConsentimientosNiRutasRaras() {
        var actual = DatosApp()
        actual.avisoIAAceptado = false
        actual.coachCompartirResumen = false
        var entrada = DatosApp()
        entrada.avisoIAAceptado = true
        entrada.coachCompartirResumen = true
        entrada.modeloIA = "../../v1/otra-cosa"
        entrada.fotos = [FotoProgreso(fecha: Date(), archivo: "../datos-sazon.json"),
                         FotoProgreso(fecha: Date(), archivo: "bien.jpg")]
        entrada.colaIA = [PendienteIA(comida: .almuerzo, tipo: .foto, archivoFoto: "../x"),
                          PendienteIA(comida: .cena, tipo: .texto, texto: "pan")]

        let r = ValidacionRespaldo.revisar(entrada, conservando: actual)
        XCTAssertFalse(r.datos.avisoIAAceptado)
        XCTAssertFalse(r.datos.coachCompartirResumen)
        XCTAssertEqual(r.datos.modeloIA, DatosApp.modeloPorDefecto)
        XCTAssertEqual(r.datos.fotos.map(\.archivo), ["bien.jpg"])
        XCTAssertEqual(r.datos.colaIA.count, 1)
        XCTAssertEqual(r.descartados, 2)
    }

    func testRespaldoRecortaValoresImposibles() {
        var entrada = DatosApp()
        let malo = Nutrientes(kcal: 5000, proteina: -3, carbohidratos: 50, grasas: 200, sodio: 1e9)
        entrada.registros = [
            Registro(fecha: Date(), comida: .almuerzo, nombre: String(repeating: "a", count: 500), gramos: 150,
                     por100g: malo, origen: .manual, codigoBarras: "77abc", confianzaIA: 7),
            Registro(fecha: Date(), comida: .cena, nombre: "negativo", gramos: -10,
                     por100g: .cero, origen: .manual)
        ]
        entrada.pesos = [RegistroPeso(fecha: Date(), kg: 70), RegistroPeso(fecha: Date(), kg: -1)]
        entrada.agua = [RegistroAgua(fecha: Date(), ml: 250), RegistroAgua(fecha: Date(), ml: 1e7)]
        entrada.vasoMl = 0

        let r = ValidacionRespaldo.revisar(entrada, conservando: DatosApp())
        XCTAssertEqual(r.datos.registros.count, 1)
        let reg = try? XCTUnwrap(r.datos.registros.first)
        XCTAssertEqual(reg?.por100g.kcal, 900)
        XCTAssertEqual(reg?.por100g.proteina, 0)
        XCTAssertEqual(reg?.por100g.grasas, 100)
        XCTAssertEqual(reg?.por100g.sodio, 40000)
        XCTAssertEqual(reg?.nombre.count, ValidacionRespaldo.largoNombre)
        XCTAssertNil(reg?.codigoBarras)
        XCTAssertEqual(reg?.confianzaIA, 1)
        XCTAssertEqual(r.datos.pesos.count, 1)
        XCTAssertEqual(r.datos.agua.count, 1)
        XCTAssertEqual(r.datos.vasoMl, 250)
        XCTAssertEqual(r.descartados, 3)
    }

    // MARK: Nombre del modelo

    func testNombreDeModelo() {
        XCTAssertTrue(PoliticaIA.nombreModeloValido("gemini-3.8-flash"))
        XCTAssertTrue(PoliticaIA.nombreModeloValido("gemini-3.5-flash-lite"))
        XCTAssertFalse(PoliticaIA.nombreModeloValido("../files"))
        XCTAssertFalse(PoliticaIA.nombreModeloValido("gemini/../x"))
        XCTAssertFalse(PoliticaIA.nombreModeloValido("Gemini?key=1"))
        XCTAssertFalse(PoliticaIA.nombreModeloValido(""))
        XCTAssertFalse(PoliticaIA.nombreModeloValido(String(repeating: "a", count: 65)))
    }

    // MARK: Respuestas de la IA

    private func alimento(_ nombre: String, gramos: String = "100") -> String {
        #"{"nombre": "\#(nombre)", "gramos": \#(gramos), "kcal_100g": 100, "proteina_100g": 5, "carbohidratos_100g": 10, "grasas_100g": 2}"#
    }

    func testIATopeDeAlimentosYDeLargo() throws {
        let lista = (1...30).map { alimento("arroz \($0)") }.joined(separator: ",")
        let a = try LectorIA.alimentos(desde: #"{"alimentos": [\#(lista)]}"#)
        XCTAssertEqual(a.count, LectorIA.maxAlimentos)

        let largo = try LectorIA.alimentos(desde: #"{"alimentos": [\#(alimento(String(repeating: "x", count: 300)))]}"#)
        XCTAssertEqual(largo.first?.nombre.count, LectorIA.maxLargoNombre)
    }

    func testIARechazaNumerosNoFinitosEnTexto() {
        XCTAssertNil(LectorIA.numero("inf"))
        XCTAssertNil(LectorIA.numero("nan"))
        XCTAssertNil(LectorIA.numero("-infinity"))
        XCTAssertEqual(LectorIA.numero("60,5"), 60.5)
        XCTAssertThrowsError(try LectorIA.alimentos(desde: #"{"alimentos": [\#(alimento("pan", gramos: "\"inf\""))]}"#))
    }

    func testCoachConTopeDeLargo() {
        let r = LectorIA.respuestaCoach(String(repeating: "a", count: 10_000))
        XCTAssertEqual(r.count, LectorIA.maxLargoCoach + 1)
        XCTAssertEqual(LectorIA.respuestaCoach("  hola \n"), "hola")
    }

    // MARK: Open Food Facts

    func testOpenFoodFactsDescartaMacrosImposibles() throws {
        let json = #"""
        {"status": 1, "product": {"product_name": "Galleta", "nutriments": {
          "energy-kcal_100g": 450, "proteins_100g": -5, "carbohidratos_100g": 60,
          "carbohydrates_100g": 300, "fat_100g": 20, "sodium_100g": 900, "sugars_100g": -1, "fiber_100g": 3}}}
        """#
        let p = try LectorOpenFoodFacts.producto(desde: Data(json.utf8), codigo: "7750000000000")
        XCTAssertEqual(p.por100g.proteina, 0)
        XCTAssertEqual(p.por100g.carbohidratos, 0)
        XCTAssertEqual(p.por100g.grasas, 20)
        XCTAssertEqual(p.por100g.sodio, 0)
        XCTAssertEqual(p.por100g.azucar, 0)
        XCTAssertEqual(p.por100g.fibra, 3)
        XCTAssertTrue(p.datosIncompletos)
    }

    func testCodigoDeBarrasSoloDigitos() {
        XCTAssertEqual(LectorOpenFoodFacts.codigoValido("7750 1234 5678 9"), "7750123456789")
        XCTAssertNil(LectorOpenFoodFacts.codigoValido("12345"))
        XCTAssertNil(LectorOpenFoodFacts.codigoValido("775012345678a"))
        XCTAssertNil(LectorOpenFoodFacts.codigoValido("７７５０１２３４５６７８９")) // dígitos de ancho completo
        XCTAssertNil(LectorOpenFoodFacts.codigoValido("../../x/12345678"))
    }
}
