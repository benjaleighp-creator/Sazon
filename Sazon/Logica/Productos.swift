import Foundation

/// Productos con código de barras que la app recuerda.
enum Productos {

    /// Guarda (o actualiza) el producto de un registro que tiene código de barras.
    /// Así, la próxima vez que lo escanees, se encuentra sin internet.
    static func actualizar(_ productos: [String: ProductoGuardado], con registro: Registro, ahora: Date = Date()) -> [String: ProductoGuardado] {
        guard let bruto = registro.codigoBarras, let codigo = LectorOpenFoodFacts.codigoValido(bruto) else { return productos }
        var copia = productos
        copia[codigo] = ProductoGuardado(
            codigo: codigo,
            nombre: registro.nombre,
            por100g: registro.por100g,
            origen: registro.origen,
            porcion: registro.medida,
            actualizado: ahora
        )
        return copia
    }

    static func buscar(_ codigo: String, en productos: [String: ProductoGuardado]) -> ProductoGuardado? {
        guard let limpio = LectorOpenFoodFacts.codigoValido(codigo) else { return nil }
        return productos[limpio]
    }
}

extension LectorOpenFoodFacts {
    /// Los códigos EAN-13 que empiezan con 2 (prefijos 20 a 29 de GS1) son de
    /// circulación restringida: las tiendas los usan para productos pesados o
    /// etiquetados en el local, así que no están en bases públicas.
    static func esCodigoInterno(_ codigo: String) -> Bool {
        guard let limpio = codigoValido(codigo) else { return false }
        return limpio.count == 13 && limpio.hasPrefix("2")
    }
}
