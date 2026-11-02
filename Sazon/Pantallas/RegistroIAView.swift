import PhotosUI
import SwiftUI

// MARK: - Estado común

enum EstadoIA: Equatable {
    case inactivo
    case analizando
    case error(ErrorIA)
}

/// Bloque que muestra el estado de la IA (cargando o error con salida).
private struct EstadoIAVista: View {
    let estado: EstadoIA
    let texto: String
    @Environment(\.paleta) private var paleta

    var body: some View {
        switch estado {
        case .inactivo:
            EmptyView()
        case .analizando:
            HStack(spacing: Espacio.s) {
                ProgressView()
                Text(texto).font(Tipo.nota).foregroundStyle(paleta.textoSecundario)
            }
            .accessibilityElement(children: .combine)
        case .error(let e):
            Aviso(icono: "exclamationmark.triangle", titulo: e.titulo, texto: e.mensaje, color: paleta.aviso)
        }
    }
}

// MARK: - Texto y voz

/// Registro por texto o por voz (dictado del teclado de iOS, sin costo).
struct RegistroTextoView: View {
    @Binding var comida: TipoComida
    let alGuardar: ([Registro]) -> Void

    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var texto = ""
    @State private var estado: EstadoIA = .inactivo
    @State private var identificados: [AlimentoIdentificado] = []
    @State private var revisar = false
    @State private var envios = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.l) {
                VStack(alignment: .leading, spacing: Espacio.s) {
                    TituloSeccion("¿Qué comiste?")
                    CampoTexto(titulo: "Por ejemplo: 2 panes con palta y un café con leche", texto: $texto, eje: .vertical)
                        .lineLimit(3...8)
                    Label("Para dictar, toca el micrófono del teclado y habla.", systemImage: "mic")
                        .font(Tipo.pie)
                        .foregroundStyle(paleta.textoSecundario)
                }
                FormularioClaveSiFalta()
                EstadoIAVista(estado: estado, texto: "Gemini está identificando los alimentos…")
                Text("Solo se envía este texto a Google Gemini. Después revisas y corriges antes de guardar.")
                    .font(Tipo.pie)
                    .foregroundStyle(paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Espacio.margen)
            .padding(.vertical, Espacio.m)
        }
        .fondoDePantalla()
        .navigationTitle("Escribir o dictar")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                analizar()
            } label: {
                Label("Analizar con IA", systemImage: "sparkles")
            }
            .buttonStyle(.principal)
            .disabled(texto.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || estado == .analizando)
            .padding(.horizontal, Espacio.margen)
            .padding(.bottom, Espacio.xs)
        }
        .navigationDestination(isPresented: $revisar) {
            RevisionIAView(identificados: identificados, comida: $comida, alGuardar: alGuardar)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: envios)
        .sensoryFeedback(.warning, trigger: estado) { _, nuevo in
            if case .error = nuevo { return true } else { return false }
        }
    }

    private func analizar() {
        envios += 1
        estado = .analizando
        let pedido = texto
        Task {
            do {
                let proveedor = try ServicioIA.proveedorActual(almacen.datos)
                identificados = try await proveedor.analizar(texto: pedido)
                estado = .inactivo
                revisar = true
            } catch let e as ErrorIA {
                estado = .error(e)
            } catch is CancellationError {
                estado = .inactivo
            } catch {
                estado = .error(.desconocido(error.localizedDescription))
            }
        }
    }
}

// MARK: - Foto

/// Registro por foto: cámara o galería, foto reducida y una sola llamada.
struct RegistroFotoView: View {
    @Binding var comida: TipoComida
    let alGuardar: ([Registro]) -> Void

    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var imagen: UIImage?
    @State private var seleccion: PhotosPickerItem?
    @State private var mostrarCamara = false
    @State private var estado: EstadoIA = .inactivo
    @State private var identificados: [AlimentoIdentificado] = []
    @State private var revisar = false
    @State private var envios = 0
    @State private var errorFoto: String?

