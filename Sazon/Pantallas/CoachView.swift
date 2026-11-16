import SwiftUI

/// Coach con IA (Gemini): conversación sobre tu alimentación.
struct CoachView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @Environment(\.dismiss) private var cerrar
    @Environment(\.accessibilityReduceMotion) private var reducir
    @State private var texto = ""
    @State private var tarea: Task<Void, Never>?
    /// Sube solo cuando llega una respuesta del coach (para el háptico).
    @State private var respuestas = 0
    @State private var enviando = false
    @State private var error: ErrorIA?
    @State private var pedirAviso = false
    @FocusState private var enfocado: Bool

    private let sugerencias = [
        "¿Qué puedo cenar para llegar a mi proteína?",
        "Ideas de desayuno peruano con menos azúcar",
        "¿Cómo reparto mis comidas si entreno de noche?"
    ]

    var body: some View {
        @Bindable var a = almacen
        NavigationStack {
            ScrollViewReader { lector in
                ScrollView {
                    VStack(alignment: .leading, spacing: Espacio.s) {
                        cabecera
                        if almacen.datos.coach.isEmpty {
                            ForEach(sugerencias, id: \.self) { s in
                                Button { enviar(s) } label: {
                                    Text(s).font(Tipo.nota).foregroundStyle(paleta.acento)
                                        .padding(.horizontal, Espacio.m).padding(.vertical, Espacio.s)
                                        .background(Capsule().fill(paleta.acentoSuave))
                                }
                                .buttonStyle(.plain)
                                .disabled(enviando)
                            }
                        }
                        ForEach(almacen.datos.coach) { m in
                            Burbuja(mensaje: m).id(m.id)
                        }
                        if enviando {
                            HStack(spacing: Espacio.xs) {
                                ProgressView()
                                Text("El coach está escribiendo…").font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                                Spacer(minLength: Espacio.xs)
                                Button("Cancelar", action: cancelar)
                                    .buttonStyle(.texto)
                                    .frame(minHeight: Medida.toqueMinimo)
                            }
                            .id("escribiendo")
                        }
                        if let error {
                            TarjetaErrorIA(error: error)
                        }
                    }
                    .padding(.horizontal, Espacio.margen)
                    .padding(.vertical, Espacio.m)
                }
                .onChange(of: almacen.datos.coach.count) { _, _ in
                    if let id = almacen.datos.coach.last?.id {
                        withAnimation(Movimiento.estandar.animacion(reducir: reducir)) {
                            lector.scrollTo(id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let id = almacen.datos.coach.last?.id { lector.scrollTo(id, anchor: .bottom) }
                }
            }
            .fondoDePantalla()
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: Espacio.s) {
                    CampoTexto(titulo: "Escribe tu pregunta", texto: $texto, eje: .vertical)
                        .focused($enfocado)
                        .lineLimit(1...4)
                    Button { enviar(texto) } label: {
                        Image(systemName: "arrow.up")
                            .font(Tipo.iconoFila)
                            .foregroundStyle(paleta.textoSobreAcento)
                            .frame(width: Medida.toque, height: Medida.toque)
                            .background(Circle().fill(paleta.acento))
                    }
                    .buttonStyle(.plain)
                    .disabled(enviando || texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Enviar")
                }
                .padding(.horizontal, Espacio.margen)
                .padding(.vertical, Espacio.s)
                .background(paleta.fondo.ignoresSafeArea(edges: .bottom))
            }
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { cerrar() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Compartir el resumen de hoy", isOn: $a.datos.coachCompartirResumen)
                        Button("Borrar conversación", role: .destructive) { a.datos.coach = [] }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $pedirAviso) {
                AvisoPrivacidadView {
                    almacen.datos.avisoIAAceptado = true
                    pedirAviso = false
                }
                .entornoSazon(almacen)
            }
            // Vibra solo cuando responde el coach o hay un error (no con
            // tus propios mensajes ni al borrar la conversación).
            .sensoryFeedback(.impact(weight: .light), trigger: respuestas)
            .sensoryFeedback(.warning, trigger: error) { _, nuevo in nuevo != nil }
            .onDisappear { cancelar() }
        }
    }

    /// Corta la petición en curso (botón Cancelar o al cerrar el coach).
    private func cancelar() {
        tarea?.cancel()
        tarea = nil
        enviando = false
    }

    private var cabecera: some View {
        HStack(alignment: .top, spacing: Espacio.s) {
            AzulejoIcono(simbolo: "sparkles", tamano: 40)
            VStack(alignment: .leading, spacing: Espacio.xxxs) {
                Text("Coach Sazón").font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                Text(almacen.datos.coachCompartirResumen
                     ? "Se envía a Gemini lo que escribes y un resumen de tus números de hoy (sin tu nombre)."
                     : "Se envía a Gemini solo lo que escribes. Puedes compartir tu resumen del día en el menú ⋯.")
                    .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                Text("No es un profesional de salud: sus respuestas son orientativas y pueden equivocarse.")
                    .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tarjeta()
    }

    private func enviar(_ contenido: String) {
        let limpio = contenido.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty, !enviando else { return }
        guard almacen.datos.avisoIAAceptado else { pedirAviso = true; return }
        error = nil
        let proveedor: ProveedorIA
        do {
            proveedor = try ServicioIA.proveedorActual(almacen.datos)
        } catch let e as ErrorIA {
            error = e; return
        } catch {
            self.error = .desconocido(error.localizedDescription); return
        }
        almacen.datos.coach.append(MensajeCoach(autor: .usuario, texto: limpio))
        texto = ""
        enviando = true
        let mensajes = almacen.datos.coach
        let contexto = almacen.contextoCoach()
        tarea = Task {
            do {
                let respuesta = try await proveedor.conversar(mensajes: mensajes, contexto: contexto)
                try Task.checkCancellation()
                almacen.datos.coach.append(MensajeCoach(autor: .coach, texto: respuesta))
                respuestas += 1
                // Se guardan como máximo los últimos 60 mensajes.
                if almacen.datos.coach.count > 60 { almacen.datos.coach.removeFirst(almacen.datos.coach.count - 60) }
            } catch {
                if Task.isCancelled || error is CancellationError { return }
                self.error = (error as? ErrorIA) ?? .desconocido(error.localizedDescription)
            }
            enviando = false
            tarea = nil
        }
    }
}

private struct Burbuja: View {
    let mensaje: MensajeCoach
    @Environment(\.paleta) private var paleta

    var body: some View {
        let mio = mensaje.autor == .usuario
        HStack {
            if mio { Spacer(minLength: Espacio.xl) }
            // Texto plano: sin enlaces que se puedan tocar ni formato oculto.
            Text(verbatim: mio ? mensaje.texto : Formato.textoPlano(mensaje.texto))
                .font(Tipo.cuerpo)
                .foregroundStyle(mio ? paleta.textoSobreAcento : paleta.texto)
                .padding(.horizontal, Espacio.m)
                .padding(.vertical, Espacio.s)
                .background(
                    RoundedRectangle(cornerRadius: Radio.tarjeta, style: .continuous)
                        .fill(mio ? paleta.acento : paleta.superficie)
                )
                .textSelection(.enabled)
            if !mio { Spacer(minLength: Espacio.xl) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((mio ? "Tú: " : "Coach: ") + (mio ? mensaje.texto : Formato.textoPlano(mensaje.texto)))
    }
}
