import Foundation

/// Recuerda las porciones que corriges. Si siempre cambias «arroz» de 150 g
/// a 200 g, la próxima vez la revisión propone 200 g (y lo dice).
enum PorcionesAprendidas {
    /// Máximo de alimentos recordados (se quitan los primeros si se pasa).
    static let maximo = 200

    static func clave(_ nombre: String) -> String { Busqueda.normalizar(nombre) }

    /// Porción que usaste la última vez para este alimento (si la corregiste).
    static func sugerida(_ aprendidas: [String: Double], nombre: String) -> Double? {
        guard let g = aprendidas[clave(nombre)], Porciones.esValido(g) else { return nil }
        return g
    }

    /// Aprende una porción solo si la cambiaste de verdad (más de 5 g y más
    /// del 5 % de lo que propuso la IA). Si vuelves a lo que dijo la IA, se olvida.
    static func aprender(_ aprendidas: [String: Double], nombre: String, gramosIA: Double, gramosFinal: Double) -> [String: Double] {
        let k = clave(nombre)
        guard !k.isEmpty, Porciones.esValido(gramosFinal) else { return aprendidas }
        var nuevas = aprendidas
        let diferencia = abs(gramosFinal - gramosIA)
        if diferencia > 5, diferencia > gramosIA * 0.05 {
            nuevas[k] = gramosFinal.rounded()
        } else if nuevas[k] != nil, abs(gramosFinal - (nuevas[k] ?? 0)) > 5 {
            nuevas[k] = nil
        }
        if nuevas.count > maximo {
            for k in nuevas.keys.sorted().prefix(nuevas.count - maximo) { nuevas[k] = nil }
        }
        return nuevas
    }
}
