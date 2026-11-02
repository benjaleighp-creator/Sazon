import Foundation

/// Tabla del INS que viene dentro de la app (Sazon/Datos/alimentos-ins.json).
/// Funciona sin internet. La generó herramientas/convertir_ins.py.
struct TablaINS {
    let fuente: String
    let alimentos: [AlimentoBase]
    /// Si el archivo no se pudo leer, explica por qué (se muestra en la búsqueda).
    let error: String?

    private let porCodigo: [String: AlimentoBase]

    init(fuente: String, alimentos: [AlimentoBase], error: String?) {
        self.fuente = fuente
        self.alimentos = alimentos
        self.error = error
        var indice: [String: AlimentoBase] = [:]
        for a in alimentos { indice[a.codigo] = a }
        self.porCodigo = indice
    }

    static func cargar(bundle: Bundle = .main) -> TablaINS {
        guard let url = bundle.url(forResource: "alimentos-ins", withExtension: "json") else {
            return TablaINS(fuente: "", alimentos: [], error: "No se encontró la tabla del INS dentro de la app.")
        }
        do {
            let archivo = try ArchivoTabla.leer(Data(contentsOf: url))
            return TablaINS(fuente: archivo.fuente, alimentos: archivo.alimentos, error: nil)
        } catch {
            return TablaINS(fuente: "", alimentos: [], error: "No se pudo leer la tabla del INS: \(error.localizedDescription)")
        }
    }

    func alimento(codigo: String) -> AlimentoBase? { porCodigo[codigo] }

    func buscar(_ texto: String, limite: Int = 40) -> [Coincidencia] {
        Busqueda.buscar(texto, en: alimentos, limite: limite)
    }

    func emparejar(_ nombreIA: String) -> Coincidencia? {
        Busqueda.emparejar(nombreIA, en: alimentos)
    }
}
