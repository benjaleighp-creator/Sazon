import SwiftUI

/// Vista raíz: aplica tema, apariencia, tipografía y ahorro de batería, y
/// muestra las pestañas Diario, Plan, Progreso, Ayuno y Ajustes.
struct RaizView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.colorScheme) private var esquemaSistema
    @State private var bajoConsumo = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var pestana = 0

    var body: some View {
        let tema = almacen.tema
        let paleta = tema.paleta(esquemaEfectivo)

        TabView(selection: $pestana) {
            DiarioView()
                .tabItem { Label("Diario", systemImage: "fork.knife") }
                .tag(0)
            PlanView()
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(1)
            ProgresoView()
                .tabItem { Label("Progreso", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(2)
            AyunoView()
                .tabItem { Label("Ayuno", systemImage: "timer") }
                .tag(3)
            AjustesView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
                .tag(4)
        }
        .sensoryFeedback(.selection, trigger: pestana)
        .environment(\.paleta, paleta)
        .environment(\.temaActivo, tema)
        .environment(\.ahorroActivo, almacen.datos.ahorroBateria || bajoConsumo)
        .fontDesign(tema.estilo.diseno.fontDesign)
        .tint(paleta.acento)
        .preferredColorScheme(esquemaForzado)
        .animacion(.pantalla, valor: almacen.datos.temaID)
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            bajoConsumo = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    private var esquemaForzado: ColorScheme? {
        switch almacen.datos.apariencia {
        case .sistema: return nil
        case .claro: return .light
        case .oscuro: return .dark
        }
    }

    private var esquemaEfectivo: ColorScheme {
        esquemaForzado ?? esquemaSistema
    }
}

/// Aplica a una hoja (sheet) el mismo entorno que la raíz: almacén, tema,
/// paleta, tipografía y ahorro. Se pone explícito en cada hoja para no
/// depender de qué valores hereda una presentación.
private struct EntornoSazon: ViewModifier {
    let almacen: Almacen
    @Environment(\.colorScheme) private var esquema

    func body(content: Content) -> some View {
        let tema = almacen.tema
        let ahorro = almacen.datos.ahorroBateria || ProcessInfo.processInfo.isLowPowerModeEnabled
        content
            .environment(almacen)
            .environment(\.paleta, tema.paleta(esquema))
            .environment(\.temaActivo, tema)
            .environment(\.ahorroActivo, ahorro)
            .fontDesign(tema.estilo.diseno.fontDesign)
            .tint(tema.paleta(esquema).acento)
    }
}

extension View {
    func entornoSazon(_ almacen: Almacen) -> some View {
        modifier(EntornoSazon(almacen: almacen))
    }
}
