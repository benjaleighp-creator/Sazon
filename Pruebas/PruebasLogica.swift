import XCTest

final class PruebasMeta: XCTestCase {

    func testBasalHombre() {
        let p = Perfil(sexo: .masculino, edad: 20, pesoKg: 70, tallaCm: 170, actividad: .ligero, objetivo: .mantener)
        XCTAssertEqual(CalculoMeta.metabolismoBasal(p), 1667.5, accuracy: 0.001)
        XCTAssertEqual(CalculoMeta.gastoDiario(p), 2292.8125, accuracy: 0.001)
    }

    func testMetaMantenerHombre() {
        let p = Perfil(sexo: .masculino, edad: 20, pesoKg: 70, tallaCm: 170, actividad: .ligero, objetivo: .mantener)
        let m = CalculoMeta.meta(p)
        XCTAssertEqual(m.kcal, 2290)
        XCTAssertEqual(m.proteina, 112)
        XCTAssertEqual(m.grasas, 64)
        XCTAssertEqual(m.carbohidratos, 317)
    }

    func testMetaBajarGrasaMujer() {
        let p = Perfil(sexo: .femenino, edad: 30, pesoKg: 60, tallaCm: 160, actividad: .sedentario, objetivo: .bajarGrasa)
        XCTAssertEqual(CalculoMeta.metabolismoBasal(p), 1289, accuracy: 0.001)
        let m = CalculoMeta.meta(p)
        XCTAssertEqual(m.kcal, 1240)
        XCTAssertEqual(m.proteina, 120)
        XCTAssertEqual(m.grasas, 34)
        XCTAssertEqual(m.carbohidratos, 114)
    }

    func testMetaTienePisoDeCalorias() {
        let p = Perfil(sexo: .femenino, edad: 60, pesoKg: 45, tallaCm: 150, actividad: .sedentario, objetivo: .bajarGrasa)
        XCTAssertEqual(CalculoMeta.meta(p).kcal, CalculoMeta.caloriasMinimas)
        XCTAssertTrue(CalculoMeta.explicacion(p).last?.contains("mínimo") ?? false)
    }

    func testGanarMusculoSubeCalorias() {
        var p = Perfil(sexo: .masculino, edad: 25, pesoKg: 75, tallaCm: 178, actividad: .moderado, objetivo: .mantener)
        let mantener = CalculoMeta.meta(p).kcal
        p.objetivo = .ganarMusculo
        XCTAssertGreaterThan(CalculoMeta.meta(p).kcal, mantener)
    }

    func testCarbohidratosNuncaNegativos() {
        let p = Perfil(sexo: .masculino, edad: 30, pesoKg: 200, tallaCm: 150, actividad: .sedentario, objetivo: .bajarGrasa)
        XCTAssertGreaterThanOrEqual(CalculoMeta.meta(p).carbohidratos, 0)
    }

    func testMetaManualTienePrioridad() {
        var d = DatosApp()
        XCTAssertNil(CalculoMeta.metaVigente(d))
        d.perfil = Perfil()
        XCTAssertEqual(CalculoMeta.metaVigente(d), CalculoMeta.meta(Perfil()))
        let manual = Nutrientes(kcal: 2000, proteina: 150, carbohidratos: 200, grasas: 60)
        d.metaManual = manual
        XCTAssertEqual(CalculoMeta.metaVigente(d), manual)
    }

    func testExplicacionTieneTodosLosPasos() {
        let pasos = CalculoMeta.explicacion(Perfil())
        XCTAssertEqual(pasos.count, 6)
        XCTAssertTrue(pasos[0].contains("Mifflin-St Jeor"))
    }
}

final class PruebasDiario: XCTestCase {

    func testTotalDeUnRegistro() {
        let r = registro("Pan", gramos: 50, kcal100: 280, p: 8, c: 57, g: 2, en: fecha(2026, 11, 1, 8))
        XCTAssertEqual(r.total.kcal, 140, accuracy: 0.001)
        XCTAssertEqual(r.total.proteina, 4, accuracy: 0.001)
        XCTAssertEqual(r.total.carbohidratos, 28.5, accuracy: 0.001)
        XCTAssertEqual(r.total.grasas, 1, accuracy: 0.001)
    }

