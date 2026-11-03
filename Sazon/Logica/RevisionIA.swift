import Foundation

/// Un alimento identificado por la IA mientras lo revisas antes de guardar.
/// Regla de los datos: si hay coincidencia en la tabla del INS y la usas,
/// los valores salen de la tabla; si no, se usa la estimación de la IA
/// marcada como "≈ estimado".
struct ItemRevision: Identifiable, Equatable {
    let id: UUID
    var nombre: String
    var gramos: Double
    var confianza: Double
    /// Medida casera sugerida por la IA y cuántas (solo para mostrar).
    var medida: MedidaCasera?
    var cantidadMedida: Double?
    /// Estimación de la IA por 100 g.
    var estimacion: Nutrientes
    /// Alimento de la tabla del INS que corresponde (si hay).
    var ins: AlimentoBase?
    var usarINS: Bool
    /// Rango probable de gramos que dio la IA.
    var gramosMin: Double?
    var gramosMax: Double?

    init(identificado: AlimentoIdentificado, coincidencia: AlimentoBase?) {
        gramosMin = identificado.gramosMin
        gramosMax = identificado.gramosMax
        id = identificado.id
        nombre = identificado.nombre
        gramos = identificado.gramos
        confianza = identificado.confianza
        medida = identificado.medida
        cantidadMedida = identificado.cantidadMedida
        estimacion = identificado.por100g
        ins = coincidencia
        usarINS = coincidencia != nil
    }

    /// Ingrediente que no se veía (aceite, mayonesa…), agregado desde la
    /// tabla del INS con su medida casera aproximada.
    init(extra: ExtraOculto, alimento: AlimentoBase, cantidad: Double = 1) {
        id = UUID()
        nombre = alimento.nombre
        gramos = extra.gramosPorMedida * cantidad
        confianza = 1
        medida = MedidaCasera(nombre: extra.medida, gramos: extra.gramosPorMedida, estimada: true)
        cantidadMedida = cantidad
        estimacion = alimento.por100g
        ins = alimento
        usarINS = true
        gramosMin = nil
        gramosMax = nil
    }

    /// Calorías mínima y máxima según el rango de la IA (nil si no hay rango).
    var rangoKcal: ClosedRange<Double>? {
        // Si cambiaste la porción fuera del rango de la IA, el rango ya no aplica.
        guard let a = gramosMin, let b = gramosMax, b > a, (a...b).contains(gramos) else { return nil }
        return (por100g.kcal * a / 100)...(por100g.kcal * b / 100)
    }

    /// Suma de rangos de varios alimentos (los que no tienen rango cuentan
    /// con su valor actual). nil si ninguno tiene rango.
    static func rangoTotal(_ items: [ItemRevision]) -> ClosedRange<Double>? {
        guard items.contains(where: { $0.rangoKcal != nil }) else { return nil }
        var minimo = 0.0, maximo = 0.0
        for i in items {
            if let r = i.rangoKcal { minimo += r.lowerBound; maximo += r.upperBound } else { minimo += i.total.kcal; maximo += i.total.kcal }
        }
        return minimo...maximo
    }

    /// Confianza por debajo de este valor se marca para revisar.
    static let confianzaBaja = 0.6

    var confianzaEsBaja: Bool { confianza < ItemRevision.confianzaBaja }

    var origen: OrigenDato { usarINS && ins != nil ? .ins : .estimadoIA }

    var por100g: Nutrientes {
        if usarINS, let ins { return ins.por100g }
        return estimacion
    }

    var total: Nutrientes { por100g * (gramos / 100) }

    /// La medida casera solo se guarda si los gramos siguen coincidiendo con
    /// ella (si corregiste los gramos a mano, ya no aplica).
    var medidaVigente: (MedidaCasera, Double)? {
        guard let medida, let cantidad = cantidadMedida, cantidad > 0 else { return nil }
        let esperado = medida.gramos * cantidad
        return abs(esperado - gramos) < 0.5 ? (medida, cantidad) : nil
    }

