import Foundation
import UIKit

// Acciones del almacén para agua, progreso, ayuno, alimentos propios,
// recetas, plan, compras y coach. Todas guardan en el JSON local.

extension Almacen {

    // MARK: Agua

    var metaAgua: Double { Agua.meta(datos) }
    var aguaVisible: Double { Agua.delDia(diaVisible, en: datos.agua) }

    /// Suma agua al día de hoy (Siri, Atajos), sin importar el día que muestra el diario.
    func agregarAguaHoy(_ ml: Double) {
        datos.agua.append(RegistroAgua(fecha: Date(), ml: ml))
    }

    /// Aplica lo que se hizo desde los botones del widget («+ agua» y
    /// «repetir favorito»). Si los datos no se pudieron abrir, la cola
    /// espera (no se pierde).
    func procesarAccionesWidget() {
        guard !archivoProtegido else { return }
        let acciones = ColaWidget.tomarTodas()
        guard !acciones.isEmpty else { return }
        var d = datos
        var nuevos: [Registro] = []
        for a in acciones {
            switch a.tipo {
            case .agua:
                d.agua.append(RegistroAgua(fecha: a.fecha, ml: a.ml ?? d.vasoMl))
            case .favorito:
                guard let f = d.favoritos.first(where: { $0.id.uuidString == a.favoritoID }) else { continue }
                nuevos += Copiado.copiar(f.registros, aDia: a.fecha, comida: f.comidaHabitual).map { r in
                    var r = r
                    r.fecha = a.fecha
                    return r
                }
            }
        }
        datos = d
        agregar(nuevos)
    }

    func agregarAgua(_ ml: Double) {
        datos.agua.append(RegistroAgua(fecha: Diario.fechaParaRegistrar(enDia: diaVisible), ml: ml))
    }

    /// Quita el último vaso del día visible.
    func quitarAgua() {
        guard let i = datos.agua.lastIndex(where: { Calendar.current.isDate($0.fecha, inSameDayAs: diaVisible) }) else { return }
        datos.agua.remove(at: i)
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

    /// Miniatura de una foto de progreso: se genera una sola vez (lado
    /// mayor de `MiniaturasFotos.lado` px) y queda en memoria. Antes se
    /// leía el JPEG completo de 1600 px en cada dibujo de la lista.
    func miniatura(de foto: FotoProgreso) -> UIImage? {
        let clave = foto.archivo as NSString
        if let guardada = MiniaturasFotos.cache.object(forKey: clave) { return guardada }
        guard let completa = imagen(de: foto) else { return nil }
        let escala = MiniaturasFotos.lado / max(completa.size.width, completa.size.height, 1)
        let tamano = CGSize(width: completa.size.width * min(escala, 1), height: completa.size.height * min(escala, 1))
        let mini = completa.preparingThumbnail(of: tamano) ?? completa
        MiniaturasFotos.cache.setObject(mini, forKey: clave)
        return mini
    }

    func eliminarFoto(_ foto: FotoProgreso) {
        MiniaturasFotos.cache.removeObject(forKey: foto.archivo as NSString)
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
    }

    func terminarAyuno(_ fin: Date = Date()) {
        guard let i = datos.ayunos.lastIndex(where: { $0.finReal == nil }) else { return }
        datos.ayunos[i].finReal = max(fin, datos.ayunos[i].inicio)
        Recordatorios.cancelarFinAyuno()
        ActividadAyuno.terminar()
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

    /// Tus alimentos y tus recetas como alimentos buscables.
    /// Llevan código "P:" (propio) o "R:" (receta).
    var alimentosPropiosYRecetas: [AlimentoBase] {
        let propios = datos.alimentosPropios.map {
            AlimentoBase(codigo: "P:\($0.id.uuidString)", nombre: $0.nombre, grupo: "Mis alimentos", por100g: $0.por100g, medidas: $0.medidas)
        }
        let recetas = datos.recetas.filter { !$0.ingredientes.isEmpty }.map { r in
            AlimentoBase(codigo: "R:\(r.id.uuidString)", nombre: r.nombre, grupo: "Mis recetas", por100g: Recetas.por100g(r),
                         medidas: [MedidaCasera(nombre: "porción", gramos: Recetas.gramosPorPorcion(r), estimada: false)])
        }
        return propios + recetas
    }

    func buscarTodo(_ texto: String, limite: Int = 50) -> [Coincidencia] {
        // Tus alimentos y recetas son pocos: se buscan directo. La tabla del
        // INS usa su índice ya normalizado.
        let tuyos = Busqueda.buscar(texto, en: alimentosPropiosYRecetas, limite: limite)
        let tabla = Busqueda.buscar(texto, en: self.tabla.indice, limite: limite)
        return Busqueda.ordenar(tuyos + tabla, limite: limite)
    }

    // MARK: Plan de comidas

    func planDe(_ dia: Date) -> PlanDia {
        datos.plan.first { Calendar.current.isDate($0.dia, inSameDayAs: dia) } ?? PlanDia(dia: Calendar.current.startOfDay(for: dia))
    }

    func guardarPlan(_ plan: PlanDia) {
        var d = datos
        d.plan.removeAll { Calendar.current.isDate($0.dia, inSameDayAs: plan.dia) }
        if !plan.items.isEmpty { d.plan.append(plan) }
        // Se borran los planes de hace más de 30 días (los futuros se quedan).
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

    /// Lo que se repite para una comida: tu favorito de esa comida o, si no
    /// tienes, lo que comiste en ella el último día (hasta 14 días atrás).
    /// Devuelve una descripción («tu favorito «Desayuno de siempre»») y los registros.
    func ultimaComida(_ comida: TipoComida, hoy: Date = Date()) -> (String, [Registro])? {
        if let f = datos.favoritos.first(where: { $0.comidaHabitual == comida }), !f.registros.isEmpty {
            return ("tu favorito «\(f.nombre)»", f.registros)
        }
        let cal = Calendar.current
        let inicioHoy = cal.startOfDay(for: hoy)
        let grupos = Diario.porDia(datos.registros.filter { $0.comida == comida && $0.fecha < inicioHoy })
        for atras in 1...14 {
            guard let dia = cal.date(byAdding: .day, value: -atras, to: inicioHoy),
                  let lista = grupos[dia], !lista.isEmpty else { continue }
            return (atras == 1 ? "el \(comida.nombre.lowercased()) de ayer" : "el \(comida.nombre.lowercased()) del \(Formato.diaLargo(dia).lowercased())",
                    lista.sorted { $0.fecha < $1.fecha })
        }
        return nil
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
    /// Lo llama el guardado (una vez por grupo de cambios) y la app al
    /// volver a primer plano.
    func avisarCambios() {
        ResumenWidget.desde(self).guardarYRecargar()
    }
}

/// Memoria de miniaturas de las fotos de progreso (iOS la vacía sola si
/// falta memoria).
enum MiniaturasFotos {
    /// Lado mayor en píxeles (la miniatura se ve de 96 × 128 pt; × 3 en
    /// pantallas Retina).
    static let lado: CGFloat = 400
    static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 120
        return c
    }()
}
