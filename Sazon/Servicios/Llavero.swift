import Foundation
import Security

/// De quién es una clave guardada en el Llavero.
enum ProveedorClave: String {
    /// Google Gemini (la principal).
    case gemini
    /// Groq (respaldo opcional).
    case groq

    /// Servicio del Llavero. El de Gemini se mantiene igual que antes para
    /// no perder la clave que ya tenías guardada.
    var servicio: String { "pe.benjamin.sazon." + rawValue }
}

/// Guarda las claves de API (Gemini y, si quieres, Groq) en el Llavero de
/// iOS: cifradas por el sistema, solo disponibles con el iPhone
/// desbloqueado y nunca copiadas a otro dispositivo
/// (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`). Nunca se escriben en el
/// JSON de datos, en el respaldo, en los registros (logs) ni en el repositorio.
enum Llavero {
    private static let cuenta = "clave-api"

    private static func consultaBase(_ p: ProveedorClave) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: p.servicio,
            kSecAttrAccount as String: cuenta
        ]
    }

    /// Guarda (o reemplaza) la clave. Devuelve false si el sistema la rechazó.
    @discardableResult
    static func guardarClave(_ clave: String, de p: ProveedorClave = .gemini) -> Bool {
        let limpia = clave.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpia.isEmpty, let datos = limpia.data(using: .utf8) else { return false }
        SecItemDelete(consultaBase(p) as CFDictionary)
        var nueva = consultaBase(p)
        nueva[kSecValueData as String] = datos
        // Solo disponible con el iPhone desbloqueado y nunca se copia a otro dispositivo.
        nueva[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(nueva as CFDictionary, nil) == errSecSuccess
    }

    static func leerClave(de p: ProveedorClave = .gemini) -> String? {
        var consulta = consultaBase(p)
        consulta[kSecReturnData as String] = true
        consulta[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: AnyObject?
        guard SecItemCopyMatching(consulta as CFDictionary, &resultado) == errSecSuccess,
              let datos = resultado as? Data,
              let clave = String(data: datos, encoding: .utf8),
              !clave.isEmpty else { return nil }
        return clave
    }

    static func borrarClave(de p: ProveedorClave = .gemini) {
        SecItemDelete(consultaBase(p) as CFDictionary)
    }

    static var hayClave: Bool { leerClave() != nil }

    static func hayClave(de p: ProveedorClave) -> Bool { leerClave(de: p) != nil }

    /// Muestra solo los últimos 4 caracteres: "••••••••abcd".
    static func claveOculta(de p: ProveedorClave = .gemini) -> String? {
        guard let clave = leerClave(de: p) else { return nil }
        return String(repeating: "•", count: 8) + String(clave.suffix(4))
    }
}
