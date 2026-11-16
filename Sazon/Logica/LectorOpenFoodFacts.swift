import Foundation

/// Producto envasado leído de Open Food Facts.
struct ProductoEnvasado: Equatable {
    let codigo: String
    let nombre: String
    let marca: String?
    /// Valores por 100 g (o 100 ml). Puede faltar alguno.
    let por100g: Nutrientes
    /// True si Open Food Facts no trae alguno de los cuatro valores.
    let datosIncompletos: Bool
    /// Porción declarada en el envase, si la trae ("30 g").
    let porcion: MedidaCasera?
}

enum ErrorOpenFoodFacts: Error, Equatable {
    case codigoInvalido
    case noEncontrado
    case sinInternet
    case lento
    case sinDatosNutricionales
    case servidor(Int)
    case respuestaInvalida

    var mensaje: String {
        switch self {
        case .codigoInvalido: return "El código de barras no es válido. Debe tener solo números (8 a 14 dígitos)."
        case .noEncontrado: return "Este producto no está en Open Food Facts. Puedes buscarlo en la tabla o agregarlo a mano."
        case .sinInternet: return "Para consultar Open Food Facts hace falta internet. La búsqueda en la tabla funciona sin conexión."
        case .lento: return "Open Food Facts tardó demasiado en responder. Tu conexión funciona; inténtalo de nuevo en un momento."
        case .sinDatosNutricionales: return "El producto está en Open Food Facts, pero sin calorías por 100 g. Agrégalo a mano con los datos del envase."
        case .servidor(let codigo): return "Open Food Facts respondió con el error \(codigo). Inténtalo más tarde."
        case .respuestaInvalida: return "La respuesta de Open Food Facts no se pudo leer."
        }
    }
}

/// Lectura de la API v2 de Open Food Facts (sin red: solo el JSON).
/// Petición: GET https://world.openfoodfacts.org/api/v2/product/{codigo}?fields=…
enum LectorOpenFoodFacts {

    static let campos = "code,product_name,product_name_es,brands,nutriments,serving_size,serving_quantity"

    /// Solo dígitos, de 8 a 14 (EAN-8, UPC-A, EAN-13, GTIN-14).
    static func codigoValido(_ codigo: String) -> String? {
        let limpio = codigo.filter { !$0.isWhitespace }
        guard (8...14).contains(limpio.count), limpio.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return limpio
    }

    static func url(codigo: String) -> URL? {
        URL(string: "https://world.openfoodfacts.org/api/v2/product/\(codigo)?fields=\(campos)")
    }

    static func producto(desde datos: Data, codigo: String) throws -> ProductoEnvasado {
        guard let raiz = try? JSONSerialization.jsonObject(with: datos) as? [String: Any] else {
            throw ErrorOpenFoodFacts.respuestaInvalida
        }
        let estado = LectorIA.numero(raiz["status"]) ?? 0
        guard estado == 1, let p = raiz["product"] as? [String: Any] else {
            throw ErrorOpenFoodFacts.noEncontrado
        }
        let n = (p["nutriments"] as? [String: Any]) ?? [:]
        let kcal = LectorIA.numero(n["energy-kcal_100g"])
            ?? LectorIA.numero(n["energy_100g"]).map { $0 / 4.184 }   // kJ → kcal
        // Valores imposibles (más de 900 kcal por 100 g) se tratan como faltantes.
        guard let kcal, (0...900).contains(kcal) else { throw ErrorOpenFoodFacts.sinDatosNutricionales }
        // Valores fuera de rango (negativos o imposibles) se tratan como faltantes.
        let prot = enRango(n["proteins_100g"], 0...100)
        let carb = enRango(n["carbohydrates_100g"], 0...100)
        let gras = enRango(n["fat_100g"], 0...100)

        let nombreES = LectorIA.textoLimpio(p["product_name_es"], maximo: LectorIA.maxLargoNombre)
        let nombreGeneral = LectorIA.textoLimpio(p["product_name"], maximo: LectorIA.maxLargoNombre)
        let nombre = !nombreES.isEmpty ? nombreES : (!nombreGeneral.isEmpty ? nombreGeneral : "Producto \(codigo)")
        let marca = (p["brands"] as? String)?
            .split(separator: ",").first
            .map { LectorIA.textoLimpio(String($0), maximo: 60) }
            .flatMap { $0.isEmpty ? nil : $0 }

        var porcion: MedidaCasera?
        if let gramos = LectorIA.numero(p["serving_quantity"]), Porciones.esValido(gramos) {
            let texto = LectorIA.textoLimpio(p["serving_size"], maximo: 30)
            porcion = MedidaCasera(nombre: texto.isEmpty ? "porción del envase" : "porción (\(texto))",
                                   gramos: gramos, estimada: false)
        }

        return ProductoEnvasado(
            codigo: codigo,
            nombre: Formato.primeraMayuscula(nombre),
            marca: marca,
            por100g: Nutrientes(kcal: kcal, proteina: prot ?? 0, carbohidratos: carb ?? 0, grasas: gras ?? 0,
                                fibra: enRango(n["fiber_100g"], 0...100) ?? 0,
                                // Open Food Facts da el sodio en gramos; aquí va en miligramos
                                // (como máximo 40 g por 100 g, la sal pura).
                                sodio: (enRango(n["sodium_100g"], 0...40) ?? 0) * 1000,
                                azucar: enRango(n["sugars_100g"], 0...100) ?? 0),
            datosIncompletos: prot == nil || carb == nil || gras == nil,
            porcion: porcion
        )
    }

    /// Número dentro del rango, o nil si falta o no tiene sentido.
    static func enRango(_ valor: Any?, _ rango: ClosedRange<Double>) -> Double? {
        guard let v = LectorIA.numero(valor), rango.contains(v) else { return nil }
        return v
    }
}
