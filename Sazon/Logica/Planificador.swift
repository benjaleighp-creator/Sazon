import Foundation

// MARK: - Recetas

enum Recetas {
    static func total(_ r: Receta) -> Nutrientes {
        r.ingredientes.reduce(Nutrientes.cero) { $0 + $1.total }
    }

    /// Peso de la receta terminada: el que pesaste o la suma de ingredientes.
    static func pesoTotal(_ r: Receta) -> Double {
        if let p = r.pesoFinal, p > 0 { return p }
        return r.ingredientes.reduce(0) { $0 + $1.gramos }
    }

    static func por100g(_ r: Receta) -> Nutrientes {
        let peso = pesoTotal(r)
        guard peso > 0 else { return .cero }
        return total(r) * (100 / peso)
    }

    static func gramosPorPorcion(_ r: Receta) -> Double {
        let porciones = max(r.porciones, 1)
        return pesoTotal(r) / porciones
    }

    static func porPorcion(_ r: Receta) -> Nutrientes {
        total(r) * (1 / max(r.porciones, 1))
    }
}

// MARK: - Generador de números (repetible)

/// SplitMix64: siempre da la misma secuencia con la misma semilla
/// (así el plan de un día no cambia solo al abrir la app).
struct Aleatorio {
    private var estado: UInt64

