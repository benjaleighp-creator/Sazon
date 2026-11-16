import WidgetKit
import SwiftUI
import ActivityKit

// Widgets de Sazón: calorías y macros, agua, ayuno y la Actividad en vivo
// del ayuno. Leen el resumen que escribe la app en el App Group. Si no hay
// App Group (firma sin ese permiso) muestran un aviso.

@main
struct SazonWidgets: WidgetBundle {
    var body: some Widget {
        WidgetCalorias()
        WidgetAgua()
        WidgetAyuno()
        WidgetBloqueo()
        ActividadAyunoWidget()
    }
}

// MARK: - Datos

struct EntradaSazon: TimelineEntry {
    let date: Date
    let resumen: ResumenWidget
    let esEjemplo: Bool
}

struct ProveedorSazon: TimelineProvider {
    func placeholder(in context: Context) -> EntradaSazon {
        EntradaSazon(date: Date(), resumen: .ejemplo, esEjemplo: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (EntradaSazon) -> Void) {
        completion(entrada())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EntradaSazon>) -> Void) {
        let ahora = Date()
        var e = entrada()
        // Si el resumen es de otro día, se muestra en cero hasta abrir la app.
        if !e.esEjemplo, !Calendar.current.isDate(e.resumen.fecha, inSameDayAs: ahora) {
            var r = e.resumen
            r.kcal = 0; r.proteina = 0; r.carbohidratos = 0; r.grasas = 0; r.aguaMl = 0
            e = EntradaSazon(date: ahora, resumen: r, esEjemplo: false)
        }
        let medianoche = Calendar.current.startOfDay(for: ahora.addingTimeInterval(86_400)).addingTimeInterval(60)
        let siguiente = min(medianoche, ahora.addingTimeInterval(30 * 60))
        completion(Timeline(entries: [e], policy: .after(siguiente)))
    }

    private func entrada() -> EntradaSazon {
        if let r = ResumenWidget.leer() {
            return EntradaSazon(date: Date(), resumen: r, esEjemplo: false)
        }
        return EntradaSazon(date: Date(), resumen: .ejemplo, esEjemplo: true)
    }
}

// MARK: - Ayudas visuales

func colorHex(_ hex: String) -> Color {
    var v: UInt64 = 0
    Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))).scanHexInt64(&v)
    return Color(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
                 blue: Double(v & 0xFF) / 255, opacity: 1)
}

private let formateadorEntero: NumberFormatter = {
    let f = NumberFormatter()
    f.locale = Locale(identifier: "es_PE")
    f.maximumFractionDigits = 0
    f.numberStyle = .decimal
    return f
}()

func entero(_ v: Double) -> String {
    formateadorEntero.string(from: NSNumber(value: v.rounded())) ?? "\(Int(v.rounded()))"
}

/// Tipografía de los widgets: estilos de texto del sistema (respetan el
/// tamaño de letra elegido) con diseño redondeado, como la app.
extension Font {
    static func estiloWidget(_ estilo: Font.TextStyle, _ peso: Font.Weight) -> Font {
        .system(estilo, design: .rounded, weight: peso)
    }
}