    func testResumenSoloIncluyeElDia() {
        let todos = [
            registro("Pan", gramos: 100, kcal100: 280, comida: .desayuno, en: fecha(2026, 11, 1, 7)),
            registro("Arroz", gramos: 200, kcal100: 130, comida: .almuerzo, en: fecha(2026, 11, 1, 13)),
            registro("Ayer", gramos: 100, kcal100: 999, comida: .cena, en: fecha(2026, 10, 31, 23, 59)),
            registro("Mañana", gramos: 100, kcal100: 999, comida: .desayuno, en: fecha(2026, 11, 2, 0, 1))
        ]
        let r = Diario.resumen(de: fecha(2026, 11, 1), en: todos, calendario: calendarioPrueba)
        XCTAssertEqual(r.total.kcal, 280 + 260, accuracy: 0.001)
        XCTAssertEqual(r.registros(.desayuno).count, 1)
        XCTAssertEqual(r.registros(.almuerzo).count, 1)
        XCTAssertEqual(r.registros(.cena).count, 0)
        XCTAssertEqual(r.totales(.almuerzo).kcal, 260, accuracy: 0.001)
        XCTAssertFalse(r.incluyeEstimados)
    }

    func testResumenMarcaEstimados() {
        let todos = [registro("Plato", gramos: 300, kcal100: 150, en: fecha(2026, 11, 1), origen: .estimadoIA)]
        XCTAssertTrue(Diario.resumen(de: fecha(2026, 11, 1), en: todos, calendario: calendarioPrueba).incluyeEstimados)
    }

    func testProgreso() {
        let p = Progreso(consumido: 1500, meta: 2000)
        XCTAssertEqual(p.fraccion, 0.75, accuracy: 0.0001)
        XCTAssertEqual(p.restante, 500)
        XCTAssertFalse(p.excedido)
        let pasado = Progreso(consumido: 2500, meta: 2000)
        XCTAssertEqual(pasado.fraccion, 1)
        XCTAssertTrue(pasado.excedido)
        XCTAssertEqual(Progreso(consumido: 100, meta: 0).fraccion, 0)
    }

    func testFechaParaRegistrarEnOtroDia() {
        let ahora = fecha(2026, 11, 1, 14, 30)
        let ayer = fecha(2026, 10, 31, 9)
        let f = Diario.fechaParaRegistrar(enDia: ayer, ahora: ahora, calendario: calendarioPrueba)
        XCTAssertTrue(calendarioPrueba.isDate(f, inSameDayAs: ayer))
        XCTAssertEqual(calendarioPrueba.component(.hour, from: f), 14)
        XCTAssertEqual(Diario.fechaParaRegistrar(enDia: ahora, ahora: ahora, calendario: calendarioPrueba), ahora)
    }

    func testMoverDia() {
        let d = Diario.moverDia(fecha(2026, 11, 1, 15), dias: -1, calendario: calendarioPrueba)
        XCTAssertEqual(d, fecha(2026, 10, 31, 0))
    }

    func testRecientesSinRepetir() {
        let a = registro("Pan francés", gramos: 50, kcal100: 280, en: fecha(2026, 11, 1))
        let b = registro("Palta", gramos: 50, kcal100: 160, en: fecha(2026, 11, 1))
        var lista = Diario.actualizarRecientes([], con: a)
        lista = Diario.actualizarRecientes(lista, con: b)
        lista = Diario.actualizarRecientes(lista, con: registro("pan frances", gramos: 80, kcal100: 280, en: fecha(2026, 11, 2)))
        XCTAssertEqual(lista.count, 2)
        XCTAssertEqual(lista.first?.gramos, 80)
    }

