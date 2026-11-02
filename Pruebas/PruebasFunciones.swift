import XCTest

final class PruebasDietasYAjustes: XCTestCase {

    private let base = Perfil(sexo: .masculino, edad: 20, pesoKg: 70, tallaCm: 170, actividad: .ligero, objetivo: .mantener)

    func testKeto() {
        var p = base
        p.dieta = .keto
        let m = CalculoMeta.meta(p)
        XCTAssertEqual(m.kcal, 2290)
        XCTAssertEqual(m.proteina, 112)
        XCTAssertEqual(m.carbohidratos, 29)
        XCTAssertEqual(m.grasas, 192)
    }

    func testAltaProteinaYBajaGrasa() {
        var p = base
        p.dieta = .altaProteina
        let a = CalculoMeta.meta(p)
        XCTAssertEqual(a.proteina, 154)
        XCTAssertEqual(a.grasas, 64)
        XCTAssertEqual(a.carbohidratos, 275)
        p.dieta = .bajaGrasa
        let b = CalculoMeta.meta(p)
        XCTAssertEqual(b.grasas, 38)
        XCTAssertEqual(b.carbohidratos, 375)
    }

    func testBajaCarbohidratos() {
        var p = base
        p.dieta = .bajaCarbohidratos
        let m = CalculoMeta.meta(p)
        XCTAssertEqual(m.carbohidratos, 115)   // 20 % de 2290 ÷ 4 = 114,5
        XCTAssertEqual(m.grasas, 154)          // (2290 − 448 − 460) ÷ 9 = 153,6
    }

    func testExtraKcalYAjusteAutomatico() {
        XCTAssertEqual(CalculoMeta.meta(base, extraKcal: 200).kcal, 2490)
        var d = DatosApp()
        d.perfil = base
        d.ajusteKcal = -150
        XCTAssertEqual(CalculoMeta.metaVigente(d)?.kcal, 2290, "Sin activar el ajuste automático no se aplica")
        d.ajusteAutomatico = true
        XCTAssertEqual(CalculoMeta.metaVigente(d)?.kcal, 2140)
        d.sumarActividad = true
        XCTAssertEqual(CalculoMeta.metaVigente(d, actividadSalud: 300)?.kcal, 2440)
        XCTAssertTrue(CalculoMeta.explicacion(base, extraKcal: 150)[2].contains("ajustes"))
    }

    func testAgua() {
        var d = DatosApp()
        XCTAssertEqual(Agua.meta(d), 2000)
        d.perfil = base
        XCTAssertEqual(Agua.meta(d), 2500)
        d.metaAguaManual = 1800
        XCTAssertEqual(Agua.meta(d), 1800)
        let registros = [RegistroAgua(fecha: fecha(2026, 11, 1, 9), ml: 250), RegistroAgua(fecha: fecha(2026, 11, 1, 15), ml: 500),
                         RegistroAgua(fecha: fecha(2026, 10, 31, 9), ml: 250)]
        XCTAssertEqual(Agua.delDia(fecha(2026, 11, 1), en: registros, calendario: calendarioPrueba), 750)
    }
}

final class PruebasCuerpo: XCTestCase {

    func testGrasaMarina() {
        let hombre = Cuerpo.grasaMarina(sexo: .masculino, tallaCm: 175, cuello: 37, cintura: 85, cadera: nil)
        XCTAssertEqual(hombre ?? 0, 17.7, accuracy: 0.3)
        let mujer = Cuerpo.grasaMarina(sexo: .femenino, tallaCm: 165, cuello: 32, cintura: 75, cadera: 98)
        XCTAssertEqual(mujer ?? 0, 28.9, accuracy: 0.3)
        XCTAssertNil(Cuerpo.grasaMarina(sexo: .femenino, tallaCm: 165, cuello: 32, cintura: 75, cadera: nil))
        XCTAssertNil(Cuerpo.grasaMarina(sexo: .masculino, tallaCm: 175, cuello: 40, cintura: 38, cadera: nil))
    }

    func testIMC() {
        XCTAssertEqual(Cuerpo.imc(pesoKg: 70, tallaCm: 175) ?? 0, 22.86, accuracy: 0.01)
    }

