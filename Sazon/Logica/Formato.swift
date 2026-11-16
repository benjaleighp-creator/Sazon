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

extension Formato {
    /// "Buenos días" (5:00–11:59), "Buenas tardes" (12:00–18:59) o "Buenas noches".
    static func saludo(hora: Int) -> String {
        switch hora {
        case 5..<12: return "Buenos días"
        case 12..<19: return "Buenas tardes"
        default: return "Buenas noches"
        }
    }

    /// Inicial del día de la semana: L, M, M, J, V, S, D.
    static func inicialDia(_ fecha: Date, calendario: Calendar = .current) -> String {
        let iniciales = ["D", "L", "M", "M", "J", "V", "S"]
        return iniciales[calendario.component(.weekday, from: fecha) - 1]
    }

    /// Número del día del mes: "1", "15".
    static func numeroDia(_ fecha: Date, calendario: Calendar = .current) -> String {
        String(calendario.component(.day, from: fecha))
    }
}

extension Formato {
    /// Tiempo de espera corto: "8 s", "1 min 05 s". Negativos o no finitos: "0 s".
    static func duracionCorta(_ segundos: TimeInterval) -> String {
        guard segundos.isFinite, segundos > 0 else { return "0 s" }
        let total = Int(segundos)
        let minutos = total / 60
        let resto = total % 60
        if minutos == 0 { return "\(resto) s" }
        return "\(minutos) min " + (resto < 10 ? "0\(resto)" : "\(resto)") + " s"
    }

    /// Lo mismo, dicho en palabras para VoiceOver: "8 segundos", "1 minuto y 5 segundos".
    static func duracionHablada(_ segundos: TimeInterval) -> String {
        guard segundos.isFinite, segundos > 0 else { return "0 segundos" }
        let total = Int(segundos)
        let minutos = total / 60
        let resto = total % 60
        let textoSeg = resto == 1 ? "1 segundo" : "\(resto) segundos"
        if minutos == 0 { return textoSeg }
        let textoMin = minutos == 1 ? "1 minuto" : "\(minutos) minutos"
        return resto == 0 ? textoMin : "\(textoMin) y \(textoSeg)"
    }
}

extension Formato {
    /// Convierte el Markdown sencillo que a veces devuelve la IA en texto
    /// plano: quita negritas, cursivas de guion bajo, código y títulos,
    /// cambia viñetas por «•» y los enlaces por su texto (sin enlace que se
    /// pueda tocar). El «%» queda tal cual.
    static func textoPlano(_ markdown: String) -> String {
        var lineas: [String] = []
        for linea in markdown.components(separatedBy: "\n") {
            var l = linea
            // Títulos: "## Cena" → "Cena".
            if let rango = l.range(of: "^\\s{0,3}#{1,6}\\s+", options: .regularExpression) {
                l.removeSubrange(rango)
            }
            // Viñetas: "* arroz" o "- arroz" → "• arroz".
            if let rango = l.range(of: "^(\\s*)[*+-]\\s+", options: .regularExpression) {
                let sangria = l[rango].prefix { $0 == " " || $0 == "\t" }
                l.replaceSubrange(rango, with: String(sangria) + "• ")
            }
            // Enlaces: "[texto](https://…)" → "texto".
            l = l.replacingOccurrences(of: "\\[([^\\]]*)\\]\\([^)]*\\)", with: "$1", options: .regularExpression)
            for marca in ["**", "__", "`"] {
                l = l.replacingOccurrences(of: marca, with: "")
            }
            lineas.append(l)
        }
        return lineas.joined(separator: "\n")
    }
}
