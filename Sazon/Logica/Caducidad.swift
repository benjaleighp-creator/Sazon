import Foundation

/// Cuándo caduca esta instalación. Con un Apple ID gratuito, la firma de
/// AltStore o Sideloadly dura 7 días; la fecha exacta viene en el archivo
/// `embedded.mobileprovision` que va dentro de la app. Ese archivo es un
/// plist envuelto en una firma digital: aquí solo se busca el texto entre
/// `<?xml` y `</plist>` y se lee la clave `ExpirationDate`.
enum CaducidadFirma {
    /// Desde cuánto antes se muestra el aviso en Ajustes (2 días).
    static let margenAviso: TimeInterval = 2 * 24 * 60 * 60
    /// Cuánto antes llega la notificación (1 día).
    static let antelacionNotificacion: TimeInterval = 24 * 60 * 60

    /// Fecha de caducidad leída del contenido de `embedded.mobileprovision`.
    /// Devuelve nil si no encuentra el plist o la clave (nunca falla).
    static func fecha(de datos: Data) -> Date? {
        guard let inicio = datos.range(of: Data("<?xml".utf8)),
              let fin = datos.range(of: Data("</plist>".utf8), in: inicio.lowerBound..<datos.endIndex) else { return nil }
        let plist = datos.subdata(in: inicio.lowerBound..<fin.upperBound)
        guard let dic = try? PropertyListSerialization.propertyList(from: plist, options: [], format: nil) as? [String: Any] else { return nil }
        return dic["ExpirationDate"] as? Date
    }

    /// True si faltan 2 días o menos (o si ya caducó).
    static func necesitaAviso(caduca: Date, ahora: Date = Date()) -> Bool {
        caduca.timeIntervalSince(ahora) <= margenAviso
    }

    /// Días de calendario entre hoy y el día en que caduca (0 = hoy).
    static func diasRestantes(caduca: Date, ahora: Date = Date(), calendario: Calendar = .current) -> Int {
        let a = calendario.startOfDay(for: ahora)
        let b = calendario.startOfDay(for: caduca)
        return calendario.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// "Caduca el sábado, 21 de noviembre a las 14:05".
    static func textoFecha(caduca: Date, ahora: Date = Date(), calendario: Calendar = .current) -> String {
        if caduca <= ahora { return "Caducó el \(Formato.diaLargo(caduca, calendario: calendario).lowercased(with: Formato.locale)) a las \(Formato.hora(caduca, calendario: calendario))" }
        let dia: String
        switch diasRestantes(caduca: caduca, ahora: ahora, calendario: calendario) {
        case 0: dia = "hoy"
        case 1: dia = "mañana"
        default: dia = "el " + Formato.diaLargo(caduca, calendario: calendario).lowercased(with: Formato.locale)
        }
        return "Caduca \(dia) a las \(Formato.hora(caduca, calendario: calendario))"
    }

    /// "Quedan 5 días", "Caduca mañana", "Caduca hoy" o "Ya caducó".
    static func textoRestante(caduca: Date, ahora: Date = Date(), calendario: Calendar = .current) -> String {
        if caduca <= ahora { return "Ya caducó" }
        switch diasRestantes(caduca: caduca, ahora: ahora, calendario: calendario) {
        case 0: return "Caduca hoy"
        case 1: return "Caduca mañana"
        case let d: return "Quedan \(d) días"
        }
    }

    /// Momento de la notificación (1 día antes), o nil si ya pasó.
    static func momentoNotificacion(caduca: Date, ahora: Date = Date()) -> Date? {
        let momento = caduca.addingTimeInterval(-antelacionNotificacion)
        return momento > ahora ? momento : nil
    }
}