    func testTendencia() {
        let pesos = [RegistroPeso(fecha: fecha(2026, 10, 1), kg: 80), RegistroPeso(fecha: fecha(2026, 10, 8), kg: 79.7),
                     RegistroPeso(fecha: fecha(2026, 10, 15), kg: 79.4)]
        XCTAssertEqual(Cuerpo.tendenciaSemanal(pesos, hasta: fecha(2026, 10, 15, 13)) ?? 0, -0.3, accuracy: 0.001)
        XCTAssertNil(Cuerpo.tendenciaSemanal(Array(pesos.prefix(2)), hasta: fecha(2026, 10, 15, 13)))
    }

    func testAjusteDinamico() {
        let p = Perfil(sexo: .masculino, edad: 30, pesoKg: 80, tallaCm: 178, actividad: .moderado, objetivo: .bajarGrasa)
        let estancado = [RegistroPeso(fecha: fecha(2026, 10, 1), kg: 80), RegistroPeso(fecha: fecha(2026, 10, 8), kg: 80),
                         RegistroPeso(fecha: fecha(2026, 10, 15), kg: 80)]
        let s = AjusteDinamico.sugerir(perfil: p, pesos: estancado, ajusteActual: 0, hoy: fecha(2026, 10, 15, 13))
        XCTAssertEqual(s?.nuevoAjuste, -200)
        XCTAssertEqual(s?.objetivoSemanal ?? 0, -0.4, accuracy: 0.0001)
        // Al ritmo esperado: no hay ajuste.
        let alRitmo = [RegistroPeso(fecha: fecha(2026, 10, 1), kg: 80), RegistroPeso(fecha: fecha(2026, 10, 8), kg: 79.6),
                       RegistroPeso(fecha: fecha(2026, 10, 15), kg: 79.2)]
        XCTAssertNil(AjusteDinamico.sugerir(perfil: p, pesos: alRitmo, ajusteActual: 0, hoy: fecha(2026, 10, 15, 13)))
        // Nunca pasa del máximo acumulado.
        let tope = AjusteDinamico.sugerir(perfil: p, pesos: estancado, ajusteActual: -550, hoy: fecha(2026, 10, 15, 13))
        XCTAssertEqual(tope?.nuevoAjuste, -600)
    }

    func testRachaDeRegistros() {
        let todos = [registro("A", gramos: 100, kcal100: 100, en: fecha(2026, 10, 30)),
                     registro("B", gramos: 100, kcal100: 100, en: fecha(2026, 10, 31)),
                     registro("C", gramos: 100, kcal100: 100, en: fecha(2026, 11, 1, 8))]
        XCTAssertEqual(Series.racha(todos, hoy: fecha(2026, 11, 1, 20), calendario: calendarioPrueba), 3)
        XCTAssertEqual(Series.racha(Array(todos.prefix(2)), hoy: fecha(2026, 11, 1, 20), calendario: calendarioPrueba), 2)
        XCTAssertEqual(Series.racha([], hoy: fecha(2026, 11, 1), calendario: calendarioPrueba), 0)
    }

    func testSeriesYPromedio() {
        let todos = [registro("A", gramos: 100, kcal100: 1000, en: fecha(2026, 10, 31)),
                     registro("B", gramos: 100, kcal100: 2000, en: fecha(2026, 11, 1))]
        let dias = Series.nutrientesPorDia(todos, hasta: fecha(2026, 11, 1), dias: 7, calendario: calendarioPrueba)
        XCTAssertEqual(dias.count, 7)
        XCTAssertEqual(dias.last?.total.kcal, 2000)
        XCTAssertEqual(Series.promedio(dias).kcal, 1500, accuracy: 0.001)
    }
}

final class PruebasAyuno: XCTestCase {

    func testEstado() {
        let s = SesionAyuno(inicio: fecha(2026, 11, 1, 20), horas: 16)
        let e = Ayuno.estado(s, ahora: fecha(2026, 11, 2, 4))
        XCTAssertEqual(e.fraccion, 0.5, accuracy: 0.0001)
        XCTAssertEqual(e.restante, 8 * 3600, accuracy: 0.5)
        XCTAssertFalse(e.completado)
        XCTAssertTrue(Ayuno.estado(s, ahora: fecha(2026, 11, 2, 13)).completado)
        XCTAssertEqual(Ayuno.duracion(15 * 3600 + 4 * 60), "15 h 04 min")
    }

