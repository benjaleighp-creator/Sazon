import SwiftUI

/// Lee con IA la tabla nutricional de un envase (para productos que no
/// están en Open Food Facts). El resultado se revisa antes de guardar y
/// queda asociado al código de barras para la próxima vez.
struct EtiquetaView: View {
    let codigo: String?
    let alLeer: (Candidato) -> Void
    /// Salida al modo manual cuando la IA falla (tabla o a mano).
    var alSalir: ((DestinoRegistro) -> Void)? = nil

    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var imagen: UIImage?
    @State private var estado: EstadoIA = .inactivo
    @State private var tarea = TareaIA()
    @State private var errorFoto: String?
    @State private var envios = 0

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

                BotonesFoto(alElegir: usarFoto, alFallar: { errorFoto = $0 })
                if let errorFoto {
                    Text(errorFoto).font(Tipo.pie).foregroundStyle(paleta.peligro)
                }
                FormularioClaveSiFalta()
                EstadoIAVista(estado: estado, texto: "Leyendo la etiqueta…", tarea: tarea,
                              alCancelar: cancelar, alSalir: alSalir,
                              destinoManual: .porcion(Candidato(manual: "", codigoBarras: codigo)))
                Text("Primero se intenta leer en tu iPhone, sin internet. Solo si no alcanza, se envía la foto de la etiqueta (reducida y sin ubicación) a la IA. Después revisas y corriges los números antes de guardar.")
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
                .barraInferior()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: envios)
        .sensoryFeedback(.warning, trigger: estado) { _, nuevo in
            if case .error = nuevo { return true } else { return false }
        }
        .onDisappear {
            // Si sales de la pantalla, la petición a Gemini se corta.
            cancelar()
        }
    }

    private func usarFoto(_ foto: UIImage) {
        cancelar()
        imagen = foto
        errorFoto = nil
        estado = .inactivo
    }

    private func analizar() {
        guard let imagen else { return }
        envios += 1
        estado = .analizando
        errorFoto = nil
        tarea.iniciar { alAvanzar in
            do {
                // 1. En el iPhone, sin red ni cuota (Vision).
                if let local = await LectorEtiquetaLocal.leer(imagen) {
                    try Task.checkCancellation()
                    estado = .inactivo
                    alLeer(Candidato(etiqueta: local, codigoBarras: codigo))
                    return
                }
                try Task.checkCancellation()
                // 2. Si el texto no alcanzó, la IA en la nube. La etiqueta
                // necesita más detalle que un plato: lado de 1600 px.
                guard let jpeg = await ProcesadorFoto.prepararEnSegundoPlano(imagen, ladoMaximo: 1600, calidad: 0.7) else {
                    errorFoto = "No se pudo preparar la foto."
                    estado = .inactivo
                    return
                }
                let proveedor = try ServicioIA.proveedorActual(almacen.datos, alAvanzar: alAvanzar)
                let leida = try await proveedor.leerEtiqueta(fotoJPEG: jpeg)
                try Task.checkCancellation()
                estado = .inactivo
                alLeer(Candidato(etiqueta: leida, codigoBarras: codigo))
            } catch {
                if Task.isCancelled || error is CancellationError { return }
                estado = .error((error as? ErrorIA) ?? .desconocido(error.localizedDescription))
            }
        }
    }

    private func cancelar() {
        guard tarea.enCurso else { return }
        tarea.cancelar()
        if estado == .analizando { estado = .inactivo }
    }
}
