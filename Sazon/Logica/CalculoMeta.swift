import Foundation

/// Cálculo de la meta diaria de calorías y macronutrientes.
///
/// Fórmula (se muestra igual en Ajustes):
/// 1. Metabolismo basal con Mifflin-St Jeor:
///    hombre: 10 × peso(kg) + 6,25 × talla(cm) − 5 × edad + 5
///    mujer:  10 × peso(kg) + 6,25 × talla(cm) − 5 × edad − 161
/// 2. Gasto diario = basal × factor de actividad (1,2 a 1,9).
/// 3. Meta = gasto × (1 + ajuste del objetivo): −20 %, 0 % o +10 %,
///    más el ajuste automático por peso y la actividad de Apple Salud
///    (si los activaste).
/// 4. Macros según el tipo de dieta (factores de energía 4, 4 y 9 kcal/g).
///
/// Son estimaciones generales, no consejo médico.
enum CalculoMeta {

    /// Pisos de seguridad para que una entrada extraña no dé metas absurdas.
    static let caloriasMinimas: Double = 1200

    static func metabolismoBasal(_ p: Perfil) -> Double {
        let base = 10 * p.pesoKg + 6.25 * p.tallaCm - 5 * Double(p.edad)
        return base + (p.sexo == .masculino ? 5 : -161)
    }

    static func gastoDiario(_ p: Perfil) -> Double {
        metabolismoBasal(p) * p.actividad.factor
    }

    /// Gramos de proteína por kg según objetivo y dieta.
    static func proteinaPorKg(_ p: Perfil) -> Double {
        p.dieta == .altaProteina ? 2.2 : p.objetivo.proteinaPorKg
    }

    /// Meta calculada (kcal a la decena, macros al gramo).
    /// - extraKcal: ajuste automático por peso + calorías activas de Apple Salud.
    static func meta(_ p: Perfil, extraKcal: Double = 0) -> Nutrientes {
        let gasto = gastoDiario(p)
        let kcalSinPiso = gasto * (1 + p.objetivo.ajusteCalorias) + extraKcal
        let kcal = (max(kcalSinPiso, caloriasMinimas) / 10).rounded() * 10
        return macros(kcal: kcal, perfil: p)
    }

    /// Reparte unas calorías en macros según el tipo de dieta del perfil.
    static func macros(kcal: Double, perfil p: Perfil) -> Nutrientes {
        let proteina = (proteinaPorKg(p) * p.pesoKg).rounded()
        let grasas: Double
        let carbohidratos: Double
        switch p.dieta {
        case .equilibrada, .altaProteina, .bajaGrasa:
            let parteGrasa = p.dieta == .bajaGrasa ? 0.15 : p.objetivo.porcentajeGrasas
            grasas = (kcal * parteGrasa / 9).rounded()
            carbohidratos = max(0, ((kcal - proteina * 4 - grasas * 9) / 4).rounded())
        case .bajaCarbohidratos, .keto:
            let parteCarbos = p.dieta == .keto ? 0.05 : 0.20
            carbohidratos = (kcal * parteCarbos / 4).rounded()
            grasas = max(0, ((kcal - proteina * 4 - carbohidratos * 4) / 9).rounded())
        }
        return Nutrientes(kcal: kcal, proteina: proteina, carbohidratos: carbohidratos, grasas: grasas)
    }

    /// Calorías extra que se suman a la meta calculada.
    static func extraKcal(_ datos: DatosApp, actividadSalud: Double = 0) -> Double {
        (datos.ajusteAutomatico ? datos.ajusteKcal : 0) + (datos.sumarActividad ? max(0, actividadSalud) : 0)
    }

    /// Meta que usa la app: la manual si existe; si no, la calculada; si
    /// tampoco hay perfil, nil.
    static func metaVigente(_ datos: DatosApp, actividadSalud: Double = 0) -> Nutrientes? {
        if let manual = datos.metaManual { return manual }
        if let perfil = datos.perfil { return meta(perfil, extraKcal: extraKcal(datos, actividadSalud: actividadSalud)) }
        return nil
    }

    /// Pasos del cálculo con los números de tu perfil, para mostrarlos.
    static func explicacion(_ p: Perfil, extraKcal: Double = 0) -> [String] {
        let basal = metabolismoBasal(p)
        let gasto = gastoDiario(p)
        let m = meta(p, extraKcal: extraKcal)
        let signo = p.sexo == .masculino ? "+ 5" : "− 161"
        let ajuste = Int((p.objetivo.ajusteCalorias * 100).rounded())
        let textoAjuste = ajuste == 0 ? "sin ajuste" : (ajuste > 0 ? "+\(ajuste) %" : "\(ajuste) %")
        var pasos: [String] = []
        pasos.append("Basal (Mifflin-St Jeor) = 10 × \(Formato.numero(p.pesoKg)) kg + 6,25 × \(Formato.numero(p.tallaCm)) cm − 5 × \(p.edad) años \(signo) = \(Formato.entero(basal)) kcal")
        pasos.append("Gasto diario = \(Formato.entero(basal)) × \(Formato.numero(p.actividad.factor, decimales: 3)) (\(p.actividad.nombre.lowercased())) = \(Formato.entero(gasto)) kcal")
        if extraKcal != 0 {
            let signoExtra = extraKcal > 0 ? "+" : "−"
            pasos.append("Meta = gasto con \(textoAjuste) (\(p.objetivo.nombre.lowercased())) \(signoExtra) \(Formato.entero(abs(extraKcal))) kcal de ajustes ≈ \(Formato.entero(m.kcal)) kcal")
        } else {
            pasos.append("Meta = gasto con \(textoAjuste) (\(p.objetivo.nombre.lowercased())) ≈ \(Formato.entero(m.kcal)) kcal")
        }
        pasos.append("Proteína = \(Formato.numero(proteinaPorKg(p))) g × \(Formato.numero(p.pesoKg)) kg = \(Formato.entero(m.proteina)) g")
        switch p.dieta {
        case .equilibrada, .altaProteina, .bajaGrasa:
            let parte = p.dieta == .bajaGrasa ? 15 : 25
            pasos.append("Grasas = \(parte) % de las calorías ÷ 9 = \(Formato.entero(m.grasas)) g")
            pasos.append("Carbohidratos = (calorías − proteína × 4 − grasas × 9) ÷ 4 = \(Formato.entero(m.carbohidratos)) g")
        case .bajaCarbohidratos, .keto:
            let parte = p.dieta == .keto ? 5 : 20
            pasos.append("Carbohidratos = \(parte) % de las calorías ÷ 4 = \(Formato.entero(m.carbohidratos)) g")
            pasos.append("Grasas = (calorías − proteína × 4 − carbohidratos × 4) ÷ 9 = \(Formato.entero(m.grasas)) g")
        }
        if gasto * (1 + p.objetivo.ajusteCalorias) + extraKcal < caloriasMinimas {
            pasos.append("Se aplicó un mínimo de \(Formato.entero(caloriasMinimas)) kcal.")
        }
        return pasos
    }
}
