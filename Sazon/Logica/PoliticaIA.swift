import Foundation

/// Reglas de tiempo y de llamadas a la IA (criterios aprobados en la Fase 2).
/// Lógica pura: se prueba sin red.
enum PoliticaIA {
    /// A los 20 s la pantalla ofrece «Buscar en la tabla» y «Agregar a mano»
    /// (sin cancelar la petición).
    static let avisoSalida: TimeInterval = 20
    /// Corte total: a los 30 s se cancela todo, también la petición en curso.
    static let tiempoTotal: TimeInterval = 30
    /// Máximo de llamadas por registro, entre todos los modelos y proveedores.
    static let maxLlamadas = 3
    /// Tiempo máximo de una sola petición (así queda margen para un respaldo).
    static let tiempoPorPeticion: TimeInterval = 18
    /// Espera máxima que se acepta de un `retryDelay` de Google.
    static let esperaMaximaReintento: TimeInterval = 6

    /// Modelos de respaldo de Gemini, en orden (gratuitos según
    /// https://ai.google.dev/gemini-api/docs/pricing, 16-nov-2026).
    static let modelosRespaldo = ["gemini-3.5-flash-lite", "gemini-3.6-flash", "gemini-3.1-flash-lite"]

    /// Modelo de Groq con visión y JSON Schema estricto (en «Preview» según
    /// https://console.groq.com/docs/vision, 16-nov-2026).
    static let modeloGroq = "qwen/qwen3.8-27b"
    static let urlGroq = "https://api.groq.com/openai/v1/chat/completions"

    /// Nombre de modelo aceptable (se escribe en Ajustes o llega en un
    /// respaldo): de 1 a 64 caracteres, solo minúsculas, números, «.» y «-».
    static func nombreModeloValido(_ nombre: String) -> Bool {
        guard (1...64).contains(nombre.count), let primero = nombre.first,
              primero.isASCII, primero.isLetter || primero.isNumber else { return false }
        return nombre.allSatisfy { c in
            c.isASCII && (c.isLowercase || c.isNumber || c == "." || c == "-")
        }
    }

    /// Espera creciente con algo de azar antes del intento `n` (1, 2, …):
    /// 1 s, 2 s, 4 s… (tope 4 s) más hasta 0,5 s al azar, para que muchos
    /// reintentos no lleguen todos a la vez.
    static func espera(intento n: Int, azar: Double = Double.random(in: 0...1)) -> TimeInterval {
        let base = min(pow(2, Double(max(n - 1, 0))), 4)
        return base + min(max(azar, 0), 1) * 0.5
    }

    /// Cadena de modelos de Gemini: el elegido y los de respaldo, sin
    /// repetir y sin los que ya agotaron su cuota de hoy.
    static func cadena(elegido: String, agotados: Set<String>) -> [String] {
        let limpio = elegido.trimmingCharacters(in: .whitespacesAndNewlines)
        var cadena = [limpio.isEmpty ? DatosApp.modeloPorDefecto : limpio]
        for m in modelosRespaldo where !cadena.contains(m) { cadena.append(m) }
        return cadena.filter { !agotados.contains($0) }
    }

    /// Próximo reinicio de la cuota diaria de Gemini: medianoche hora del
    /// Pacífico (https://ai.google.dev/gemini-api/docs/rate-limits).
    static func proximoReinicio(desde ahora: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        let inicio = cal.startOfDay(for: ahora)
        return cal.date(byAdding: .day, value: 1, to: inicio) ?? ahora.addingTimeInterval(86400)
    }
}

/// Cuenta las llamadas y el tiempo de un registro (máximo 3 llamadas y
/// 30 s entre todos los modelos y proveedores).
final class PresupuestoIA {
    private let candado = NSLock()
    private var usadas = 0
    private var reservadas = 0
    let limite: Date
    let maxLlamadas: Int
    private let reloj: () -> Date

    init(maxLlamadas: Int = PoliticaIA.maxLlamadas, segundos: TimeInterval = PoliticaIA.tiempoTotal,
         reloj: @escaping () -> Date = Date.init) {
        self.maxLlamadas = maxLlamadas
        self.reloj = reloj
        self.limite = reloj().addingTimeInterval(segundos)
    }

    var llamadasUsadas: Int {
        candado.lock(); defer { candado.unlock() }
        return usadas
    }

    var restante: TimeInterval { max(0, limite.timeIntervalSince(reloj())) }

    /// Deja `n` llamadas apartadas para el respaldo (Groq): Gemini no las usa.
    func reservarParaRespaldo(_ n: Int) {
        candado.lock(); defer { candado.unlock() }
        reservadas = max(0, min(n, maxLlamadas - 1))
    }

    /// Toma una llamada si quedan llamadas y tiempo (al menos 1 s).
    /// - paraRespaldo: true para usar las llamadas apartadas.
    func tomarLlamada(paraRespaldo: Bool = false) -> Bool {
        candado.lock(); defer { candado.unlock() }
        let tope = paraRespaldo ? maxLlamadas : maxLlamadas - reservadas
        guard usadas < tope, limite.timeIntervalSince(reloj()) >= 1 else { return false }
        usadas += 1
        if paraRespaldo, reservadas > 0 { reservadas -= 1 }
        return true
    }
}

/// Modelos que agotaron su cuota diaria: no se vuelven a llamar hasta el
/// reinicio (medianoche del Pacífico). Se guarda en UserDefaults (solo el
/// nombre del modelo y la hora del reinicio; nada personal).
final class RegistroCuota {
    static let compartido = RegistroCuota()
    private let defaults: UserDefaults
    private let clave = "sazon.ia.cuotaAgotada"
    private let candado = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Modelos agotados en este momento.
    func agotados(ahora: Date = Date()) -> Set<String> {
        candado.lock(); defer { candado.unlock() }
        let guardados = (defaults.dictionary(forKey: clave) as? [String: Double]) ?? [:]
        return Set(guardados.filter { $0.value > ahora.timeIntervalSince1970 }.keys)
    }

    func marcarAgotado(_ modelo: String, ahora: Date = Date()) {
        candado.lock(); defer { candado.unlock() }
        var guardados = (defaults.dictionary(forKey: clave) as? [String: Double]) ?? [:]
        guardados = guardados.filter { $0.value > ahora.timeIntervalSince1970 }
        guardados[modelo] = PoliticaIA.proximoReinicio(desde: ahora).timeIntervalSince1970
        defaults.set(guardados, forKey: clave)
    }

    func limpiar() {
        candado.lock(); defer { candado.unlock() }
        defaults.removeObject(forKey: clave)
    }
}
