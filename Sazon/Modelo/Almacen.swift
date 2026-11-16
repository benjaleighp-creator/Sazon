import Foundation
import Observation

/// Fuente única de verdad de la app. Guarda todo en un archivo JSON local
/// (sin servidores ni cuentas). La clave de la IA NO va aquí: va en el Llavero.
@MainActor
@Observable
final class Almacen {

    static let compartido = Almacen()

    /// Cada cambio se guarda en disco automáticamente: se espera
    /// `Almacen.esperaGuardado` desde el último cambio (así escribir un
    /// nombre letra por letra no reescribe el archivo con cada letra) y se
    /// escribe fuera del hilo principal. Al pasar a segundo plano se guarda
    /// enseguida (`guardarYa`), para no perder nada si iOS cierra la app.
    var datos: DatosApp {
        didSet {
            EstiloActivo.actual = tema.estilo
            hayCambiosSinGuardar = true
            programarGuardado()
        }
    }

    /// Día que muestra el diario (las flechas lo cambian).
    var diaVisible: Date = Calendar.current.startOfDay(for: Date())

    /// Tabla del INS (se carga una vez desde el archivo de la app).
    let tabla: TablaINS

    /// Último error al guardar (se muestra en Ajustes si ocurre).
    var errorGuardado: String?

    /// Problema al abrir los datos guardados (se muestra en Ajustes).
    var avisoCarga: String?

    /// True si el archivo de datos existe pero no se pudo leer (por ejemplo,
    /// con el iPhone bloqueado). Mientras sea true no se escribe encima,
    /// para no reemplazar tus datos por unos vacíos.
    private var protegerArchivo = false

    /// Segundos que se espera desde el último cambio antes de guardar.
    static let esperaGuardado: TimeInterval = 0.7
    @ObservationIgnored private var hayCambiosSinGuardar = false
    @ObservationIgnored private var tareaGuardado: Task<Void, Never>?
    /// Cola de escritura: una sola, en orden, para que la última versión
    /// de los datos siempre sea la que queda en disco.
    private static let colaDisco = DispatchQueue(label: "pe.benjamin.sazon.guardado", qos: .utility)

    /// Calorías activas de hoy según Apple Salud (0 si no está conectado).
    var actividadSalud: Double = 0
    /// Pasos de hoy según Apple Salud.
    var pasosSalud: Double = 0

    private static let nombreArchivo = "datos-sazon.json"

    private init() {
        self.tabla = TablaINS.cargar()
        let carga = Almacen.cargarDesdeDisco()
        self.datos = carga.datos ?? DatosApp()
        self.avisoCarga = carga.aviso
        self.protegerArchivo = carga.proteger
        EstiloActivo.actual = CatalogoTemas.tema(id: datos.temaID).estilo
    }

    // MARK: - Lectura rápida

    var tema: Tema { CatalogoTemas.tema(id: datos.temaID) }

    var meta: Nutrientes? { CalculoMeta.metaVigente(datos, actividadSalud: actividadSalud) }

    var resumenVisible: ResumenDia { Diario.resumen(de: diaVisible, en: datos.registros) }

    var esHoy: Bool { Calendar.current.isDateInToday(diaVisible) }

    // MARK: - Diario

    func agregar(_ nuevos: [Registro]) {
        guard !nuevos.isEmpty else { return }
        var d = datos
        d.registros.append(contentsOf: nuevos)
        for r in nuevos {
            d.recientes = Diario.actualizarRecientes(d.recientes, con: r)
            d.productos = Productos.actualizar(d.productos, con: r)
        }
        datos = d
    }

    func actualizar(_ registro: Registro) {
        guard let i = datos.registros.firstIndex(where: { $0.id == registro.id }) else { return }
        var d = datos
        d.registros[i] = registro
        d.productos = Productos.actualizar(d.productos, con: registro)
        datos = d
    }

    func eliminar(_ registro: Registro) {
        datos.registros.removeAll { $0.id == registro.id }
    }

    /// Copia un registro anterior al día visible (acceso rápido "Recientes").
    func repetir(_ registro: Registro, en comida: TipoComida) {
        var copia = registro
        copia.id = UUID()
        copia.fecha = Diario.fechaParaRegistrar(enDia: diaVisible)
        copia.comida = comida
        agregar([copia])
    }

