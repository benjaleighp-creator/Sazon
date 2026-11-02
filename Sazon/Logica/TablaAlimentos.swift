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

    var id: String { codigo }

    init(codigo: String, nombre: String, grupo: String, por100g: Nutrientes, medidas: [MedidaCasera] = []) {
        self.codigo = codigo
        self.nombre = nombre
        self.grupo = grupo
        self.por100g = por100g
        self.medidas = medidas
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        codigo = try c.decode(String.self, forKey: .codigo)
        nombre = try c.decode(String.self, forKey: .nombre)
        grupo = try c.decodeIfPresent(String.self, forKey: .grupo) ?? ""
        por100g = try c.decode(Nutrientes.self, forKey: .por100g)
        medidas = try c.decodeIfPresent([MedidaCasera].self, forKey: .medidas) ?? []
    }
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
        let q = palabras(consulta)
        let n = palabras(nombre)
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
        guard !palabras(consulta).isEmpty else { return [] }
        return tabla
            .map { Coincidencia(alimento: $0, puntaje: puntaje(consulta: consulta, nombre: $0.nombre)) }
            .filter { $0.puntaje > 0 }
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
        guard let mejor = buscar(nombreIA, en: tabla, limite: 1).first, mejor.puntaje >= minimo else { return nil }
        return mejor
    }
}
