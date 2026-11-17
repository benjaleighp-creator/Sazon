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
        id = c.tolerante(UUID.self, .id) ?? UUID()
        fecha = c.tolerante(Date.self, .fecha) ?? Date()
        ml = c.tolerante(Double.self, .ml) ?? 250
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
        id = c.tolerante(UUID.self, .id) ?? UUID()
        fecha = c.tolerante(Date.self, .fecha) ?? Date()
        kg = c.tolerante(Double.self, .kg) ?? 0
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
        id = c.tolerante(UUID.self, .id) ?? UUID()
        fecha = c.tolerante(Date.self, .fecha) ?? Date()
        cuello = c.tolerante(Double.self, .cuello)
        cintura = c.tolerante(Double.self, .cintura)
        cadera = c.tolerante(Double.self, .cadera)
        pecho = c.tolerante(Double.self, .pecho)
        brazo = c.tolerante(Double.self, .brazo)
        muslo = c.tolerante(Double.self, .muslo)
        grasaManual = c.tolerante(Double.self, .grasaManual)
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
        id = c.tolerante(UUID.self, .id) ?? UUID()
        fecha = c.tolerante(Date.self, .fecha) ?? Date()
        archivo = c.tolerante(String.self, .archivo) ?? ""
        nota = c.tolerante(String.self, .nota) ?? ""
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
        id = c.tolerante(UUID.self, .id) ?? UUID()
        inicio = c.tolerante(Date.self, .inicio) ?? Date()
        horas = c.tolerante(Double.self, .horas) ?? 16
        finReal = c.tolerante(Date.self, .finReal)
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
        id = c.tolerante(UUID.self, .id) ?? UUID()
        nombre = c.tolerante(String.self, .nombre) ?? "Alimento"
        por100g = c.tolerante(Nutrientes.self, .por100g) ?? .cero
        medidas = c.listaTolerante(MedidaCasera.self, .medidas) ?? []
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
        id = c.tolerante(UUID.self, .id) ?? UUID()
        nombre = c.tolerante(String.self, .nombre) ?? "Ingrediente"
        gramos = c.tolerante(Double.self, .gramos) ?? 100
        por100g = c.tolerante(Nutrientes.self, .por100g) ?? .cero
        origen = c.enumTolerante(OrigenDato.self, .origen) ?? .manual
        codigoINS = c.tolerante(String.self, .codigoINS)
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
        id = c.tolerante(UUID.self, .id) ?? UUID()
        nombre = c.tolerante(String.self, .nombre) ?? "Receta"
        porciones = c.tolerante(Double.self, .porciones) ?? 1
        ingredientes = c.listaTolerante(Ingrediente.self, .ingredientes) ?? []
        pasos = c.listaTolerante(String.self, .pasos) ?? []
        pesoFinal = c.tolerante(Double.self, .pesoFinal)
        creada = c.tolerante(Date.self, .creada) ?? Date()
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
        id = c.tolerante(UUID.self, .id) ?? UUID()
        comida = c.enumTolerante(TipoComida.self, .comida) ?? .almuerzo
        nombre = c.tolerante(String.self, .nombre) ?? "Alimento"
        gramos = c.tolerante(Double.self, .gramos) ?? 100
        por100g = c.tolerante(Nutrientes.self, .por100g) ?? .cero
        origen = c.enumTolerante(OrigenDato.self, .origen) ?? .ins
        codigoINS = c.tolerante(String.self, .codigoINS)
        recetaID = c.tolerante(UUID.self, .recetaID)
        hecho = c.tolerante(Bool.self, .hecho) ?? false
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
        dia = c.tolerante(Date.self, .dia) ?? Date()
        items = c.listaTolerante(ItemPlan.self, .items) ?? []
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
        comidasActivas = c.tolerante(Bool.self, .comidasActivas) ?? base.comidasActivas
        horaDesayuno = c.tolerante(Int.self, .horaDesayuno) ?? base.horaDesayuno
        horaAlmuerzo = c.tolerante(Int.self, .horaAlmuerzo) ?? base.horaAlmuerzo
        horaCena = c.tolerante(Int.self, .horaCena) ?? base.horaCena
        aguaActiva = c.tolerante(Bool.self, .aguaActiva) ?? base.aguaActiva
        aguaCadaHoras = c.tolerante(Int.self, .aguaCadaHoras) ?? base.aguaCadaHoras
        pesoActivo = c.tolerante(Bool.self, .pesoActivo) ?? base.pesoActivo
        pesoDiaSemana = c.tolerante(Int.self, .pesoDiaSemana) ?? base.pesoDiaSemana
        pesoHora = c.tolerante(Int.self, .pesoHora) ?? base.pesoHora
        ayunoActivo = c.tolerante(Bool.self, .ayunoActivo) ?? base.ayunoActivo
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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.tolerante(UUID.self, .id) ?? UUID()
        autor = c.enumTolerante(Autor.self, .autor) ?? .coach
        texto = c.tolerante(String.self, .texto) ?? ""
        fecha = c.tolerante(Date.self, .fecha) ?? Date()
    }
}

