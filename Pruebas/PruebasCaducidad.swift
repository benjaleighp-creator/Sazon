import XCTest

/// Lectura de la fecha de caducidad de `embedded.mobileprovision`.
final class PruebasCaducidad: XCTestCase {

    /// Imita un perfil real: bytes de firma antes y después del plist.
    private func perfil(plist: String) -> Data {
        var d = Data([0x30, 0x82, 0x0F, 0x3A, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x07, 0x02, 0xA0])
        d.append(Data(plist.utf8))
        d.append(Data([0x00, 0xA0, 0x82, 0x0B, 0x7F, 0x30, 0x82]))
        return d
    }

    private let plistEjemplo = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>AppIDName</key>
        <string>Sazon</string>
        <key>CreationDate</key>
        <date>2026-11-17T19:05:00Z</date>
        <key>Entitlements</key>
        <dict>
            <key>com.apple.security.application-groups</key>
            <array><string>group.pe.benjamin.sazon</string></array>
        </dict>
        <key>ExpirationDate</key>
        <date>2026-11-24T19:05:00Z</date>
        <key>TimeToLive</key>
        <integer>7</integer>
    </dict>
    </plist>
    """

    func testLeeExpirationDate() {
        let fecha = CaducidadFirma.fecha(de: perfil(plist: plistEjemplo))
        XCTAssertEqual(fecha, ISO8601DateFormatter().date(from: "2026-11-24T19:05:00Z"))
    }

    func testSinPlistOSinClaveDevuelveNil() {
        XCTAssertNil(CaducidadFirma.fecha(de: Data()))
        XCTAssertNil(CaducidadFirma.fecha(de: Data([0x30, 0x82, 0x01, 0x02])))
        // Empieza el plist pero no termina.
        XCTAssertNil(CaducidadFirma.fecha(de: Data("<?xml version=\"1.0\"?><plist><dict>".utf8)))
        // Plist válido sin ExpirationDate.
        let sinClave = plistEjemplo.replacingOccurrences(of: "<key>ExpirationDate</key>", with: "<key>Otra</key>")
        XCTAssertNil(CaducidadFirma.fecha(de: perfil(plist: sinClave)))
        // ExpirationDate con otro tipo.
        let malTipo = plistEjemplo.replacingOccurrences(of: "<date>2026-11-24T19:05:00Z</date>", with: "<string>mañana</string>")
        XCTAssertNil(CaducidadFirma.fecha(de: perfil(plist: malTipo)))
    }

    func testAvisoDesdeDosDias() {
        let caduca = fecha(2026, 11, 24, 14, 5)
        XCTAssertFalse(CaducidadFirma.necesitaAviso(caduca: caduca, ahora: fecha(2026, 11, 21, 14, 5)))
        XCTAssertFalse(CaducidadFirma.necesitaAviso(caduca: caduca, ahora: fecha(2026, 11, 22, 14, 4)))
        XCTAssertTrue(CaducidadFirma.necesitaAviso(caduca: caduca, ahora: fecha(2026, 11, 22, 14, 5)))
        XCTAssertTrue(CaducidadFirma.necesitaAviso(caduca: caduca, ahora: fecha(2026, 11, 25)))
    }

    func testTextos() {
        let caduca = fecha(2026, 11, 24, 14, 5)   // martes
        let c = calendarioPrueba
        XCTAssertEqual(CaducidadFirma.diasRestantes(caduca: caduca, ahora: fecha(2026, 11, 17, 20), calendario: c), 7)
        XCTAssertEqual(CaducidadFirma.textoRestante(caduca: caduca, ahora: fecha(2026, 11, 17, 20), calendario: c), "Quedan 7 días")
        XCTAssertEqual(CaducidadFirma.textoRestante(caduca: caduca, ahora: fecha(2026, 11, 23, 9), calendario: c), "Caduca mañana")
        XCTAssertEqual(CaducidadFirma.textoRestante(caduca: caduca, ahora: fecha(2026, 11, 24, 9), calendario: c), "Caduca hoy")
        XCTAssertEqual(CaducidadFirma.textoRestante(caduca: caduca, ahora: fecha(2026, 11, 24, 15), calendario: c), "Ya caducó")
        XCTAssertEqual(CaducidadFirma.textoFecha(caduca: caduca, ahora: fecha(2026, 11, 17, 20), calendario: c),
                       "Caduca el martes, 24 de noviembre a las 14:05")
        XCTAssertEqual(CaducidadFirma.textoFecha(caduca: caduca, ahora: fecha(2026, 11, 23, 9), calendario: c),
                       "Caduca mañana a las 14:05")
    }

    func testMomentoNotificacion() {
        let caduca = fecha(2026, 11, 24, 14, 5)
        XCTAssertEqual(CaducidadFirma.momentoNotificacion(caduca: caduca, ahora: fecha(2026, 11, 20)), fecha(2026, 11, 23, 14, 5))
        XCTAssertNil(CaducidadFirma.momentoNotificacion(caduca: caduca, ahora: fecha(2026, 11, 23, 15)))
    }
}