    func testComidaSugerida() {
        XCTAssertEqual(TipoComida.sugerida(minutoDelDia: 7 * 60), .desayuno)
        XCTAssertEqual(TipoComida.sugerida(minutoDelDia: 13 * 60), .almuerzo)
        XCTAssertEqual(TipoComida.sugerida(minutoDelDia: 17 * 60), .snacks)
        XCTAssertEqual(TipoComida.sugerida(minutoDelDia: 20 * 60), .cena)
        XCTAssertEqual(TipoComida.sugerida(minutoDelDia: 2 * 60), .snacks)
    }
}

final class PruebasPorciones: XCTestCase {

    func testOnzas() {
        XCTAssertEqual(Porciones.aGramos(1, desde: .onzas), 28.349523125, accuracy: 1e-9)
        XCTAssertEqual(Porciones.desdeGramos(28.349523125, a: .onzas), 1, accuracy: 1e-9)
        XCTAssertEqual(Porciones.aGramos(150, desde: .gramos), 150)
    }

    func testMedidaCasera() {
        let unidad = MedidaCasera(nombre: "unidad", gramos: 30, estimada: true)
        XCTAssertEqual(Porciones.gramos(cantidad: 2, de: unidad), 60)
        XCTAssertEqual(Porciones.texto(gramos: 60, unidad: .gramos, medida: unidad, cantidadMedida: 2), "2 unidades (≈ 60 g)")
        XCTAssertEqual(Porciones.texto(gramos: 30, unidad: .gramos, medida: unidad, cantidadMedida: 1), "1 unidad (≈ 30 g)")
        XCTAssertEqual(Porciones.plural("rebanada"), "rebanadas")
        XCTAssertEqual(Porciones.plural("porción del envase"), "porciones del envase")
        XCTAssertEqual(Porciones.plural("unidad mediana"), "unidades medianas")
        XCTAssertEqual(Porciones.plural("porción (30 g)"), "porciones (30 g)")
        XCTAssertEqual(Porciones.plural("cucharada"), "cucharadas")
    }

    func testTextoSimple() {
        XCTAssertEqual(Porciones.texto(gramos: 150, unidad: .gramos), "150 g")
        XCTAssertEqual(Porciones.texto(gramos: 150, unidad: .onzas), "5,3 oz")
    }

    func testValidez() {
        XCTAssertFalse(Porciones.esValido(0))
        XCTAssertFalse(Porciones.esValido(-5))
        XCTAssertFalse(Porciones.esValido(6000))
        XCTAssertFalse(Porciones.esValido(.nan))
        XCTAssertTrue(Porciones.esValido(150))
    }

    func testMedidasSinRepetidos() {
        let a = MedidaCasera(nombre: "Taza", gramos: 200, estimada: false)
        let b = MedidaCasera(nombre: "taza", gramos: 180, estimada: true)
        let c = MedidaCasera(nombre: "cucharada", gramos: 15, estimada: true)
        XCTAssertEqual(Porciones.medidasDisponibles(base: [a], adicional: b), [a])
        XCTAssertEqual(Porciones.medidasDisponibles(base: [a], adicional: c).count, 2)
    }
}

final class PruebasBusqueda: XCTestCase {

    func testNormalizar() {
        XCTAssertEqual(Busqueda.normalizar("  Pan FRANCÉS, con   palta! "), "pan frances con palta")
    }

    func testSingular() {
        XCTAssertEqual(Busqueda.singular("panes"), "pan")
        XCTAssertEqual(Busqueda.singular("tomates"), "tomate")
        XCTAssertEqual(Busqueda.singular("papas"), "papa")
        XCTAssertEqual(Busqueda.singular("frijoles"), "frijol")
        XCTAssertEqual(Busqueda.singular("pan"), "pan")
    }

    func testBuscarOrdenaPorParecido() {
        let r = Busqueda.buscar("pan", en: tablaPrueba)
        XCTAssertEqual(r.map(\.alimento.codigo), ["A1", "A2"])
    }

    func testBuscarSinTildesYEnPlural() {
        XCTAssertEqual(Busqueda.buscar("panes frances", en: tablaPrueba).first?.alimento.codigo, "A1")
        XCTAssertEqual(Busqueda.buscar("tomates", en: tablaPrueba).first?.alimento.codigo, "E1")
        XCTAssertEqual(Busqueda.buscar("frijoles", en: tablaPrueba).first?.alimento.codigo, "F1")
    }

