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

    func leerRespaldo(_ contenido: Data) -> DatosApp? {
        try? DatosApp.decodificador.decode(DatosApp.self, from: contenido)
    }

    func restaurar(_ respaldo: DatosApp) {
        datos = respaldo
    }
}
