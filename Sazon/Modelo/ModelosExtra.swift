import Foundation

// Modelos de las funciones de progreso, agua, ayuno, recetas, plan y
// recordatorios. Solo Foundation (también los compilan las pruebas).
// Todos decodifican con valores por defecto para leer datos antiguos.

// MARK: - Agua

struct RegistroAgua: Codable, Identifiable, Equatable {
    var id: UUID
    var fecha: Date
    var ml: Double

    init(id: UUID = UUID(), fecha: Date, ml: Double) {
        self.id = id; self.fecha = fecha; self.ml = ml
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        fecha = try c.decodeIfPresent(Date.self, forKey: .fecha) ?? Date()
        ml = try c.decodeIfPresent(Double.self, forKey: .ml) ?? 250
    }
}

// MARK: - Progreso corporal

struct RegistroPeso: Codable, Identifiable, Equatable {
    var id: UUID
    var fecha: Date
    var kg: Double

    init(id: UUID = UUID(), fecha: Date, kg: Double) {
        self.id = id; self.fecha = fecha; self.kg = kg
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        fecha = try c.decodeIfPresent(Date.self, forKey: .fecha) ?? Date()
        kg = try c.decodeIfPresent(Double.self, forKey: .kg) ?? 0
    }
}

/// Medidas corporales en centímetros (todas opcionales).
struct RegistroMedidas: Codable, Identifiable, Equatable {
    var id: UUID
    var fecha: Date
    var cuello: Double?
    var cintura: Double?
    var cadera: Double?
    var pecho: Double?
    var brazo: Double?
    var muslo: Double?
    /// % de grasa escrito a mano (si lo mediste con otro método).
    var grasaManual: Double?

    init(id: UUID = UUID(), fecha: Date, cuello: Double? = nil, cintura: Double? = nil, cadera: Double? = nil,
         pecho: Double? = nil, brazo: Double? = nil, muslo: Double? = nil, grasaManual: Double? = nil) {
        self.id = id; self.fecha = fecha; self.cuello = cuello; self.cintura = cintura; self.cadera = cadera
        self.pecho = pecho; self.brazo = brazo; self.muslo = muslo; self.grasaManual = grasaManual
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        fecha = try c.decodeIfPresent(Date.self, forKey: .fecha) ?? Date()
        cuello = try c.decodeIfPresent(Double.self, forKey: .cuello)
        cintura = try c.decodeIfPresent(Double.self, forKey: .cintura)
        cadera = try c.decodeIfPresent(Double.self, forKey: .cadera)
        pecho = try c.decodeIfPresent(Double.self, forKey: .pecho)
        brazo = try c.decodeIfPresent(Double.self, forKey: .brazo)
        muslo = try c.decodeIfPresent(Double.self, forKey: .muslo)
        grasaManual = try c.decodeIfPresent(Double.self, forKey: .grasaManual)
    }
}

/// Foto de progreso: la imagen se guarda en la carpeta de la app; aquí
/// solo va el nombre del archivo.
struct FotoProgreso: Codable, Identifiable, Equatable {
    var id: UUID
    var fecha: Date
    var archivo: String
    var nota: String

    init(id: UUID = UUID(), fecha: Date, archivo: String, nota: String = "") {
        self.id = id; self.fecha = fecha; self.archivo = archivo; self.nota = nota
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        fecha = try c.decodeIfPresent(Date.self, forKey: .fecha) ?? Date()
        archivo = try c.decodeIfPresent(String.self, forKey: .archivo) ?? ""
        nota = try c.decodeIfPresent(String.self, forKey: .nota) ?? ""
    }
}

// MARK: - Tipo de dieta

enum TipoDieta: String, Codable, CaseIterable, Identifiable {
    case equilibrada, altaProteina, bajaCarbohidratos, keto, bajaGrasa
    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .equilibrada: return "Equilibrada"
        case .altaProteina: return "Alta en proteína"
        case .bajaCarbohidratos: return "Baja en carbohidratos"
        case .keto: return "Keto"
        case .bajaGrasa: return "Baja en grasa"
        }
    }

    var descripcion: String {
        switch self {
        case .equilibrada: return "Proteína según tu objetivo, 25 % de grasas y el resto en carbohidratos."
        case .altaProteina: return "2,2 g de proteína por kg, 25 % de grasas y el resto en carbohidratos."
        case .bajaCarbohidratos: return "Proteína según tu objetivo, 20 % de carbohidratos y el resto en grasas."
        case .keto: return "Proteína según tu objetivo, 5 % de carbohidratos y el resto en grasas."
        case .bajaGrasa: return "Proteína según tu objetivo, 15 % de grasas y el resto en carbohidratos."
        }
    }
}

