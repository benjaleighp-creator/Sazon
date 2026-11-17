import Foundation
import UserNotifications
import HealthKit
import WidgetKit
import ActivityKit

// Integraciones con el sistema: widgets, recordatorios, Apple Salud y la
// Actividad en vivo del ayuno. Todas fallan en silencio si el permiso no
// está (por ejemplo, si la firma gratuita no conserva un permiso): la app
// sigue funcionando igual.

// MARK: - Qué permite la firma

/// Lee el perfil de aprovisionamiento que agrega Sideloadly al firmar
/// (embedded.mobileprovision) para saber qué permisos quedaron activos.
enum Firma {
    static var permisos: [String: Any] { PerfilFirma.permisos }

    /// True si la firma incluye HealthKit.
    static var salud: Bool { (permisos["com.apple.developer.healthkit"] as? Bool) == true }

    /// True si la app trae la extensión de widgets.
    static var widgets: Bool {
        guard let url = Bundle.main.builtInPlugInsURL,
              let contenido = try? FileManager.default.contentsOfDirectory(atPath: url.path) else { return false }
        return contenido.contains { $0.hasSuffix(".appex") }
    }

    /// Fecha en que caduca esta instalación (firma de 7 días con Apple ID
    /// gratuito). Nil si no hay `embedded.mobileprovision` (simulador) o no
    /// se puede leer.
    static let caducidad: Date? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let datos = try? Data(contentsOf: url) else { return nil }
        return CaducidadFirma.fecha(de: datos)
    }()
}

// MARK: - Widgets

extension ResumenWidget {
    @MainActor
    static func desde(_ a: Almacen) -> ResumenWidget {
        let hoy = Date()
        let consumido = Diario.resumen(de: hoy, en: a.datos.registros).total
        let meta = a.metaDe(hoy) ?? .cero
        let ayuno = a.ayunoActivo
        let hex = a.tema.claro.hexHero
        let favorito = a.datos.favoritos.first
        return ResumenWidget(
            fecha: hoy, kcal: consumido.kcal, metaKcal: meta.kcal,
            proteina: consumido.proteina, metaProteina: meta.proteina,
            carbohidratos: consumido.carbohidratos, metaCarbohidratos: meta.carbohidratos,
            grasas: consumido.grasas, metaGrasas: meta.grasas,
            aguaMl: Agua.delDia(hoy, en: a.datos.agua), metaAguaMl: a.metaAgua,
            racha: Series.racha(a.datos.registros, hoy: hoy),
            ayunoInicio: ayuno?.inicio, ayunoHoras: ayuno?.horas,
            colorInicio: hex[0], colorFin: hex[1], colorTexto: hex[2], colorSecundario: hex[3],
            vasoMl: a.datos.vasoMl,
            favoritoID: favorito?.id.uuidString, favoritoNombre: favorito?.nombre, favoritoKcal: favorito?.total.kcal)
    }