/// Tope del tamaño de letra en los widgets: crece con Dynamic Type, pero
/// sin pasar de «XXL» para que el contenido quepa en el espacio fijo.
extension View {
    func letraWidget() -> some View {
        dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}

func fraccion(_ valor: Double, _ meta: Double) -> Double {
    guard meta > 0 else { return 0 }
    return min(max(valor / meta, 0), 1)
}

struct FondoSazon: View {
    let r: ResumenWidget
    var body: some View {
        LinearGradient(colors: [colorHex(r.colorInicio), colorHex(r.colorFin)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct Anillo: View {
    let progreso: Double
    let color: Color
    var grosor: CGFloat = 8
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.25), lineWidth: grosor)
            Circle().trim(from: 0, to: progreso)
                .stroke(color, style: StrokeStyle(lineWidth: grosor, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct AvisoEjemplo: View {
    let r: ResumenWidget
    var body: some View {
        Text("Abre Sazón para ver tus datos")
            .font(.estiloWidget(.caption2, .medium))
            .foregroundStyle(colorHex(r.colorSecundario))
            .lineLimit(2)
    }
}

// MARK: - Calorías y macros

struct WidgetCalorias: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SazonCalorias", provider: ProveedorSazon()) { e in
            VistaCalorias(e: e)
        }
        .configurationDisplayName("Calorías de hoy")
        .description("Lo que llevas comido frente a tu meta, con proteína, carbohidratos y grasas.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct VistaCalorias: View {
    let e: EntradaSazon
    @Environment(\.widgetFamily) private var familia

    var body: some View {
        let r = e.resumen
        let texto = colorHex(r.colorTexto)
        let secundario = colorHex(r.colorSecundario)
        let restante = max(r.metaKcal - r.kcal, 0)
        Group {
            if familia == .systemMedium {
                HStack(spacing: 16) {
                    anillo(r, texto: texto, secundario: secundario, restante: restante)
                        .frame(width: 110, height: 110)
                    VStack(alignment: .leading, spacing: 8) {
                        macro("Proteína", r.proteina, r.metaProteina, texto, secundario)
                        macro("Carbohidratos", r.carbohidratos, r.metaCarbohidratos, texto, secundario)
                        macro("Grasas", r.grasas, r.metaGrasas, texto, secundario)
                        if e.esEjemplo {
                            AvisoEjemplo(r: r)
                        } else if r.racha > 0 {
                            Label("\(r.racha) \(r.racha == 1 ? "día" : "días") seguidos", systemImage: "flame.fill")
                                .font(.estiloWidget(.caption2, .semibold))
                                .foregroundStyle(secundario)
                        }
                    }
                }
            } else {
                VStack(spacing: 6) {
                    anillo(r, texto: texto, secundario: secundario, restante: restante)
                    if e.esEjemplo { AvisoEjemplo(r: r) }
                }
            }
        }
        .letraWidget()
        .containerBackground(for: .widget) { FondoSazon(r: r) }
    }

    private func anillo(_ r: ResumenWidget, texto: Color, secundario: Color, restante: Double) -> some View {
        ZStack {
            Anillo(progreso: fraccion(r.kcal, r.metaKcal), color: texto, grosor: 9)
            VStack(spacing: 0) {
                Text(entero(restante))
                    .font(.estiloWidget(.title2, .bold))
                    .foregroundStyle(texto)
                    .minimumScaleFactor(0.6)
                Text("kcal restantes")
                    .font(.estiloWidget(.caption2, .medium))
                    .foregroundStyle(secundario)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(8)
        }
    }

    private func macro(_ nombre: String, _ valor: Double, _ meta: Double, _ texto: Color, _ secundario: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(nombre).font(.estiloWidget(.caption, .semibold)).foregroundStyle(texto)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                Text("\(entero(valor))/\(entero(meta)) g")
                    .font(.estiloWidget(.caption2, .medium).monospacedDigit())
                    .foregroundStyle(secundario)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(texto.opacity(0.25))
                    Capsule().fill(texto).frame(width: g.size.width * fraccion(valor, meta))
                }
            }
            .frame(height: 5)
        }
    }
}

// MARK: - Agua

struct WidgetAgua: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SazonAgua", provider: ProveedorSazon()) { e in
            VistaAgua(e: e)
        }
        .configurationDisplayName("Agua")
        .description("Cuánta agua llevas hoy.")
        .supportedFamilies([.systemSmall])
    }
}

struct VistaAgua: View {
    let e: EntradaSazon
    var body: some View {
        let r = e.resumen
        let texto = colorHex(r.colorTexto)
        VStack(alignment: .leading, spacing: 6) {
            Label("Agua", systemImage: "drop.fill")
                .font(.estiloWidget(.footnote, .semibold))
                .foregroundStyle(texto)
            Spacer(minLength: 0)
            Text(String(format: "%.1f L", r.aguaMl / 1000).replacingOccurrences(of: ".", with: ","))
                .font(.estiloWidget(.title, .bold))
                .foregroundStyle(texto)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("de " + String(format: "%.1f L", r.metaAguaMl / 1000).replacingOccurrences(of: ".", with: ","))
                .font(.estiloWidget(.caption, .medium))
                .foregroundStyle(colorHex(r.colorSecundario))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(texto.opacity(0.25))
                    Capsule().fill(texto).frame(width: g.size.width * fraccion(r.aguaMl, r.metaAguaMl))
                }
            }
            .frame(height: 6)
            if e.esEjemplo { AvisoEjemplo(r: r) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .letraWidget()
        .containerBackground(for: .widget) { FondoSazon(r: r) }
    }
}

// MARK: - Ayuno

