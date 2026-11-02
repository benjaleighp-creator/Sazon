import SwiftUI

/// Punto de entrada de la app.
@main
struct SazonApp: App {
    @State private var almacen = Almacen.compartido

    var body: some Scene {
        WindowGroup {
            RaizView()
                .environment(almacen)
        }
    }
}
