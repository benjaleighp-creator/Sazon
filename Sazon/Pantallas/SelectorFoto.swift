import PhotosUI
import SwiftUI

/// Botones «Tomar foto» y «Elegir de la galería» con la cámara y el
/// selector de fotos. Los usan la foto del plato y la etiqueta.
struct BotonesFoto: View {
    let alElegir: (UIImage) -> Void
    var alFallar: (String) -> Void = { _ in }

    @State private var seleccion: PhotosPickerItem?
    @State private var mostrarCamara = false

    private var camaraDisponible: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Espacio.s) { botones }
            VStack(spacing: Espacio.s) { botones }
        }
        .fullScreenCover(isPresented: $mostrarCamara) {
            Camara { foto in alElegir(foto) }
                .ignoresSafeArea()
        }
        .onChange(of: seleccion) { _, nueva in
            guard let nueva else { return }
            Task {
                if let datos = try? await nueva.loadTransferable(type: Data.self), let foto = UIImage(data: datos) {
                    alElegir(foto)
                } else {
                    alFallar("No se pudo abrir esa foto. Prueba con otra.")
                }
                // Así se puede volver a elegir la misma foto.
                seleccion = nil
            }
        }
    }

    @ViewBuilder
    private var botones: some View {
        if camaraDisponible {
            Button { mostrarCamara = true } label: { Label("Tomar foto", systemImage: "camera") }
                .buttonStyle(.secundario)
        }
        PhotosPicker(selection: $seleccion, matching: .images) {
            Label("Elegir de la galería", systemImage: "photo.on.rectangle")
        }
        .buttonStyle(.secundario)
    }
}

/// Cámara del sistema (UIImagePickerController).
struct Camara: UIViewControllerRepresentable {
    let alTomar: (UIImage) -> Void
    @Environment(\.dismiss) private var cerrar

    func makeCoordinator() -> Coordinador { Coordinador(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let selector = UIImagePickerController()
        selector.sourceType = .camera
        selector.cameraCaptureMode = .photo
        selector.delegate = context.coordinator
        return selector
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinador: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let padre: Camara
        init(_ padre: Camara) { self.padre = padre }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let foto = info[.originalImage] as? UIImage {
                padre.alTomar(foto)
            }
            padre.cerrar()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            padre.cerrar()
        }
    }
}
