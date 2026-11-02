import SwiftUI

extension Color {
    /// Crea un color a partir de un texto hexadecimal "RRGGBB" (con o sin "#").
    init(hex: String) {
        let limpio = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        var valor: UInt64 = 0
        Scanner(string: limpio).scanHexInt64(&valor)
        let r = Double((valor >> 16) & 0xFF) / 255.0
        let g = Double((valor >> 8) & 0xFF) / 255.0
        let b = Double(valor & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

/// Colores de una variante (clara u oscura) de un tema. Los cuatro colores
/// de datos (calorías y macros) solo se usan en anillos, barras y puntos;
/// los textos van siempre con `texto` o `textoSecundario`.
struct Paleta: Equatable {
    let fondo: Color
    let superficie: Color
    let superficieAlta: Color
    let borde: Color
    let texto: Color
    let textoSecundario: Color
    let acento: Color
    let textoSobreAcento: Color
    let acentoSuave: Color
    let exito: Color
    let aviso: Color
    let peligro: Color
    let calorias: Color
    let proteina: Color
    let carbohidratos: Color
    let grasas: Color

    init(fondo: String, superficie: String, superficieAlta: String, borde: String,
         texto: String, textoSecundario: String, acento: String, textoSobreAcento: String,
         acentoSuave: String, exito: String, aviso: String, peligro: String,
         calorias: String, proteina: String, carbohidratos: String, grasas: String) {
        self.fondo = Color(hex: fondo)
        self.superficie = Color(hex: superficie)
        self.superficieAlta = Color(hex: superficieAlta)
        self.borde = Color(hex: borde)
        self.texto = Color(hex: texto)
        self.textoSecundario = Color(hex: textoSecundario)
        self.acento = Color(hex: acento)
        self.textoSobreAcento = Color(hex: textoSobreAcento)
        self.acentoSuave = Color(hex: acentoSuave)
        self.exito = Color(hex: exito)
        self.aviso = Color(hex: aviso)
        self.peligro = Color(hex: peligro)
        self.calorias = Color(hex: calorias)
        self.proteina = Color(hex: proteina)
        self.carbohidratos = Color(hex: carbohidratos)
        self.grasas = Color(hex: grasas)
    }

    func color(_ macro: Macro) -> Color {
        switch macro {
        case .calorias: return calorias
        case .proteina: return proteina
        case .carbohidratos: return carbohidratos
        case .grasas: return grasas
        }
    }
}

/// Los cuatro datos que sigue el diario.
enum Macro: String, CaseIterable, Identifiable {
    case calorias, proteina, carbohidratos, grasas
    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .calorias: return "Calorías"
        case .proteina: return "Proteína"
        case .carbohidratos: return "Carbohidratos"
        case .grasas: return "Grasas"
        }
    }

    var unidad: String { self == .calorias ? "kcal" : "g" }

    func valor(_ n: Nutrientes) -> Double {
        switch self {
        case .calorias: return n.kcal
        case .proteina: return n.proteina
        case .carbohidratos: return n.carbohidratos
        case .grasas: return n.grasas
        }
    }
}

// MARK: - Perfil de estilo del tema

enum DisenoLetra: String {
    case redondeada, serif, estandar, mono

    var fontDesign: Font.Design {
        switch self {
        case .redondeada: return .rounded
        case .serif: return .serif
        case .estandar: return .default
        case .mono: return .monospaced
        }
    }
}

enum PesoTitulo: String {
    case medium, semibold, bold, heavy

    var weight: Font.Weight {
        switch self {
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        }
    }
}

enum SombraTema: String {
    case ninguna, suave
}

/// Personalidad del movimiento del tema.
enum TransicionTema: String {
    case elastica, fluida, lenta, nitida
}

struct EstiloTema: Equatable {
    let diseno: DisenoLetra
    let pesoTitulo: PesoTitulo
    let radioTarjeta: CGFloat
    let radioControl: CGFloat
    let sombra: SombraTema
    let transicion: TransicionTema
    let cifrasMono: Bool
}

/// Estilo del tema en uso. Lo actualiza el almacén al cargar y al cambiar
/// de tema; lo leen la escala tipográfica, los radios y las animaciones.
enum EstiloActivo {
    static var actual: EstiloTema = CatalogoTemas.todos[0].estilo
}

struct Tema: Identifiable, Equatable {
    let id: String
    let nombre: String
    let concepto: String
    let estilo: EstiloTema
    let claro: Paleta
    let oscuro: Paleta

    func paleta(_ esquema: ColorScheme) -> Paleta {
        esquema == .dark ? oscuro : claro
    }

    static func == (a: Tema, b: Tema) -> Bool { a.id == b.id }
}

// MARK: - Entorno

private struct ClavePaleta: EnvironmentKey {
    static let defaultValue: Paleta = CatalogoTemas.todos[0].claro
}

private struct ClaveTema: EnvironmentKey {
    static let defaultValue: Tema = CatalogoTemas.todos[0]
}

private struct ClaveAhorro: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// Paleta activa (tema + modo claro/oscuro).
    var paleta: Paleta {
        get { self[ClavePaleta.self] }
        set { self[ClavePaleta.self] = newValue }
    }

    var temaActivo: Tema {
        get { self[ClaveTema.self] }
        set { self[ClaveTema.self] = newValue }
    }

    /// True con el ahorro de batería de la app o el modo de bajo consumo:
    /// las animaciones decorativas se apagan.
    var ahorroActivo: Bool {
        get { self[ClaveAhorro.self] }
        set { self[ClaveAhorro.self] = newValue }
    }
}
