import SwiftUI

// Sistema de diseño de Sazón: valores base que usan todas las pantallas.
// Regla: en las pantallas no se escriben números sueltos (tamaños de letra,
// rellenos o radios); se usan estos nombres.

/// Espaciado en múltiplos de 4 pt.
enum Espacio {
    /// 2 pt — solo entre un título y su subtítulo pegado.
    static let xxxs: CGFloat = 2
    /// 4 pt — dentro de un dato.
    static let xxs: CGFloat = 4
    /// 8 pt — entre chips.
    static let xs: CGFloat = 8
    /// 12 pt — entre elementos de una tarjeta.
    static let s: CGFloat = 12
    /// 16 pt — relleno de tarjetas.
    static let m: CGFloat = 16
    /// 24 pt — entre bloques grandes.
    static let l: CGFloat = 24
    /// 32 pt — final de pantalla.
    static let xl: CGFloat = 32
    /// 48 pt — respiro superior.
    static let xxl: CGFloat = 48
    /// Margen lateral de todas las pantallas.
    static let margen: CGFloat = 20
}

/// Radios de esquina (siempre `.continuous`). Dependen del tema.
enum Radio {
    static var chico: CGFloat { (EstiloActivo.actual.radioControl * 0.65).rounded() }
    static var medio: CGFloat { EstiloActivo.actual.radioControl }
    static var tarjeta: CGFloat { EstiloActivo.actual.radioTarjeta }
    static var grande: CGFloat { EstiloActivo.actual.radioTarjeta + 4 }
}

/// Escala tipográfica con estilos del sistema (respeta el tamaño de letra).
enum Tipo {
    private static var pesoTitulo: Font.Weight { EstiloActivo.actual.pesoTitulo.weight }
    private static var disenoCifras: Font.Design? { EstiloActivo.actual.cifrasMono ? .monospaced : nil }

    static var titulo1: Font { Font.system(.largeTitle, weight: pesoTitulo) }
    static var titulo2: Font { Font.system(.title, weight: pesoTitulo) }
    static var titulo3: Font { Font.system(.title2, weight: .semibold) }
    static var subtitulo: Font { Font.system(.title3, weight: .semibold) }
    static var cuerpo: Font { Font.system(.body) }
    static var cuerpoFuerte: Font { Font.system(.body, weight: .semibold) }
    static var nota: Font { Font.system(.subheadline) }
    static var pie: Font { Font.system(.footnote, weight: .medium) }
    static var micro: Font { Font.system(.caption2, weight: .semibold) }
    /// Números destacados (dígitos de ancho fijo).
    static var cifra: Font { Font.system(.title, design: disenoCifras, weight: pesoTitulo).monospacedDigit() }
    /// Cifra grande del anillo de calorías.
    static var cifraGrande: Font { Font.system(.largeTitle, design: disenoCifras, weight: pesoTitulo).monospacedDigit() }

    static let iconoChico = Font.system(.footnote, weight: .semibold)
    static let iconoDato = Font.system(.subheadline, weight: .medium)
    static let iconoFila = Font.system(.title3, weight: .semibold)
    static let iconoMedio = Font.system(.title2)
    static let iconoGrande = Font.system(.title)
}

/// Sombras suaves; en modo oscuro las tarjetas se separan solo con su borde.
enum Sombra {
    static func suave(_ esquema: ColorScheme) -> (color: Color, radio: CGFloat, y: CGFloat) {
        esquema == .dark ? (Color.clear, 0, 0) : (Color.black.opacity(0.06), 14, 4)
    }

    static func elevada(_ esquema: ColorScheme) -> (color: Color, radio: CGFloat, y: CGFloat) {
        esquema == .dark ? (Color.black.opacity(0.45), 20, 10) : (Color.black.opacity(0.12), 20, 8)
    }
}

/// Tamaños mínimos de toque y elementos gráficos (se escalan con @ScaledMetric
/// en cada vista cuando hace falta).
enum Medida {
    /// Alto mínimo de botones (Apple recomienda al menos 44 pt).
    static let toque: CGFloat = 48
    /// Diámetro base del anillo de calorías.
    static let anillo: CGFloat = 168
    /// Grosor del anillo de calorías.
    static let grosorAnillo: CGFloat = 14
    /// Alto de las barras de macros.
    static let barra: CGFloat = 8
    /// Lado máximo (px) de las fotos que se envían a la IA.
    static let ladoFotoIA: CGFloat = 1024
}

/// Opacidades de capas decorativas y pistas (siempre con estos nombres).
enum Opacidad {
    /// Estampado de ingredientes sobre el encabezado.
    static let estampado: Double = 0.06
    /// Brillo radial de la esquina del encabezado. Si cambias estampado o
    /// brillo, actualiza `capa` en herramientas/verificar_contraste.py.
    static let brillo: Double = 0.08
    /// Resplandor cálido arriba de cada pantalla.
    static let resplandor: Double = 0.55
    /// Pista de anillos y barras sobre el degradado.
    static let pistaHero: Double = 0.22
    /// Fondo de chips y cápsulas sobre el degradado.
    static let capsulaHero: Double = 0.16
    /// Relleno suave de los azulejos de color.
    static let azulejoFuerte: Double = 0.22
    static let azulejoSuave: Double = 0.10
}

/// Tamaños de las piezas del rediseño (se escalan con @ScaledMetric donde aplica).
extension Medida {
    /// Anillo pequeño de cada comida.
    static let anilloComida: CGFloat = 44
    /// Alto del resplandor del fondo.
    static let resplandor: CGFloat = 340
    /// Tamaño de cada ícono del estampado.
    static let iconoEstampado: CGFloat = 22
    /// Separación entre íconos del estampado.
    static let pasoEstampado: CGFloat = 46
}
