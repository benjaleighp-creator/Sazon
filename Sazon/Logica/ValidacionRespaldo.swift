import Foundation

/// Revisa un respaldo antes de restaurarlo. Un respaldo es un archivo de
/// texto que pudo editarse fuera de la app, así que no se confía en él:
/// - tamaño máximo,
/// - nombres de archivo de fotos sin carpetas (evita que «borrar foto»
///   apunte a otro archivo, por ejemplo `../datos-sazon.json`),
/// - números finitos y en rango (los valores imposibles se recortan; los
///   registros sin una porción válida se descartan),
/// - textos con largo máximo,
/// - y no trae consentimientos: el aviso de la IA y el «compartir resumen»
///   del coach se quedan como estén en este iPhone.
enum ValidacionRespaldo {
    /// Tamaño máximo del archivo (años de registros caben de sobra).
    static let tamanoMaximo = 25 * 1024 * 1024
    /// Largo máximo de nombres y notas.
    static let largoNombre = 120
    static let largoNota = 2000

    /// Solo un nombre de archivo simple: letras y números ASCII, «-», «_» y
    /// «.», sin «/», sin «..» y sin empezar por punto.
    static func esNombreArchivoSeguro(_ nombre: String) -> Bool {
        guard (1...100).contains(nombre.count), !nombre.hasPrefix("."), !nombre.contains("..") else { return false }
        return nombre.allSatisfy { c in
            c.isASCII && (c.isLetter || c.isNumber || c == "-" || c == "_" || c == ".")
        }
    }

    /// Resultado de revisar un respaldo: los datos limpios y cuántos
    /// elementos se descartaron por inválidos.
    struct Resultado {
        var datos: DatosApp
        var descartados: Int
    }

    static func revisar(_ entrada: DatosApp, conservando actual: DatosApp) -> Resultado {
        var d = entrada
        var descartados = 0

        // Consentimientos: no se importan.
        d.avisoIAAceptado = actual.avisoIAAceptado
        d.coachCompartirResumen = actual.coachCompartirResumen
        let modelo = d.modeloIA.trimmingCharacters(in: .whitespacesAndNewlines)
        d.modeloIA = PoliticaIA.nombreModeloValido(modelo) ? modelo : DatosApp.modeloPorDefecto

        func registrosValidos(_ lista: [Registro]) -> [Registro] {
            let limpios = lista.compactMap(registro)
            descartados += lista.count - limpios.count
            return limpios
        }
        d.registros = registrosValidos(d.registros)
        d.recientes = registrosValidos(d.recientes)
        for i in d.favoritos.indices {
            d.favoritos[i].nombre = recortar(d.favoritos[i].nombre, largoNombre)
            d.favoritos[i].registros = registrosValidos(d.favoritos[i].registros)
        }

        let fotos = d.fotos.filter { esNombreArchivoSeguro($0.archivo) }
        descartados += d.fotos.count - fotos.count
        d.fotos = fotos.map { f in
            var f = f
            f.nota = recortar(f.nota, largoNota)
            return f
        }

        let cola = d.colaIA.filter { $0.archivoFoto.map(esNombreArchivoSeguro) ?? true }
        descartados += d.colaIA.count - cola.count
        d.colaIA = cola

        let pesos = d.pesos.filter { $0.kg.isFinite && (20...400).contains($0.kg) }
        descartados += d.pesos.count - pesos.count
        d.pesos = pesos

        let agua = d.agua.filter { $0.ml.isFinite && $0.ml > 0 && $0.ml <= 5000 }
        descartados += d.agua.count - agua.count
        d.agua = agua

        if !(d.vasoMl.isFinite && (50...2000).contains(d.vasoMl)) { d.vasoMl = 250 }
        if let m = d.metaAguaManual, !(m.isFinite && (500...10000).contains(m)) { d.metaAguaManual = nil }
        if !(d.horasAyuno.isFinite && (1...72).contains(d.horasAyuno)) { d.horasAyuno = 16 }
        if !(d.ajusteKcal.isFinite && (-2000...2000).contains(d.ajusteKcal)) { d.ajusteKcal = 0 }
        if let meta = d.metaManual { d.metaManual = nutrientesPorDia(meta) }
        d.nombre = recortar(d.nombre, largoNombre)
        d.porcionesAprendidas = d.porcionesAprendidas.filter { Porciones.esValido($0.value) }

        return Resultado(datos: d, descartados: descartados)
    }

    /// Un registro con porción válida y valores por 100 g dentro de rango
    /// (recortados). nil si la porción no es válida.
    static func registro(_ r: Registro) -> Registro? {
        guard Porciones.esValido(r.gramos) else { return nil }
        var r = r
        r.nombre = recortar(r.nombre, largoNombre)
        r.por100g = por100g(r.por100g)
        if let m = r.medida, !Porciones.esValido(m.gramos) { r.medida = nil; r.cantidadMedida = nil }
        if let c = r.cantidadMedida, !(c.isFinite && c > 0 && c <= 1000) { r.cantidadMedida = nil }
        if let c = r.confianzaIA { r.confianzaIA = c.isFinite ? min(max(c, 0), 1) : nil }
        if let codigo = r.codigoBarras, codigo.count > 14 || !codigo.allSatisfy({ $0.isASCII && $0.isNumber }) {
            r.codigoBarras = nil
        }
        return r
    }

    /// Valores por 100 g recortados a lo posible.
    static func por100g(_ n: Nutrientes) -> Nutrientes {
        Nutrientes(kcal: limitar(n.kcal, 0...900), proteina: limitar(n.proteina, 0...100),
                   carbohidratos: limitar(n.carbohidratos, 0...100), grasas: limitar(n.grasas, 0...100),
                   fibra: limitar(n.fibra, 0...100), sodio: limitar(n.sodio, 0...40000),
                   azucar: limitar(n.azucar, 0...100))
    }

    /// Meta diaria recortada a lo posible.
    static func nutrientesPorDia(_ n: Nutrientes) -> Nutrientes {
        Nutrientes(kcal: limitar(n.kcal, 0...10000), proteina: limitar(n.proteina, 0...1000),
                   carbohidratos: limitar(n.carbohidratos, 0...2000), grasas: limitar(n.grasas, 0...1000),
                   fibra: limitar(n.fibra, 0...500), sodio: limitar(n.sodio, 0...100000),
                   azucar: limitar(n.azucar, 0...2000))
    }

    static func limitar(_ v: Double, _ rango: ClosedRange<Double>) -> Double {
        guard v.isFinite else { return rango.lowerBound }
        return min(max(v, rango.lowerBound), rango.upperBound)
    }

    static func recortar(_ s: String, _ maximo: Int) -> String {
        s.count > maximo ? String(s.prefix(maximo)) : s
    }
}
