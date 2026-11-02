import Foundation
import Observation

/// Fuente única de verdad de la app. Guarda todo en un archivo JSON local
/// (sin servidores ni cuentas). La clave de la IA NO va aquí: va en el Llavero.
@MainActor
@Observable
final class Almacen {

    static let compartido = Almacen()

    /// Cada cambio se guarda en disco automáticamente.
    var datos: DatosApp {
        didSet {
            guardar()
            EstiloActivo.actual = tema.estilo
        }
    }

    /// Día que muestra el diario (las flechas lo cambian).
    var diaVisible: Date = Calendar.current.startOfDay(for: Date())

    /// Tabla del INS (se carga una vez desde el archivo de la app).
    let tabla: TablaINS

    /// Último error al guardar (se muestra en Ajustes si ocurre).
    var errorGuardado: String?

    private static let nombreArchivo = "datos-sazon.json"

    private init() {
        self.tabla = TablaINS.cargar()
        self.datos = Almacen.cargarDesdeDisco() ?? DatosApp()
        EstiloActivo.actual = CatalogoTemas.tema(id: datos.temaID).estilo
    }

    // MARK: - Lectura rápida

    var tema: Tema { CatalogoTemas.tema(id: datos.temaID) }

    var meta: Nutrientes? { CalculoMeta.metaVigente(datos) }

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
        return TipoComida.sugerida(minutoDelDia: (c.hour ?? 12) * 60 + (c.minute ?? 0))
    }

    // MARK: - Disco

    private static var urlArchivo: URL {
        let carpeta = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return carpeta.appendingPathComponent(nombreArchivo)
    }

    private static func cargarDesdeDisco() -> DatosApp? {
        guard let contenido = try? Data(contentsOf: urlArchivo) else { return nil }
        return try? DatosApp.decodificador.decode(DatosApp.self, from: contenido)
    }

    private func guardar() {
        do {
            let contenido = try DatosApp.codificador.encode(datos)
            try contenido.write(to: Self.urlArchivo, options: [.atomic, .completeFileProtection])
            errorGuardado = nil
        } catch {
            errorGuardado = "No se pudo guardar: \(error.localizedDescription)"
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
