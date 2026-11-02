import Foundation
import UIKit

// Acciones del almacén para agua, progreso, ayuno, alimentos propios,
// recetas, plan, compras y coach. Todas guardan en el JSON local.

extension Almacen {

    // MARK: Agua

    var metaAgua: Double { Agua.meta(datos) }
    var aguaVisible: Double { Agua.delDia(diaVisible, en: datos.agua) }

    func agregarAgua(_ ml: Double) {
        datos.agua.append(RegistroAgua(fecha: Diario.fechaParaRegistrar(enDia: diaVisible), ml: ml))
        avisarCambios()
    }

    /// Quita el último vaso del día visible.
    func quitarAgua() {
        guard let i = datos.agua.lastIndex(where: { Calendar.current.isDate($0.fecha, inSameDayAs: diaVisible) }) else { return }
        datos.agua.remove(at: i)
        avisarCambios()
    }

    // MARK: Peso, medidas y fotos

    var pesoActual: Double? { Cuerpo.ordenados(datos.pesos).last?.kg ?? datos.perfil?.pesoKg }

    /// Guarda un peso y lo usa en tu perfil (la meta se recalcula).
    func registrarPeso(_ kg: Double, fecha: Date = Date()) {
        var d = datos
        d.pesos.append(RegistroPeso(fecha: fecha, kg: kg))
        if var perfil = d.perfil, fecha >= (Cuerpo.ordenados(d.pesos).last?.fecha ?? fecha) {
            perfil.pesoKg = kg
            d.perfil = perfil
        }
        datos = d
        Salud.compartido.guardarPeso(kg, fecha: fecha, activa: datos.saludActiva)
    }

    func eliminarPeso(_ p: RegistroPeso) {
        datos.pesos.removeAll { $0.id == p.id }
    }

    func registrarMedidas(_ m: RegistroMedidas) {
        datos.medidas.append(m)
    }

    func eliminarMedidas(_ m: RegistroMedidas) {
        datos.medidas.removeAll { $0.id == m.id }
    }

