import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

// Código que comparten la app y la extensión de widgets.
// Sin App Group (por ejemplo, si la firma no lo conserva) la app sigue
// funcionando y los widgets muestran datos de ejemplo.

enum ContenedorCompartido {
    /// Identificador del App Group (leído del Info.plist, clave "GrupoCompartido").
    static var identificadorGrupo: String {
        (Bundle.main.object(forInfoDictionaryKey: "GrupoCompartido") as? String) ?? "group.pe.benjamin.sazon"
    }

    static var carpetaGrupo: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identificadorGrupo)
    }

    static var grupoDisponible: Bool { carpetaGrupo != nil }
}

/// Resumen pequeño que la app escribe para los widgets.
struct ResumenWidget: Codable, Equatable {
    var fecha: Date
    var kcal: Double
    var metaKcal: Double
    var proteina: Double
    var metaProteina: Double
    var carbohidratos: Double
    var metaCarbohidratos: Double
    var grasas: Double
    var metaGrasas: Double
    var aguaMl: Double
    var metaAguaMl: Double
    var racha: Int
    /// Ayuno en curso: inicio y horas planeadas (nil si no hay).
    var ayunoInicio: Date?
    var ayunoHoras: Double?
    /// Colores del tema (hex) para que el widget se vea igual que la app.
    var colorInicio: String
    var colorFin: String
    var colorTexto: String
    var colorSecundario: String

    static let nombreArchivo = "resumen-widget.json"

    static let ejemplo = ResumenWidget(
        fecha: Date(), kcal: 1350, metaKcal: 2200, proteina: 72, metaProteina: 120, carbohidratos: 160,
        metaCarbohidratos: 260, grasas: 40, metaGrasas: 65, aguaMl: 1250, metaAguaMl: 2500, racha: 5,
        ayunoInicio: nil, ayunoHoras: nil,
        colorInicio: "A63E17", colorFin: "6E2410", colorTexto: "FFF7EC", colorSecundario: "FBE6D7")

    static func leer() -> ResumenWidget? {
        guard let carpeta = ContenedorCompartido.carpetaGrupo,
              let datos = try? Data(contentsOf: carpeta.appendingPathComponent(nombreArchivo)) else { return nil }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try? d.decode(ResumenWidget.self, from: datos)
    }

    /// Escribe el resumen. Devuelve false si no hay App Group.
    @discardableResult
    func guardar() -> Bool {
        guard let carpeta = ContenedorCompartido.carpetaGrupo else { return false }
        let c = JSONEncoder()
        c.dateEncodingStrategy = .iso8601
        guard let datos = try? c.encode(self) else { return false }
        return (try? datos.write(to: carpeta.appendingPathComponent(ResumenWidget.nombreArchivo), options: .atomic)) != nil
    }
}

#if canImport(ActivityKit)
/// Datos de la Actividad en vivo del ayuno (pantalla bloqueada e Isla Dinámica).
struct AtributosAyuno: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var fin: Date
    }
    var inicio: Date
    var horas: Double
    var colorInicio: String
    var colorFin: String
    var colorTexto: String
}
#endif
