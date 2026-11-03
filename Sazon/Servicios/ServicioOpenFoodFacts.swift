import Foundation

/// Consulta un producto por código de barras en Open Food Facts (sin IA ni clave).
/// API: https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/tutorial-off-api/
/// Los datos de Open Food Facts tienen licencia Open Database License (ODbL).
enum ServicioOpenFoodFacts {

    static func buscar(codigo bruto: String, sesion: URLSession = .shared) async throws -> ProductoEnvasado {
        guard let codigo = LectorOpenFoodFacts.codigoValido(bruto),
              let url = LectorOpenFoodFacts.url(codigo: codigo) else {
            throw ErrorOpenFoodFacts.codigoInvalido
        }
        var peticion = URLRequest(url: url)
        peticion.timeoutInterval = 20
        // Open Food Facts pide identificar la app que hace la consulta.
        peticion.setValue("Sazon/1.0 (app personal para iPhone)", forHTTPHeaderField: "User-Agent")

        let resultado: (Data, URLResponse)
        do {
            resultado = try await sesion.data(for: peticion)
        } catch let error as URLError {
            switch error.code {
            case .cancelled: throw CancellationError()
            case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
                throw ErrorOpenFoodFacts.sinInternet
            default:
                // Hay red, pero el servidor tardó o cortó la conexión.
                throw ErrorOpenFoodFacts.lento
            }
        }
        let (datos, respuesta) = resultado
        if let http = respuesta as? HTTPURLResponse {
            if http.statusCode == 404 { throw ErrorOpenFoodFacts.noEncontrado }
            guard (200..<300).contains(http.statusCode) else { throw ErrorOpenFoodFacts.servidor(http.statusCode) }
        }
        return try LectorOpenFoodFacts.producto(desde: datos, codigo: codigo)
    }
}