    func testBuscarPorInicioDePalabra() {
        XCTAssertEqual(Busqueda.buscar("pal", en: tablaPrueba).first?.alimento.codigo, "B1")
    }

    func testBuscarVacio() {
        XCTAssertTrue(Busqueda.buscar("  ", en: tablaPrueba).isEmpty)
        XCTAssertTrue(Busqueda.buscar("de la", en: tablaPrueba).isEmpty)
        XCTAssertTrue(Busqueda.buscar("chocolate", en: tablaPrueba).isEmpty)
    }

    func testEmparejarNombreDeLaIA() {
        XCTAssertEqual(Busqueda.emparejar("Pan francés", en: tablaPrueba)?.alimento.codigo, "A1")
        XCTAssertEqual(Busqueda.emparejar("Palta", en: tablaPrueba)?.alimento.codigo, "B1")
        XCTAssertEqual(Busqueda.emparejar("Arroz", en: tablaPrueba)?.alimento.codigo, "C1")
        XCTAssertNil(Busqueda.emparejar("Lomo saltado", en: tablaPrueba))
        XCTAssertNil(Busqueda.emparejar("Huevo frito", en: tablaPrueba))
    }

    func testLeerArchivoTabla() throws {
        let json = """
        {"fuente": "INS 2023", "alimentos": [
          {"codigo": "A1", "nombre": "Pan francés", "grupo": "Cereales",
           "por100g": {"kcal": 280, "proteina": 8, "carbohidratos": 57, "grasas": 2},
           "medidas": [{"nombre": "unidad", "gramos": 30, "estimada": false}]}
        ]}
        """
        let archivo = try ArchivoTabla.leer(Data(json.utf8))
        XCTAssertEqual(archivo.alimentos.count, 1)
        XCTAssertEqual(archivo.alimentos[0].medidas.first?.gramos, 30)
    }
}

final class PruebasFormato: XCTestCase {

    func testNumeros() {
        XCTAssertEqual(Formato.numero(2.5), "2,5")
        XCTAssertEqual(Formato.numero(70), "70")
        XCTAssertEqual(Formato.numero(1.375, decimales: 3), "1,375")
        XCTAssertEqual(Formato.entero(1834.6), "1835")
    }

    func testPrimeraMayuscula() {
        XCTAssertEqual(Formato.primeraMayuscula("domingo, 1 de noviembre"), "Domingo, 1 de noviembre")
        XCTAssertEqual(Formato.primeraMayuscula(""), "")
    }

    func testDiaLargo() {
        XCTAssertEqual(Formato.diaLargo(fecha(2026, 11, 1), calendario: calendarioPrueba), "Domingo, 1 de noviembre")
    }

    func testDiaRelativo() {
        let hoy = fecha(2026, 11, 1, 10)
        XCTAssertEqual(Formato.diaRelativo(fecha(2026, 11, 1, 22), hoy: hoy, calendario: calendarioPrueba), "Hoy")
        XCTAssertEqual(Formato.diaRelativo(fecha(2026, 10, 31, 1), hoy: hoy, calendario: calendarioPrueba), "Ayer")
    }

    func testHora24() {
        XCTAssertEqual(Formato.hora(fecha(2026, 11, 1, 21, 5), calendario: calendarioPrueba), "21:05")
    }

    func testEstimados() {
        XCTAssertEqual(Formato.kcal(250.4, estimado: true), "≈ 250 kcal")
        XCTAssertEqual(Formato.kcal(250.4), "250 kcal")
    }
}

final class PruebasDatosGuardados: XCTestCase {

