import SwiftUI

// Componentes base de Sazón. Todos leen la paleta activa del entorno.

// MARK: - Botones

struct EstiloBotonPrincipal: ButtonStyle {
    @Environment(\.paleta) private var paleta
    @Environment(\.isEnabled) private var habilitado
    @Environment(\.accessibilityReduceMotion) private var reducir

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tipo.cuerpoFuerte)
            .foregroundStyle(paleta.textoSobreAcento)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: Medida.toque)
            .padding(.horizontal, Espacio.m)
            .background(
                RoundedRectangle(cornerRadius: Radio.medio, style: .continuous)
                    .fill(paleta.acento)
            )
            .opacity(habilitado ? (configuration.isPressed ? 0.88 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reducir ? 0.97 : 1)
            .animation(Movimiento.micro.animacion(reducir: reducir), value: configuration.isPressed)
    }
}

struct EstiloBotonSecundario: ButtonStyle {
    @Environment(\.paleta) private var paleta
    @Environment(\.isEnabled) private var habilitado
    @Environment(\.accessibilityReduceMotion) private var reducir

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tipo.cuerpoFuerte)
            .foregroundStyle(paleta.acento)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: Medida.toque)
            .padding(.horizontal, Espacio.m)
            .background(
                RoundedRectangle(cornerRadius: Radio.medio, style: .continuous)
                    .fill(paleta.acentoSuave)
            )
            .opacity(habilitado ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reducir ? 0.97 : 1)
            .animation(Movimiento.micro.animacion(reducir: reducir), value: configuration.isPressed)
    }
}

struct EstiloBotonTexto: ButtonStyle {
    @Environment(\.paleta) private var paleta
    var color: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tipo.cuerpoFuerte)
            .foregroundStyle(color ?? paleta.acento)
            .padding(.vertical, Espacio.xs)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == EstiloBotonPrincipal {
    static var principal: EstiloBotonPrincipal { EstiloBotonPrincipal() }
}

extension ButtonStyle where Self == EstiloBotonSecundario {
    static var secundario: EstiloBotonSecundario { EstiloBotonSecundario() }
}

extension ButtonStyle where Self == EstiloBotonTexto {
    static var texto: EstiloBotonTexto { EstiloBotonTexto() }
}

// MARK: - Tarjeta y fondo

private struct ModificadorTarjeta: ViewModifier {
    @Environment(\.paleta) private var paleta
    @Environment(\.temaActivo) private var tema
    @Environment(\.colorScheme) private var esquema
    var relleno: CGFloat

    func body(content: Content) -> some View {
        let radio = tema.estilo.radioTarjeta
        let suave = Sombra.suave(esquema)
        let conSombra = tema.estilo.sombra == .suave
        let colorSombra: Color = conSombra ? suave.color : Color.clear
        let radioSombra: CGFloat = conSombra ? suave.radio : 0
        let ySombra: CGFloat = conSombra ? suave.y : 0
        return content
            .padding(relleno)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radio, style: .continuous)
                    .fill(paleta.superficie)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radio, style: .continuous)
                    .strokeBorder(paleta.borde, lineWidth: 1)
            )
            .shadow(color: colorSombra, radius: radioSombra, x: 0, y: ySombra)
    }
}

private struct FondoPantalla: ViewModifier {
    @Environment(\.paleta) private var paleta
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background {
                ZStack {
                    paleta.fondo.ignoresSafeArea()
                    ResplandorFondo()
                }
            }
    }
}

private struct BarraInferior: ViewModifier {
    @Environment(\.paleta) private var paleta
    func body(content: Content) -> some View {
        content
            .padding(.top, Espacio.s)
            .frame(maxWidth: .infinity)
            .background(paleta.fondo.opacity(0.96).ignoresSafeArea(edges: .bottom))
    }
}

extension View {
    /// Envuelve el contenido en una tarjeta del tema.
    func tarjeta(relleno: CGFloat = Espacio.m) -> some View {
        modifier(ModificadorTarjeta(relleno: relleno))
    }

    /// Fondo para los botones fijos al pie de la pantalla: así el texto que
    /// se desplaza por debajo no se ve detrás ni debajo del botón.
    func barraInferior() -> some View {
        modifier(BarraInferior())
    }

    /// Fondo de pantalla del tema.
    func fondoDePantalla() -> some View {
        modifier(FondoPantalla())
    }
}

// MARK: - Chip y filas flexibles

