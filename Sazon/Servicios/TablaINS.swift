import Foundation

/// Tabla del INS que viene dentro de la app (Sazon/Datos/alimentos-ins.json).
/// Funciona sin internet. La generó herramientas/convertir_ins.py.
/// Se carga en segundo plano al abrir la app (`Almacen`), con los nombres
/// ya normalizados para buscar rápido.
struct TablaINS {
    let fuente: String
    let alimentos: [AlimentoBase]
    /// Si el archivo no se pudo leer, explica por qué (se muestra en la búsqueda).
    let error: String?
    /// False mientras se lee el archivo al abrir la app.
    let cargada: Bool
    /// Nombres normalizados, para buscar sin recalcularlos.
    let indice: IndiceBusqueda

    private let porCodigo: [String: AlimentoBase]

    init(fuente: String, alimentos: [AlimentoBase], error: String?, cargada: Bool = true) {
        self.fuente = fuente
        self.alimentos = alimentos
        self.error = error
        self.cargada = cargada
        self.indice = IndiceBusqueda(alimentos)
        var porCodigo: [String: AlimentoBase] = [:]
        for a in alimentos { porCodigo[a.codigo] = a }
        self.porCodigo = porCodigo
    }

    /// Tabla vacía mientras se carga la de verdad.
    static let cargando = TablaINS(fuente: "", alimentos: [], error: nil, cargada: false)

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

    func emparejar(_ nombreIA: String) -> Coincidencia? {
        Busqueda.emparejar(nombreIA, en: indice)
    }
}