    func moverDia(_ dias: Int) {
        diaVisible = Diario.moverDia(diaVisible, dias: dias)
    }

    func irAHoy() {
        diaVisible = Calendar.current.startOfDay(for: Date())
    }

    /// Comida sugerida para registrar ahora.
    var comidaSugerida: TipoComida {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return TipoComida.sugerida(minutoDelDia: (c.hour ?? 12) * 60 + (c.minute ?? 0), extra: datos.comidasExtra)
    }

    // MARK: - Disco

    private static var urlArchivo: URL {
        let carpeta = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return carpeta.appendingPathComponent(nombreArchivo)
    }

    /// Lee los datos. Si el archivo existe pero no se puede leer, no se
    /// pierde: o se protege (no se escribe encima) o se guarda una copia.
    private static func cargarDesdeDisco() -> (datos: DatosApp?, aviso: String?, proteger: Bool) {
        let url = urlArchivo
        guard FileManager.default.fileExists(atPath: url.path) else { return (nil, nil, false) }
        let contenido: Data
        do {
            contenido = try Data(contentsOf: url)
        } catch {
            return (nil, "No se pudieron abrir tus datos guardados (\(error.localizedDescription)). Cierra Sazón por completo y vuelve a abrirla con el iPhone desbloqueado; mientras tanto no se guarda nada para no borrar lo que tenías.", true)
        }
        do {
            return (try DatosApp.decodificador.decode(DatosApp.self, from: contenido), nil, false)
        } catch {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd-HHmmss"
            let copia = url.deletingLastPathComponent().appendingPathComponent("datos-sazon-no-leidos-\(f.string(from: Date())).json")
            if (try? FileManager.default.copyItem(at: url, to: copia)) != nil {
                return (nil, "Tus datos guardados no se pudieron leer y la app empezó en blanco. El archivo original quedó copiado como «\(copia.lastPathComponent)». Si tienes un respaldo, impórtalo en Ajustes › Respaldo.", false)
            }
            return (nil, "Tus datos guardados no se pudieron leer y no se pudo hacer una copia; para no perderlos, no se guarda nada nuevo. Si tienes un respaldo, impórtalo en Ajustes › Respaldo.", true)
        }
    }

    /// Lo usa la restauración de un respaldo: ahí sí se quiere escribir encima.
    func permitirGuardar() {
        protegerArchivo = false
    }

    /// Programa el guardado (y el aviso a los widgets) para dentro de
    /// `esperaGuardado`; un cambio nuevo reinicia la espera.
    private func programarGuardado() {
        tareaGuardado?.cancel()
        tareaGuardado = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Almacen.esperaGuardado * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.guardarYa()
        }
    }

    /// Guarda ahora lo pendiente y avisa a los widgets una sola vez.
    /// - esperar: true al pasar a segundo plano: espera a que el archivo
    ///   quede escrito antes de devolver el control a iOS.
    func guardarYa(esperar: Bool = false) {
        tareaGuardado?.cancel()
        tareaGuardado = nil
        guard hayCambiosSinGuardar else { return }
        hayCambiosSinGuardar = false
        avisarCambios()
        guard !protegerArchivo else {
            errorGuardado = "No se guardó el último cambio para no reemplazar tus datos anteriores, que no se pudieron abrir."
            return
        }
        // Copia de los datos (es un valor): se codifica fuera del hilo principal.
        let copia = datos
        let url = Self.urlArchivo
        let trabajo = { [weak self] in
            var problema: String?
            do {
                let contenido = try DatosApp.codificador.encode(copia)
                try contenido.write(to: url, options: [.atomic, .completeFileProtection])
            } catch {
                problema = "No se pudo guardar: \(error.localizedDescription)"
            }
            Task { @MainActor in
                if self?.errorGuardado != problema { self?.errorGuardado = problema }
            }
        }
        if esperar {
            Self.colaDisco.sync(execute: trabajo)
        } else {
            Self.colaDisco.async(execute: trabajo)
        }
    }
}

extension DatosApp {
    static var codificador: JSONEncoder {
        let c = JSONEncoder()
        c.dateEncodingStrategy = .iso8601
        c.outputFormatting = [.sortedKeys]
        return c
    }

    static var decodificador: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
