import SwiftUI

/// Ayuno intermitente: temporizador, protocolos e historial.
struct AyunoView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var cambiarInicio = false
    @State private var inicioManual = Date()
    @State private var accion = 0

    var body: some View {
        @Bindable var a = almacen
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Espacio.l) {
                    Text("Ayuno")
                        .font(Tipo.titulo1)
                        .foregroundStyle(paleta.texto)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, Espacio.s)

                    TimelineView(.periodic(from: .now, by: 1)) { contexto in
                        heroTemporizador(ahora: contexto.date)
                    }
                    .aparicion(0)

                    VStack(alignment: .leading, spacing: Espacio.s) {
                        EncabezadoSeccion(titulo: "Protocolo", icono: "clock.badge.checkmark")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Espacio.xs)], spacing: Espacio.xs) {
                            ForEach(Ayuno.protocolos, id: \.horas) { p in
                                TarjetaProtocolo(nombre: p.nombre, horas: p.horas, elegido: almacen.datos.horasAyuno == p.horas) {
                                    animar(.seleccion) { a.datos.horasAyuno = p.horas }
                                }
                            }
                        }
                        .sensoryFeedback(.selection, trigger: almacen.datos.horasAyuno)
                        Stepper(value: $a.datos.horasAyuno, in: 1...72, step: 1) {
                            Text("Personalizado: \(Formato.entero(almacen.datos.horasAyuno)) h de ayuno")
                                .font(Tipo.nota).foregroundStyle(paleta.texto)
                        }
                        Text("Se aplica al próximo ayuno que empieces. El protocolo 16:8 significa 16 horas de ayuno y 8 de ventana para comer.")
                            .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .tarjeta()
                    .aparicion(1)

                    EncabezadoSeccion(titulo: "Historial", icono: "calendar")
                        .aparicion(2)
                    historial.aparicion(2)

                    Text("El ayuno no es adecuado para todas las personas (por ejemplo, en el embarazo, con diabetes u otras condiciones). Consulta a un profesional de salud antes de empezar.")
                        .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Espacio.margen)
                .padding(.bottom, Espacio.xxl)
            }
            .fondoDePantalla()
            .toolbar(.hidden, for: .navigationBar)
            .sensoryFeedback(.success, trigger: accion)
            .sheet(isPresented: $cambiarInicio) {
                NavigationStack {
                    Form {
                        DatePicker("Empezó", selection: $inicioManual, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    }
                    .navigationTitle("¿Cuándo empezaste?")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cambiarInicio = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Empezar") {
                                almacen.iniciarAyuno(desde: inicioManual)
                                accion += 1
                                cambiarInicio = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
                .entornoSazon(almacen)
            }
        }
    }

    private func heroTemporizador(ahora: Date) -> some View {
        let activa = almacen.ayunoActivo
        let estado = activa.map { Ayuno.estado($0, ahora: ahora) }
        return VStack(spacing: Espacio.m) {
            ZStack {
                AnilloHero(valor: estado?.fraccion ?? 0, grosor: 16)
                VStack(spacing: Espacio.xxs) {
                    if let estado, let activa {
                        Text(estado.completado ? "¡Meta cumplida!" : "Te faltan")
                            .font(Tipo.pie).foregroundStyle(paleta.textoHeroSecundario)
                        Text(Ayuno.duracion(estado.completado ? estado.transcurrido : estado.restante))
                            .font(Tipo.cifra).foregroundStyle(paleta.textoHero)
                            .contentTransition(.numericText())
                        Text(estado.completado ? "de ayuno" : "de \(Formato.entero(activa.horas)) h")
                            .font(Tipo.pie).foregroundStyle(paleta.textoHeroSecundario)
                    } else {
                        Image(systemName: "timer").font(Tipo.iconoGrande).foregroundStyle(paleta.textoHero)
                        Text("Sin ayuno en curso").font(Tipo.cuerpoFuerte).foregroundStyle(paleta.textoHero)
                        Text("Protocolo \(Formato.entero(almacen.datos.horasAyuno)) h")
                            .font(Tipo.pie).foregroundStyle(paleta.textoHeroSecundario)
                    }
                }
                .multilineTextAlignment(.center)
            }
            .frame(width: Medida.anillo + 40, height: Medida.anillo + 40)
            .accessibilityElement(children: .combine)

            if let activa {
                HStack(spacing: Espacio.m) {
                    datoHero("Empezó", Formato.hora(activa.inicio))
                    datoHero("Termina", Formato.hora(activa.finPlaneado))
                    datoHero("Racha", "\(Ayuno.racha(almacen.datos.ayunos))")
                }
                botonHero("Terminar ayuno", "stop.fill") {
                    almacen.terminarAyuno()
                    accion += 1
                }
            } else {
                botonHero("Empezar ahora", "play.fill") {
                    almacen.iniciarAyuno()
                    accion += 1
                }
                Button("Ya había empezado antes…") {
                    inicioManual = Date().addingTimeInterval(-3600)
                    cambiarInicio = true
                }
                .font(Tipo.pie)
                .foregroundStyle(paleta.textoHero)
            }
        }
        .frame(maxWidth: .infinity)
        .hero()
    }

    private func datoHero(_ titulo: String, _ valor: String) -> some View {
        VStack(spacing: Espacio.xxxs) {
            Text(titulo).font(Tipo.micro).foregroundStyle(paleta.textoHeroSecundario)
            Text(valor).font(Tipo.cuerpoFuerte).foregroundStyle(paleta.textoHero)
        }
        .frame(maxWidth: .infinity)
    }

    private func botonHero(_ titulo: String, _ icono: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Label(titulo, systemImage: icono)
                .font(Tipo.cuerpoFuerte)
                .foregroundStyle(paleta.heroFin)
                .frame(maxWidth: .infinity, minHeight: Medida.toque)
                .background(Capsule().fill(paleta.textoHero))
        }
        .buttonStyle(.plain)
    }

    private var historial: some View {
        let terminados = almacen.datos.ayunos.filter { $0.finReal != nil }.sorted { $0.inicio > $1.inicio }
        return VStack(alignment: .leading, spacing: Espacio.s) {
            if terminados.isEmpty {
                Text("Aquí verás tus ayunos terminados.")
                    .font(Tipo.nota).foregroundStyle(paleta.textoSecundario)
            } else {
                ForEach(terminados.prefix(14)) { s in
                    let estado = Ayuno.estado(s, ahora: s.finReal ?? Date())
                    HStack(spacing: Espacio.s) {
                        Image(systemName: estado.completado ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(estado.completado ? paleta.exito : paleta.textoSecundario)
                        VStack(alignment: .leading, spacing: Espacio.xxxs) {
                            Text(Formato.diaRelativo(s.inicio)).font(Tipo.nota).foregroundStyle(paleta.texto)
                            Text("Meta \(Formato.entero(s.horas)) h").font(Tipo.micro).foregroundStyle(paleta.textoSecundario)
                        }
                        Spacer()
                        Text(Ayuno.duracion(estado.transcurrido)).font(Tipo.nota.monospacedDigit()).foregroundStyle(paleta.texto)
                        Menu {
                            Button("Borrar", role: .destructive) { almacen.eliminarAyuno(s) }
                        } label: {
                            Image(systemName: "ellipsis").foregroundStyle(paleta.textoSecundario)
                                .frame(width: 32, height: 32)
                        }
                    }
                    BarraProgreso(valor: estado.fraccion, color: estado.completado ? paleta.exito : paleta.aviso, alto: 4)
                }
            }
        }
        .tarjeta()
    }
}

