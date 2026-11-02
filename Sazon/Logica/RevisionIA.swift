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

    init(identificado: AlimentoIdentificado, coincidencia: AlimentoBase?) {
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
        a.ins == b.ins && a.estimacion == b.estimacion && a.medida == b.medida && a.cantidadMedida == b.cantidadMedida
    }
}
