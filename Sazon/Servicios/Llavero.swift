import Foundation
import Security

/// Guarda la clave de API de Gemini en el Llavero de iOS (cifrada por el
/// sistema, solo en este iPhone). Nunca se escribe en el JSON de datos, en
/// el respaldo ni en el repositorio.
enum Llavero {
    private static let servicio = "pe.benjamin.sazon.gemini"
    private static let cuenta = "clave-api"

    private static var consultaBase: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta
        ]
    }

    /// Guarda (o reemplaza) la clave. Devuelve false si el sistema la rechazó.
    @discardableResult
    static func guardarClave(_ clave: String) -> Bool {
        let limpia = clave.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpia.isEmpty, let datos = limpia.data(using: .utf8) else { return false }
        SecItemDelete(consultaBase as CFDictionary)
        var nueva = consultaBase
        nueva[kSecValueData as String] = datos
        // Solo disponible con el iPhone desbloqueado y nunca se copia a otro dispositivo.
        nueva[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(nueva as CFDictionary, nil) == errSecSuccess
    }

    static func leerClave() -> String? {
        var consulta = consultaBase
        consulta[kSecReturnData as String] = true
        consulta[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: AnyObject?
        guard SecItemCopyMatching(consulta as CFDictionary, &resultado) == errSecSuccess,
              let datos = resultado as? Data,
              let clave = String(data: datos, encoding: .utf8),
              !clave.isEmpty else { return nil }
        return clave
    }

    static func borrarClave() {
        SecItemDelete(consultaBase as CFDictionary)
    }

    static var hayClave: Bool { leerClave() != nil }

    /// Muestra solo los últimos 4 caracteres: "••••••••abcd".
    static func claveOculta() -> String? {
        guard let clave = leerClave() else { return nil }
        return String(repeating: "•", count: 8) + String(clave.suffix(4))
    }
}
