import Foundation

/// Calendario fijo para que las pruebas den lo mismo en cualquier máquina.
let calendarioPrueba: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/Lima")!
    c.locale = Locale(identifier: "es_PE")
    return c
}()

/// Fecha en hora de Lima: fecha(2026, 11, 1, 8, 30).
func fecha(_ anio: Int, _ mes: Int, _ dia: Int, _ hora: Int = 12, _ minuto: Int = 0) -> Date {
    calendarioPrueba.date(from: DateComponents(year: anio, month: mes, day: dia, hour: hora, minute: minuto))!
}

func registro(_ nombre: String, gramos: Double, kcal100: Double, p: Double = 0, c: Double = 0, g: Double = 0,
              comida: TipoComida = .almuerzo, en momento: Date, origen: OrigenDato = .ins) -> Registro {
    Registro(fecha: momento, comida: comida, nombre: nombre, gramos: gramos,
             por100g: Nutrientes(kcal: kcal100, proteina: p, carbohidratos: c, grasas: g), origen: origen)
}

/// Tabla pequeña de ejemplo (valores ficticios, solo para probar la búsqueda).
let tablaPrueba: [AlimentoBase] = [
    AlimentoBase(codigo: "A1", nombre: "Pan francés", grupo: "Cereales", por100g: Nutrientes(kcal: 280, proteina: 8, carbohidratos: 57, grasas: 2)),
    AlimentoBase(codigo: "A2", nombre: "Pan de molde integral", grupo: "Cereales", por100g: Nutrientes(kcal: 250, proteina: 9, carbohidratos: 45, grasas: 4)),
    AlimentoBase(codigo: "B1", nombre: "Palta", grupo: "Frutas", por100g: Nutrientes(kcal: 160, proteina: 2, carbohidratos: 9, grasas: 15)),
    AlimentoBase(codigo: "C1", nombre: "Arroz blanco cocido", grupo: "Cereales", por100g: Nutrientes(kcal: 130, proteina: 2.5, carbohidratos: 28, grasas: 0.3)),
    AlimentoBase(codigo: "D1", nombre: "Huevo de gallina entero", grupo: "Huevos", por100g: Nutrientes(kcal: 150, proteina: 12.5, carbohidratos: 1, grasas: 10)),
    AlimentoBase(codigo: "E1", nombre: "Tomate", grupo: "Verduras", por100g: Nutrientes(kcal: 20, proteina: 1, carbohidratos: 4, grasas: 0.2)),
    AlimentoBase(codigo: "F1", nombre: "Frijol canario cocido", grupo: "Leguminosas", por100g: Nutrientes(kcal: 120, proteina: 8, carbohidratos: 21, grasas: 0.5))
]
