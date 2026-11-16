import Foundation

/// Un trozo de texto leído en la foto, con su posición (coordenadas de
/// Vision: de 0 a 1, con el origen abajo a la izquierda).
struct PiezaTexto: Equatable {
    var x: Double
    var y: Double
    var alto: Double
    var texto: String
}

/// Lee una tabla nutricional a partir del texto reconocido en el iPhone
/// (sin red). Si no encuentra con seguridad energía, proteína,
/// carbohidratos y grasas por 100 g (o por porción con su tamaño), devuelve
/// nil y la app recurre a la IA en la nube. Nunca inventa valores.
enum ParserEtiqueta {

    /// Junta las piezas que están a la misma altura en filas (de arriba
    /// abajo, cada fila de izquierda a derecha).
    static func filas(_ piezas: [PiezaTexto]) -> [String] {
        let ordenadas = piezas.sorted { $0.y > $1.y }
        var filas: [[PiezaTexto]] = []
        for p in ordenadas {
            if let i = filas.indices.last, let ref = filas[i].first,
               abs(ref.y - p.y) <= max(ref.alto, p.alto) * 0.5 {
                filas[i].append(p)
            } else {
                filas.append([p])
            }
        }
        return filas.map { $0.sorted { $0.x < $1.x }.map(\.texto).joined(separator: " ") }
    }

    /// Texto sin tildes, en minúsculas y con coma decimal convertida a punto.
    static func normalizar(_ fila: String) -> String {
        let plegado = fila.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es")).lowercased()
        return plegado.replacingOccurrences(of: "(\\d),(\\d)", with: "$1.$2", options: .regularExpression)
    }

    /// Un número con su unidad, en el orden en que aparece en la fila.
    struct Valor: Equatable {
        var numero: Double
        var unidad: String
    }

    /// Números de una fila (después de `desde`), sin los porcentajes (%VD).
    static func valores(_ fila: String, desde: String.Index? = nil) -> [Valor] {
        let texto = desde.map { String(fila[$0...]) } ?? fila
        guard let regex = try? NSRegularExpression(pattern: "(<\\s*)?(\\d+(?:\\.\\d+)?)\\s*(kcal|kj|mg|g|ml|%)?") else { return [] }
        let rango = NSRange(texto.startIndex..., in: texto)
        var lista: [Valor] = []
        for m in regex.matches(in: texto, range: rango) {
            guard let rNum = Range(m.range(at: 2), in: texto), let n = Double(texto[rNum]) else { continue }
            let unidad = Range(m.range(at: 3), in: texto).map { String(texto[$0]) } ?? ""
            if unidad == "%" { continue }
            // «< 1 g» se toma como 0 (cantidad no significativa).
            let menorQue = m.range(at: 1).location != NSNotFound
            lista.append(Valor(numero: menorQue ? 0 : n, unidad: unidad))
        }
        return lista
    }

    /// Lee la etiqueta. Devuelve nil si no hay datos suficientes y fiables.
    static func leer(_ filasCrudas: [String]) -> EtiquetaLeida? {
        let filas = filasCrudas.map(normalizar)

        // Columnas: ¿hay «por 100 g» y «por porción»? ¿en qué orden?
        var columna100: Int?
        var columnaPorcion: Int?
        for f in filas {
            let pos100 = f.range(of: "100\\s*(g|ml)", options: .regularExpression)?.lowerBound
            let posPorcion = f.range(of: "porcion")?.lowerBound
            if let pos100, let posPorcion, !f.contains("tamano") {
                columna100 = pos100 < posPorcion ? 0 : 1
                columnaPorcion = 1 - (columna100 ?? 0)
                break
            } else if pos100 != nil, columna100 == nil {
                columna100 = 0
            }
        }

        // Tamaño de la porción: «Porción: 30 g» o «Tamaño de porción 30 g».
        var porcion: Double?
        for f in filas where f.contains("porcion") && !f.contains("porciones") && !f.contains("100") {
            if let v = valores(f).first(where: { $0.unidad == "g" || $0.unidad == "ml" }), v.numero > 0, v.numero <= 2000 {
                porcion = v.numero
                break
            }
        }
        if columnaPorcion == nil, columna100 == nil, porcion != nil { columnaPorcion = 0 }

        func valor(_ claves: [String], excluir: [String] = []) -> [Valor]? {
            for f in filas {
                guard let clave = claves.first(where: { f.contains($0) }),
                      !excluir.contains(where: { f.contains($0) }),
                      let pos = f.range(of: clave)?.upperBound else { continue }
                let v = valores(f, desde: pos)
                if !v.isEmpty { return v }
            }
            return nil
        }

        /// Elige el valor de la columna buscada y lo pasa a «por 100 g».
        func por100(_ lista: [Valor]?) -> Double? {
            guard let lista, !lista.isEmpty else { return nil }
            if let c = columna100 {
                return c < lista.count ? lista[c].numero : (lista.count == 1 ? lista[0].numero : nil)
            }
            if let c = columnaPorcion, let porcion, porcion > 0 {
                let v = c < lista.count ? lista[c].numero : lista[0].numero
                return v * 100 / porcion
            }
            return nil
        }

        // Energía: se prefiere el valor en kcal; si solo hay kJ, se convierte.
        var kcal: Double?
        if let lista = valor(["valor energetico", "energia", "calorias"]) {
            let enKcal = lista.filter { $0.unidad == "kcal" }
            let enKj = lista.filter { $0.unidad == "kj" }
            if !enKcal.isEmpty {
                kcal = por100(enKcal)
            } else if !enKj.isEmpty {
                kcal = por100(enKj).map { $0 / 4.184 }
            } else {
                kcal = por100(lista)
            }
        }
        let proteina = por100(valor(["proteina"]))
        let grasas = por100(valor(["grasa total", "grasas totales", "grasa", "lipidos"],
                                  excluir: ["saturada", "trans", "monoinsat", "poliinsat"]))
        let carbohidratos = por100(valor(["carbohidrato", "hidratos de carbono"]))
        let azucar = por100(valor(["azucar"])) ?? 0
        let fibra = por100(valor(["fibra"])) ?? 0
        var sodio = 0.0
        if let lista = valor(["sodio"]), let v = por100(lista) {
            let enGramos = lista.first?.unidad == "g"
            sodio = enGramos ? v * 1000 : v
        }

        guard let kcal, let proteina, let grasas, let carbohidratos,
              (0...900).contains(kcal), (0...100).contains(proteina),
              (0...100).contains(grasas), (0...100).contains(carbohidratos),
              proteina + grasas + carbohidratos <= 105 else { return nil }
        // Coherencia: las kcal deben parecerse a las de los macros
        // (4-4-9). Si no, probablemente se leyó mal una columna.
        let calculadas = proteina * 4 + carbohidratos * 4 + grasas * 9
        if kcal > 20 || calculadas > 20 {
            let diferencia = abs(kcal - calculadas) / max(kcal, calculadas)
            guard diferencia <= 0.3 else { return nil }
        }
        return EtiquetaLeida(
            nombre: "",
            por100g: Nutrientes(kcal: kcal, proteina: proteina, carbohidratos: carbohidratos, grasas: grasas,
                                fibra: (0...100).contains(fibra) ? fibra : 0,
                                sodio: (0...40000).contains(sodio) ? sodio : 0,
                                azucar: (0...100).contains(azucar) ? azucar : 0),
            porcionGramos: porcion,
            confianza: 0.75,
            capa: .iPhone)
    }
}