    func testRachaYActiva() {
        let a = SesionAyuno(inicio: fecha(2026, 10, 30, 20), horas: 16, finReal: fecha(2026, 10, 31, 12, 30))
        let b = SesionAyuno(inicio: fecha(2026, 10, 31, 20), horas: 16, finReal: fecha(2026, 11, 1, 13))
        let c = SesionAyuno(inicio: fecha(2026, 11, 1, 20), horas: 16)
        XCTAssertEqual(Ayuno.racha([a, b, c]), 2)
        XCTAssertEqual(Ayuno.activa([a, b, c])?.id, c.id)
        let corto = SesionAyuno(inicio: fecha(2026, 11, 1, 20), horas: 16, finReal: fecha(2026, 11, 2, 2))
        XCTAssertEqual(Ayuno.racha([a, b, corto]), 0)
    }
}

final class PruebasRecetasYPlan: XCTestCase {

    private let arroz = Ingrediente(nombre: "Arroz cocido", gramos: 200, por100g: Nutrientes(kcal: 130, proteina: 2.5, carbohidratos: 28, grasas: 0.3), origen: .ins, codigoINS: "A2")
    private let pollo = Ingrediente(nombre: "Pollo", gramos: 100, por100g: Nutrientes(kcal: 200, proteina: 25, carbohidratos: 0, grasas: 10), origen: .ins, codigoINS: "F1")

    func testReceta() {
        let r = Receta(nombre: "Arroz con pollo", porciones: 2, ingredientes: [arroz, pollo])
        XCTAssertEqual(Recetas.total(r).kcal, 460, accuracy: 0.001)
        XCTAssertEqual(Recetas.pesoTotal(r), 300)
        XCTAssertEqual(Recetas.por100g(r).kcal, 153.333, accuracy: 0.01)
        XCTAssertEqual(Recetas.gramosPorPorcion(r), 150)
        XCTAssertEqual(Recetas.porPorcion(r).kcal, 230, accuracy: 0.001)
        var cocida = r
        cocida.pesoFinal = 400
        XCTAssertEqual(Recetas.por100g(cocida).kcal, 115, accuracy: 0.001)
    }

    private var tablaPlan: [AlimentoBase] {
        [
            AlimentoBase(codigo: "A47", nombre: "Pan de molde", grupo: "", por100g: Nutrientes(kcal: 300, proteina: 9, carbohidratos: 55, grasas: 4)),
            AlimentoBase(codigo: "SB1", nombre: "Hojuela de avena, bebida", grupo: "", por100g: Nutrientes(kcal: 60, proteina: 2, carbohidratos: 10, grasas: 1)),
            AlimentoBase(codigo: "J1", nombre: "Huevo de gallina sancochado", grupo: "", por100g: Nutrientes(kcal: 150, proteina: 12, carbohidratos: 1, grasas: 10)),
            AlimentoBase(codigo: "J2", nombre: "Huevo en polvo", grupo: "", por100g: Nutrientes(kcal: 600, proteina: 45, carbohidratos: 4, grasas: 40)),
            AlimentoBase(codigo: "SS1", nombre: "Lomo saltado con arroz", grupo: "", por100g: Nutrientes(kcal: 160, proteina: 8, carbohidratos: 20, grasas: 5)),
            AlimentoBase(codigo: "SE1", nombre: "Aguadito de pollo", grupo: "", por100g: Nutrientes(kcal: 42, proteina: 2.4, carbohidratos: 5.6, grasas: 0.9)),
            AlimentoBase(codigo: "C1", nombre: "Plátano de seda", grupo: "", por100g: Nutrientes(kcal: 90, proteina: 1, carbohidratos: 22, grasas: 0.2)),
            AlimentoBase(codigo: "C2", nombre: "Durazno, néctar envasado", grupo: "", por100g: Nutrientes(kcal: 50, proteina: 0, carbohidratos: 12, grasas: 0))
        ]
    }

    func testOpcionesFiltranProductosNoAptos() {
        let o = Planificador.opciones(tabla: tablaPlan, recetas: [], dieta: .equilibrada)
        XCTAssertEqual(o.desayunoComplemento.map(\.codigoINS), ["J1"])
        XCTAssertEqual(o.snacks.map(\.codigoINS), ["C1"])
        XCTAssertEqual(Set(o.desayunoPrincipal.compactMap(\.codigoINS)), ["A47", "SB1"])
        XCTAssertEqual(o.cena.count, 2)
    }