    func testLeeDatosAntiguosSinCamposNuevos() throws {
        let json = #"{"version": 1, "registros": [{"nombre": "Pan", "gramos": 50}]}"#
        let decodificador = JSONDecoder()
        decodificador.dateDecodingStrategy = .iso8601
        let d = try decodificador.decode(DatosApp.self, from: Data(json.utf8))
        XCTAssertEqual(d.registros.count, 1)
        XCTAssertEqual(d.registros[0].origen, .manual)
        XCTAssertEqual(d.temaID, "mercado")
        XCTAssertEqual(d.modeloIA, DatosApp.modeloPorDefecto)
        XCTAssertFalse(d.avisoIAAceptado)
    }

    func testIdaYVuelta() throws {
        var d = DatosApp()
        d.perfil = Perfil(sexo: .femenino, edad: 22, pesoKg: 55, tallaCm: 158, actividad: .moderado, objetivo: .ganarMusculo)
        d.registros = [registro("Palta", gramos: 80, kcal100: 160, en: fecha(2026, 11, 1))]
        let c = JSONEncoder()
        c.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let vuelta = try dec.decode(DatosApp.self, from: c.encode(d))
        XCTAssertEqual(vuelta, d)
    }
}

final class PruebasSemanaYSaludo: XCTestCase {

    func testInicioDeSemanaEsLunes() {
        // 1 de noviembre de 2026 es domingo: su semana empieza el lunes 26 de octubre.
        XCTAssertEqual(Diario.inicioSemana(fecha(2026, 11, 1, 18), calendario: calendarioPrueba), fecha(2026, 10, 26, 0))
        XCTAssertEqual(Diario.inicioSemana(fecha(2026, 10, 26, 9), calendario: calendarioPrueba), fecha(2026, 10, 26, 0))
        XCTAssertEqual(Diario.inicioSemana(fecha(2026, 11, 2, 9), calendario: calendarioPrueba), fecha(2026, 11, 2, 0))
    }

    func testSemanaConCalorias() {
        let todos = [
            registro("Pan", gramos: 100, kcal100: 280, en: fecha(2026, 10, 27, 8)),
            registro("Arroz", gramos: 200, kcal100: 130, en: fecha(2026, 11, 1, 13))
        ]
        let meta = Nutrientes(kcal: 2000, proteina: 100, carbohidratos: 250, grasas: 60)
        let semana = Diario.semana(de: fecha(2026, 10, 29), en: todos, meta: meta, calendario: calendarioPrueba)
        XCTAssertEqual(semana.count, 7)
        XCTAssertEqual(semana[1].kcal, 280, accuracy: 0.001)
        XCTAssertEqual(semana[1].fraccion, 0.14, accuracy: 0.0001)
        XCTAssertTrue(semana[1].tieneRegistros)
        XCTAssertFalse(semana[2].tieneRegistros)
        XCTAssertEqual(semana[6].kcal, 260, accuracy: 0.001)
        XCTAssertEqual(Diario.semana(de: fecha(2026, 10, 29), en: todos, meta: nil, calendario: calendarioPrueba)[1].fraccion, 0)
    }

    func testRepartoEnergia() {
        let r = Nutrientes(kcal: 0, proteina: 25, carbohidratos: 25, grasas: 0).repartoEnergia
        XCTAssertEqual(r.proteina, 0.5, accuracy: 1e-9)
        XCTAssertEqual(r.carbohidratos, 0.5, accuracy: 1e-9)
        XCTAssertEqual(r.grasas, 0)
        XCTAssertEqual(Nutrientes.cero.repartoEnergia.proteina, 0)
    }

    func testSaludoEInicial() {
        XCTAssertEqual(Formato.saludo(hora: 7), "Buenos días")
        XCTAssertEqual(Formato.saludo(hora: 15), "Buenas tardes")
        XCTAssertEqual(Formato.saludo(hora: 22), "Buenas noches")
        XCTAssertEqual(Formato.saludo(hora: 2), "Buenas noches")
        XCTAssertEqual(Formato.inicialDia(fecha(2026, 11, 1), calendario: calendarioPrueba), "D")
        XCTAssertEqual(Formato.inicialDia(fecha(2026, 11, 2), calendario: calendarioPrueba), "L")
        XCTAssertEqual(Formato.numeroDia(fecha(2026, 11, 1), calendario: calendarioPrueba), "1")
    }
}