    private var camaraDisponible: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.l) {
                if let imagen {
                    Image(uiImage: imagen)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: Radio.tarjeta, style: .continuous))
                        .accessibilityLabel("Foto del plato elegida")
                } else {
                    EstadoVacio(icono: "camera", titulo: "Toma o elige una foto",
                                texto: "Que se vea todo el plato, con buena luz y desde arriba o un poco inclinada.")
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Espacio.s) { botones }
                    VStack(spacing: Espacio.s) { botones }
                }
                if let errorFoto {
                    Text(errorFoto).font(Tipo.pie).foregroundStyle(paleta.peligro)
                }
                FormularioClaveSiFalta()
                EstadoIAVista(estado: estado, texto: "Gemini está mirando la foto…")
                Text("Solo se envía la foto, reducida y sin datos de ubicación, a Google Gemini. Después revisas y corriges antes de guardar.")
                    .font(Tipo.pie)
                    .foregroundStyle(paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Espacio.margen)
            .padding(.vertical, Espacio.m)
        }
        .fondoDePantalla()
        .navigationTitle("Foto del plato")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                analizar()
            } label: {
                Label("Analizar con IA", systemImage: "sparkles")
            }
            .buttonStyle(.principal)
            .disabled(imagen == nil || estado == .analizando)
            .padding(.horizontal, Espacio.margen)
            .padding(.bottom, Espacio.xs)
        }
        .fullScreenCover(isPresented: $mostrarCamara) {
            Camara { foto in
                imagen = foto
                estado = .inactivo
            }
            .ignoresSafeArea()
        }
        .onChange(of: seleccion) { _, nueva in
            guard let nueva else { return }
            Task {
                if let datos = try? await nueva.loadTransferable(type: Data.self), let foto = UIImage(data: datos) {
                    imagen = foto
                    errorFoto = nil
                    estado = .inactivo
                } else {
                    errorFoto = "No se pudo abrir esa foto. Prueba con otra."
                }
            }
        }
        .navigationDestination(isPresented: $revisar) {
            RevisionIAView(identificados: identificados, comida: $comida, alGuardar: alGuardar)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: envios)
        .sensoryFeedback(.warning, trigger: estado) { _, nuevo in
            if case .error = nuevo { return true } else { return false }
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

    private func analizar() {
        guard let imagen else { return }
        guard let jpeg = ProcesadorFoto.prepararParaIA(imagen) else {
            errorFoto = "No se pudo preparar la foto."
            return
        }
        envios += 1
        estado = .analizando
        Task {
            do {
                let proveedor = try ServicioIA.proveedorActual(almacen.datos)
                identificados = try await proveedor.analizar(fotoJPEG: jpeg)
                estado = .inactivo
                revisar = true
            } catch let e as ErrorIA {
                estado = .error(e)
            } catch is CancellationError {
                estado = .inactivo
            } catch {
                estado = .error(.desconocido(error.localizedDescription))
            }
        }
    }
}

/// Cámara del sistema (UIImagePickerController).
private struct Camara: UIViewControllerRepresentable {
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

// MARK: - Clave si falta

/// Si no hay clave guardada, la pide aquí mismo (se guarda en el Llavero).
struct FormularioClaveSiFalta: View {
    @Environment(\.paleta) private var paleta
    @State private var hayClave = Llavero.hayClave
    @State private var clave = ""
    @State private var error: String?

    var body: some View {
        if !hayClave {
            VStack(alignment: .leading, spacing: Espacio.s) {
                Text("Falta tu clave de Gemini")
                    .font(Tipo.cuerpoFuerte)
                    .foregroundStyle(paleta.texto)
                Text("Pégala una vez; se guarda cifrada en el Llavero de este iPhone. Cómo crearla: Ajustes › Inteligencia artificial.")
                    .font(Tipo.pie)
                    .foregroundStyle(paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                SecureField("Clave de API", text: $clave)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, Espacio.m)
                    .frame(minHeight: Medida.toque)
                    .background(RoundedRectangle(cornerRadius: Radio.medio, style: .continuous).fill(paleta.superficieAlta))
                if let error {
                    Text(error).font(Tipo.pie).foregroundStyle(paleta.peligro)
                }
                Button("Guardar clave") {
                    if Llavero.guardarClave(clave) {
                        clave = ""
                        hayClave = true
                    } else {
                        error = "No se pudo guardar en el Llavero. Revisa que la clave no esté vacía."
                    }
                }
                .buttonStyle(.secundario)
                .disabled(clave.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .tarjeta()
        }
    }
}
