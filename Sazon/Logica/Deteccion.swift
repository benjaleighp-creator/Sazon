import Foundation

// Lógica de la animación de detección (sin interfaz, con pruebas).
// Gemini puede devolver cajas «box_2d» en orden [ymin, xmin, ymax, xmax]
// normalizadas de 0 a 1000 (documentación oficial de comprensión de imágenes).
// Aquí se validan y se convierten a coordenadas de 0 a 1 de la foto.

/// Caja de un alimento en la foto, normalizada de 0 a 1.
struct CajaFoto: Equatable {
    let xmin: Double
    let ymin: Double
    let xmax: Double
    let ymax: Double

    var centro: (x: Double, y: Double) { ((xmin + xmax) / 2, (ymin + ymax) / 2) }
    var ancho: Double { xmax - xmin }
    var alto: Double { ymax - ymin }

    /// Lee [ymin, xmin, ymax, xmax] de 0 a 1000. nil si no es una caja válida
    /// (no se inventan posiciones).
    static func desdeGemini(_ valor: Any?) -> CajaFoto? {
        guard let lista = valor as? [Any], lista.count == 4 else { return nil }
        let n = lista.compactMap { LectorIA.numero($0) }
        guard n.count == 4, n.allSatisfy({ (0...1000).contains($0) }) else { return nil }
        let (ymin, xmin, ymax, xmax) = (n[0], n[1], n[2], n[3])
        // Cajas vacías o de menos de 1 % del lado no sirven para ubicar nada.
        guard ymax - ymin >= 10, xmax - xmin >= 10 else { return nil }
        return CajaFoto(xmin: xmin / 1000, ymin: ymin / 1000, xmax: xmax / 1000, ymax: ymax / 1000)
    }
}

enum Deteccion {
    /// Cantidad de puntos según el ahorro de batería.
    static func cantidadPuntos(ahorro: Bool) -> Int { ahorro ? 10 : 28 }

    /// Tiempo entre una etiqueta y la siguiente: la revelación completa dura
    /// como máximo 1,2 s para no alargar la espera.
    static func intervaloEtiquetas(_ n: Int) -> Double {
        guard n > 0 else { return 0 }
        return min(0.32, 1.2 / Double(n))
    }

    /// Número pseudoaleatorio estable de 0 a 1 para el punto i (semilla k).
    static func azar(_ i: Int, _ k: Int) -> Double {
        var z = UInt64(truncatingIfNeeded: i &* 7919 &+ k &* 104_729 &+ 12_345)
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return Double(z % 10_000) / 10_000
    }

    /// Posición del punto i mientras la IA analiza (se mueve suave por la foto).
    static func deambular(_ i: Int, t: Double) -> (x: Double, y: Double) {
        let a = 0.25 + azar(i, 1) * 0.5
        let b = 0.25 + azar(i, 2) * 0.5
        let fx = azar(i, 3) * 6.283
        let fy = azar(i, 4) * 6.283
        let rx = 0.18 + azar(i, 5) * 0.27
        let ry = 0.18 + azar(i, 6) * 0.27
        return (0.5 + rx * sin(a * t + fx), 0.5 + ry * cos(b * t + fy))
    }

    /// Punto de destino del punto i cuando llegan los resultados: el centro de
    /// la caja del alimento que le toca (o el centro de la foto si no hay caja),
    /// con una pequeña separación para que se vea un grupo.
    static func destino(_ i: Int, cajas: [CajaFoto?]) -> (x: Double, y: Double) {
        guard !cajas.isEmpty else { return (0.5, 0.5) }
        let caja = cajas[i % cajas.count]
        let angulo = azar(i, 7) * 6.283
        if let caja {
            let r = 0.25 * min(caja.ancho, caja.alto) * azar(i, 8)
            return (caja.centro.x + r * cos(angulo), caja.centro.y + r * sin(angulo))
        }
        let r = 0.06 * azar(i, 8)
        return (0.5 + r * cos(angulo), 0.5 + r * sin(angulo))
    }

    /// Avance suave (0 a 1) de la reunión de los puntos.
    static func suavizar(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Posición durante la reunión: del punto donde estaba al destino.
    static func reunir(_ i: Int, desde t0: Double, avance: Double, cajas: [CajaFoto?]) -> (x: Double, y: Double) {
        let a = deambular(i, t: t0)
        let b = destino(i, cajas: cajas)
        let k = suavizar(avance)
        return (a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k)
    }
}