    init(semilla: UInt64) { estado = semilla &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func siguiente() -> UInt64 {
        estado = estado &+ 0x9E37_79B9_7F4A_7C15
        var z = estado
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func elegir<T>(_ lista: [T]) -> T? {
        guard !lista.isEmpty else { return nil }
        return lista[Int(siguiente() % UInt64(lista.count))]
    }
}

// MARK: - Plan de comidas

/// Un alimento o plato que el planificador puede proponer.
struct OpcionPlan: Equatable {
    let nombre: String
    let por100g: Nutrientes
    let origen: OrigenDato
    let codigoINS: String?
    let recetaID: UUID?
}

/// Opciones para cada parte de cada comida.
struct OpcionesPlan: Equatable {
    var desayunoPrincipal: [OpcionPlan] = []
    var desayunoComplemento: [OpcionPlan] = []
    var almuerzo: [OpcionPlan] = []
    var cena: [OpcionPlan] = []
    var snacks: [OpcionPlan] = []
}

struct ElementoCompra: Identifiable, Equatable {
    /// Nombre normalizado (para marcarlo como comprado).
    let clave: String
    let nombre: String
    let gramos: Double
    let grupo: String
    var id: String { clave }
}

enum Planificador {

    static func opcion(_ a: AlimentoBase) -> OpcionPlan {
        OpcionPlan(nombre: a.nombre, por100g: a.por100g, origen: .ins, codigoINS: a.codigo, recetaID: nil)
    }

    static func opcion(_ r: Receta) -> OpcionPlan {
        OpcionPlan(nombre: r.nombre, por100g: Recetas.por100g(r), origen: .manual, codigoINS: nil, recetaID: r.id)
    }

    /// Palabras que indican que algo no está listo para comer (crudo, harina…)
    /// o no es buena opción de plan (jugos envasados, conservas…).
    static let excluir = ["crud", "harina", "polvo", "deshidrat", "seco", "envasad", "conserva", "nectar",
                          "jugo", "mermelada", "almibar", "concentrad", "sangre", "cascara", "grano"]

    static func apto(_ nombre: String) -> Bool {
        let n = Busqueda.normalizar(nombre)
        return !excluir.contains { n.contains($0) }
    }

    /// Arma las opciones desde la tabla del INS y tus recetas, filtradas por tipo de dieta.
    static func opciones(tabla: [AlimentoBase], recetas: [Receta], dieta: TipoDieta) -> OpcionesPlan {
        func grupo(_ prefijo: String) -> [AlimentoBase] { tabla.filter { $0.codigo.hasPrefix(prefijo) } }
        func nombre(_ a: AlimentoBase, empiezaCon palabras: [String]) -> Bool {
            let n = Busqueda.normalizar(a.nombre)
            return palabras.contains { n.hasPrefix($0) }
        }
        var o = OpcionesPlan()
        let panes = tabla.filter { $0.codigo.hasPrefix("A") && nombre($0, empiezaCon: ["pan ", "avena"]) && !Busqueda.normalizar($0.nombre).contains("crud") }
        o.desayunoPrincipal = (panes + grupo("SB")).map(opcion)
        let huevos = grupo("J").filter { Busqueda.normalizar($0.nombre).contains("huevo") && apto($0.nombre) }
        let lacteos = grupo("G").filter { nombre($0, empiezaCon: ["leche", "yogur", "queso"]) && apto($0.nombre) }
        o.desayunoComplemento = (huevos + lacteos).map(opcion)
        let segundos = grupo("SS").map(opcion)
        let entradas = grupo("SE").map(opcion)
        let propias = recetas.filter { !$0.ingredientes.isEmpty }.map(opcion)
        o.almuerzo = segundos + propias
        o.cena = segundos + entradas + propias
        let frutas = grupo("C").filter { apto($0.nombre) }
        let frutosSecos = grupo("D").filter { nombre($0, empiezaCon: ["mani", "almendra", "nuez", "castana", "pecana"]) }
        o.snacks = (frutas + frutosSecos).map(opcion)

        // Filtro por dieta (si deja una lista vacía, se usa la lista completa).
        func filtrar(_ lista: [OpcionPlan]) -> [OpcionPlan] {
            let filtrada = lista.filter { encajaEnDieta($0.por100g, dieta) && $0.por100g.kcal > 0 }
            return filtrada.isEmpty ? lista.filter { $0.por100g.kcal > 0 } : filtrada
        }
        o.desayunoPrincipal = filtrar(o.desayunoPrincipal)
        o.desayunoComplemento = filtrar(o.desayunoComplemento)
        o.almuerzo = filtrar(o.almuerzo)
        o.cena = filtrar(o.cena)
        o.snacks = filtrar(o.snacks)
        return o
    }

    static func encajaEnDieta(_ n: Nutrientes, _ dieta: TipoDieta) -> Bool {
        guard n.kcal > 0 else { return false }
        let carbos = n.carbohidratos * 4 / n.kcal
        let grasas = n.grasas * 9 / n.kcal
        let proteina = n.proteina * 4 / n.kcal
        switch dieta {
        case .equilibrada: return true
        case .altaProteina: return proteina >= 0.15
        case .bajaCarbohidratos: return carbos <= 0.35
        case .keto: return carbos <= 0.12
        case .bajaGrasa: return grasas <= 0.30
        }
    }

    /// Gramos para llegar a unas calorías, redondeados a 5 g y dentro de un rango.
    static func gramos(paraKcal kcal: Double, con por100g: Nutrientes, rango: ClosedRange<Double>) -> Double {
        guard por100g.kcal > 0 else { return rango.lowerBound }
        let bruto = kcal / por100g.kcal * 100
        let acotado = min(max(bruto, rango.lowerBound), rango.upperBound)
        return (acotado / 5).rounded() * 5
    }

    /// Semilla repetible para un día (más un número para "otra propuesta").
    static func semilla(dia: Date, variante: Int, calendario: Calendar = .current) -> UInt64 {
        let dias = Int(calendario.startOfDay(for: dia).timeIntervalSince1970 / 86400)
        return UInt64(bitPattern: Int64(dias &* 31 &+ variante &* 7919))
    }

    /// Propone un día completo según la meta. Desayuno: principal + complemento
    /// (30 % de sus calorías); almuerzo y cena: un plato; snacks: una opción.
    static func generarDia(_ dia: Date, meta: Nutrientes, opciones o: OpcionesPlan, variante: Int = 0,
                           calendario: Calendar = .current) -> PlanDia {
        var rng = Aleatorio(semilla: semilla(dia: dia, variante: variante, calendario: calendario))
        var items: [ItemPlan] = []
        func agregar(_ op: OpcionPlan?, _ comida: TipoComida, kcal: Double, rango: ClosedRange<Double>) {
            guard let op else { return }
            items.append(ItemPlan(comida: comida, nombre: op.nombre,
                                  gramos: gramos(paraKcal: kcal, con: op.por100g, rango: rango),
                                  por100g: op.por100g, origen: op.origen, codigoINS: op.codigoINS, recetaID: op.recetaID))
        }
        let kDesayuno = meta.kcal * TipoComida.desayuno.parteDelDia
        let complemento = rng.elegir(o.desayunoComplemento)
        agregar(rng.elegir(o.desayunoPrincipal), .desayuno, kcal: kDesayuno * (complemento == nil ? 1 : 0.7), rango: 40...400)
        agregar(complemento, .desayuno, kcal: kDesayuno * 0.3, rango: 30...300)
        agregar(rng.elegir(o.almuerzo), .almuerzo, kcal: meta.kcal * TipoComida.almuerzo.parteDelDia, rango: 150...700)
        agregar(rng.elegir(o.cena), .cena, kcal: meta.kcal * TipoComida.cena.parteDelDia, rango: 150...600)
        agregar(rng.elegir(o.snacks), .snacks, kcal: meta.kcal * TipoComida.snacks.parteDelDia, rango: 30...350)
        return PlanDia(dia: calendario.startOfDay(for: dia), items: items)
    }

    static func total(_ plan: PlanDia) -> Nutrientes {
        plan.items.reduce(Nutrientes.cero) { $0 + $1.total }
    }

    /// Ajusta las porciones de lo que aún no comes para acercarte a la meta
    /// según lo ya registrado (entre la mitad y 1,5 veces lo planeado).
    static func ajustarPorciones(_ plan: PlanDia, consumidoKcal: Double, meta: Nutrientes) -> PlanDia {
        let pendientes = plan.items.filter { !$0.hecho }
        let kcalPendientes = pendientes.reduce(0) { $0 + $1.total.kcal }
        guard kcalPendientes > 0 else { return plan }
        let restante = meta.kcal - consumidoKcal
        let factor = min(max(restante / kcalPendientes, 0.5), 1.5)
        guard abs(factor - 1) >= 0.05 else { return plan }
        var nuevo = plan
        for i in nuevo.items.indices where !nuevo.items[i].hecho {
            nuevo.items[i].gramos = max(5, (nuevo.items[i].gramos * factor / 5).rounded() * 5)
        }
        return nuevo
    }

    /// Lista de compras de varios días: suma por alimento y abre las recetas
    /// en sus ingredientes.
    static func listaCompras(_ planes: [PlanDia], recetas: [Receta]) -> [ElementoCompra] {
        var suma: [String: (nombre: String, gramos: Double, grupo: String)] = [:]
        func agregar(_ nombre: String, _ gramos: Double, _ codigo: String?) {
            let clave = Busqueda.normalizar(nombre)
            let grupo = codigo.map { grupoCompra($0) } ?? "Otros"
            let previo = suma[clave]
            suma[clave] = (previo?.nombre ?? nombre, (previo?.gramos ?? 0) + gramos, previo?.grupo ?? grupo)
        }
        for plan in planes {
            for item in plan.items {
                if let id = item.recetaID, let receta = recetas.first(where: { $0.id == id }) {
                    let peso = Recetas.pesoTotal(receta)
                    guard peso > 0 else { continue }
                    let factor = item.gramos / peso
                    for ing in receta.ingredientes { agregar(ing.nombre, ing.gramos * factor, ing.codigoINS) }
                } else {
                    agregar(item.nombre, item.gramos, item.codigoINS)
                }
            }
        }
        return suma.map { ElementoCompra(clave: $0.key, nombre: $0.value.nombre, gramos: $0.value.gramos, grupo: $0.value.grupo) }
            .sorted { ($0.grupo, $0.nombre) < ($1.grupo, $1.nombre) }
    }

    /// Sección del mercado según el código del INS.
    static func grupoCompra(_ codigo: String) -> String {
        if codigo.hasPrefix("S") { return "Platos preparados" }
        switch codigo.first {
        case "A": return "Cereales y panadería"
        case "B": return "Verduras"
        case "C": return "Frutas"
        case "D": return "Aceites y frutos secos"
        case "E": return "Pescados y mariscos"
        case "F": return "Carnes"
        case "G": return "Lácteos"
        case "J": return "Huevos"
        case "T": return "Menestras"
        case "U": return "Tubérculos"
        default: return "Otros"
        }
    }
}

extension TipoComida {
    /// Parte orientativa de las calorías del día para cada comida (suma 1).
    var parteDelDia: Double {
        switch self {
        case .desayuno: return 0.25
        case .almuerzo: return 0.35
        case .cena: return 0.25
        case .snacks: return 0.15
        }
    }
}

// MARK: - Exportar

enum Exportar {
    static func campo(_ texto: String) -> String {
        if texto.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) {
            return "\"" + texto.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return texto
    }

    static func iso(_ fecha: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: fecha)
    }

    /// Historial de comidas en CSV (se abre en Excel o Google Sheets).
    static func csvRegistros(_ registros: [Registro]) -> String {
        var lineas = ["fecha,comida,alimento,gramos,kcal,proteina_g,carbohidratos_g,grasas_g,fibra_g,sodio_mg,origen"]
        for r in registros.sorted(by: { $0.fecha < $1.fecha }) {
            let t = r.total
            let valores = [iso(r.fecha), r.comida.nombre, campo(r.nombre), Formato.numeroCSV(r.gramos),
                           Formato.numeroCSV(t.kcal), Formato.numeroCSV(t.proteina), Formato.numeroCSV(t.carbohidratos),
                           Formato.numeroCSV(t.grasas), Formato.numeroCSV(t.fibra), Formato.numeroCSV(t.sodio), r.origen.etiqueta]
            lineas.append(valores.joined(separator: ","))
        }
        return lineas.joined(separator: "\n") + "\n"
    }

    static func csvPesos(_ pesos: [RegistroPeso]) -> String {
        var lineas = ["fecha,peso_kg"]
        for p in pesos.sorted(by: { $0.fecha < $1.fecha }) {
            lineas.append("\(iso(p.fecha)),\(Formato.numeroCSV(p.kg))")
        }
        return lineas.joined(separator: "\n") + "\n"
    }
}

extension Formato {
    /// Número para CSV: punto decimal y hasta 2 decimales ("12.5").
    static func numeroCSV(_ valor: Double) -> String {
        let redondeado = (valor * 100).rounded() / 100
        if redondeado == redondeado.rounded() { return String(Int(redondeado)) }
        return String(redondeado)
    }
}