struct Chip: View {
    let texto: String
    var icono: String? = nil
    let seleccionado: Bool
    let accion: () -> Void
    @Environment(\.paleta) private var paleta
    @Environment(\.accessibilityReduceMotion) private var reducir

    var body: some View {
        Button(action: accion) {
            HStack(spacing: Espacio.xxs) {
                if let icono { Image(systemName: icono).font(Tipo.iconoChico) }
                Text(texto).font(Tipo.pie)
            }
            .padding(.horizontal, Espacio.s)
            .padding(.vertical, Espacio.xs)
            .frame(minHeight: 36)
            .foregroundStyle(seleccionado ? paleta.textoSobreAcento : paleta.texto)
            .background(Capsule().fill(seleccionado ? paleta.acento : paleta.superficieAlta))
            .overlay(Capsule().strokeBorder(seleccionado ? Color.clear : paleta.borde, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(Movimiento.seleccion.animacion(reducir: reducir), value: seleccionado)
        .sensoryFeedback(.selection, trigger: seleccionado)
        .accessibilityAddTraits(seleccionado ? .isSelected : [])
    }
}

/// Distribuye vistas en varias líneas (izquierda o centradas).
struct FilaFlexible: Layout {
    var espacio: CGFloat = Espacio.xs
    var centrada: Bool = false

    init(espacio: CGFloat = Espacio.xs, centrada: Bool = false) {
        self.espacio = espacio
        self.centrada = centrada
    }

    private func filas(ancho: CGFloat, subviews: Subviews) -> [[(indice: Int, tamano: CGSize)]] {
        var resultado: [[(indice: Int, tamano: CGSize)]] = [[]]
        var x: CGFloat = 0
        for (i, vista) in subviews.enumerated() {
            let t = vista.sizeThatFits(.unspecified)
            let tamano = CGSize(width: min(t.width, ancho), height: t.height)
            if x + tamano.width > ancho && x > 0 {
                resultado.append([])
                x = 0
            }
            resultado[resultado.count - 1].append((indice: i, tamano: tamano))
            x += tamano.width + espacio
        }
        return resultado
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ancho = proposal.width ?? .infinity
        let lista = filas(ancho: ancho, subviews: subviews)
        var alto: CGFloat = 0
        var anchoMax: CGFloat = 0
        for (n, fila) in lista.enumerated() {
            let anchoFila = fila.reduce(0) { $0 + $1.tamano.width } + espacio * CGFloat(max(0, fila.count - 1))
            anchoMax = max(anchoMax, anchoFila)
            alto += (fila.map(\.tamano.height).max() ?? 0) + (n > 0 ? espacio : 0)
        }
        return CGSize(width: ancho == .infinity ? anchoMax : ancho, height: alto)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for fila in filas(ancho: bounds.width, subviews: subviews) {
            let anchoFila = fila.reduce(0) { $0 + $1.tamano.width } + espacio * CGFloat(max(0, fila.count - 1))
            var x = centrada ? bounds.minX + (bounds.width - anchoFila) / 2 : bounds.minX
            let altoFila = fila.map(\.tamano.height).max() ?? 0
            for elemento in fila {
                subviews[elemento.indice].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(elemento.tamano))
                x += elemento.tamano.width + espacio
            }
            y += altoFila + espacio
        }
    }
}

/// Varios datos en fila; si con letra grande no caben, pasan a columna.
struct FilaDatos<Contenido: View>: View {
    @ViewBuilder let contenido: () -> Contenido

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Espacio.s) { contenido() }
            VStack(alignment: .leading, spacing: Espacio.s) { contenido() }
        }
    }
}

// MARK: - Progreso

/// Barra horizontal de progreso (0 a 1).
struct BarraProgreso: View {
    let valor: Double
    var color: Color? = nil
    var alto: CGFloat = Medida.barra
    @Environment(\.paleta) private var paleta
    @Environment(\.accessibilityReduceMotion) private var reducir
    @Environment(\.ahorroActivo) private var ahorro
    @State private var mostrado = false

    var body: some View {
        let fraccion = CGFloat(min(max(valor, 0), 1))
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(paleta.superficieAlta)
                Capsule()
                    .fill(color ?? paleta.acento)
                    .frame(width: max(alto, geo.size.width * (mostrado ? fraccion : 0)))
                    .opacity(valor <= 0 ? 0 : 1)
            }
        }
        .frame(height: alto)
        .onAppear {
            withAnimation(Movimiento.progreso.animacion(reducir: reducir || ahorro)) { mostrado = true }
        }
        .animation(Movimiento.progreso.animacion(reducir: reducir || ahorro), value: valor)
        .accessibilityHidden(true)
    }
}

