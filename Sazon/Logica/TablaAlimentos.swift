import Foundation

/// Un alimento de la tabla (INS) con sus valores por 100 g de parte comestible.
struct AlimentoBase: Codable, Identifiable, Equatable, Hashable {
    /// Código del alimento en la tabla (por ejemplo "A12").
    let codigo: String
    let nombre: String
    let grupo: String
    let por100g: Nutrientes
    /// Medidas caseras conocidas para este alimento (puede estar vacía).
    let medidas: [MedidaCasera]
    /// Micronutrientes por 100 g (solo si la tabla los trae; hoy el
    /// archivo de la app aún no los incluye: ver herramientas/convertir_ins.py).
    let micros: Micronutrientes?

    var id: String { codigo }

    init(codigo: String, nombre: String, grupo: String, por100g: Nutrientes, medidas: [MedidaCasera] = [],
         micros: Micronutrientes? = nil) {
        self.codigo = codigo
        self.nombre = nombre
        self.grupo = grupo
        self.por100g = por100g
        self.medidas = medidas
        self.micros = micros
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        codigo = try c.decode(String.self, forKey: .codigo)
        nombre = try c.decode(String.self, forKey: .nombre)
        grupo = try c.decodeIfPresent(String.self, forKey: .grupo) ?? ""
        por100g = try c.decode(Nutrientes.self, forKey: .por100g)
        medidas = try c.decodeIfPresent([MedidaCasera].self, forKey: .medidas) ?? []
        micros = c.tolerante(Micronutrientes.self, .micros)
    }
}

/// Micronutrientes por 100 g de las Tablas Peruanas (INS). Todos son
/// opcionales: un valor que la tabla no informa queda en nil (nunca se
/// inventa). Unidades: mg, salvo la vitamina A (µg de equivalentes de retinol).
struct Micronutrientes: Codable, Equatable, Hashable {
    var calcio: Double?
    var fosforo: Double?
    var zinc: Double?
    var hierro: Double?
    var vitaminaA: Double?
    var tiamina: Double?
    var riboflavina: Double?
    var niacina: Double?
    var vitaminaC: Double?
    var potasio: Double?

    init(calcio: Double? = nil, fosforo: Double? = nil, zinc: Double? = nil, hierro: Double? = nil,
         vitaminaA: Double? = nil, tiamina: Double? = nil, riboflavina: Double? = nil, niacina: Double? = nil,
         vitaminaC: Double? = nil, potasio: Double? = nil) {
        self.calcio = calcio; self.fosforo = fosforo; self.zinc = zinc; self.hierro = hierro
        self.vitaminaA = vitaminaA; self.tiamina = tiamina; self.riboflavina = riboflavina
        self.niacina = niacina; self.vitaminaC = vitaminaC; self.potasio = potasio
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        calcio = c.tolerante(Double.self, .calcio)
        fosforo = c.tolerante(Double.self, .fosforo)
        zinc = c.tolerante(Double.self, .zinc)
        hierro = c.tolerante(Double.self, .hierro)
        vitaminaA = c.tolerante(Double.self, .vitaminaA)
        tiamina = c.tolerante(Double.self, .tiamina)
        riboflavina = c.tolerante(Double.self, .riboflavina)
        niacina = c.tolerante(Double.self, .niacina)
        vitaminaC = c.tolerante(Double.self, .vitaminaC)
        potasio = c.tolerante(Double.self, .potasio)
    }

    /// Filas para mostrar (nombre, valor para `gramos`, unidad), solo las que existen.
    func filas(gramos: Double) -> [(nombre: String, valor: Double, unidad: String)] {
        let f = gramos / 100
        let todas: [(String, Double?, String)] = [
            ("Hierro", hierro, "mg"), ("Calcio", calcio, "mg"), ("Zinc", zinc, "mg"),
            ("Vitamina C", vitaminaC, "mg"), ("Vitamina A", vitaminaA, "µg"), ("Fósforo", fosforo, "mg"),
            ("Potasio", potasio, "mg"), ("Tiamina (B1)", tiamina, "mg"), ("Riboflavina (B2)", riboflavina, "mg"),
            ("Niacina (B3)", niacina, "mg")
        ]
        return todas.compactMap { n, v, u in v.map { (n, $0 * f, u) } }
    }
}

extension AlimentoBase {
    /// True si es un alimento tuyo ("P:") o una receta tuya ("R:"), no de la tabla del INS.
    var esPropio: Bool { codigo.hasPrefix("P:") || codigo.hasPrefix("R:") }
}

/// Alimentos con sus nombres ya normalizados (sin tildes, en singular),
/// calculados una sola vez. Así cada búsqueda no vuelve a normalizar los
/// 1692 nombres de la tabla.
struct IndiceBusqueda {
    let alimentos: [AlimentoBase]
    let palabras: [[String]]

    init(_ alimentos: [AlimentoBase]) {
        self.alimentos = alimentos
        self.palabras = alimentos.map { Busqueda.palabras($0.nombre) }
    }

    static let vacio = IndiceBusqueda([])
}

/// Archivo de la tabla que va dentro de la app (Sazon/Datos/alimentos-ins.json).
struct ArchivoTabla: Codable {
    /// Cita de la fuente que se muestra en "Acerca de".
    let fuente: String
    let alimentos: [AlimentoBase]

    static func leer(_ datos: Data) throws -> ArchivoTabla {
        try JSONDecoder().decode(ArchivoTabla.self, from: datos)
    }
}

