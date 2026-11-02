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
        let nombre = cantidad == 1 ? medida.nombre : plural(medida.nombre)
        return "\(Formato.numero(cantidad)) \(nombre) (\(aprox)\(base))"
    }

    /// Plural en español de una medida casera: «rebanada» → «rebanadas»,
    /// «unidad mediana» → «unidades medianas», «porción del envase» →
    /// «porciones del envase». Cambia las palabras hasta llegar a «de», «del»,
    /// «con», «por» o a un paréntesis; el resto queda igual.
    static func plural(_ texto: String) -> String {
        var palabras = texto.components(separatedBy: " ")
        let paradas: Set<String> = ["de", "del", "con", "por", "para", "en"]
        for i in palabras.indices {
            let p = palabras[i]
            if p.isEmpty { continue }
            if paradas.contains(p.lowercased()) || p.hasPrefix("(") || p.first?.isNumber == true { break }
            palabras[i] = pluralPalabra(p)
        }
        return palabras.joined(separator: " ")
    }

    private static func pluralPalabra(_ p: String) -> String {
        guard let ultima = p.last?.lowercased().first else { return p }
        if "aeiouáéó".contains(ultima) { return p + "s" }
        if ultima == "z" { return String(p.dropLast()) + "ces" }
        if ultima == "s" || ultima == "x" {
            // «mes» → «meses», pero «tórax» o «análisis» no cambian.
            return p.count <= 3 ? p + "es" : p
        }
        // «porción» → «porciones»: la tilde de la última sílaba se pierde.
        let sinTilde: [Character: Character] = ["á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u"]
        var letras = Array(p)
        if letras.count >= 2, let reemplazo = sinTilde[letras[letras.count - 2]] {
            letras[letras.count - 2] = reemplazo
        }
        return String(letras) + "es"
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