// MARK: - Ayuno intermitente

struct SesionAyuno: Codable, Identifiable, Equatable {
    var id: UUID
    var inicio: Date
    /// Horas de ayuno planeadas.
    var horas: Double
    /// nil mientras está en curso.
    var finReal: Date?

    init(id: UUID = UUID(), inicio: Date, horas: Double, finReal: Date? = nil) {
        self.id = id; self.inicio = inicio; self.horas = horas; self.finReal = finReal
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        inicio = try c.decodeIfPresent(Date.self, forKey: .inicio) ?? Date()
        horas = try c.decodeIfPresent(Double.self, forKey: .horas) ?? 16
        finReal = try c.decodeIfPresent(Date.self, forKey: .finReal)
    }

    var finPlaneado: Date { inicio.addingTimeInterval(horas * 3600) }
}

// MARK: - Alimentos propios y recetas

/// Alimento que creaste (aparece en la búsqueda junto con la tabla del INS).
struct AlimentoPropio: Codable, Identifiable, Equatable {
    var id: UUID
    var nombre: String
    var por100g: Nutrientes
    var medidas: [MedidaCasera]

    init(id: UUID = UUID(), nombre: String, por100g: Nutrientes, medidas: [MedidaCasera] = []) {
        self.id = id; self.nombre = nombre; self.por100g = por100g; self.medidas = medidas
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? "Alimento"
        por100g = try c.decodeIfPresent(Nutrientes.self, forKey: .por100g) ?? .cero
        medidas = try c.decodeIfPresent([MedidaCasera].self, forKey: .medidas) ?? []
    }
}

struct Ingrediente: Codable, Identifiable, Equatable {
    var id: UUID
    var nombre: String
    var gramos: Double
    var por100g: Nutrientes
    var origen: OrigenDato
    var codigoINS: String?

    init(id: UUID = UUID(), nombre: String, gramos: Double, por100g: Nutrientes, origen: OrigenDato, codigoINS: String? = nil) {
        self.id = id; self.nombre = nombre; self.gramos = gramos; self.por100g = por100g
        self.origen = origen; self.codigoINS = codigoINS
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? "Ingrediente"
        gramos = try c.decodeIfPresent(Double.self, forKey: .gramos) ?? 100
        por100g = try c.decodeIfPresent(Nutrientes.self, forKey: .por100g) ?? .cero
        origen = try c.decodeIfPresent(OrigenDato.self, forKey: .origen) ?? .manual
        codigoINS = try c.decodeIfPresent(String.self, forKey: .codigoINS)
    }

    var total: Nutrientes { por100g * (gramos / 100) }
}

struct Receta: Codable, Identifiable, Equatable {
    var id: UUID
    var nombre: String
    var porciones: Double
    var ingredientes: [Ingrediente]
    var pasos: [String]
    /// Peso final cocido en gramos, si lo pesaste (si no, se usa la suma de ingredientes).
    var pesoFinal: Double?
    var creada: Date

    init(id: UUID = UUID(), nombre: String, porciones: Double = 1, ingredientes: [Ingrediente] = [],
         pasos: [String] = [], pesoFinal: Double? = nil, creada: Date = Date()) {
        self.id = id; self.nombre = nombre; self.porciones = porciones; self.ingredientes = ingredientes
        self.pasos = pasos; self.pesoFinal = pesoFinal; self.creada = creada
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? "Receta"
        porciones = try c.decodeIfPresent(Double.self, forKey: .porciones) ?? 1
        ingredientes = try c.decodeIfPresent([Ingrediente].self, forKey: .ingredientes) ?? []
        pasos = try c.decodeIfPresent([String].self, forKey: .pasos) ?? []
        pesoFinal = try c.decodeIfPresent(Double.self, forKey: .pesoFinal)
        creada = try c.decodeIfPresent(Date.self, forKey: .creada) ?? Date()
    }
}

// MARK: - Plan de comidas

struct ItemPlan: Codable, Identifiable, Equatable {
    var id: UUID
    var comida: TipoComida
    var nombre: String
    var gramos: Double
    var por100g: Nutrientes
    var origen: OrigenDato
    var codigoINS: String?
    var recetaID: UUID?
    /// True cuando ya lo pasaste al diario.
    var hecho: Bool

