import PhotosUI
import SwiftUI

// MARK: - Estado común

enum EstadoIA: Equatable {
    case inactivo
    case analizando
    case error(ErrorIA)
}

/// Bloque que muestra el estado de la IA: espera (con tiempo, avisos y
/// Cancelar) o error (con salidas al modo manual).
struct EstadoIAVista: View {
    let estado: EstadoIA
    let texto: String
    let tarea: TareaIA
    let alCancelar: () -> Void
    /// Salida al modo manual (nil: el error no ofrece salidas).
    var alSalir: ((DestinoRegistro) -> Void)? = nil
    /// A dónde lleva «Agregar a mano».
    var destinoManual: DestinoRegistro = .manual

    var body: some View {
        switch estado {
        case .inactivo:
            EmptyView()
        case .analizando:
            TarjetaEsperaIA(titulo: texto, inicio: tarea.inicio, paso: tarea.paso, alCancelar: alCancelar)
        case .error(let e):
            if let alSalir {
                TarjetaErrorIA(error: e,
                               alBuscarTabla: { alSalir(.buscar) },
                               alAgregarAMano: { alSalir(destinoManual) })
            } else {
                TarjetaErrorIA(error: e)
            }
        }
    }
}

// MARK: - Texto y voz

/// Registro por texto o por voz (dictado del teclado de iOS, sin costo).
struct RegistroTextoView: View {
    @Binding var comida: TipoComida
    let alGuardar: ([Registro]) -> Void
    /// Salida al modo manual cuando la IA falla (tabla o a mano).
    var alSalir: ((DestinoRegistro) -> Void)? = nil

    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var texto = ""
    @State private var estado: EstadoIA = .inactivo
    @State private var tarea = TareaIA()
    @State private var analisis = AnalisisIA(alimentos: [], posiblesOcultos: [])
    @State private var revisar = false
    @State private var envios = 0
    @State private var dictado = Dictado()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.l) {
                VStack(alignment: .leading, spacing: Espacio.s) {
                    TituloSeccion("¿Qué comiste?")
                    CampoTexto(titulo: "Por ejemplo: 2 panes con palta y un café con leche", texto: $texto, eje: .vertical)
                        .lineLimit(3...8)
                    Button {
                        dictado.texto = texto
                        Task { await dictado.alternar() }
                    } label: {
                        Label(dictado.escuchando ? "Escuchando… toca para terminar" : "Dictar con la voz",
                              systemImage: dictado.escuchando ? "waveform" : "mic.fill")
                            .symbolEffect(.variableColor.iterative, isActive: dictado.escuchando)
                    }
                    .buttonStyle(.secundario)
                    if let e = dictado.error {
                        Text(e).font(Tipo.pie).foregroundStyle(paleta.aviso)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(dictado.enDispositivo
                         ? "El dictado se procesa en tu iPhone. También puedes usar el micrófono del teclado."
                         : "El dictado lo procesa Apple (puede usar sus servidores). También puedes usar el micrófono del teclado.")
                        .font(Tipo.pie)
                        .foregroundStyle(paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                FormularioClaveSiFalta()
                EstadoIAVista(estado: estado, texto: "Gemini está identificando los alimentos…", tarea: tarea,
                              alCancelar: cancelar, alSalir: alSalir)
                Text("Solo se envía este texto a Google Gemini. Después revisas y corriges antes de guardar.")
                    .font(Tipo.pie)
                    .foregroundStyle(paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Espacio.margen)
            .padding(.vertical, Espacio.m)
        }
        .fondoDePantalla()
        .onChange(of: dictado.texto) { _, nuevo in
            if dictado.escuchando { texto = nuevo }
        }
        .onDisappear {
            dictado.detener()
            // Si sales de la pantalla, la petición a Gemini se corta.
            cancelar()
        }
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
            .barraInferior()
        }
        .navigationDestination(isPresented: $revisar) {
            RevisionIAView(identificados: analisis.alimentos, posiblesOcultos: analisis.posiblesOcultos, comida: $comida, alGuardar: alGuardar)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: envios)
        .sensoryFeedback(.warning, trigger: estado) { _, nuevo in
            if case .error = nuevo { return true } else { return false }
        }
    }

    private func analizar() {
        dictado.detener()
        envios += 1
        estado = .analizando
        let pedido = texto
        tarea.iniciar { alAvanzar in
            do {
                let proveedor = try ServicioIA.proveedorActual(almacen.datos, alAvanzar: alAvanzar)
                analisis = try await proveedor.analizar(texto: pedido)
                try Task.checkCancellation()
                estado = .inactivo
                revisar = true
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

// MARK: - Foto

/// Registro por foto: cámara o galería, foto reducida y una sola llamada.
struct RegistroFotoView: View {
    @Binding var comida: TipoComida
    let alGuardar: ([Registro]) -> Void
    /// Salida al modo manual cuando la IA falla (tabla o a mano).
    var alSalir: ((DestinoRegistro) -> Void)? = nil

    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var tarea = TareaIA()
    @State private var imagen: UIImage?
    @State private var seleccion: PhotosPickerItem?
    @State private var mostrarCamara = false
    @State private var estado: EstadoIA = .inactivo
    @State private var analisis = AnalisisIA(alimentos: [], posiblesOcultos: [])
    @State private var revisar = false
    @State private var envios = 0
    @State private var errorFoto: String?
    @State private var fase: FaseDeteccion = .inactiva
    @State private var visibles = 0
    @State private var exitos = 0
    @Environment(\.accessibilityReduceMotion) private var reducir

    private var camaraDisponible: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.l) {
                if let imagen {
                    Image(uiImage: imagen)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .overlay {
                            CapaDeteccion(fase: fase, alimentos: analisis.alimentos, visibles: visibles)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Radio.tarjeta, style: .continuous))
                        .frame(maxWidth: .infinity, maxHeight: Medida.altoFoto)
                        .accessibilityLabel("Foto del plato elegida")
                    if case .detectando = fase {
                        ListaDetectados(alimentos: analisis.alimentos, visibles: visibles)
                    }
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
                EstadoIAVista(estado: estado, texto: "Gemini está mirando la foto…", tarea: tarea,
                              alCancelar: cancelar, alSalir: alSalir)
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
            .disabled(imagen == nil || estado == .analizando || esDetectando)
            .padding(.horizontal, Espacio.margen)
            .padding(.bottom, Espacio.xs)
            .barraInferior()
        }
        .fullScreenCover(isPresented: $mostrarCamara) {
            Camara { foto in
                cancelar()
                imagen = foto
                estado = .inactivo
                fase = .inactiva
            }
            .ignoresSafeArea()
        }
        .onChange(of: seleccion) { _, nueva in
            guard let nueva else { return }
            Task {
                if let datos = try? await nueva.loadTransferable(type: Data.self), let foto = UIImage(data: datos) {
                    // Foto nueva: la petición anterior ya no sirve.
                    cancelar()
                    imagen = foto
                    errorFoto = nil
                    estado = .inactivo
                    fase = .inactiva
                } else {
                    errorFoto = "No se pudo abrir esa foto. Prueba con otra."
                }
            }
        }
        .navigationDestination(isPresented: $revisar) {
            RevisionIAView(identificados: analisis.alimentos, posiblesOcultos: analisis.posiblesOcultos, comida: $comida, alGuardar: alGuardar)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: envios)
        .sensoryFeedback(.selection, trigger: visibles)
        .sensoryFeedback(.success, trigger: exitos)
        .sensoryFeedback(.warning, trigger: estado) { _, nuevo in
            if case .error = nuevo { return true } else { return false }
        }
        .onChange(of: revisar) { _, abierto in
            // Al volver de la revisión, la foto queda limpia.
            if !abierto { fase = .inactiva; visibles = 0 }
        }
        .onDisappear {
            // Si sales de la pantalla, la petición a Gemini se corta.
            cancelar()
        }
    }

    private var esDetectando: Bool {
        if case .detectando = fase { return true }
        return false
    }

    /// Revela las etiquetas una tras otra y pasa a la revisión.
    private func revelar() async {
        let n = analisis.alimentos.count
        let paso = Deteccion.intervaloEtiquetas(n)
        // Los puntos tardan 0,6 s en reunirse (0,2 s con Reducir movimiento).
        try? await Task.sleep(nanoseconds: UInt64((reducir ? 0.2 : 0.6) * 1e9))
        for i in 0..<n {
            withAnimation(Movimiento.estandar.animacion(reducir: reducir)) { visibles = i + 1 }
            try? await Task.sleep(nanoseconds: UInt64(paso * 1e9))
        }
        try? await Task.sleep(nanoseconds: 350_000_000)
        guard !Task.isCancelled else { return }
        exitos += 1
        revisar = true
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
        visibles = 0
        analisis = AnalisisIA(alimentos: [], posiblesOcultos: [])
        let inicio = Date()
        fase = .esperando(inicio: inicio)
        tarea.iniciar { alAvanzar in
            do {
                let proveedor = try ServicioIA.proveedorActual(almacen.datos, alAvanzar: alAvanzar)
                analisis = try await proveedor.analizar(fotoJPEG: jpeg)
                try Task.checkCancellation()
                estado = .inactivo
                fase = .detectando(inicio: Date(), desdeEspera: Date().timeIntervalSince(inicio))
                // VoiceOver lee todos los alimentos detectados (la capa de
                // puntos y cajas es solo decorativa).
                UIAccessibility.post(notification: .announcement,
                                     argument: Deteccion.anuncio(analisis.alimentos.map { (nombre: $0.nombre, gramos: $0.gramos) }))
                await revelar()
            } catch {
                if Task.isCancelled || error is CancellationError { return }
                estado = .error((error as? ErrorIA) ?? .desconocido(error.localizedDescription))
                fase = .detenida
            }
        }
    }

    private func cancelar() {
        guard tarea.enCurso else { return }
        tarea.cancelar()
        if estado == .analizando { estado = .inactivo }
        if case .esperando = fase { fase = .inactiva }
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