struct WidgetAyuno: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SazonAyuno", provider: ProveedorSazon()) { e in
            VistaAyuno(e: e)
        }
        .configurationDisplayName("Ayuno")
        .description("El tiempo de tu ayuno en curso.")
        .supportedFamilies([.systemSmall])
    }
}

struct VistaAyuno: View {
    let e: EntradaSazon
    var body: some View {
        let r = e.resumen
        let texto = colorHex(r.colorTexto)
        let secundario = colorHex(r.colorSecundario)
        VStack(alignment: .leading, spacing: 6) {
            Label("Ayuno", systemImage: "timer")
                .font(.estiloWidget(.footnote, .semibold))
                .foregroundStyle(texto)
            Spacer(minLength: 0)
            if let inicio = r.ayunoInicio, let horas = r.ayunoHoras {
                let fin = inicio.addingTimeInterval(horas * 3600)
                if fin > Date() {
                    Text(timerInterval: Date()...fin, countsDown: true)
                        .font(.estiloWidget(.title, .bold).monospacedDigit())
                        .foregroundStyle(texto)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("para tus \(entero(horas)) h")
                        .font(.estiloWidget(.caption, .medium))
                        .foregroundStyle(secundario)
                } else {
                    Text("¡Listo!")
                        .font(.estiloWidget(.title, .bold))
                        .foregroundStyle(texto)
                    Text("Completaste \(entero(horas)) h")
                        .font(.estiloWidget(.caption, .medium))
                        .foregroundStyle(secundario)
                }
            } else {
                Text("Sin ayuno")
                    .font(.estiloWidget(.title3, .bold))
                    .foregroundStyle(texto)
                Text("Empieza uno en la app")
                    .font(.estiloWidget(.caption, .medium))
                    .foregroundStyle(secundario)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .letraWidget()
        .containerBackground(for: .widget) { FondoSazon(r: r) }
    }
}

// MARK: - Pantalla bloqueada

struct WidgetBloqueo: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SazonBloqueo", provider: ProveedorSazon()) { e in
            VistaBloqueo(e: e)
        }
        .configurationDisplayName("Sazón en la pantalla bloqueada")
        .description("Calorías restantes de hoy.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct VistaBloqueo: View {
    let e: EntradaSazon
    @Environment(\.widgetFamily) private var familia

    var body: some View {
        let r = e.resumen
        let restante = max(r.metaKcal - r.kcal, 0)
        Group {
            switch familia {
            case .accessoryCircular:
                Gauge(value: fraccion(r.kcal, r.metaKcal)) {
                    Image(systemName: "fork.knife")
                } currentValueLabel: {
                    Text(entero(restante)).minimumScaleFactor(0.5)
                }
                .gaugeStyle(.accessoryCircular)
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sazón").font(.headline)
                    Text("\(entero(restante)) kcal restantes")
                    Text("Agua \(entero(r.aguaMl)) / \(entero(r.metaAguaMl)) ml").foregroundStyle(.secondary)
                }
            default:
                Text("\(entero(restante)) kcal restantes")
            }
        }
        .letraWidget()
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Actividad en vivo del ayuno

struct ActividadAyunoWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AtributosAyuno.self) { contexto in
            let a = contexto.attributes
            let texto = colorHex(a.colorTexto)
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .font(.estiloWidget(.title, .semibold))
                    .foregroundStyle(texto)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ayuno de \(entero(a.horas)) h")
                        .font(.estiloWidget(.subheadline, .semibold))
                        .foregroundStyle(texto)
                    if contexto.state.fin > Date() {
                        Text(timerInterval: Date()...contexto.state.fin, countsDown: true)
                            .font(.estiloWidget(.title, .bold).monospacedDigit())
                            .foregroundStyle(texto)
                    } else {
                        Text("¡Completado!")
                            .font(.estiloWidget(.title, .bold))
                            .foregroundStyle(texto)
                    }
                }
                Spacer()
                ProgressView(timerInterval: a.inicio...contexto.state.fin, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.circular)
                    .tint(texto)
            }
            .padding(16)
            .letraWidget()
            .activityBackgroundTint(colorHex(a.colorFin))
            .activitySystemActionForegroundColor(texto)
        } dynamicIsland: { contexto in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Ayuno", systemImage: "timer")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(entero(contexto.attributes.horas)) h")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(timerInterval: Date()...max(contexto.state.fin, Date()), countsDown: true)
                        .font(.estiloWidget(.title, .bold).monospacedDigit())
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(timerInterval: Date()...max(contexto.state.fin, Date()), countsDown: true)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
}