/// Protocolo de ayuno con una barra que muestra ayuno frente a ventana de comida.
private struct TarjetaProtocolo: View {
    let nombre: String
    let horas: Double
    let elegido: Bool
    let accion: () -> Void
    @Environment(\.paleta) private var paleta

    var body: some View {
        Button(action: accion) {
            VStack(alignment: .leading, spacing: Espacio.xs) {
                Text(nombre)
                    .font(Tipo.subtitulo.monospacedDigit())
                    .foregroundStyle(elegido ? paleta.textoSobreAcento : paleta.texto)
                GeometryReader { g in
                    HStack(spacing: 2) {
                        Capsule().fill(elegido ? paleta.textoSobreAcento : paleta.proteina)
                            .frame(width: max(4, (g.size.width - 2) * horas / 24))
                        Capsule().fill(elegido ? paleta.textoSobreAcento.opacity(Opacidad.pistaHero) : paleta.carbohidratos)
                    }
                }
                .frame(height: Medida.barra)
                Text("\(Formato.entero(horas)) h ayuno · \(Formato.entero(24 - horas)) h comida")
                    .font(Tipo.micro)
                    .foregroundStyle(elegido ? paleta.textoSobreAcento : paleta.textoSecundario)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Espacio.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radio.medio, style: .continuous)
                .fill(elegido ? paleta.acento : paleta.superficieAlta))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Protocolo \(nombre): \(Formato.entero(horas)) horas de ayuno")
        .accessibilityAddTraits(elegido ? .isSelected : [])
    }
}
