import Foundation

/// Conversión de porciones. Internamente todo se guarda en gramos; la
/// interfaz muestra gramos u onzas según Ajustes, o una medida casera.
enum Porciones {

    /// 1 onza avoirdupois = 28,349523125 g (valor exacto por definición).
    static let gramosPorOnza: Double = 28.349523125

    static func aGramos(_ valor: Double, desde unidad: UnidadPorcion) -> Double {
        unidad == .gramos ? valor : valor * gramosPorOnza
    }

    static func desdeGramos(_ gramos: Double, a unidad: UnidadPorcion) -> Double {
        unidad == .gramos ? gramos : gramos / gramosPorOnza
    }

    /// Gramos de `cantidad` medidas caseras.
    static func gramos(cantidad: Double, de medida: MedidaCasera) -> Double {
        cantidad * medida.gramos
    }

    /// Texto de la porción: "150 g", "5,3 oz" o "2 unidad mediana (≈ 120 g)".
    static func texto(gramos: Double, unidad: UnidadPorcion, medida: MedidaCasera? = nil, cantidadMedida: Double? = nil) -> String {
        let base: String
        if unidad == .gramos {
            base = Formato.numero(gramos, decimales: gramos < 10 ? 1 : 0) + " g"
        } else {
            base = Formato.numero(desdeGramos(gramos, a: .onzas), decimales: 1) + " oz"
        }
        guard let medida, let cantidad = cantidadMedida, cantidad > 0 else { return base }
        let aprox = medida.estimada ? "≈ " : ""
        return "\(Formato.numero(cantidad)) \(medida.nombre) (\(aprox)\(base))"
    }

    /// Gramos válidos para guardar: mayores que 0 y como máximo 5 kg.
    static func esValido(_ gramos: Double) -> Bool {
        gramos.isFinite && gramos > 0 && gramos <= 5000
    }

    /// Opciones de unidad para un alimento: la unidad de Ajustes, la otra
    /// (g u oz) y sus medidas caseras, sin repetidos.
    static func medidasDisponibles(base: [MedidaCasera], adicional: MedidaCasera?) -> [MedidaCasera] {
        var resultado: [MedidaCasera] = []
        for m in base + [adicional].compactMap({ $0 }) where m.gramos > 0 {
            let nombre = Busqueda.normalizar(m.nombre)
            if !resultado.contains(where: { Busqueda.normalizar($0.nombre) == nombre }) {
                resultado.append(m)
            }
        }
        return resultado
    }
}