    init(id: UUID = UUID(), comida: TipoComida, nombre: String, gramos: Double, por100g: Nutrientes,
         origen: OrigenDato, codigoINS: String? = nil, recetaID: UUID? = nil, hecho: Bool = false) {
        self.id = id; self.comida = comida; self.nombre = nombre; self.gramos = gramos; self.por100g = por100g
        self.origen = origen; self.codigoINS = codigoINS; self.recetaID = recetaID; self.hecho = hecho
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        comida = try c.decodeIfPresent(TipoComida.self, forKey: .comida) ?? .almuerzo
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? "Alimento"
        gramos = try c.decodeIfPresent(Double.self, forKey: .gramos) ?? 100
        por100g = try c.decodeIfPresent(Nutrientes.self, forKey: .por100g) ?? .cero
        origen = try c.decodeIfPresent(OrigenDato.self, forKey: .origen) ?? .ins
        codigoINS = try c.decodeIfPresent(String.self, forKey: .codigoINS)
        recetaID = try c.decodeIfPresent(UUID.self, forKey: .recetaID)
        hecho = try c.decodeIfPresent(Bool.self, forKey: .hecho) ?? false
    }

    var total: Nutrientes { por100g * (gramos / 100) }
}

struct PlanDia: Codable, Identifiable, Equatable {
    /// Inicio del día (medianoche, hora local).
    var dia: Date
    var items: [ItemPlan]
    var id: Date { dia }

    init(dia: Date, items: [ItemPlan] = []) {
        self.dia = dia; self.items = items
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dia = try c.decodeIfPresent(Date.self, forKey: .dia) ?? Date()
        items = try c.decodeIfPresent([ItemPlan].self, forKey: .items) ?? []
    }
}

// MARK: - Recordatorios

struct ConfigRecordatorios: Codable, Equatable {
    var comidasActivas: Bool
    /// Hora de cada comida en minutos desde medianoche.
    var horaDesayuno: Int
    var horaAlmuerzo: Int
    var horaCena: Int
    var aguaActiva: Bool
    /// Cada cuántas horas recordar el agua (entre 8:00 y 21:00).
    var aguaCadaHoras: Int
    var pesoActivo: Bool
    /// Día de la semana para pesarte (1 = domingo … 7 = sábado).
    var pesoDiaSemana: Int
    var pesoHora: Int
    var ayunoActivo: Bool

    init() {
        comidasActivas = false
        horaDesayuno = 8 * 60
        horaAlmuerzo = 13 * 60
        horaCena = 20 * 60
        aguaActiva = false
        aguaCadaHoras = 2
        pesoActivo = false
        pesoDiaSemana = 2
        pesoHora = 7 * 60 + 30
        ayunoActivo = true
    }

    init(from decoder: Decoder) throws {
        let base = ConfigRecordatorios()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        comidasActivas = try c.decodeIfPresent(Bool.self, forKey: .comidasActivas) ?? base.comidasActivas
        horaDesayuno = try c.decodeIfPresent(Int.self, forKey: .horaDesayuno) ?? base.horaDesayuno
        horaAlmuerzo = try c.decodeIfPresent(Int.self, forKey: .horaAlmuerzo) ?? base.horaAlmuerzo
        horaCena = try c.decodeIfPresent(Int.self, forKey: .horaCena) ?? base.horaCena
        aguaActiva = try c.decodeIfPresent(Bool.self, forKey: .aguaActiva) ?? base.aguaActiva
        aguaCadaHoras = try c.decodeIfPresent(Int.self, forKey: .aguaCadaHoras) ?? base.aguaCadaHoras
        pesoActivo = try c.decodeIfPresent(Bool.self, forKey: .pesoActivo) ?? base.pesoActivo
        pesoDiaSemana = try c.decodeIfPresent(Int.self, forKey: .pesoDiaSemana) ?? base.pesoDiaSemana
        pesoHora = try c.decodeIfPresent(Int.self, forKey: .pesoHora) ?? base.pesoHora
        ayunoActivo = try c.decodeIfPresent(Bool.self, forKey: .ayunoActivo) ?? base.ayunoActivo
    }
}

// MARK: - Coach

struct MensajeCoach: Codable, Identifiable, Equatable {
    enum Autor: String, Codable { case usuario, coach }
    var id: UUID
    var autor: Autor
    var texto: String
    var fecha: Date

    init(id: UUID = UUID(), autor: Autor, texto: String, fecha: Date = Date()) {
        self.id = id; self.autor = autor; self.texto = texto; self.fecha = fecha
    }
}
