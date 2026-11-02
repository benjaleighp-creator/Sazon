import Foundation

// Modelos de datos de Sazón. Solo Foundation: este archivo también lo
// compilan las pruebas automáticas, sin interfaz.
//
// Regla de compatibilidad: cada `init(from:)` usa `decodeIfPresent` con un
// valor por defecto, así una versión nueva de la app lee los datos de la
// anterior sin perder nada.

// MARK: - Nutrientes

/// Energía y macronutrientes. Según el contexto son "por 100 g" o el total
/// de una porción; el nombre de la variable lo deja claro.
struct Nutrientes: Codable, Equatable, Hashable {
    var kcal: Double
    var proteina: Double
    var carbohidratos: Double
    var grasas: Double

    static let cero = Nutrientes(kcal: 0, proteina: 0, carbohidratos: 0, grasas: 0)

    init(kcal: Double, proteina: Double, carbohidratos: Double, grasas: Double) {
        self.kcal = kcal
        self.proteina = proteina
        self.carbohidratos = carbohidratos
        self.grasas = grasas
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kcal = try c.decodeIfPresent(Double.self, forKey: .kcal) ?? 0
        proteina = try c.decodeIfPresent(Double.self, forKey: .proteina) ?? 0
        carbohidratos = try c.decodeIfPresent(Double.self, forKey: .carbohidratos) ?? 0
        grasas = try c.decodeIfPresent(Double.self, forKey: .grasas) ?? 0
    }

    static func + (a: Nutrientes, b: Nutrientes) -> Nutrientes {
        Nutrientes(kcal: a.kcal + b.kcal, proteina: a.proteina + b.proteina,
                   carbohidratos: a.carbohidratos + b.carbohidratos, grasas: a.grasas + b.grasas)
    }

    static func * (a: Nutrientes, factor: Double) -> Nutrientes {
        Nutrientes(kcal: a.kcal * factor, proteina: a.proteina * factor,
                   carbohidratos: a.carbohidratos * factor, grasas: a.grasas * factor)
    }

    /// Energía que dan los macros con los factores generales de Atwater
    /// (4 kcal/g proteína y carbohidratos, 9 kcal/g grasa).
    var kcalPorMacros: Double { proteina * 4 + carbohidratos * 4 + grasas * 9 }
}

// MARK: - Comidas del día

enum TipoComida: String, Codable, CaseIterable, Identifiable {
    case desayuno, almuerzo, cena, snacks

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .desayuno: return "Desayuno"
        case .almuerzo: return "Almuerzo"
        case .cena: return "Cena"
        case .snacks: return "Snacks"
        }
    }

    var simbolo: String {
        switch self {
        case .desayuno: return "cup.and.saucer"
        case .almuerzo: return "fork.knife"
        case .cena: return "moon.stars"
        case .snacks: return "carrot"
        }
    }

    /// Comida sugerida según la hora (minutos desde medianoche).
    static func sugerida(minutoDelDia: Int) -> TipoComida {
        switch minutoDelDia {
        case 300..<660: return .desayuno     // 05:00–10:59
        case 660..<960: return .almuerzo     // 11:00–15:59
        case 1080..<1440: return .cena       // 18:00–23:59
        default: return .snacks
        }
    }
}

/// De dónde salen los valores nutricionales de un registro.
enum OrigenDato: String, Codable, CaseIterable {
    /// Tablas Peruanas de Composición de Alimentos (INS).
    case ins
    /// Open Food Facts (código de barras).
    case openFoodFacts
    /// Estimación de la IA (sin coincidencia en la tabla).
    case estimadoIA
    /// Escrito a mano por ti.
    case manual

    var etiqueta: String {
        switch self {
        case .ins: return "INS"
        case .openFoodFacts: return "Open Food Facts"
        case .estimadoIA: return "≈ estimado por IA"
        case .manual: return "Manual"
        }
    }

    /// Si es true, la interfaz marca las cifras con "≈".
    var esEstimado: Bool { self == .estimadoIA }
}

// MARK: - Medidas caseras

/// Una medida casera ("1 taza", "1 unidad mediana") con su equivalencia en gramos.
struct MedidaCasera: Codable, Equatable, Hashable, Identifiable {
    var nombre: String
    var gramos: Double
    /// True si la equivalencia la estimó la IA (se muestra con "≈").
    var estimada: Bool

    var id: String { "\(nombre)-\(gramos)" }

    init(nombre: String, gramos: Double, estimada: Bool) {
        self.nombre = nombre
        self.gramos = gramos
        self.estimada = estimada
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? "porción"
        gramos = try c.decodeIfPresent(Double.self, forKey: .gramos) ?? 100
        estimada = try c.decodeIfPresent(Bool.self, forKey: .estimada) ?? false
    }
}

// MARK: - Registro