    func testGenerarDiaEsRepetibleYCercaDeLaMeta() {
        let o = Planificador.opciones(tabla: tablaPlan, recetas: [], dieta: .equilibrada)
        let meta = Nutrientes(kcal: 2000, proteina: 100, carbohidratos: 250, grasas: 60)
        let a = Planificador.generarDia(fecha(2026, 11, 3), meta: meta, opciones: o, calendario: calendarioPrueba)
        let b = Planificador.generarDia(fecha(2026, 11, 3, 18), meta: meta, opciones: o, calendario: calendarioPrueba)
        XCTAssertEqual(a.items.map(\.nombre), b.items.map(\.nombre))
        XCTAssertEqual(Set(a.items.map(\.comida)), Set(TipoComida.allCases))
        let total = Planificador.total(a).kcal
        XCTAssertEqual(total, 2000, accuracy: 400, "El plan debe quedar cerca de la meta")
        XCTAssertTrue(a.items.allSatisfy { Int($0.gramos) % 5 == 0 })
    }

    func testFiltroKeto() {
        XCTAssertFalse(Planificador.encajaEnDieta(Nutrientes(kcal: 90, proteina: 1, carbohidratos: 22, grasas: 0.2), .keto))
        XCTAssertTrue(Planificador.encajaEnDieta(Nutrientes(kcal: 150, proteina: 12, carbohidratos: 1, grasas: 10), .keto))
    }

    func testAjustarPorciones() {
        var plan = PlanDia(dia: fecha(2026, 11, 1), items: [
            ItemPlan(comida: .desayuno, nombre: "Pan", gramos: 100, por100g: Nutrientes(kcal: 300, proteina: 0, carbohidratos: 0, grasas: 0), origen: .ins, hecho: true),
            ItemPlan(comida: .cena, nombre: "Lomo", gramos: 300, por100g: Nutrientes(kcal: 160, proteina: 0, carbohidratos: 0, grasas: 0), origen: .ins)
        ])
        // Comiste de más: la cena baja (hasta la mitad como mínimo).
        let menos = Planificador.ajustarPorciones(plan, consumidoKcal: 1900, meta: Nutrientes(kcal: 2000, proteina: 0, carbohidratos: 0, grasas: 0))
        XCTAssertEqual(menos.items[0].gramos, 100, "Lo ya comido no cambia")
        XCTAssertEqual(menos.items[1].gramos, 150)
        // Al ritmo esperado no cambia nada.
        plan.items[1].gramos = 300
        let igual = Planificador.ajustarPorciones(plan, consumidoKcal: 1520, meta: Nutrientes(kcal: 2000, proteina: 0, carbohidratos: 0, grasas: 0))
        XCTAssertEqual(igual.items[1].gramos, 300)
    }

    func testListaDeCompras() {
        let receta = Receta(nombre: "Arroz con pollo", porciones: 2, ingredientes: [arroz, pollo])
        let dia1 = PlanDia(dia: fecha(2026, 11, 2), items: [
            ItemPlan(comida: .almuerzo, nombre: "Arroz con pollo", gramos: 150, por100g: Recetas.por100g(receta), origen: .manual, recetaID: receta.id),
            ItemPlan(comida: .snacks, nombre: "Plátano de seda", gramos: 120, por100g: .cero, origen: .ins, codigoINS: "C1")
        ])
        let dia2 = PlanDia(dia: fecha(2026, 11, 3), items: [
            ItemPlan(comida: .snacks, nombre: "plátano de seda", gramos: 100, por100g: .cero, origen: .ins, codigoINS: "C1")
        ])
        let lista = Planificador.listaCompras([dia1, dia2], recetas: [receta])
        let platano = lista.first { $0.clave == "platano de seda" }
        XCTAssertEqual(platano?.gramos, 220)
        XCTAssertEqual(platano?.grupo, "Frutas")
        XCTAssertEqual(lista.first { $0.nombre == "Arroz cocido" }?.gramos, 100)
        XCTAssertEqual(lista.first { $0.nombre == "Pollo" }?.gramos, 50)
    }
}