    var esValido: Bool {
        !nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Porciones.esValido(gramos)
    }

    func registro(fecha: Date, comida: TipoComida) -> Registro {
        let m = medidaVigente
        let nombreFinal = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        return Registro(
            fecha: fecha,
            comida: comida,
            nombre: nombreFinal,
            gramos: gramos,
            por100g: por100g,
            origen: origen,
            codigoINS: origen == .ins ? ins?.codigo : nil,
            medida: m?.0,
            cantidadMedida: m?.1,
            confianzaIA: confianza
        )
    }

    static func == (a: ItemRevision, b: ItemRevision) -> Bool {
        a.id == b.id && a.nombre == b.nombre && a.gramos == b.gramos && a.usarINS == b.usarINS &&
        a.ins == b.ins && a.estimacion == b.estimacion && a.medida == b.medida && a.cantidadMedida == b.cantidadMedida &&
        a.gramosMin == b.gramosMin && a.gramosMax == b.gramosMax
    }
}

/// Ingredientes que suelen no verse en una foto. Los valores salen de la
/// tabla del INS (por el código); los gramos de cada medida casera son
/// aproximados y se marcan con «≈».
struct ExtraOculto: Identifiable, Equatable {
    let id: String
    let nombre: String
    let simbolo: String
    let codigoINS: String
    let medida: String
    let gramosPorMedida: Double
    /// Palabras (sin tildes) que lo relacionan con lo que sugiere la IA.
    let claves: [String]

    static let todos: [ExtraOculto] = [
        ExtraOculto(id: "aceite", nombre: "Aceite", simbolo: "drop.fill", codigoINS: "D4", medida: "cucharada", gramosPorMedida: 14, claves: ["aceite", "fritur", "frito"]),
        ExtraOculto(id: "mayonesa", nombre: "Mayonesa", simbolo: "takeoutbag.and.cup.and.straw", codigoINS: "L42", medida: "cucharada", gramosPorMedida: 15, claves: ["mayones"]),
        ExtraOculto(id: "mantequilla", nombre: "Mantequilla", simbolo: "square.fill", codigoINS: "D19", medida: "cucharadita", gramosPorMedida: 5, claves: ["mantequ"]),
        ExtraOculto(id: "margarina", nombre: "Margarina", simbolo: "square", codigoINS: "D21", medida: "cucharadita", gramosPorMedida: 5, claves: ["margarin"]),
        ExtraOculto(id: "azucar", nombre: "Azúcar", simbolo: "cube.fill", codigoINS: "K1", medida: "cucharadita", gramosPorMedida: 5, claves: ["azucar", "endulz"]),
        ExtraOculto(id: "queso", nombre: "Queso fresco", simbolo: "triangle.fill", codigoINS: "G14", medida: "tajada", gramosPorMedida: 30, claves: ["queso"]),
        ExtraOculto(id: "crema", nombre: "Crema de leche", simbolo: "cup.and.saucer.fill", codigoINS: "G1", medida: "cucharada", gramosPorMedida: 15, claves: ["crema", "nata"]),
        ExtraOculto(id: "soya", nombre: "Salsa de soya", simbolo: "drop", codigoINS: "L48", medida: "cucharada", gramosPorMedida: 15, claves: ["soya", "sillao"])
    ]

    /// Extras que corresponden a lo que sugirió la IA, en su orden, y los
    /// textos que no corresponden a ninguno (para mostrarlos como pregunta).
    static func relacionar(_ sugeridos: [String]) -> (extras: [ExtraOculto], otros: [String]) {
        var extras: [ExtraOculto] = []
        var otros: [String] = []
        for s in sugeridos {
            let n = Busqueda.normalizar(s)
            if let e = todos.first(where: { e in e.claves.contains { n.contains($0) } }) {
                if !extras.contains(e) { extras.append(e) }
            } else if !otros.contains(s) {
                otros.append(s)
            }
        }
        return (extras, otros)
    }
}
