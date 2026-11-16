import SwiftUI
import UniformTypeIdentifiers

/// Archivo de respaldo (JSON) para exportar e importar todos los datos.
/// No incluye la clave de la IA (esa vive solo en el Llavero).
struct DocumentoRespaldo: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var contenido: Data

    init(contenido: Data) {
        self.contenido = contenido
    }

    init(configuration: ReadConfiguration) throws {
        guard let datos = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        contenido = datos
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: contenido)
    }
}

extension Almacen {
    func exportarRespaldo() -> DocumentoRespaldo? {
        let codificador = DatosApp.codificador
        codificador.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let contenido = try? codificador.encode(datos) else { return nil }
        return DocumentoRespaldo(contenido: contenido)
    }

    var nombreRespaldo: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "Sazon-respaldo-\(f.string(from: Date()))"
    }

    /// Solo acepta archivos que parecen un respaldo de Sazón (con «version»
    /// y «registros») y de tamaño razonable. Cualquier otro JSON se leería
    /// como datos vacíos y borraría todo al restaurarlo. Luego se revisan
    /// los valores (ValidacionRespaldo): nombres de fotos, rangos, largo de
    /// textos, y el aviso de la IA no se importa.
    func leerRespaldo(_ contenido: Data) -> ValidacionRespaldo.Resultado? {
        guard contenido.count <= ValidacionRespaldo.tamanoMaximo,
              let raiz = try? JSONSerialization.jsonObject(with: contenido) as? [String: Any],
              raiz["version"] != nil, raiz["registros"] is [Any],
              let leidos = try? DatosApp.decodificador.decode(DatosApp.self, from: contenido) else { return nil }
        return ValidacionRespaldo.revisar(leidos, conservando: datos)
    }

    func restaurar(_ respaldo: DatosApp) {
        // Si los datos anteriores no se podían abrir, restaurar sí los reemplaza.
        permitirGuardar()
        datos = respaldo
        avisoCarga = nil
        // Un respaldo restaurado se escribe enseguida, sin esperar.
        guardarYa()
    }
}