/// Anillo circular de progreso (0 a 1).
struct AnilloProgreso: View {
    let valor: Double
    var grosor: CGFloat = Medida.grosorAnillo
    var color: Color? = nil
    @Environment(\.paleta) private var paleta
    @Environment(\.accessibilityReduceMotion) private var reducir
    @Environment(\.ahorroActivo) private var ahorro
    @State private var mostrado = false

    var body: some View {
        let fraccion = CGFloat(min(max(valor, 0), 1))
        ZStack {
            Circle().stroke(paleta.superficieAlta, lineWidth: grosor)
            Circle()
                .trim(from: 0, to: mostrado ? fraccion : 0)
                .stroke(color ?? paleta.acento, style: StrokeStyle(lineWidth: grosor, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(grosor / 2)
        .onAppear {
            withAnimation(Movimiento.progreso.animacion(reducir: reducir || ahorro)) { mostrado = true }
        }
        .animation(Movimiento.progreso.animacion(reducir: reducir || ahorro), value: valor)
        .accessibilityHidden(true)
    }
}

// MARK: - Piezas pequeñas

/// Ícono SF Symbol dentro de un círculo suave.
struct IconoCirculo: View {
    let simbolo: String
    var tamano: CGFloat = 36
    var color: Color? = nil
    var fondo: Color? = nil
    @Environment(\.paleta) private var paleta
    @ScaledMetric(relativeTo: .body) private var escala: CGFloat = 1

    var body: some View {
        let lado = tamano * min(escala, 1.6)
        Image(systemName: simbolo)
            .font(.system(size: lado * 0.45, weight: .medium))
            .foregroundStyle(color ?? paleta.acento)
            .frame(width: lado, height: lado)
            .background(Circle().fill(fondo ?? paleta.acentoSuave))
            .accessibilityHidden(true)
    }
}

/// Título pequeño de sección en mayúsculas.
struct TituloSeccion: View {
    let texto: String
    @Environment(\.paleta) private var paleta

    init(_ texto: String) { self.texto = texto }

    var body: some View {
        Text(texto.uppercased())
            .font(Tipo.micro)
            .tracking(0.8)
            .foregroundStyle(paleta.textoSecundario)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Punto de color que acompaña el nombre de un macro (el nombre va con el
/// color de texto, nunca con el color del dato).
struct PuntoMacro: View {
    let macro: Macro
    @Environment(\.paleta) private var paleta
    @ScaledMetric(relativeTo: .footnote) private var lado: CGFloat = 8

    var body: some View {
        Circle()
            .fill(paleta.color(macro))
            .frame(width: min(lado, 14), height: min(lado, 14))
            .accessibilityHidden(true)
    }
}

/// Etiqueta pequeña de estado.
struct Insignia: View {
    let texto: String
    var icono: String? = nil
    var color: Color? = nil
    @Environment(\.paleta) private var paleta

    var body: some View {
        HStack(spacing: Espacio.xxs) {
            if let icono { Image(systemName: icono).font(Tipo.micro) }
            Text(texto).font(Tipo.micro)
        }
        .foregroundStyle(color ?? paleta.texto)
        .lineLimit(1)
        .padding(.horizontal, Espacio.xs)
        .padding(.vertical, Espacio.xxs)
        .background(Capsule().fill(paleta.superficieAlta))
        .overlay(Capsule().strokeBorder(paleta.borde, lineWidth: 1))
    }
}

/// Insignia con el origen de los datos de un registro.
struct InsigniaOrigen: View {
    let origen: OrigenDato

    var body: some View {
        Insignia(texto: origen.etiqueta, icono: icono)
            .accessibilityLabel("Origen: \(origen.etiqueta)")
    }

    private var icono: String {
        switch origen {
        case .ins: return "book.closed"
        case .openFoodFacts: return "barcode"
        case .estimadoIA: return "sparkles"
        case .manual: return "pencil"
        case .envase: return "doc.text.viewfinder"
        }
    }
}

/// Mensaje de estado vacío.
struct EstadoVacio: View {
    let icono: String
    let titulo: String
    let texto: String
    @Environment(\.paleta) private var paleta

    var body: some View {
        VStack(spacing: Espacio.s) {
            IconoCirculo(simbolo: icono, tamano: 56)
            Text(titulo)
                .font(Tipo.subtitulo)
                .foregroundStyle(paleta.texto)
                .multilineTextAlignment(.center)
            Text(texto)
                .font(Tipo.nota)
                .foregroundStyle(paleta.textoSecundario)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Espacio.l)
        .accessibilityElement(children: .combine)
    }
}

/// Aviso con ícono (errores, límites, privacidad).
struct Aviso: View {
    let icono: String
    let titulo: String
    let texto: String
    var color: Color? = nil
    @Environment(\.paleta) private var paleta

    var body: some View {
        HStack(alignment: .top, spacing: Espacio.s) {
            Image(systemName: icono)
                .font(Tipo.iconoFila)
                .foregroundStyle(color ?? paleta.aviso)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Espacio.xxs) {
                Text(titulo)
                    .font(Tipo.cuerpoFuerte)
                    .foregroundStyle(paleta.texto)
                Text(texto)
                    .font(Tipo.nota)
                    .foregroundStyle(paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tarjeta()
        .accessibilityElement(children: .combine)
    }
}

/// Campo de texto con estilo del tema.
struct CampoTexto: View {
    let titulo: String
    @Binding var texto: String
    var eje: Axis = .horizontal
    @Environment(\.paleta) private var paleta

    var body: some View {
        TextField(titulo, text: $texto, axis: eje)
            .font(Tipo.cuerpo)
            .foregroundStyle(paleta.texto)
            .padding(.horizontal, Espacio.m)
            .padding(.vertical, Espacio.s)
            .frame(minHeight: Medida.toque)
            .background(
                RoundedRectangle(cornerRadius: Radio.medio, style: .continuous)
                    .fill(paleta.superficieAlta)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radio.medio, style: .continuous)
                    .strokeBorder(paleta.borde, lineWidth: 1)
            )
    }
}

/// Campo numérico que acepta coma o punto decimal ("2,5" o "2.5").
struct CampoNumero: View {
    let titulo: String
    @Binding var valor: Double
    var unidad: String? = nil
    var decimales: Int = 1
    @Environment(\.paleta) private var paleta
    @State private var texto = ""
    @FocusState private var enfocado: Bool

    var body: some View {
        HStack(spacing: Espacio.xs) {
            TextField(titulo, text: $texto)
                .keyboardType(.decimalPad)
                .focused($enfocado)
                .font(Tipo.cuerpo.monospacedDigit())
                .foregroundStyle(paleta.texto)
                .onChange(of: texto) { _, nuevo in
                    let limpio = nuevo.trimmingCharacters(in: .whitespaces)
                    if limpio.isEmpty {
                        // Borrar el campo deja el valor en 0 (antes quedaba el anterior).
                        valor = 0
                    } else if let numero = Double(limpio.replacingOccurrences(of: ",", with: ".")), numero.isFinite {
                        valor = numero
                    }
                }
            if let unidad {
                Text(unidad)
                    .font(Tipo.nota)
                    .foregroundStyle(paleta.textoSecundario)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Espacio.m)
        .frame(minHeight: Medida.toque)
        .background(
            RoundedRectangle(cornerRadius: Radio.medio, style: .continuous)
                .fill(paleta.superficieAlta)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radio.medio, style: .continuous)
                .strokeBorder(enfocado ? paleta.acento : paleta.borde, lineWidth: enfocado ? 2 : 1)
        )
        .onAppear { texto = valor == 0 ? "" : Formato.numero(valor, decimales: decimales) }
        .onChange(of: valor) { _, nuevo in
            // Si el valor cambió desde fuera (por ejemplo, una medida casera),
            // se actualiza el texto sin pelear con lo que escribes.
            let actual = Double(texto.replacingOccurrences(of: ",", with: "."))
            if actual != nuevo && !enfocado {
                texto = nuevo == 0 ? "" : Formato.numero(nuevo, decimales: decimales)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(titulo + (unidad.map { " en \($0)" } ?? ""))
    }
}

/// Fila con un dato a la derecha (Ajustes y detalles).
struct FilaValor: View {
    let titulo: String
    let valor: String
    @Environment(\.paleta) private var paleta

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(titulo).foregroundStyle(paleta.texto)
                Spacer(minLength: Espacio.s)
                Text(valor).foregroundStyle(paleta.textoSecundario).multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: Espacio.xxxs) {
                Text(titulo).foregroundStyle(paleta.texto)
                Text(valor).foregroundStyle(paleta.textoSecundario)
            }
        }
        .font(Tipo.cuerpo)
        .accessibilityElement(children: .combine)
    }
}
