import CryptoKit
import Foundation

/// Memoria local de respuestas de la IA: si analizas la misma foto o el
/// mismo texto en las próximas 24 h, la respuesta sale de aquí, sin red ni
/// cuota. La clave es una huella (SHA-256) del contenido, así el archivo
/// no guarda la foto ni el texto, solo la respuesta. Tiene tope de tamaño.
final class CacheIA {
    static let compartido = CacheIA(url: CacheIA.urlPorDefecto)

    /// Cuánto dura una respuesta guardada.
    static let duracion: TimeInterval = 24 * 3600
    /// Máximo de respuestas y de bytes guardados (se borran las más viejas).
    static let maxEntradas = 80
    static let maxBytes = 1_000_000

    struct Entrada: Codable, Equatable {
        var fecha: Date
        var respuesta: String
        var capa: String
    }

    private let url: URL?
    private let reloj: () -> Date
    private let candado = NSLock()
    private var entradas: [String: Entrada]?

    init(url: URL?, reloj: @escaping () -> Date = Date.init) {
        self.url = url
        self.reloj = reloj
    }

    static var urlPorDefecto: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("respuestas-ia.json")
    }

    // MARK: Claves

    /// Huella de una foto ya reducida (los mismos bytes dan la misma clave).
    static func clave(tarea: String, datos: Data) -> String {
        var h = SHA256()
        h.update(data: Data(tarea.utf8))
        h.update(data: Data([0]))
        h.update(data: datos)
        return h.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Huella de un texto normalizado («2 Panes  con palta» = «2 panes con palta»).
    static func clave(tarea: String, texto: String) -> String {
        let normalizado = texto.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return clave(tarea: tarea, datos: Data(normalizado.utf8))
    }

    // MARK: Leer y guardar

    func leer(_ clave: String) -> Entrada? {
        candado.lock(); defer { candado.unlock() }
        cargarSiHaceFalta()
        guard let e = entradas?[clave] else { return nil }
        guard reloj().timeIntervalSince(e.fecha) < Self.duracion else {
            entradas?[clave] = nil
            return nil
        }
        return e
    }

    func guardar(_ respuesta: String, capa: String, en clave: String) {
        candado.lock(); defer { candado.unlock() }
        cargarSiHaceFalta()
        var lista = entradas ?? [:]
        let ahora = reloj()
        lista = lista.filter { ahora.timeIntervalSince($0.value.fecha) < Self.duracion }
        lista[clave] = Entrada(fecha: ahora, respuesta: respuesta, capa: capa)
        // Tope: se quitan las más viejas hasta caber.
        var ordenadas = lista.sorted { $0.value.fecha > $1.value.fecha }
        while ordenadas.count > Self.maxEntradas ||
                (ordenadas.count > 1 && ordenadas.reduce(0, { $0 + $1.value.respuesta.utf8.count }) > Self.maxBytes) {
            ordenadas.removeLast()
        }
        entradas = Dictionary(uniqueKeysWithValues: ordenadas.map { ($0.key, $0.value) })
        escribir()
    }

    func vaciar() {
        candado.lock(); defer { candado.unlock() }
        entradas = [:]
        if let url { try? FileManager.default.removeItem(at: url) }
    }

    var cantidad: Int {
        candado.lock(); defer { candado.unlock() }
        cargarSiHaceFalta()
        return entradas?.count ?? 0
    }

    private func cargarSiHaceFalta() {
        guard entradas == nil else { return }
        guard let url, let datos = try? Data(contentsOf: url) else { entradas = [:]; return }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        entradas = (try? d.decode([String: Entrada].self, from: datos)) ?? [:]
    }

    private func escribir() {
        guard let url, let entradas else { return }
        let c = JSONEncoder()
        c.dateEncodingStrategy = .iso8601
        guard let datos = try? c.encode(entradas) else { return }
        #if os(iOS)
        try? datos.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try? datos.write(to: url, options: [.atomic])
        #endif
    }
}
