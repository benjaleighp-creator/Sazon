import SwiftUI

/// Punto de entrada de la app.
@main
struct SazonApp: App {
    @State private var almacen = Almacen.compartido
    @Environment(\.scenePhase) private var fase

    var body: some Scene {
        WindowGroup {
            RaizView()
                .environment(almacen)
        }
        .onChange(of: fase) { _, nueva in
            guard nueva == .active else { return }
            // Al volver a la app: datos de Salud, recordatorios y widgets al día.
            Task { await Salud.compartido.actualizarHoy(en: almacen) }
            Recordatorios.reprogramar(almacen.datos.recordatorios)
            almacen.avisarCambios()
        }
    }
}
