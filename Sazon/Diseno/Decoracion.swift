import SwiftUI

// Piezas decorativas de la identidad «Mercado»: estampado de ingredientes,
// resplandor del fondo, encabezados de sección y colores por comida. Todo es
// decorativo (oculto a VoiceOver) y estático: no gasta batería.

/// Estampado de ingredientes dibujado con SF Symbols, en diagonal.
struct EstampadoMercado: View {
    var color: Color
    private static let simbolos = ["leaf.fill", "carrot.fill", "fish.fill", "cup.and.saucer.fill",
                                   "fork.knife", "takeoutbag.and.cup.and.straw.fill", "birthday.cake.fill", "drop.fill"]

    var body: some View {
        Canvas { contexto, tamano in
            let paso = Medida.pasoEstampado
            let columnas = Int(tamano.width / paso) + 2
            let filas = Int(tamano.height / paso) + 2
            for f in 0..<filas {
                for c in 0..<columnas {
                    let indice = (f * 3 + c) % Self.simbolos.count
                    guard let simbolo = contexto.resolveSymbol(id: indice) else { continue }
                    let desplazamiento = f.isMultiple(of: 2) ? 0 : paso / 2
                    let punto = CGPoint(x: CGFloat(c) * paso + desplazamiento, y: CGFloat(f) * paso)
                    contexto.draw(simbolo, at: punto)
                }
            }
        } symbols: {
            ForEach(Array(Self.simbolos.enumerated()), id: \.offset) { i, nombre in
                Image(systemName: nombre)
                    .font(.system(size: Medida.iconoEstampado, weight: .semibold))
                    .foregroundStyle(color)
                    .rotationEffect(.degrees(Double((i % 3) - 1) * 18))
                    .tag(i)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Resplandor cálido detrás del contenido, arriba de la pantalla.
struct ResplandorFondo: View {
    @Environment(\.paleta) private var paleta

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [paleta.acentoSuave.opacity(Opacidad.resplandor), paleta.fondo.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: Medida.resplandor)
            Spacer(minLength: 0)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Encabezado de sección con ícono, título y una acción opcional.
struct EncabezadoSeccion<Accion: View>: View {
    let titulo: String
    var icono: String? = nil
    var detalle: String? = nil
    @ViewBuilder var accion: () -> Accion
    @Environment(\.paleta) private var paleta

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Espacio.xs) {
            if let icono {
                Image(systemName: icono)
                    .font(Tipo.iconoDato)
                    .foregroundStyle(paleta.acento)
                    .accessibilityHidden(true)
            }
            Text(titulo)
                .font(Tipo.subtitulo)
                .foregroundStyle(paleta.texto)
                .accessibilityAddTraits(.isHeader)
            if let detalle {
                Text(detalle).font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
            }
            Spacer(minLength: Espacio.xs)
            accion()
        }
    }
}

extension EncabezadoSeccion where Accion == EmptyView {
    init(titulo: String, icono: String? = nil, detalle: String? = nil) {
        self.titulo = titulo
        self.icono = icono
        self.detalle = detalle
        self.accion = { EmptyView() }
    }
}

extension Paleta {
    /// Color de cada comida (se usa en azulejos y anillos; los textos van
    /// siempre con el color de texto).
    func color(_ comida: TipoComida) -> Color {
        switch comida {
        case .desayuno: return carbohidratos
        case .mediaManana: return grasas
        case .mediaTarde: return carbohidratos
        case .almuerzo: return calorias
        case .cena: return proteina
        case .snacks: return grasas
        }
    }
}

/// Azulejo grande con degradado lleno del color (para comidas y accesos).
struct AzulejoColor: View {
    let simbolo: String
    let color: Color
    var tamano: CGFloat = 48
    @ScaledMetric(relativeTo: .body) private var escala: CGFloat = 1

    var body: some View {
        let l = tamano * min(escala, 1.5)
        Image(systemName: simbolo)
            .font(.system(size: l * 0.42, weight: .bold))
            .foregroundStyle(color)
            .frame(width: l, height: l)
            .background(
                RoundedRectangle(cornerRadius: l * 0.32, style: .continuous)
                    .fill(LinearGradient(colors: [color.opacity(Opacidad.azulejoFuerte), color.opacity(Opacidad.azulejoSuave)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(alignment: .topTrailing) {
                Circle().fill(color).frame(width: l * 0.16, height: l * 0.16).offset(x: -l * 0.12, y: l * 0.12)
            }
            .accessibilityHidden(true)
    }
}
