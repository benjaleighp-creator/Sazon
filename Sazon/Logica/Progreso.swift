import Foundation

/// Agua, peso, grasa corporal, ajuste automático, gráficos y ayuno.

// MARK: - Agua

enum Agua {
    /// Meta de agua: la escrita a mano o 35 ml por kg de peso, redondeada a
    /// 250 ml y entre 1,5 y 4 litros. Sin perfil: 2 litros. Es una regla
    /// general orientativa, no una indicación médica.
    static func meta(_ datos: DatosApp) -> Double {
        if let manual = datos.metaAguaManual, manual > 0 { return manual }
        guard let peso = datos.perfil?.pesoKg else { return 2000 }
        let bruto = peso * 35
        let redondeado = (bruto / 250).rounded() * 250
        return min(max(redondeado, 1500), 4000)
    }

    static func delDia(_ dia: Date, en registros: [RegistroAgua], calendario: Calendar = .current) -> Double {
        registros.filter { calendario.isDate($0.fecha, inSameDayAs: dia) }.reduce(0) { $0 + $1.ml }
    }
}

// MARK: - Cuerpo

enum Cuerpo {

    /// % de grasa corporal con la fórmula de la Marina de EE. UU. (medidas en cm).
    /// Hombres: 495 / (1,0324 − 0,19077·log10(cintura − cuello) + 0,15456·log10(talla)) − 450
    /// Mujeres: 495 / (1,29579 − 0,35004·log10(cintura + cadera − cuello) + 0,22100·log10(talla)) − 450
    /// Es una estimación; devuelve nil si faltan medidas o no tienen sentido.
    static func grasaMarina(sexo: Sexo, tallaCm: Double, cuello: Double?, cintura: Double?, cadera: Double?) -> Double? {
        guard let cuello, let cintura, tallaCm > 0 else { return nil }
        let densidad: Double
        switch sexo {
        case .masculino:
            let d = cintura - cuello
            guard d > 0 else { return nil }
            densidad = 1.0324 - 0.19077 * log10(d) + 0.15456 * log10(tallaCm)
        case .femenino:
            guard let cadera else { return nil }
            let d = cintura + cadera - cuello
            guard d > 0 else { return nil }
            densidad = 1.29579 - 0.35004 * log10(d) + 0.22100 * log10(tallaCm)
        }
        guard densidad > 0 else { return nil }
        let grasa = 495 / densidad - 450
        guard grasa.isFinite, (2...70).contains(grasa) else { return nil }
        return grasa
    }

    /// % de grasa de un registro: el escrito a mano o el calculado.
    static func grasa(de m: RegistroMedidas, perfil: Perfil?) -> Double? {
        if let manual = m.grasaManual { return manual }
        guard let p = perfil else { return nil }
        return grasaMarina(sexo: p.sexo, tallaCm: p.tallaCm, cuello: m.cuello, cintura: m.cintura, cadera: m.cadera)
    }

    /// Índice de masa corporal (kg/m²).
    static func imc(pesoKg: Double, tallaCm: Double) -> Double? {
        guard pesoKg > 0, tallaCm > 0 else { return nil }
        let m = tallaCm / 100
        return pesoKg / (m * m)
    }

    /// Pesos ordenados del más antiguo al más nuevo.
    static func ordenados(_ pesos: [RegistroPeso]) -> [RegistroPeso] {
        pesos.sorted { $0.fecha < $1.fecha }
    }

    /// Cambio de peso en kg por semana (regresión lineal de los pesos de
    /// los últimos `dias` días). Necesita al menos 3 pesos que abarquen 10 días.
    static func tendenciaSemanal(_ pesos: [RegistroPeso], hasta: Date, dias: Int = 21) -> Double? {
        let desde = hasta.addingTimeInterval(-Double(dias) * 86400)
        let puntos = ordenados(pesos).filter { $0.fecha >= desde && $0.fecha <= hasta }
        guard puntos.count >= 3, let primero = puntos.first, let ultimo = puntos.last,
              ultimo.fecha.timeIntervalSince(primero.fecha) >= 10 * 86400 else { return nil }
        let xs = puntos.map { $0.fecha.timeIntervalSince(primero.fecha) / 86400 }
        let ys = puntos.map(\.kg)
        let n = Double(puntos.count)
        let mx = xs.reduce(0, +) / n
        let my = ys.reduce(0, +) / n
        var num = 0.0, den = 0.0
        for i in 0..<puntos.count {
            num += (xs[i] - mx) * (ys[i] - my)
            den += (xs[i] - mx) * (xs[i] - mx)
        }
        guard den > 0 else { return nil }
        return num / den * 7
    }
}

// MARK: - Ajuste automático de calorías

struct AjusteSugerido: Equatable {
    /// Nuevo ajuste total (kcal por día) que se sumaría a la meta calculada.
    let nuevoAjuste: Double
    let tendencia: Double
    let objetivoSemanal: Double
    let explicacion: String
}

enum AjusteDinamico {
    /// Aproximación habitual: 1 kg de peso corporal ≈ 7700 kcal.
    static let kcalPorKg: Double = 7700
    /// Cambio máximo por revisión y ajuste máximo acumulado (kcal/día).
    static let pasoMaximo: Double = 200
    static let ajusteMaximo: Double = 600

    /// Ritmo semanal esperado según el objetivo (kg por semana).
    static func objetivoSemanal(_ p: Perfil) -> Double {
        switch p.objetivo {
        case .bajarGrasa: return -0.005 * p.pesoKg
        case .mantener: return 0
        case .ganarMusculo: return 0.0025 * p.pesoKg
        }
    }

