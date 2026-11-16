import Foundation
import Network
import Observation

/// Cola sin conexión: fotos y textos que guardaste sin internet se
/// analizan solos cuando vuelve la red (con la app abierta). Cada uno usa
/// el mismo tope que un registro normal (3 llamadas y 30 s), se analizan de
/// uno en uno y se para si se acaba la cuota o falta la clave. El resultado
/// queda «listo para revisar»: nada se guarda en el diario sin que lo confirmes.
@MainActor
@Observable
final class ColaIA {
    static let compartida = ColaIA()

    /// True mientras se analiza un pendiente.
    private(set) var procesando = false
    /// Máximo de pendientes por vuelta (para no gastar toda la cuota de golpe).
    static let maximoPorVuelta = 5

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private var hayRed = true
    @ObservationIgnored private var iniciado = false

    static var carpeta: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let carpeta = base.appendingPathComponent("cola-ia", isDirectory: true)
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        return carpeta
    }

    /// Empieza a escuchar la red: al volver internet, procesa la cola.
    func iniciar(_ almacen: Almacen) {
        guard !iniciado else { return }
        iniciado = true
        monitor.pathUpdateHandler = { [weak self] ruta in
            let conectado = ruta.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                let volvio = conectado && !self.hayRed
                self.hayRed = conectado
                if volvio { self.procesar(almacen) }
            }
        }
        monitor.start(queue: DispatchQueue(label: "pe.benjamin.sazon.red"))
    }

    // MARK: Guardar

    /// Guarda una foto (ya reducida) o un texto para analizarlo después.
    func guardar(foto: Data?, texto: String, comida: TipoComida, en almacen: Almacen) -> Bool {
        var p = PendienteIA(comida: comida, tipo: foto == nil ? .texto : .foto, texto: texto)
        if let foto {
            let nombre = "\(p.id.uuidString).jpg"
            do {
                try foto.write(to: Self.carpeta.appendingPathComponent(nombre), options: [.atomic, .completeFileProtection])
            } catch {
                return false
            }
            p.archivoFoto = nombre
        }
        almacen.datos.colaIA.append(p)
        return true
    }

    func quitar(_ p: PendienteIA, de almacen: Almacen) {
        if let archivo = p.archivoFoto, Self.esNombreSeguro(archivo) {
            try? FileManager.default.removeItem(at: Self.carpeta.appendingPathComponent(archivo))
        }
        almacen.datos.colaIA.removeAll { $0.id == p.id }
    }

    func reintentar(_ p: PendienteIA, en almacen: Almacen) {
        actualizar(p.id, en: almacen) { $0.estado = .esperando; $0.error = nil }
        procesar(almacen)
    }

    /// Solo un nombre de archivo, sin carpetas (por si un respaldo trae algo raro).
    static func esNombreSeguro(_ nombre: String) -> Bool {
        ValidacionRespaldo.esNombreArchivoSeguro(nombre)
    }

    // MARK: Procesar

    /// Analiza los pendientes que esperan internet, de uno en uno.
    func procesar(_ almacen: Almacen) {
        guard !procesando, hayRed, almacen.datos.colaIA.contains(where: { $0.estado == .esperando }) else { return }
        procesando = true
        Task { @MainActor in
            defer { procesando = false }
            var hechos = 0
            while hechos < Self.maximoPorVuelta,
                  let p = almacen.datos.colaIA.first(where: { $0.estado == .esperando }) {
                hechos += 1
                let seguir = await analizar(p, en: almacen)
                if !seguir { break }
            }
        }
    }

    /// Devuelve false si conviene parar la vuelta (sin red, sin cuota, sin clave…).
    private func analizar(_ p: PendienteIA, en almacen: Almacen) async -> Bool {
        do {
            let proveedor = try ServicioIA.proveedorActual(almacen.datos)
            let resultado: AnalisisIA
            switch p.tipo {
            case .texto:
                resultado = try await proveedor.analizar(texto: p.texto)
            case .foto:
                guard let archivo = p.archivoFoto, Self.esNombreSeguro(archivo),
                      let datos = try? Data(contentsOf: Self.carpeta.appendingPathComponent(archivo)) else {
                    actualizar(p.id, en: almacen) { $0.estado = .fallo; $0.error = "No se encontró la foto guardada." }
                    return true
                }
                resultado = try await proveedor.analizar(fotoJPEG: datos)
            }
            actualizar(p.id, en: almacen) {
                $0.estado = .listo
                $0.respuesta = LectorIA.json(de: resultado)
                $0.capa = resultado.capa?.clave
                $0.intentos += 1
            }
            return true
        } catch let e as ErrorIA {
            switch e {
            case .sinInternet, .conexionLenta, .tiempoAgotado, .servidor:
                // Se queda esperando: se intenta en la próxima vuelta.
                actualizar(p.id, en: almacen) { $0.intentos += 1 }
                return false
            case .limiteAlcanzado, .cuotaDiariaAgotada, .sinClave, .avisoNoAceptado, .claveInvalida, .claveGroqInvalida:
                return false
            default:
                actualizar(p.id, en: almacen) { $0.estado = .fallo; $0.error = e.titulo + ". " + e.mensaje; $0.intentos += 1 }
                return true
            }
        } catch {
            return false
        }
    }

    private func actualizar(_ id: UUID, en almacen: Almacen, _ cambio: (inout PendienteIA) -> Void) {
        guard let i = almacen.datos.colaIA.firstIndex(where: { $0.id == id }) else { return }
        var p = almacen.datos.colaIA[i]
        cambio(&p)
        almacen.datos.colaIA[i] = p
    }
}