final class PruebasExportarYCoach: XCTestCase {

    func testCSV() {
        var r = registro("Pan, con \"palta\"", gramos: 60, kcal100: 280, p: 8, c: 57, g: 2, en: fecha(2026, 11, 1, 8))
        r.por100g.sodio = 500
        let csv = Exportar.csvRegistros([r])
        let lineas = csv.split(separator: "\n")
        XCTAssertEqual(lineas.count, 2)
        XCTAssertTrue(lineas[1].contains("\"Pan, con \"\"palta\"\"\""))
        XCTAssertTrue(lineas[1].contains(",168,"))
        XCTAssertTrue(lineas[1].contains(",300,"), "Sodio de la porción en mg")
        XCTAssertEqual(Formato.numeroCSV(12.345), "12.35")
        XCTAssertEqual(Formato.numeroCSV(7), "7")
    }

    func testCuerpoCoach() throws {
        let mensajes = [MensajeCoach(autor: .usuario, texto: "¿Qué ceno?"), MensajeCoach(autor: .coach, texto: "Un caldo."),
                        MensajeCoach(autor: .usuario, texto: "¿Y algo con más proteína?")]
        let datos = try LectorIA.cuerpoCoach(mensajes: mensajes, contexto: "Resumen de hoy")
        let raiz = try XCTUnwrap(JSONSerialization.jsonObject(with: datos) as? [String: Any])
        let contenidos = try XCTUnwrap(raiz["contents"] as? [[String: Any]])
        XCTAssertEqual(contenidos.map { $0["role"] as? String }, ["user", "model", "user"])
        let texto = String(decoding: datos, as: UTF8.self)
        XCTAssertTrue(texto.contains("systemInstruction"))
        XCTAssertTrue(texto.contains("Resumen de hoy"))
        let sinContexto = String(decoding: try LectorIA.cuerpoCoach(mensajes: mensajes, contexto: nil), as: UTF8.self)
        XCTAssertFalse(sinContexto.contains("Resumen de hoy"))
    }

    func testContextoCoachSinDatosPersonales() {
        let c = LectorIA.contextoCoach(consumido: Nutrientes(kcal: 1200, proteina: 60, carbohidratos: 150, grasas: 40),
                                       meta: nil, aguaMl: 1000, metaAguaMl: 2000, objetivo: .mantener, dieta: .keto)
        XCTAssertTrue(c.contains("1200 kcal"))
        XCTAssertTrue(c.contains("keto"))
        XCTAssertFalse(c.contains("kg"))
    }
}

final class PruebasAzucarYEtiqueta: XCTestCase {
    func testAzucarSeSumaYEscala() {
        let a = Nutrientes(kcal: 100, proteina: 1, carbohidratos: 20, grasas: 0, azucar: 10)
        let b = Nutrientes(kcal: 50, proteina: 0, carbohidratos: 5, grasas: 0, azucar: 4)
        XCTAssertEqual((a + b).azucar, 14, accuracy: 0.001)
        XCTAssertEqual((a * 0.5).azucar, 5, accuracy: 0.001)
    }

    func testDatosAntiguosSinAzucar() throws {
        let json = #"{"kcal":100,"proteina":2,"carbohidratos":10,"grasas":5}"#
        let n = try JSONDecoder().decode(Nutrientes.self, from: Data(json.utf8))
        XCTAssertEqual(n.azucar, 0)
        XCTAssertEqual(n.kcal, 100)
    }

    func testEtiquetaConAzucarFibraYSodio() throws {
        let texto = #"{"es_etiqueta":true,"nombre":"galletas","porcion_g":30,"kcal_100g":480,"proteina_100g":6,"carbohidratos_100g":68,"grasas_100g":20,"azucares_100g":28,"fibra_100g":2.5,"sodio_mg_100g":350,"confianza":0.9}"#
        let e = try LectorIA.etiqueta(desde: texto)
        XCTAssertEqual(e.por100g.azucar, 28, accuracy: 0.001)
        XCTAssertEqual(e.por100g.fibra, 2.5, accuracy: 0.001)
        XCTAssertEqual(e.por100g.sodio, 350, accuracy: 0.001)
    }