/// Un alimento anotado en el diario.
struct Registro: Codable, Identifiable, Equatable {
    var id: UUID
    /// Momento del registro (define el día y la comida sugerida).
    var fecha: Date
    var comida: TipoComida
    var nombre: String
    /// Cantidad comida, siempre en gramos (o mililitros tratados como gramos).
    var gramos: Double
    /// Valores por 100 g de la fuente indicada en `origen`.
    var por100g: Nutrientes
    var origen: OrigenDato
    /// Código del alimento en la tabla del INS, si salió de ahí.
    var codigoINS: String?
    /// Código de barras, si salió de Open Food Facts.
    var codigoBarras: String?
    /// Medida casera elegida y cuántas de ellas (solo para mostrar).
    var medida: MedidaCasera?
    var cantidadMedida: Double?
    /// Confianza de la IA (0 a 1) al identificar el alimento, si aplica.
    var confianzaIA: Double?
    /// True si corregiste a mano algún valor después de guardarlo.
    var editado: Bool

    init(id: UUID = UUID(), fecha: Date, comida: TipoComida, nombre: String, gramos: Double,
         por100g: Nutrientes, origen: OrigenDato, codigoINS: String? = nil, codigoBarras: String? = nil,
         medida: MedidaCasera? = nil, cantidadMedida: Double? = nil, confianzaIA: Double? = nil,
         editado: Bool = false) {
        self.id = id
        self.fecha = fecha
        self.comida = comida
        self.nombre = nombre
        self.gramos = gramos
        self.por100g = por100g
        self.origen = origen
        self.codigoINS = codigoINS
        self.codigoBarras = codigoBarras
        self.medida = medida
        self.cantidadMedida = cantidadMedida
        self.confianzaIA = confianzaIA
        self.editado = editado
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        fecha = try c.decodeIfPresent(Date.self, forKey: .fecha) ?? Date()
        comida = try c.decodeIfPresent(TipoComida.self, forKey: .comida) ?? .snacks
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? "Alimento"
        gramos = try c.decodeIfPresent(Double.self, forKey: .gramos) ?? 100
        por100g = try c.decodeIfPresent(Nutrientes.self, forKey: .por100g) ?? .cero
        origen = try c.decodeIfPresent(OrigenDato.self, forKey: .origen) ?? .manual
        codigoINS = try c.decodeIfPresent(String.self, forKey: .codigoINS)
        codigoBarras = try c.decodeIfPresent(String.self, forKey: .codigoBarras)
        medida = try c.decodeIfPresent(MedidaCasera.self, forKey: .medida)
        cantidadMedida = try c.decodeIfPresent(Double.self, forKey: .cantidadMedida)
        confianzaIA = try c.decodeIfPresent(Double.self, forKey: .confianzaIA)
        editado = try c.decodeIfPresent(Bool.self, forKey: .editado) ?? false
    }

    /// Nutrientes de la porción comida.
    var total: Nutrientes { por100g * (gramos / 100) }
}

// MARK: - Perfil y meta

enum Sexo: String, Codable, CaseIterable, Identifiable {
    case masculino, femenino
    var id: String { rawValue }
    var nombre: String { self == .masculino ? "Masculino" : "Femenino" }
}

/// Nivel de actividad física con su factor multiplicador.
enum NivelActividad: String, Codable, CaseIterable, Identifiable {
    case sedentario, ligero, moderado, intenso, muyIntenso
    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .sedentario: return "Sedentario"
        case .ligero: return "Ligero"
        case .moderado: return "Moderado"
        case .intenso: return "Intenso"
        case .muyIntenso: return "Muy intenso"
        }
    }

    var descripcion: String {
        switch self {
        case .sedentario: return "Poco o nada de ejercicio"
        case .ligero: return "Ejercicio 1 a 3 días por semana"
        case .moderado: return "Ejercicio 3 a 5 días por semana"
        case .intenso: return "Ejercicio 6 a 7 días por semana"
        case .muyIntenso: return "Entrenamiento diario fuerte o trabajo físico"
        }
    }

    /// Factores de actividad de uso común con Mifflin-St Jeor.
    var factor: Double {
        switch self {
        case .sedentario: return 1.2
        case .ligero: return 1.375
        case .moderado: return 1.55
        case .intenso: return 1.725
        case .muyIntenso: return 1.9
        }
    }
}

enum Objetivo: String, Codable, CaseIterable, Identifiable {
    case bajarGrasa, mantener, ganarMusculo
    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .bajarGrasa: return "Bajar grasa"
        case .mantener: return "Mantener"
        case .ganarMusculo: return "Ganar músculo"
        }
    }

    /// Ajuste sobre el gasto diario (−20 %, 0 %, +10 %).
    var ajusteCalorias: Double {
        switch self {
        case .bajarGrasa: return -0.20
        case .mantener: return 0
        case .ganarMusculo: return 0.10
        }
    }

    /// Gramos de proteína por kg de peso corporal.
    var proteinaPorKg: Double {
        switch self {
        case .bajarGrasa: return 2.0
        case .mantener: return 1.6
        case .ganarMusculo: return 1.8
        }
    }

    /// Porcentaje de las calorías que vienen de grasas.
    var porcentajeGrasas: Double { 0.25 }
}

