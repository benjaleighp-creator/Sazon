import AppIntents
import Foundation

// Acciones de Siri y Atajos (App Intents, iOS 16+; verificado en
// developer.apple.com el 16-nov-2026). Corren en la app (también sin
// abrirla) y escriben en los mismos datos. Piden el iPhone desbloqueado
// porque los datos están cifrados mientras está bloqueado.

/// «Oye Siri, agrega un vaso de agua en Sazón».
struct AgregarAguaIntent: AppIntent {
    static var title: LocalizedStringResource = "Agregar un vaso de agua"
    static var description = IntentDescription("Suma un vaso de agua (del tamaño elegido en Sazón) al día de hoy.")
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let almacen = Almacen.compartido
        guard !almacen.archivoProtegido else {
            return .result(dialog: "No pude abrir tus datos de Sazón. Abre la app para revisarlo.")
        }
        let ml = almacen.datos.vasoMl
        almacen.agregarAguaHoy(ml)
        almacen.guardarYa(esperar: true)
        let hoy = Agua.delDia(Date(), en: almacen.datos.agua)
        return .result(dialog: "Listo: \(Formato.entero(ml)) ml de agua. Hoy llevas \(Formato.entero(hoy)) de \(Formato.entero(almacen.metaAgua)) ml.")
    }
}

/// Comida para las frases de Siri.
enum ComidaAtajo: String, AppEnum {
    case desayuno, mediaManana, almuerzo, mediaTarde, cena, snacks

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Comida"
    static var caseDisplayRepresentations: [ComidaAtajo: DisplayRepresentation] = [
        .desayuno: "desayuno",
        .mediaManana: "media mañana",
        .almuerzo: "almuerzo",
        .mediaTarde: "media tarde",
        .cena: "cena",
        .snacks: "snack"
    ]

    var comida: TipoComida { TipoComida(rawValue: rawValue) ?? .snacks }
}

/// «Oye Siri, repite mi desayuno en Sazón»: registra hoy tu favorito de esa
/// comida o, si no tienes, lo que comiste en esa comida el último día.
struct RepetirComidaIntent: AppIntent {
    static var title: LocalizedStringResource = "Repetir una comida"
    static var description = IntentDescription("Registra hoy tu favorito de esa comida o lo que comiste en ella el último día.")
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Comida")
    var comida: ComidaAtajo

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let almacen = Almacen.compartido
        guard !almacen.archivoProtegido else {
            return .result(dialog: "No pude abrir tus datos de Sazón. Abre la app para revisarlo.")
        }
        let tipo = comida.comida
        guard let encontrada = almacen.ultimaComida(tipo) else {
            return .result(dialog: "No encontré un \(tipo.nombre.lowercased()) para repetir. Registra uno o guárdalo como favorito en Sazón.")
        }
        let (origen, registros) = encontrada
        almacen.agregar(Copiado.copiar(registros, aDia: Date(), comida: tipo).map { r in
            var r = r
            r.fecha = Date()
            return r
        })
        almacen.guardarYa(esperar: true)
        let kcal = registros.reduce(0) { $0 + $1.total.kcal }
        return .result(dialog: "Listo: repetí \(origen) (\(Formato.entero(kcal)) kcal) en tu \(tipo.nombre.lowercased()) de hoy.")
    }
}

/// Frases de Siri (cada una debe incluir el nombre de la app).
struct AtajosSazon: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AgregarAguaIntent(),
                    phrases: ["Agrega un vaso de agua en \(.applicationName)",
                              "Registra agua en \(.applicationName)",
                              "Suma agua en \(.applicationName)"],
                    shortTitle: "Vaso de agua",
                    systemImageName: "drop.fill")
        AppShortcut(intent: RepetirComidaIntent(),
                    phrases: ["Repite mi \(\.$comida) en \(.applicationName)",
                              "Repetir \(\.$comida) en \(.applicationName)",
                              "Repite una comida en \(.applicationName)"],
                    shortTitle: "Repetir comida",
                    systemImageName: "arrow.clockwise")
    }
}
