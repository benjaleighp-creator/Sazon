import Foundation

/// Formatos en español (Perú): números con coma decimal, fechas con solo la
/// primera letra en mayúscula ("Domingo, 1 de noviembre") y horas en 24 h.
enum Formato {

    static let locale = Locale(identifier: "es_PE")

    /// Número con hasta `decimales` decimales, sin ceros sobrantes: 2,5 · 70 · 1,375.
    static func numero(_ valor: Double, decimales: Int = 1) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "es_ES")   // coma decimal, sin separador raro
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = decimales
        return f.string(from: NSNumber(value: valor)) ?? String(valor)
    }

    /// Entero redondeado: 1834.
    static func entero(_ valor: Double) -> String {
        guard valor.isFinite else { return "0" }
        return String(Int(valor.rounded()))
    }

    /// Solo la primera letra en mayúscula (`.capitalized` pone mayúscula a cada palabra).
    static func primeraMayuscula(_ texto: String) -> String {
        guard let primera = texto.first else { return texto }
        return String(primera).uppercased(with: locale) + texto.dropFirst()
    }

    /// "Domingo, 1 de noviembre".
    static func diaLargo(_ fecha: Date, calendario: Calendar = .current) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.calendar = calendario
        f.timeZone = calendario.timeZone
        f.dateFormat = "EEEE, d 'de' MMMM"
        return primeraMayuscula(f.string(from: fecha))
    }

    /// "Hoy", "Ayer", "Mañana" o el día largo.
    static func diaRelativo(_ fecha: Date, hoy: Date = Date(), calendario: Calendar = .current) -> String {
        let a = calendario.startOfDay(for: fecha)
        let b = calendario.startOfDay(for: hoy)
        let dias = calendario.dateComponents([.day], from: b, to: a).day ?? 0
        switch dias {
        case 0: return "Hoy"
        case -1: return "Ayer"
        case 1: return "Mañana"
        default: return diaLargo(fecha, calendario: calendario)
        }
    }

    /// "14:05".
    static func hora(_ fecha: Date, calendario: Calendar = .current) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = calendario.timeZone
        f.dateFormat = "HH:mm"
        return f.string(from: fecha)
    }

    /// "1834 kcal" o "≈ 1834 kcal" si es estimado.
    static func kcal(_ valor: Double, estimado: Bool = false) -> String {
        (estimado ? "≈ " : "") + entero(valor) + " kcal"
    }

    /// "12 g" o "≈ 12 g".
    static func gramos(_ valor: Double, estimado: Bool = false) -> String {
        (estimado ? "≈ " : "") + numero(valor, decimales: valor < 10 ? 1 : 0) + " g"
    }
}