    /// Guarda el resumen solo si cambió y pide a los widgets redibujarse.
    func guardarYRecargar() {
        guard ContenedorCompartido.grupoDisponible else { return }
        var comparable = self
        if var anterior = ResumenWidget.leer() {
            anterior.fecha = fecha
            comparable.fecha = fecha
            if anterior == comparable, Calendar.current.isDateInToday(fecha) { return }
        }
        if guardar() {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

// MARK: - Recordatorios (notificaciones locales)

enum Recordatorios {
    private static var centro: UNUserNotificationCenter { .current() }
    private static let prefijo = "sazon."
    private static let idAyuno = "sazon.ayuno.fin"
    private static let idCaducidad = "sazon.caducidad"

    /// Pide permiso para notificaciones. Devuelve true si lo diste.
    static func pedirPermiso() async -> Bool {
        (try? await centro.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func permisoConcedido() async -> Bool {
        let ajustes = await centro.notificationSettings()
        return ajustes.authorizationStatus == .authorized || ajustes.authorizationStatus == .provisional
    }

    /// Vuelve a programar comidas, agua y peso según la configuración.
    static func reprogramar(_ c: ConfigRecordatorios) {
        centro.getPendingNotificationRequests { pendientes in
            let viejos = pendientes.map(\.identifier).filter { $0.hasPrefix(prefijo) && $0 != idAyuno && $0 != idCaducidad }
            centro.removePendingNotificationRequests(withIdentifiers: viejos)

            if c.comidasActivas {
                let comidas: [(String, String, Int)] = [
                    ("desayuno", "¿Ya desayunaste?", c.horaDesayuno),
                    ("almuerzo", "Hora del almuerzo", c.horaAlmuerzo),
                    ("cena", "¿Qué cenaste hoy?", c.horaCena)
                ]
                for (id, titulo, minuto) in comidas {
                    programarDiario(id: prefijo + "comida." + id, titulo: titulo,
                                    texto: "Registra tu comida en Sazón para seguir tu día.", minuto: minuto)
                }
            }
            if c.aguaActiva {
                let paso = max(1, min(c.aguaCadaHoras, 6))
                for hora in stride(from: 9, through: 21, by: paso) {
                    programarDiario(id: prefijo + "agua.\(hora)", titulo: "Un vaso de agua",
                                    texto: "Toca para sumar agua en Sazón.", minuto: hora * 60)
                }
            }
            if c.pesoActivo {
                var f = DateComponents()
                f.weekday = c.pesoDiaSemana
                f.hour = c.pesoHora / 60
                f.minute = c.pesoHora % 60
                agregar(id: prefijo + "peso", titulo: "Día de pesarte",
                        texto: "Anota tu peso en Progreso para ajustar tu meta.",
                        disparador: UNCalendarNotificationTrigger(dateMatching: f, repeats: true))
            }
        }
    }

    private static func programarDiario(id: String, titulo: String, texto: String, minuto: Int) {
        var f = DateComponents()
        f.hour = minuto / 60
        f.minute = minuto % 60
        agregar(id: id, titulo: titulo, texto: texto,
                disparador: UNCalendarNotificationTrigger(dateMatching: f, repeats: true))
    }

    private static func agregar(id: String, titulo: String, texto: String, disparador: UNNotificationTrigger) {
        let contenido = UNMutableNotificationContent()
        contenido.title = titulo
        contenido.body = texto
        contenido.sound = .default
        centro.add(UNNotificationRequest(identifier: id, content: contenido, trigger: disparador))
    }

    static func programarFinAyuno(_ s: SesionAyuno, activo: Bool) {
        cancelarFinAyuno()
        guard activo else { return }
        let segundos = s.finPlaneado.timeIntervalSinceNow
        guard segundos > 1 else { return }
        agregar(id: idAyuno, titulo: "¡Ayuno completado!",
                texto: "Llegaste a tus \(Formato.numero(s.horas)) horas. Ábrelo en Sazón para terminarlo.",
                disparador: UNTimeIntervalNotificationTrigger(timeInterval: segundos, repeats: false))
    }

    static func cancelarFinAyuno() {
        centro.removePendingNotificationRequests(withIdentifiers: [idAyuno])
    }

    /// Aviso 1 día antes de que caduque la instalación. Solo se programa si
    /// ya diste permiso de notificaciones: no lo pide por esto.
    static func programarCaducidad(_ caduca: Date?) async {
        centro.removePendingNotificationRequests(withIdentifiers: [idCaducidad])
        guard let caduca, let momento = CaducidadFirma.momentoNotificacion(caduca: caduca),
              await permisoConcedido() else { return }
        agregar(id: idCaducidad, titulo: "Sazón caduca mañana",
                texto: "Renueva la app con AltStore (o vuelve a instalarla) antes de \(Formato.hora(caduca)) para seguir usándola. Tus datos no se pierden.",
                disparador: UNTimeIntervalNotificationTrigger(timeInterval: max(1, momento.timeIntervalSinceNow), repeats: false))
    }
}

// MARK: - Apple Salud

/// Lee pasos, calorías activas y peso, y guarda tu peso en Apple Salud.
/// Necesita el permiso de HealthKit en la firma; si no está, las llamadas
/// devuelven error y la app sigue sin datos de Salud.
@MainActor
final class Salud {
    static let compartido = Salud()
    private let tienda = HKHealthStore()

    /// Apple Salud existe en el iPhone y la firma incluye el permiso.
    var disponible: Bool { HKHealthStore.isHealthDataAvailable() && Firma.salud }

    private var tiposLectura: Set<HKObjectType> {
        var s = Set<HKObjectType>()
        if let t = HKObjectType.quantityType(forIdentifier: .stepCount) { s.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { s.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .bodyMass) { s.insert(t) }
        return s
    }

    /// Lo que se escribe por cada comida: energía y macros consumidos.
    private static let tiposComida: [(id: HKQuantityTypeIdentifier, unidad: HKUnit, valor: KeyPath<Nutrientes, Double>, sufijo: String)] = [
        (.dietaryEnergyConsumed, .kilocalorie(), \Nutrientes.kcal, "kcal"),
        (.dietaryProtein, .gram(), \Nutrientes.proteina, "proteina"),
        (.dietaryCarbohydrates, .gram(), \Nutrientes.carbohidratos, "carbohidratos"),
        (.dietaryFatTotal, .gram(), \Nutrientes.grasas, "grasas")
    ]

    private func tiposEscritura(comidas: Bool) -> Set<HKSampleType> {
        var s = Set<HKSampleType>()
        if let t = HKObjectType.quantityType(forIdentifier: .bodyMass) { s.insert(t) }
        if comidas {
            for c in Salud.tiposComida {
                if let t = HKObjectType.quantityType(forIdentifier: c.id) { s.insert(t) }
            }
        }
        return s
    }

    /// Pide permiso. Devuelve nil si todo fue bien o un texto con el problema.
    /// - escribirComidas: pide también escribir calorías y macros consumidos.
    func pedirPermiso(escribirComidas: Bool = false) async -> String? {
        guard HKHealthStore.isHealthDataAvailable() else { return "Apple Salud no está disponible en este dispositivo." }
        guard Firma.salud else {
            return "La firma de esta instalación no incluye el permiso de Apple Salud. Instala la versión «completa» del .ipa; si Sideloadly no lo conserva, esta función no está disponible con tu cuenta gratuita."
        }
        do {
            try await tienda.requestAuthorization(toShare: tiposEscritura(comidas: escribirComidas), read: tiposLectura)
            return nil
        } catch {
            return "No se pudo conectar con Apple Salud (\(error.localizedDescription)). Es posible que la firma de la app no incluya el permiso de HealthKit."
        }
    }

    /// Actualiza pasos y calorías activas de hoy en el almacén.
    func actualizarHoy(en almacen: Almacen) async {
        guard almacen.datos.saludActiva, disponible else {
            almacen.actividadSalud = 0
            almacen.pasosSalud = 0
            return
        }
        let inicio = Calendar.current.startOfDay(for: Date())
        async let pasos = suma(.stepCount, unidad: .count(), desde: inicio)
        async let energia = suma(.activeEnergyBurned, unidad: .kilocalorie(), desde: inicio)
        let (p, e) = await (pasos, energia)
        almacen.pasosSalud = p ?? 0
        almacen.actividadSalud = e ?? 0
    }

    /// Último peso guardado en Apple Salud (kg y fecha).
    func ultimoPeso() async -> (kg: Double, fecha: Date)? {
        guard disponible, let tipo = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        return await withCheckedContinuation { cont in
            let orden = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let consulta = HKSampleQuery(sampleType: tipo, predicate: nil, limit: 1, sortDescriptors: [orden]) { _, muestras, _ in
                if let m = muestras?.first as? HKQuantitySample {
                    cont.resume(returning: (m.quantity.doubleValue(for: .gramUnit(with: .kilo)), m.endDate))
                } else {
                    cont.resume(returning: nil)
                }
            }
            tienda.execute(consulta)
        }
    }

    func guardarPeso(_ kg: Double, fecha: Date, activa: Bool) {
        guard activa, disponible, kg > 0, let tipo = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        let muestra = HKQuantitySample(type: tipo, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
                                       start: fecha, end: fecha)
        tienda.save(muestra) { _, _ in }
    }

    /// Escribe (o actualiza) en Salud las calorías y macros de unos
    /// registros, y borra los de los registros eliminados. Cada muestra lleva
    /// un identificador de sincronización (`HKMetadataKeySyncIdentifier`)
    /// con el id del registro: al editarlo, la versión nueva reemplaza a la
    /// anterior. Sin el permiso de HealthKit en la firma (por ejemplo, el
    /// .ipa sencillo) o sin autorización, no hace nada.
    func sincronizarComidas(cambiados: [Registro], borrados: [UUID]) {
        guard disponible, !(cambiados.isEmpty && borrados.isEmpty) else { return }
        let version = NSNumber(value: Int(Date().timeIntervalSince1970))
        var muestras: [HKObject] = []
        for c in Salud.tiposComida {
            guard let tipo = HKQuantityType.quantityType(forIdentifier: c.id),
                  tienda.authorizationStatus(for: tipo) == .sharingAuthorized else { continue }
            for r in cambiados {
                let valor = max(0, r.total[keyPath: c.valor])
                guard valor.isFinite else { continue }
                let metadatos: [String: Any] = [
                    HKMetadataKeySyncIdentifier: "sazon.\(r.id.uuidString).\(c.sufijo)",
                    HKMetadataKeySyncVersion: version,
                    HKMetadataKeyFoodType: r.nombre
                ]
                muestras.append(HKQuantitySample(type: tipo, quantity: HKQuantity(unit: c.unidad, doubleValue: valor),
                                                 start: r.fecha, end: r.fecha, metadata: metadatos))
            }
            if !borrados.isEmpty {
                let ids = borrados.map { "sazon.\($0.uuidString).\(c.sufijo)" }
                let filtro = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: ids)
                tienda.deleteObjects(of: tipo, predicate: filtro) { _, _, _ in }
            }
        }
        if !muestras.isEmpty {
            tienda.save(muestras) { _, _ in }
        }
    }

    private func suma(_ id: HKQuantityTypeIdentifier, unidad: HKUnit, desde: Date) async -> Double? {
        guard let tipo = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        let predicado = HKQuery.predicateForSamples(withStart: desde, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let consulta = HKStatisticsQuery(quantityType: tipo, quantitySamplePredicate: predicado, options: .cumulativeSum) { _, estadistica, _ in
                cont.resume(returning: estadistica?.sumQuantity()?.doubleValue(for: unidad))
            }
            tienda.execute(consulta)
        }
    }
}

// MARK: - Actividad en vivo del ayuno

enum ActividadAyuno {
    static func iniciar(_ s: SesionAyuno, tema: Tema) {
        guard Firma.widgets, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        terminar()
        let hex = tema.claro.hexHero
        let atributos = AtributosAyuno(inicio: s.inicio, horas: s.horas,
                                       colorInicio: hex[0], colorFin: hex[1], colorTexto: hex[2])
        let estado = AtributosAyuno.ContentState(fin: s.finPlaneado)
        _ = try? Activity.request(attributes: atributos,
                                  content: ActivityContent(state: estado, staleDate: s.finPlaneado.addingTimeInterval(6 * 3600)),
                                  pushType: nil)
    }

    static func terminar() {
        let actividades = Activity<AtributosAyuno>.activities
        guard !actividades.isEmpty else { return }
        Task {
            for a in actividades {
                await a.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