// MARK: - Favoritos

/// Combo de alimentos que repites seguido (por ejemplo, tu desayuno de siempre).
struct ComidaFavorita: Codable, Identifiable, Equatable {
    var id: UUID
    var nombre: String
    /// Alimentos con sus porciones (la fecha y la comida se ignoran al usarlo).
    var registros: [Registro]
    var comidaHabitual: TipoComida
    var creada: Date

    init(id: UUID = UUID(), nombre: String, registros: [Registro], comidaHabitual: TipoComida, creada: Date = Date()) {
        self.id = id; self.nombre = nombre; self.registros = registros
        self.comidaHabitual = comidaHabitual; self.creada = creada
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.tolerante(UUID.self, .id) ?? UUID()
        nombre = c.tolerante(String.self, .nombre) ?? "Favorito"
        registros = c.listaTolerante(Registro.self, .registros) ?? []
        comidaHabitual = c.enumTolerante(TipoComida.self, .comidaHabitual) ?? .desayuno
        creada = c.tolerante(Date.self, .creada) ?? Date()
    }

    var total: Nutrientes { registros.reduce(Nutrientes.cero) { $0 + $1.total } }
}

// MARK: - Cola sin conexión

/// Foto o texto guardado sin internet para analizarlo con la IA cuando
/// vuelva la red. El resultado nunca se guarda solo: queda «listo para
/// revisar» y tú lo confirmas.
struct PendienteIA: Codable, Identifiable, Hashable {
    enum Tipo: String, Codable { case foto, texto }
    enum Estado: String, Codable {
        /// Esperando internet.
        case esperando
        /// La IA respondió: falta que lo revises.
        case listo
        /// La IA no pudo (se muestra el motivo y puedes reintentar).
        case fallo
    }

    var id: UUID
    var creado: Date
    var comida: TipoComida
    var tipo: Tipo
    /// Texto escrito (vacío si es foto).
    var texto: String
    /// Nombre del archivo de la foto reducida (en la carpeta de la app).
    var archivoFoto: String?
    var estado: Estado
    /// Respuesta JSON de la IA (cuando está lista).
    var respuesta: String?
    /// Quién respondió (clave de CapaIA).
    var capa: String?
    /// Motivo del fallo, para mostrarlo.
    var error: String?
    var intentos: Int

    init(id: UUID = UUID(), creado: Date = Date(), comida: TipoComida, tipo: Tipo, texto: String = "",
         archivoFoto: String? = nil) {
        self.id = id; self.creado = creado; self.comida = comida; self.tipo = tipo; self.texto = texto
        self.archivoFoto = archivoFoto; estado = .esperando; respuesta = nil; capa = nil; error = nil; intentos = 0
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.tolerante(UUID.self, .id) ?? UUID()
        creado = c.tolerante(Date.self, .creado) ?? Date()
        comida = c.enumTolerante(TipoComida.self, .comida) ?? .snacks
        tipo = c.enumTolerante(Tipo.self, .tipo) ?? .texto
        texto = c.tolerante(String.self, .texto) ?? ""
        archivoFoto = c.tolerante(String.self, .archivoFoto)
        estado = c.enumTolerante(Estado.self, .estado) ?? .esperando
        respuesta = c.tolerante(String.self, .respuesta)
        capa = c.tolerante(String.self, .capa)
        error = c.tolerante(String.self, .error)
        intentos = c.tolerante(Int.self, .intentos) ?? 0
    }
}