    func testEtiquetaSinCamposOpcionales() throws {
        let texto = #"{"es_etiqueta":true,"nombre":"","porcion_g":0,"kcal_100g":40,"proteina_100g":1,"carbohidratos_100g":9,"grasas_100g":0,"confianza":0.7}"#
        let e = try LectorIA.etiqueta(desde: texto)
        XCTAssertEqual(e.por100g.azucar, 0)
        XCTAssertEqual(e.por100g.sodio, 0)
    }

    func testCSVIncluyeAzucar() {
        XCTAssertTrue(Exportar.csvRegistros([]).hasPrefix("fecha,comida,alimento,gramos,kcal,proteina_g,carbohidratos_g,grasas_g,fibra_g,sodio_mg,azucar_g,origen"))
    }
}

final class PruebasRangosYOcultos: XCTestCase {
    private let json = #"""
    {"alimentos":[{"nombre":"Lomo saltado","gramos":400,"confianza":0.7,"medida":"","cantidad":0,"gramos_por_medida":0,
    "kcal_100g":150,"proteina_100g":10,"carbohidratos_100g":12,"grasas_100g":7,"gramos_min":300,"gramos_max":550}],
    "posibles_ocultos":["aceite","Aceite","sillao","ají"]}
    """#

    func testRangoYOcultos() throws {
        let a = try LectorIA.analisis(desde: json)
        XCTAssertEqual(a.alimentos.first?.gramosMin, 300)
        XCTAssertEqual(a.alimentos.first?.gramosMax, 550)
        XCTAssertEqual(a.posiblesOcultos, ["aceite", "sillao", "ají"])
        let rel = ExtraOculto.relacionar(a.posiblesOcultos)
        XCTAssertEqual(rel.extras.map(\.id), ["aceite", "soya"])
        XCTAssertEqual(rel.otros, ["ají"])
    }

    func testRangoIncoherenteSeIgnora() throws {
        let malo = json.replacingOccurrences(of: "\"gramos_min\":300", with: "\"gramos_min\":450")
        let a = try LectorIA.analisis(desde: malo)
        XCTAssertNil(a.alimentos.first?.gramosMin)
    }

    func testRespuestaAntiguaSinCamposNuevos() throws {
        let viejo = #"{"alimentos":[{"nombre":"Pan francés","gramos":30,"confianza":0.9,"medida":"unidad","cantidad":1,"gramos_por_medida":30,"kcal_100g":290,"proteina_100g":8,"carbohidratos_100g":58,"grasas_100g":2}]}"#
        let a = try LectorIA.analisis(desde: viejo)
        XCTAssertEqual(a.alimentos.count, 1)
        XCTAssertTrue(a.posiblesOcultos.isEmpty)
        XCTAssertNil(a.alimentos[0].gramosMax)
    }

    func testRangoDeCalorias() throws {
        let a = try LectorIA.analisis(desde: json)
        let item = ItemRevision(identificado: a.alimentos[0], coincidencia: nil)
        let r = try XCTUnwrap(item.rangoKcal)
        XCTAssertEqual(r.lowerBound, 450, accuracy: 0.01)
        XCTAssertEqual(r.upperBound, 825, accuracy: 0.01)
        let aceite = AlimentoBase(codigo: "D4", nombre: "Aceite vegetal de girasol", grupo: "D", por100g: Nutrientes(kcal: 884, proteina: 0, carbohidratos: 0, grasas: 100))
        let extra = ItemRevision(extra: ExtraOculto.todos[0], alimento: aceite)
        XCTAssertEqual(extra.gramos, 14)
        XCTAssertEqual(extra.origen, .ins)
        let total = try XCTUnwrap(ItemRevision.rangoTotal([item, extra]))
        XCTAssertEqual(total.lowerBound, 450 + 884 * 0.14, accuracy: 0.01)
    }

    func testExtrasExistenEnLaTablaDelINS() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sazon/Datos/alimentos-ins.json")
        let datos = try Data(contentsOf: url)
        let raiz = try XCTUnwrap(JSONSerialization.jsonObject(with: datos) as? [String: Any])
        let codigos = Set(((raiz["alimentos"] as? [[String: Any]]) ?? []).compactMap { $0["codigo"] as? String })
        for e in ExtraOculto.todos { XCTAssertTrue(codigos.contains(e.codigoINS), "Falta \(e.codigoINS)") }
    }
}
