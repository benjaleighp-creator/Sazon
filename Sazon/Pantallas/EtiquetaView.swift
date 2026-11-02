import PhotosUI
import SwiftUI

/// Lee con IA la tabla nutricional de un envase (para productos que no
/// están en Open Food Facts). El resultado se revisa antes de guardar y
/// queda asociado al código de barras para la próxima vez.
struct EtiquetaView: View {
    let codigo: String?
    let alLeer: (Candidato) -> Void

    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var imagen: UIImage?
    @State private var seleccion: PhotosPickerItem?
    @State private var mostrarCamara = false
    @State private var estado: EstadoIA = .inactivo
    @State private var errorFoto: String?
    @State private var envios = 0

    private var camaraDisponible: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.l) {
                VStack(alignment: .leading, spacing: Espacio.xs) {
                    Label("Con IA", systemImage: "sparkles")
                        .font(Tipo.micro)
                        .foregroundStyle(paleta.heroFin)
                        .padding(.horizontal, Espacio.xs)
                        .padding(.vertical, Espacio.xxs)
                        .background(Capsule().fill(paleta.textoHero))
                    Text("Foto de la tabla nutricional")
                        .font(Tipo.titulo3)
                        .foregroundStyle(paleta.textoHero)
                    Text("De frente, con buena luz y que se lean los números. Si el código es \(codigo ?? "—"), se guardará para la próxima vez.")
                        .font(Tipo.nota)
                        .foregroundStyle(paleta.textoHeroSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .hero(relleno: Espacio.m)

                if let imagen {
                    Image(uiImage: imagen)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: Radio.tarjeta, style: .continuous))
                        .accessibilityLabel("Foto de la etiqueta elegida")
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Espacio.s) { botones }
                    VStack(spacing: Espacio.s) { botones }
                }
                if let errorFoto {
                    Text(errorFoto).font(Tipo.pie).foregroundStyle(paleta.peligro)
                }
                FormularioClaveSiFalta()
                switch estado {
                case .inactivo:
                    EmptyView()
                case .analizando:
                    HStack(spacing: Espacio.s) {
                        ProgressView()
                        Text("Gemini está leyendo la etiqueta…").font(Tipo.nota).foregroundStyle(paleta.textoSecundario)
                    }
                case .error(let e):
                    Aviso(icono: "exclamationmark.triangle", titulo: e.titulo, texto: e.mensaje, color: paleta.aviso)
                }
                Text("Solo se envía la foto de la etiqueta, reducida y sin ubicación. Después revisas y corriges los números antes de guardar.")
                    .font(Tipo.pie)
                    .foregroundStyle(paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Espacio.margen)
            .padding(.vertical, Espacio.m)
        }
        .fondoDePantalla()
        .navigationTitle("Leer etiqueta")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button { analizar() } label: { Label("Leer con IA", systemImage: "sparkles") }
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
        .sensoryFeedback(.impact(weight: .light), trigger: envios)
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
        // La etiqueta necesita más detalle que un plato: lado de 1600 px.
        guard let jpeg = ProcesadorFoto.prepararParaIA(imagen, ladoMaximo: 1600, calidad: 0.7) else {
            errorFoto = "No se pudo preparar la foto."
            return
        }
        envios += 1
        estado = .analizando
        Task {
            do {
                let proveedor = try ServicioIA.proveedorActual(almacen.datos)
                let leida = try await proveedor.leerEtiqueta(fotoJPEG: jpeg)
                estado = .inactivo
                alLeer(Candidato(etiqueta: leida, codigoBarras: codigo))
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
