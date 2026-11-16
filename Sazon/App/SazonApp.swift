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
            // Al salir de la app se guarda enseguida (sin esperar), para no
            // perder el último cambio si iOS la cierra.
            if nueva != .active {
                almacen.guardarYa(esperar: true)
                return
            }
            // Al volver a la app: datos de Salud, recordatorios y widgets al día.
            // Lo que hiciste desde los botones del widget pasa a tus datos.
            almacen.procesarAccionesWidget()
            // Fotos y textos guardados sin conexión: se analizan si hay red.
            ColaIA.compartida.iniciar(almacen)
            ColaIA.compartida.procesar(almacen)
            Task { await Salud.compartido.actualizarHoy(en: almacen) }
            Recordatorios.reprogramar(almacen.datos.recordatorios)
            almacen.avisarCambios()
        }
    }
}
