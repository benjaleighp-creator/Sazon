import Foundation
import AppIntents
import WidgetKit

// Botones del widget («+ agua» y «repetir favorito»). El widget no puede
// abrir los datos de la app (no están en el App Group), así que deja la
// acción anotada en una cola del App Group, suma lo que corresponde al
// resumen que muestra y la app la aplica de verdad al abrirse.
// Sin App Group (firma sin ese permiso), los botones no hacen nada.

/// Acción hecha desde el widget, pendiente de pasar a los datos de la app.
struct AccionWidget: Codable, Equatable {
    enum Tipo: String, Codable { case agua, favorito }
    var tipo: Tipo
    var fecha: Date
    var ml: Double?
    var favoritoID: String?
}

enum ColaWidget {
    static let nombreArchivo = "acciones-widget.json"

    private static var url: URL? {
        ContenedorCompartido.carpetaGrupo?.appendingPathComponent(nombreArchivo)
    }

    private static func leer() -> [AccionWidget] {
        guard let url, let datos = try? Data(contentsOf: url) else { return [] }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return (try? d.decode([AccionWidget].self, from: datos)) ?? []
    }

    private static func escribir(_ acciones: [AccionWidget]) -> Bool {
        guard let url else { return false }
        if acciones.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return true
        }
        let c = JSONEncoder()
        c.dateEncodingStrategy = .iso8601
        guard let datos = try? c.encode(acciones) else { return false }
        // Se puede escribir con el iPhone bloqueado (después del primer desbloqueo).
        return (try? datos.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])) != nil
    }

    /// Anota una acción. Devuelve false si no hay App Group.
    @discardableResult
    static func encolar(_ accion: AccionWidget) -> Bool {
        var lista = leer()
        guard lista.count < 200 else { return false }
        lista.append(accion)
        return escribir(lista)
    }

    /// Devuelve las acciones pendientes y vacía la cola.
    static func tomarTodas() -> [AccionWidget] {
        let lista = leer()
        if !lista.isEmpty { _ = escribir([]) }
        return lista
    }
}

/// «+ agua» desde el widget: suma un vaso (el tamaño elegido en la app).
struct SumarAguaWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Sumar un vaso de agua"
    static var description = IntentDescription("Suma un vaso de agua desde el widget de Sazón.")
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        guard var resumen = ResumenWidget.leer() else { return .result() }
        let ml = resumen.vasoMl ?? 250
        let ahora = Date()
        guard ColaWidget.encolar(AccionWidget(tipo: .agua, fecha: ahora, ml: ml, favoritoID: nil)) else { return .result() }
        if !Calendar.current.isDate(resumen.fecha, inSameDayAs: ahora) {
            resumen.aguaMl = 0
            resumen.kcal = 0; resumen.proteina = 0; resumen.carbohidratos = 0; resumen.grasas = 0
        }
        resumen.aguaMl += ml
        resumen.fecha = ahora
        resumen.guardar()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// «Repetir favorito» desde el widget: registra tu primer favorito.
struct RepetirFavoritoWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Repetir mi favorito"
    static var description = IntentDescription("Registra tu comida favorita desde el widget de Sazón.")
    static var isDiscoverable: Bool = false

    @Parameter(title: "Favorito")
    var favoritoID: String

    init() {}

    init(favoritoID: String) {
        self.favoritoID = favoritoID
    }

    func perform() async throws -> some IntentResult {
        guard var resumen = ResumenWidget.leer(), !favoritoID.isEmpty else { return .result() }
        let ahora = Date()
        guard ColaWidget.encolar(AccionWidget(tipo: .favorito, fecha: ahora, ml: nil, favoritoID: favoritoID)) else { return .result() }
        if !Calendar.current.isDate(resumen.fecha, inSameDayAs: ahora) {
            resumen.aguaMl = 0
            resumen.kcal = 0; resumen.proteina = 0; resumen.carbohidratos = 0; resumen.grasas = 0
        }
        if favoritoID == resumen.favoritoID {
            resumen.kcal += resumen.favoritoKcal ?? 0
        }
        resumen.fecha = ahora
        resumen.guardar()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