    /// Compara cómo cambia tu peso con lo esperado y propone un ajuste.
    /// nil si no hay datos suficientes o si vas al ritmo esperado.
    static func sugerir(perfil: Perfil, pesos: [RegistroPeso], ajusteActual: Double, hoy: Date) -> AjusteSugerido? {
        guard let tendencia = Cuerpo.tendenciaSemanal(pesos, hasta: hoy) else { return nil }
        let esperado = objetivoSemanal(perfil)
        let diferencia = tendencia - esperado
        guard abs(diferencia) >= 0.15 else { return nil }
        let cambio = min(max(-diferencia * kcalPorKg / 7, -pasoMaximo), pasoMaximo)
        let nuevo = min(max(ajusteActual + cambio, -ajusteMaximo), ajusteMaximo)
        guard abs(nuevo - ajusteActual) >= 10 else { return nil }
        let sentido = cambio < 0 ? "bajar" : "subir"
        let explicacion = "Tu peso cambia \(Formato.numero(tendencia, decimales: 2)) kg por semana y lo esperado para «\(perfil.objetivo.nombre.lowercased())» es \(Formato.numero(esperado, decimales: 2)) kg. Propongo \(sentido) \(Formato.entero(abs(cambio))) kcal al día (1 kg ≈ 7700 kcal, máximo \(Formato.entero(pasoMaximo)) por revisión)."
        return AjusteSugerido(nuevoAjuste: (nuevo / 10).rounded() * 10, tendencia: tendencia, objetivoSemanal: esperado, explicacion: explicacion)
    }
}

// MARK: - Gráficos

struct PuntoSerie: Identifiable, Equatable {
    let fecha: Date
    let valor: Double
    var id: Date { fecha }
}

enum Series {
    /// Totales por día de los últimos `dias` días (incluye hoy), en orden.
    static func nutrientesPorDia(_ registros: [Registro], hasta: Date, dias: Int, calendario: Calendar = .current) -> [(fecha: Date, total: Nutrientes)] {
        let hoy = calendario.startOfDay(for: hasta)
        return (0..<dias).reversed().map { (i: Int) -> (fecha: Date, total: Nutrientes) in
            let fecha = calendario.date(byAdding: .day, value: -i, to: hoy) ?? hoy
            return (fecha, Diario.suma(Diario.registros(de: fecha, en: registros, calendario: calendario)))
        }
    }

    /// Promedio diario de los días con registros (los días vacíos no cuentan).
    static func promedio(_ dias: [(fecha: Date, total: Nutrientes)]) -> Nutrientes {
        let conDatos = dias.filter { $0.total.kcal > 0 }
        guard !conDatos.isEmpty else { return .cero }
        return conDatos.reduce(Nutrientes.cero) { $0 + $1.total } * (1 / Double(conDatos.count))
    }

    /// Días seguidos con al menos un registro, contando hacia atrás desde hoy
    /// (si hoy aún no hay registros, cuenta desde ayer).
    static func racha(_ registros: [Registro], hoy: Date, calendario: Calendar = .current) -> Int {
        var dia = calendario.startOfDay(for: hoy)
        if Diario.registros(de: dia, en: registros, calendario: calendario).isEmpty {
            dia = calendario.date(byAdding: .day, value: -1, to: dia) ?? dia
        }
        var cuenta = 0
        while !Diario.registros(de: dia, en: registros, calendario: calendario).isEmpty {
            cuenta += 1
            guard let anterior = calendario.date(byAdding: .day, value: -1, to: dia) else { break }
            dia = anterior
            if cuenta > 3650 { break }
        }
        return cuenta
    }
}

// MARK: - Ayuno

struct EstadoAyuno: Equatable {
    let transcurrido: TimeInterval
    let restante: TimeInterval
    let fraccion: Double
    let completado: Bool
}

enum Ayuno {
    static let protocolos: [(nombre: String, horas: Double)] = [
        ("12:12", 12), ("14:10", 14), ("16:8", 16), ("18:6", 18), ("20:4", 20)
    ]

    static func estado(_ s: SesionAyuno, ahora: Date) -> EstadoAyuno {
        let fin = s.finReal ?? ahora
        let transcurrido = max(0, fin.timeIntervalSince(s.inicio))
        let total = s.horas * 3600
        let restante = max(0, total - transcurrido)
        return EstadoAyuno(transcurrido: transcurrido, restante: restante,
                           fraccion: total > 0 ? min(transcurrido / total, 1) : 0,
                           completado: transcurrido >= total)
    }

    static func activa(_ ayunos: [SesionAyuno]) -> SesionAyuno? {
        ayunos.last { $0.finReal == nil }
    }

    /// Ayunos terminados que llegaron a su meta, seguidos, del más nuevo hacia atrás.
    static func racha(_ ayunos: [SesionAyuno]) -> Int {
        var cuenta = 0
        for s in ayunos.filter({ $0.finReal != nil }).sorted(by: { $0.inicio > $1.inicio }) {
            guard let fin = s.finReal, fin.timeIntervalSince(s.inicio) >= s.horas * 3600 else { break }
            cuenta += 1
        }
        return cuenta
    }

    /// "15 h 04 min".
    static func duracion(_ segundos: TimeInterval) -> String {
        let total = Int(max(0, segundos)) / 60
        return "\(total / 60) h " + String(format: "%02d", total % 60) + " min"
    }
}