/// Resultado de buscar un nombre en la tabla.
struct Coincidencia: Equatable {
    let alimento: AlimentoBase
    /// 0 a 1: qué tanto se parece.
    let puntaje: Double
}

/// Búsqueda de texto tolerante: sin tildes, sin mayúsculas y sin plurales simples.
enum Busqueda {

    /// Palabras que no ayudan a distinguir alimentos.
    static let vacias: Set<String> = [
        "de", "del", "con", "sin", "en", "el", "la", "los", "las", "y", "a", "al",
        "un", "una", "unos", "unas", "por", "para", "o", "e", "tipo", "estilo"
    ]

    /// "Pañes con PALTA" → "panes con palta".
    static func normalizar(_ texto: String) -> String {
        let plegado = texto.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "es"))
            .lowercased()
        var resultado = ""
        var espacioPrevio = true
        for ch in plegado {
            if ch.isLetter || ch.isNumber {
                resultado.append(ch)
                espacioPrevio = false
            } else if !espacioPrevio {
                resultado.append(" ")
                espacioPrevio = true
            }
        }
        return resultado.trimmingCharacters(in: .whitespaces)
    }

    /// Singular aproximado: "panes" → "pan", "tomates" → "tomate", "papas" → "papa".
    static func singular(_ palabra: String) -> String {
        guard palabra.count > 3 else { return palabra }
        if palabra.hasSuffix("es") && palabra.count > 4 {
            let previo = palabra.dropLast(2).last
            if let previo, "nrldjz".contains(previo) {
                return String(palabra.dropLast(2))
            }
        }
        if palabra.hasSuffix("s") { return String(palabra.dropLast()) }
        return palabra
    }

    /// Palabras significativas, normalizadas y en singular.
    static func palabras(_ texto: String) -> [String] {
        normalizar(texto)
            .split(separator: " ")
            .map(String.init)
            .filter { !vacias.contains($0) }
            .map(singular)
    }

    /// Puntaje de 0 a 1 de qué tanto `consulta` describe a `nombre`.
    /// Todas las palabras de la consulta deben aparecer (completas o como
    /// inicio de una palabra del nombre); si falta alguna, el puntaje es 0.
    static func puntaje(consulta: String, nombre: String) -> Double {
        puntaje(q: palabras(consulta), n: palabras(nombre))
    }

    /// Lo mismo, con las palabras ya normalizadas (consulta y nombre).
    static func puntaje(q: [String], n: [String]) -> Double {
        guard !q.isEmpty, !n.isEmpty else { return 0 }
        var exactas = 0.0
        var parciales = 0.0
        for palabra in q {
            if n.contains(palabra) {
                exactas += 1
            } else if n.contains(where: { $0.hasPrefix(palabra) || (palabra.count >= 5 && palabra.hasPrefix($0) && $0.count >= 4) }) {
                parciales += 1
            } else {
                return 0
            }
        }
        let cobertura = (exactas + parciales * 0.7) / Double(q.count)
        // Qué parte del nombre explica la consulta: "pan" se parece más a
        // "Pan francés" que a "Pan de molde integral con pasas".
        let precision = Double(q.count) / Double(max(n.count, q.count))
        // Bonificación si el nombre empieza con la primera palabra buscada.
        let inicio: Double = n.first == q.first ? 0.1 : 0
        return min(1, cobertura * 0.6 + precision * 0.3 + inicio)
    }

    /// Busca en la tabla y ordena por puntaje (y luego por nombre más corto).
    static func buscar(_ consulta: String, en tabla: [AlimentoBase], limite: Int = 40) -> [Coincidencia] {
        buscar(consulta, en: IndiceBusqueda(tabla), limite: limite)
    }

    /// Busca con un índice ya preparado.
    static func buscar(_ consulta: String, en indice: IndiceBusqueda, limite: Int = 40) -> [Coincidencia] {
        let q = palabras(consulta)
        guard !q.isEmpty else { return [] }
        var encontrados: [Coincidencia] = []
        for (i, alimento) in indice.alimentos.enumerated() {
            let p = puntaje(q: q, n: indice.palabras[i])
            if p > 0 { encontrados.append(Coincidencia(alimento: alimento, puntaje: p)) }
        }
        return ordenar(encontrados, limite: limite)
    }

    /// Ordena por puntaje (y luego por nombre más corto) y recorta.
    static func ordenar(_ lista: [Coincidencia], limite: Int) -> [Coincidencia] {
        lista
            .sorted {
                if $0.puntaje != $1.puntaje { return $0.puntaje > $1.puntaje }
                return $0.alimento.nombre.count < $1.alimento.nombre.count
            }
            .prefix(limite)
            .map { $0 }
    }

    /// Mejor coincidencia para un nombre dado por la IA, solo si es
    /// suficientemente buena (si no, se usa la estimación de la IA).
    static func emparejar(_ nombreIA: String, en tabla: [AlimentoBase], minimo: Double = 0.62) -> Coincidencia? {
        emparejar(nombreIA, en: IndiceBusqueda(tabla), minimo: minimo)
    }

    static func emparejar(_ nombreIA: String, en indice: IndiceBusqueda, minimo: Double = 0.62) -> Coincidencia? {
        guard let mejor = buscar(nombreIA, en: indice, limite: 1).first, mejor.puntaje >= minimo else { return nil }
        return mejor
    }
}
