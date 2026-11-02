import Foundation

/// Cálculo de la meta diaria de calorías y macronutrientes.
///
/// Fórmula (se muestra igual en Ajustes):
/// 1. Metabolismo basal con Mifflin-St Jeor:
///    hombre: 10 × peso(kg) + 6,25 × talla(cm) − 5 × edad + 5
///    mujer:  10 × peso(kg) + 6,25 × talla(cm) − 5 × edad − 161
/// 2. Gasto diario = basal × factor de actividad (1,2 a 1,9).
/// 3. Meta = gasto × (1 + ajuste del objetivo): −20 %, 0 % o +10 %.
/// 4. Proteína = g/kg del objetivo × peso; grasas = 25 % de las calorías;
///    carbohidratos = lo que queda. Factores de energía: 4, 4 y 9 kcal/g.
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

    /// Meta calculada (redondeada: kcal a la decena, macros al gramo).
    static func meta(_ p: Perfil) -> Nutrientes {
        let gasto = gastoDiario(p)
        let kcalSinPiso = gasto * (1 + p.objetivo.ajusteCalorias)
        let kcal = (max(kcalSinPiso, caloriasMinimas) / 10).rounded() * 10
        let proteina = (p.objetivo.proteinaPorKg * p.pesoKg).rounded()
        let grasas = (kcal * p.objetivo.porcentajeGrasas / 9).rounded()
        let restante = kcal - proteina * 4 - grasas * 9
        let carbohidratos = max(0, (restante / 4).rounded())
        return Nutrientes(kcal: kcal, proteina: proteina, carbohidratos: carbohidratos, grasas: grasas)
    }

    /// Meta que usa la app: la manual si existe; si no, la calculada; si
    /// tampoco hay perfil, nil.
    static func metaVigente(_ datos: DatosApp) -> Nutrientes? {
        if let manual = datos.metaManual { return manual }
        if let perfil = datos.perfil { return meta(perfil) }
        return nil
    }

    /// Pasos del cálculo con los números de tu perfil, para mostrarlos.
    static func explicacion(_ p: Perfil) -> [String] {
        let basal = metabolismoBasal(p)
        let gasto = gastoDiario(p)
        let m = meta(p)
        let signo = p.sexo == .masculino ? "+ 5" : "− 161"
        let ajuste = Int((p.objetivo.ajusteCalorias * 100).rounded())
        let textoAjuste = ajuste == 0 ? "sin ajuste" : (ajuste > 0 ? "+\(ajuste) %" : "\(ajuste) %")
        var pasos: [String] = []
        pasos.append("Basal (Mifflin-St Jeor) = 10 × \(Formato.numero(p.pesoKg)) kg + 6,25 × \(Formato.numero(p.tallaCm)) cm − 5 × \(p.edad) años \(signo) = \(Formato.entero(basal)) kcal")
        pasos.append("Gasto diario = \(Formato.entero(basal)) × \(Formato.numero(p.actividad.factor, decimales: 3)) (\(p.actividad.nombre.lowercased())) = \(Formato.entero(gasto)) kcal")
        pasos.append("Meta = gasto con \(textoAjuste) (\(p.objetivo.nombre.lowercased())) ≈ \(Formato.entero(m.kcal)) kcal")
        pasos.append("Proteína = \(Formato.numero(p.objetivo.proteinaPorKg)) g × \(Formato.numero(p.pesoKg)) kg = \(Formato.entero(m.proteina)) g")
        pasos.append("Grasas = 25 % de las calorías ÷ 9 = \(Formato.entero(m.grasas)) g")
        pasos.append("Carbohidratos = (calorías − proteína × 4 − grasas × 9) ÷ 4 = \(Formato.entero(m.carbohidratos)) g")
        if gasto * (1 + p.objetivo.ajusteCalorias) < caloriasMinimas {
            pasos.append("Se aplicó un mínimo de \(Formato.entero(caloriasMinimas)) kcal.")
        }
        return pasos
    }
}
