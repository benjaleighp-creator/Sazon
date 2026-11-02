import SwiftUI

/// Etapa de la animación sobre la foto.
enum FaseDeteccion: Equatable {
    case inactiva
    /// La IA está analizando: los puntos se mueven sobre la foto.
    case esperando(inicio: Date)
    /// Llegó la respuesta: los puntos se reúnen y aparecen las etiquetas.
    case detectando(inicio: Date, desdeEspera: Double)
    /// Falló la IA: todo se detiene.
    case detenida
}

/// Capa que se dibuja encima de la foto (mismo tamaño que la foto).
struct CapaDeteccion: View {
    let fase: FaseDeteccion
    let alimentos: [AlimentoIdentificado]
    /// Cuántas etiquetas ya se muestran (se revelan una tras otra).
    let visibles: Int

    @Environment(\.paleta) private var paleta
    @Environment(\.accessibilityReduceMotion) private var reducir
    @Environment(\.ahorroActivo) private var ahorro
    @State private var fundido = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                switch fase {
                case .inactiva:
                    EmptyView()
                case .detenida:
                    Color.black.opacity(Opacidad.capsulaHero)
                case .esperando, .detectando:
                    if reducir {
                        // Solo un fundido, sin movimiento.
                        paleta.acento.opacity(fundido ? Opacidad.pistaHero : 0)
                            .onAppear { withAnimation(.easeInOut(duration: 0.6)) { fundido = true } }
                    } else {
                        puntos(geo.size)
                    }
                    cajas(geo.size)
                    etiquetasSobreFoto(geo.size)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Puntos

    private func puntos(_ tam: CGSize) -> some View {
        let n = Deteccion.cantidadPuntos(ahorro: ahorro)
        let cajas = alimentos.map(\.caja)
        // Con ahorro de batería: unos 15 cuadros por segundo.
        return TimelineView(.animation(minimumInterval: ahorro ? 1.0 / 15 : nil, paused: false)) { contexto in
            Canvas { ctx, size in
                for i in 0..<n {
                    let p: (x: Double, y: Double)
                    switch fase {
                    case .esperando(let inicio):
                        p = Deteccion.deambular(i, t: contexto.date.timeIntervalSince(inicio))
                    case .detectando(let inicio, let t0):
                        let avance = contexto.date.timeIntervalSince(inicio) / 0.6
                        p = Deteccion.reunir(i, desde: t0, avance: avance, cajas: cajas)
                    default:
                        p = (0.5, 0.5)
                    }
                    let radio = Medida.puntoDeteccion * (1 + Deteccion.azar(i, 9))
                    let centro = CGPoint(x: p.x * size.width, y: p.y * size.height)
                    let brillo = CGRect(x: centro.x - radio * 3, y: centro.y - radio * 3, width: radio * 6, height: radio * 6)
                    ctx.fill(Path(ellipseIn: brillo), with: .color(paleta.textoHero.opacity(Opacidad.capsulaHero)))
                    let punto = CGRect(x: centro.x - radio, y: centro.y - radio, width: radio * 2, height: radio * 2)
                    ctx.fill(Path(ellipseIn: punto), with: .color(paleta.textoHero))
                }
            }
        }
        .frame(width: tam.width, height: tam.height)
    }

    // MARK: Cajas y etiquetas

    @ViewBuilder
    private func cajas(_ tam: CGSize) -> some View {
        if case .detectando = fase {
            ForEach(Array(alimentos.enumerated()), id: \.offset) { i, a in
                if let c = a.caja, i < visibles {
                    RoundedRectangle(cornerRadius: Radio.chico, style: .continuous)
                        .strokeBorder(paleta.textoHero.opacity(Opacidad.bordeCaja), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .frame(width: c.ancho * tam.width, height: c.alto * tam.height)
                        .position(x: c.centro.x * tam.width, y: c.centro.y * tam.height)
                        .transition(.opacity)
                }
            }
        }
    }

    @ViewBuilder
    private func etiquetasSobreFoto(_ tam: CGSize) -> some View {
        if case .detectando = fase {
            ForEach(Array(alimentos.enumerated()), id: \.offset) { i, a in
                if let c = a.caja, i < visibles {
                    EtiquetaDeteccion(alimento: a)
                        .fixedSize()
                        .position(x: min(max(c.centro.x * tam.width, Medida.margenEtiquetaX), tam.width - Medida.margenEtiquetaX),
                                  y: min(max(c.centro.y * tam.height, Medida.margenEtiquetaY), tam.height - Medida.margenEtiquetaY))
                        .transition(reducir ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
                }
            }
        }
    }
}

/// Etiqueta con el nombre y los gramos de un alimento detectado.
struct EtiquetaDeteccion: View {
    let alimento: AlimentoIdentificado
    @Environment(\.paleta) private var paleta

    var body: some View {
        HStack(spacing: Espacio.xxs) {
            Image(systemName: "sparkle").font(Tipo.micro)
            Text(alimento.nombre).font(Tipo.pie.weight(.semibold)).lineLimit(1)
            Text("≈ \(Formato.entero(alimento.gramos)) g").font(Tipo.micro.monospacedDigit())
        }
        .foregroundStyle(paleta.textoSobreAcento)
        .padding(.horizontal, Espacio.s)
        .padding(.vertical, Espacio.xxs)
        .background(Capsule().fill(paleta.acento))
        .overlay(Capsule().strokeBorder(paleta.textoSobreAcento.opacity(Opacidad.pistaHero), lineWidth: 1))
    }
}

/// Lista debajo de la foto con los alimentos que no traen caja.
struct ListaDetectados: View {
    let alimentos: [AlimentoIdentificado]
    let visibles: Int
    @Environment(\.accessibilityReduceMotion) private var reducir

    var body: some View {
        let sinCaja = Array(alimentos.enumerated()).filter { $0.element.caja == nil }
        if !sinCaja.isEmpty {
            FilaFlexible(espacio: Espacio.xs) {
                ForEach(sinCaja, id: \.offset) { i, a in
                    if i < visibles {
                        EtiquetaDeteccion(alimento: a)
                            .transition(reducir ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Detectado: " + sinCaja.prefix(visibles).map { "\($0.element.nombre), \(Formato.entero($0.element.gramos)) gramos" }.joined(separator: "; "))
        }
    }
}