struct Perfil: Codable, Equatable {
    var sexo: Sexo
    var edad: Int
    var pesoKg: Double
    var tallaCm: Double
    var actividad: NivelActividad
    var objetivo: Objetivo

    init(sexo: Sexo = .masculino, edad: Int = 20, pesoKg: Double = 70, tallaCm: Double = 170,
         actividad: NivelActividad = .ligero, objetivo: Objetivo = .mantener) {
        self.sexo = sexo
        self.edad = edad
        self.pesoKg = pesoKg
        self.tallaCm = tallaCm
        self.actividad = actividad
        self.objetivo = objetivo
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sexo = try c.decodeIfPresent(Sexo.self, forKey: .sexo) ?? .masculino
        edad = try c.decodeIfPresent(Int.self, forKey: .edad) ?? 20
        pesoKg = try c.decodeIfPresent(Double.self, forKey: .pesoKg) ?? 70
        tallaCm = try c.decodeIfPresent(Double.self, forKey: .tallaCm) ?? 170
        actividad = try c.decodeIfPresent(NivelActividad.self, forKey: .actividad) ?? .ligero
        objetivo = try c.decodeIfPresent(Objetivo.self, forKey: .objetivo) ?? .mantener
    }
}

// MARK: - Preferencias

enum Apariencia: String, Codable, CaseIterable, Identifiable {
    case sistema, claro, oscuro
    var id: String { rawValue }
    var nombre: String {
        switch self {
        case .sistema: return "Automática"
        case .claro: return "Clara"
        case .oscuro: return "Oscura"
        }
    }
}

enum UnidadPorcion: String, Codable, CaseIterable, Identifiable {
    case gramos, onzas
    var id: String { rawValue }
    var nombre: String { self == .gramos ? "Gramos (g)" : "Onzas (oz)" }
    var abreviatura: String { self == .gramos ? "g" : "oz" }
}

/// Forma de pedir la respuesta en JSON a Gemini. La documentación actual
/// usa `responseFormat`; la anterior usaba `responseMimeType` +
/// `responseJsonSchema`. Se deja elegir por si Google cambia algo.
enum FormatoPeticionIA: String, Codable, CaseIterable, Identifiable {
    case actual, clasico
    var id: String { rawValue }
    var nombre: String { self == .actual ? "Actual (responseFormat)" : "Clásico (responseMimeType)" }
}

// MARK: - Todos los datos

struct DatosApp: Codable, Equatable {
    var version: Int
    var registros: [Registro]
    /// nil hasta que completes tu perfil en Ajustes.
    var perfil: Perfil?
    /// Si no es nil, reemplaza la meta calculada por la fórmula.
    var metaManual: Nutrientes?
    var temaID: String
    var apariencia: Apariencia
    var unidad: UnidadPorcion
    var ahorroBateria: Bool
    /// True cuando aceptaste el aviso de privacidad de la IA.
    var avisoIAAceptado: Bool
    /// Nombre del modelo de Gemini (editable por si Google lo cambia).
    var modeloIA: String
    var formatoPeticionIA: FormatoPeticionIA
    /// Alimentos usados hace poco (para el acceso rápido).
    var recientes: [Registro]
    /// Tu nombre para el saludo (opcional, solo en este iPhone).
    var nombre: String

    static let modeloPorDefecto = "gemini-3.8-flash"

    init() {
        version = 1
        registros = []
        perfil = nil
        metaManual = nil
        temaID = "mercado"
        apariencia = .sistema
        unidad = .gramos
        ahorroBateria = false
        avisoIAAceptado = false
        modeloIA = DatosApp.modeloPorDefecto
        formatoPeticionIA = .actual
        recientes = []
        nombre = ""
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        registros = try c.decodeIfPresent([Registro].self, forKey: .registros) ?? []
        perfil = try c.decodeIfPresent(Perfil.self, forKey: .perfil)
        metaManual = try c.decodeIfPresent(Nutrientes.self, forKey: .metaManual)
        temaID = try c.decodeIfPresent(String.self, forKey: .temaID) ?? "mercado"
        apariencia = try c.decodeIfPresent(Apariencia.self, forKey: .apariencia) ?? .sistema
        unidad = try c.decodeIfPresent(UnidadPorcion.self, forKey: .unidad) ?? .gramos
        ahorroBateria = try c.decodeIfPresent(Bool.self, forKey: .ahorroBateria) ?? false
        avisoIAAceptado = try c.decodeIfPresent(Bool.self, forKey: .avisoIAAceptado) ?? false
        let modelo = try c.decodeIfPresent(String.self, forKey: .modeloIA) ?? ""
        modeloIA = modelo.isEmpty ? DatosApp.modeloPorDefecto : modelo
        formatoPeticionIA = try c.decodeIfPresent(FormatoPeticionIA.self, forKey: .formatoPeticionIA) ?? .actual
        recientes = try c.decodeIfPresent([Registro].self, forKey: .recientes) ?? []
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? ""
    }
}
