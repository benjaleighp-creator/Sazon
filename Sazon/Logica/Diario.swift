import Foundation

/// Resumen de un día: registros por comida, totales y progreso frente a la meta.
struct ResumenDia: Equatable {
    let dia: Date
    let porComida: [TipoComida: [Registro]]
    let totalesPorComida: [TipoComida: Nutrientes]
    let total: Nutrientes
    /// True si algún registro del día es una estimación de la IA.
    let incluyeEstimados: Bool

    func registros(_ comida: TipoComida) -> [Registro] { porComida[comida] ?? [] }
    func totales(_ comida: TipoComida) -> Nutrientes { totalesPorComida[comida] ?? .cero }
}

/// Progreso de un valor frente a su meta.
struct Progreso: Equatable {
    let consumido: Double
    let meta: Double

    /// 0 a 1 para dibujar (se corta en 1).
    var fraccion: Double {
        guard meta > 0, consumido.isFinite else { return 0 }
        return min(max(consumido / meta, 0), 1)
    }

    /// Lo que falta (negativo si te pasaste).
    var restante: Double { meta - consumido }
    var excedido: Bool { meta > 0 && consumido > meta }
}

enum Diario {

    /// Registros que caen en el mismo día calendario que `dia`.
    static func registros(de dia: Date, en todos: [Registro], calendario: Calendar = .current) -> [Registro] {
        todos.filter { calendario.isDate($0.fecha, inSameDayAs: dia) }
            .sorted { $0.fecha < $1.fecha }
    }

    static func resumen(de dia: Date, en todos: [Registro], calendario: Calendar = .current) -> ResumenDia {
        let delDia = registros(de: dia, en: todos, calendario: calendario)
        var porComida: [TipoComida: [Registro]] = [:]
        var totales: [TipoComida: Nutrientes] = [:]
        for comida in TipoComida.allCases {
            let lista = delDia.filter { $0.comida == comida }
            porComida[comida] = lista
            totales[comida] = suma(lista)
        }
        return ResumenDia(
            dia: calendario.startOfDay(for: dia),
            porComida: porComida,
            totalesPorComida: totales,
            total: suma(delDia),
            incluyeEstimados: delDia.contains { $0.origen.esEstimado }
        )
    }

    static func suma(_ registros: [Registro]) -> Nutrientes {
        registros.reduce(Nutrientes.cero) { $0 + $1.total }
    }

    static func progreso(_ total: Nutrientes, meta: Nutrientes) -> (kcal: Progreso, proteina: Progreso, carbohidratos: Progreso, grasas: Progreso) {
        (Progreso(consumido: total.kcal, meta: meta.kcal),
         Progreso(consumido: total.proteina, meta: meta.proteina),
         Progreso(consumido: total.carbohidratos, meta: meta.carbohidratos),
         Progreso(consumido: total.grasas, meta: meta.grasas))
    }

    /// Fecha que se guarda al registrar en un día que no es hoy: ese día a
    /// la hora actual (así el orden dentro del día se mantiene natural).
    static func fechaParaRegistrar(enDia dia: Date, ahora: Date = Date(), calendario: Calendar = .current) -> Date {
        if calendario.isDate(dia, inSameDayAs: ahora) { return ahora }
        let hora = calendario.dateComponents([.hour, .minute, .second], from: ahora)
        let inicio = calendario.startOfDay(for: dia)
        return calendario.date(byAdding: hora, to: inicio) ?? inicio
    }

    /// Mueve un día hacia adelante o atrás.
    static func moverDia(_ dia: Date, dias: Int, calendario: Calendar = .current) -> Date {
        let inicio = calendario.startOfDay(for: dia)
        return calendario.date(byAdding: .day, value: dias, to: inicio) ?? inicio
    }

    /// Lista de recientes: el más nuevo primero, sin repetir nombre y fuente,
    /// como máximo `limite`.
    static func actualizarRecientes(_ recientes: [Registro], con nuevo: Registro, limite: Int = 20) -> [Registro] {
        let clave = { (r: Registro) -> String in
            "\(r.origen.rawValue)|\(r.codigoINS ?? "")|\(r.codigoBarras ?? "")|\(Busqueda.normalizar(r.nombre))"
        }
        let k = clave(nuevo)
        var lista = recientes.filter { clave($0) != k }
        lista.insert(nuevo, at: 0)
        return Array(lista.prefix(limite))
    }
}

// MARK: - Semana

/// Un día de la tira semanal del diario.
struct DiaSemana: Identifiable, Equatable {
    let fecha: Date
    let kcal: Double
    /// 0 a 1 frente a la meta (0 si no hay meta).
    let fraccion: Double
    let tieneRegistros: Bool
    var id: Date { fecha }
}

extension Diario {

    /// Lunes de la semana de `dia` (semanas de lunes a domingo, como en Perú).
    static func inicioSemana(_ dia: Date, calendario: Calendar = .current) -> Date {
        let inicio = calendario.startOfDay(for: dia)
        let diaSemana = calendario.component(.weekday, from: inicio)   // 1 = domingo … 7 = sábado
        let desdeLunes = (diaSemana + 5) % 7
        return calendario.date(byAdding: .day, value: -desdeLunes, to: inicio) ?? inicio
    }

    /// Los 7 días (lunes a domingo) de la semana de `dia`, con sus calorías.
    static func semana(de dia: Date, en todos: [Registro], meta: Nutrientes?, calendario: Calendar = .current) -> [DiaSemana] {
        let lunes = inicioSemana(dia, calendario: calendario)
        return (0..<7).map { (i: Int) -> DiaSemana in
            let fecha = calendario.date(byAdding: .day, value: i, to: lunes) ?? lunes
            let delDia = registros(de: fecha, en: todos, calendario: calendario)
            let kcal = suma(delDia).kcal
            let fraccion = Progreso(consumido: kcal, meta: meta?.kcal ?? 0).fraccion
            return DiaSemana(fecha: fecha, kcal: kcal, fraccion: fraccion, tieneRegistros: !delDia.isEmpty)
        }
    }
}

extension Nutrientes {
    /// Parte de la energía que viene de proteína, carbohidratos y grasas
    /// (factores 4, 4 y 9). Suman 1, o todo 0 si no hay macros.
    var repartoEnergia: (proteina: Double, carbohidratos: Double, grasas: Double) {
        let p = proteina * 4, c = carbohidratos * 4, g = grasas * 9
        let total = p + c + g
        guard total > 0 else { return (0, 0, 0) }
        return (p / total, c / total, g / total)
    }
}