    static var carpetaFotos: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let carpeta = base.appendingPathComponent("fotos-progreso", isDirectory: true)
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        return carpeta
    }

    /// Guarda una foto de progreso solo en este iPhone (sin metadatos).
    func agregarFoto(_ imagen: UIImage, nota: String = "") -> Bool {
        guard let jpeg = ProcesadorFoto.prepararParaIA(imagen, ladoMaximo: 1600, calidad: 0.8) else { return false }
        let nombre = "\(UUID().uuidString).jpg"
        do {
            try jpeg.write(to: Almacen.carpetaFotos.appendingPathComponent(nombre), options: [.atomic, .completeFileProtection])
            datos.fotos.append(FotoProgreso(fecha: Date(), archivo: nombre, nota: nota))
            return true
        } catch {
            return false
        }
    }

    func imagen(de foto: FotoProgreso) -> UIImage? {
        UIImage(contentsOfFile: Almacen.carpetaFotos.appendingPathComponent(foto.archivo).path)
    }

    func eliminarFoto(_ foto: FotoProgreso) {
        try? FileManager.default.removeItem(at: Almacen.carpetaFotos.appendingPathComponent(foto.archivo))
        datos.fotos.removeAll { $0.id == foto.id }
    }

    // MARK: Ajuste automático

    var ajusteSugerido: AjusteSugerido? {
        guard datos.metaManual == nil, let perfil = datos.perfil else { return nil }
        return AjusteDinamico.sugerir(perfil: perfil, pesos: datos.pesos, ajusteActual: datos.ajusteKcal, hoy: Date())
    }

    func aplicarAjuste(_ a: AjusteSugerido) {
        var d = datos
        d.ajusteKcal = a.nuevoAjuste
        d.ajusteAutomatico = true
        datos = d
    }

    // MARK: Ayuno

    var ayunoActivo: SesionAyuno? { Ayuno.activa(datos.ayunos) }

    func iniciarAyuno(desde inicio: Date = Date()) {
        guard ayunoActivo == nil else { return }
        let s = SesionAyuno(inicio: inicio, horas: datos.horasAyuno)
        datos.ayunos.append(s)
        Recordatorios.programarFinAyuno(s, activo: datos.recordatorios.ayunoActivo)
        ActividadAyuno.iniciar(s, tema: tema)
        avisarCambios()
    }

    func terminarAyuno(_ fin: Date = Date()) {
        guard let i = datos.ayunos.lastIndex(where: { $0.finReal == nil }) else { return }
        datos.ayunos[i].finReal = max(fin, datos.ayunos[i].inicio)
        Recordatorios.cancelarFinAyuno()
        ActividadAyuno.terminar()
        avisarCambios()
    }

    func eliminarAyuno(_ s: SesionAyuno) {
        datos.ayunos.removeAll { $0.id == s.id }
    }

    // MARK: Alimentos propios y recetas

    func guardarAlimentoPropio(_ a: AlimentoPropio) {
        if let i = datos.alimentosPropios.firstIndex(where: { $0.id == a.id }) {
            datos.alimentosPropios[i] = a
        } else {
            datos.alimentosPropios.append(a)
        }
    }

    func eliminarAlimentoPropio(_ a: AlimentoPropio) {
        datos.alimentosPropios.removeAll { $0.id == a.id }
    }

    func guardarReceta(_ r: Receta) {
        if let i = datos.recetas.firstIndex(where: { $0.id == r.id }) {
            datos.recetas[i] = r
        } else {
            datos.recetas.append(r)
        }
    }

    func eliminarReceta(_ r: Receta) {
        datos.recetas.removeAll { $0.id == r.id }
    }

    /// Todo lo que se puede buscar: tabla del INS, tus alimentos y tus recetas.
    /// Los tuyos llevan código "P:" (propio) o "R:" (receta).
    var alimentosBuscables: [AlimentoBase] {
        let propios = datos.alimentosPropios.map {
            AlimentoBase(codigo: "P:\($0.id.uuidString)", nombre: $0.nombre, grupo: "Mis alimentos", por100g: $0.por100g, medidas: $0.medidas)
        }
        let recetas = datos.recetas.filter { !$0.ingredientes.isEmpty }.map { r in
            AlimentoBase(codigo: "R:\(r.id.uuidString)", nombre: r.nombre, grupo: "Mis recetas", por100g: Recetas.por100g(r),
                         medidas: [MedidaCasera(nombre: "porción", gramos: Recetas.gramosPorPorcion(r), estimada: false)])
        }
        return propios + recetas + tabla.alimentos
    }

    func buscarTodo(_ texto: String, limite: Int = 50) -> [Coincidencia] {
        Busqueda.buscar(texto, en: alimentosBuscables, limite: limite)
    }

    // MARK: Plan de comidas

    func planDe(_ dia: Date) -> PlanDia {
        datos.plan.first { Calendar.current.isDate($0.dia, inSameDayAs: dia) } ?? PlanDia(dia: Calendar.current.startOfDay(for: dia))
    }

    func guardarPlan(_ plan: PlanDia) {
        var d = datos
        d.plan.removeAll { Calendar.current.isDate($0.dia, inSameDayAs: plan.dia) }
        if !plan.items.isEmpty { d.plan.append(plan) }
        // Se guardan como máximo 60 días de plan.
        let limite = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        d.plan.removeAll { $0.dia < limite }
        datos = d
    }

    /// Genera (o vuelve a generar) el plan de un día con la meta vigente.
    func generarPlan(_ dia: Date, variante: Int) {
        guard let meta else { return }
        let opciones = Planificador.opciones(tabla: tabla.alimentos, recetas: datos.recetas, dieta: datos.perfil?.dieta ?? .equilibrada)
        guardarPlan(Planificador.generarDia(dia, meta: meta, opciones: opciones, variante: variante))
    }

    /// Pasa un elemento del plan al diario y lo marca como hecho. Si está
    /// activado, ajusta las porciones de lo que falta del día.
    func registrarDelPlan(_ item: ItemPlan, dia: Date) {
        var plan = planDe(dia)
        guard let i = plan.items.firstIndex(where: { $0.id == item.id }) else { return }
        let registro = Registro(fecha: Diario.fechaParaRegistrar(enDia: dia), comida: item.comida, nombre: item.nombre,
                                gramos: item.gramos, por100g: item.por100g, origen: item.origen, codigoINS: item.codigoINS)
        plan.items[i].hecho = true
        agregar([registro])
        if datos.ajustarPorcionesPlan, let meta {
            let consumido = Diario.resumen(de: dia, en: datos.registros).total.kcal
            plan = Planificador.ajustarPorciones(plan, consumidoKcal: consumido, meta: meta)
        }
        guardarPlan(plan)
    }

    func alternarCompra(_ clave: String) {
        if let i = datos.comprasMarcadas.firstIndex(of: clave) {
            datos.comprasMarcadas.remove(at: i)
        } else {
            datos.comprasMarcadas.append(clave)
        }
    }

    // MARK: Coach

    func contextoCoach() -> String? {
        guard datos.coachCompartirResumen else { return nil }
        let hoy = Diario.resumen(de: Date(), en: datos.registros).total
        return LectorIA.contextoCoach(consumido: hoy, meta: meta, aguaMl: Agua.delDia(Date(), en: datos.agua),
                                      metaAguaMl: metaAgua, objetivo: datos.perfil?.objetivo, dieta: datos.perfil?.dieta)
    }

    // MARK: Copiar y favoritos

    /// Copia una comida del día visible a otro día (opcionalmente a otra comida).
    func copiarComida(_ comida: TipoComida, a dia: Date, como destino: TipoComida? = nil) {
        let origen = Diario.resumen(de: diaVisible, en: datos.registros).registros(comida)
        agregar(Copiado.copiar(origen, aDia: dia, comida: destino))
    }

    /// Copia todo el día visible a otro día.
    func copiarDia(a dia: Date) {
        let origen = Diario.registros(de: diaVisible, en: datos.registros)
        agregar(Copiado.copiar(origen, aDia: dia))
    }

    func guardarFavorito(nombre: String, registros: [Registro], comida: TipoComida) {
        let limpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        datos.favoritos.insert(ComidaFavorita(nombre: limpio.isEmpty ? Copiado.nombreSugerido(registros, comida: comida) : limpio,
                                              registros: registros, comidaHabitual: comida), at: 0)
    }

    func eliminarFavorito(_ f: ComidaFavorita) {
        datos.favoritos.removeAll { $0.id == f.id }
    }

    /// Registros listos para guardar a partir de un favorito, en el día visible.
    func registrosDe(_ f: ComidaFavorita, comida: TipoComida) -> [Registro] {
        Copiado.copiar(f.registros, aDia: diaVisible, comida: comida).map { r in
            var r = r
            r.fecha = Diario.fechaParaRegistrar(enDia: diaVisible)
            return r
        }
    }

    // MARK: Widgets

    /// Escribe el resumen que leen los widgets y les pide actualizarse.
    func avisarCambios() {
        ResumenWidget.desde(self).guardarYRecargar()
    }
}
