import SwiftUI

// Componentes visuales de la versión "rica": encabezado con degradado,
// tira semanal, botón flotante, azulejos de íconos y barras apiladas.
// Todos leen la paleta del tema; el texto sobre el degradado usa siempre
// `textoHero` / `textoHeroSecundario` (contraste verificado en ambos extremos).

// MARK: - Encabezado con degradado

private struct ModificadorHero: ViewModifier {
    @Environment(\.paleta) private var paleta
    @Environment(\.colorScheme) private var esquema
    var relleno: CGFloat

    func body(content: Content) -> some View {
        let sombra = Sombra.elevada(esquema)
        return content
            .padding(relleno)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Radio.grande, style: .continuous)
                        .fill(paleta.degradadoHero)
                    // Estampado de ingredientes (decorativo, muy tenue).
                    EstampadoMercado(color: paleta.textoHero.opacity(Opacidad.estampado))
                        .clipShape(RoundedRectangle(cornerRadius: Radio.grande, style: .continuous))
                    // Brillo suave arriba a la izquierda (decorativo).
                    RoundedRectangle(cornerRadius: Radio.grande, style: .continuous)
                        .fill(
                            RadialGradient(colors: [paleta.textoHero.opacity(Opacidad.brillo), .clear],
                                           center: .topLeading, startRadius: 0, endRadius: 260)
                        )
                }
            )
            .shadow(color: paleta.heroFin.opacity(esquema == .dark ? 0.5 : 0.28), radius: sombra.radio, x: 0, y: sombra.y)
    }
}

extension View {
    /// Tarjeta con el degradado del tema (encabezados).
    func hero(relleno: CGFloat = Espacio.l) -> some View {
        modifier(ModificadorHero(relleno: relleno))
    }
}

/// Anillo para usar sobre el degradado (color de texto del encabezado).
struct AnilloHero: View {
    let valor: Double
    var grosor: CGFloat = Medida.grosorAnillo
    @Environment(\.paleta) private var paleta
    @Environment(\.accessibilityReduceMotion) private var reducir
    @Environment(\.ahorroActivo) private var ahorro
    @State private var mostrado = false

    var body: some View {
        let fraccion = CGFloat(min(max(valor, 0), 1))
        ZStack {
            Circle().stroke(paleta.textoHero.opacity(0.22), lineWidth: grosor)
            Circle()
                .trim(from: 0, to: mostrado ? fraccion : 0)
                .stroke(paleta.textoHero, style: StrokeStyle(lineWidth: grosor, lineCap: .round))
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

/// Macro pequeño sobre el encabezado: anillo, cifra y nombre.
struct MacroHero: View {
    let macro: Macro
    let consumido: Double
    let meta: Double
    var estimado: Bool = false
    @Environment(\.paleta) private var paleta
    @ScaledMetric(relativeTo: .footnote) private var lado: CGFloat = 46

    var body: some View {
        let p = Progreso(consumido: consumido, meta: meta)
        let l = min(lado, 72)
        VStack(spacing: Espacio.xs) {
            ZStack {
                AnilloHero(valor: p.fraccion, grosor: 5)
                Text(Formato.entero(p.fraccion * 100) + "%")
                    .font(Tipo.micro.monospacedDigit())
                    .foregroundStyle(paleta.textoHero)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(Espacio.xxs)
            }
            .frame(width: l, height: l)
            VStack(spacing: Espacio.xxxs) {
                Text(macro.nombre)
                    .font(Tipo.pie)
                    .foregroundStyle(paleta.textoHero)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("\(estimado ? "≈ " : "")\(Formato.entero(consumido))/\(Formato.entero(meta)) g")
                    .font(Tipo.micro.monospacedDigit())
                    .foregroundStyle(paleta.textoHeroSecundario)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(macro.nombre)
        .accessibilityValue("\(estimado ? "aproximadamente " : "")\(Formato.entero(consumido)) de \(Formato.entero(meta)) gramos")
    }
}

// MARK: - Tira de la semana

struct TiraSemana: View {
    let dias: [DiaSemana]
    let seleccionado: Date
    let alElegir: (Date) -> Void
    @Environment(\.paleta) private var paleta

    var body: some View {
        HStack(spacing: Espacio.xxs) {
            ForEach(dias) { d in
                DiaTira(dia: d, seleccionado: Calendar.current.isDate(d.fecha, inSameDayAs: seleccionado)) {
                    alElegir(d.fecha)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: seleccionado)
    }
}

private struct DiaTira: View {
    let dia: DiaSemana
    let seleccionado: Bool
    let accion: () -> Void
    @Environment(\.paleta) private var paleta
    @ScaledMetric(relativeTo: .caption) private var lado: CGFloat = 30

    var body: some View {
        let hoy = Calendar.current.isDateInToday(dia.fecha)
        let l = min(lado, 46)
        Button(action: accion) {
            VStack(spacing: Espacio.xxs) {
                Text(Formato.inicialDia(dia.fecha))
                    .font(Tipo.micro)
                    .foregroundStyle(seleccionado ? paleta.textoSobreAcento : paleta.textoSecundario)
                ZStack {
                    Circle().stroke(seleccionado ? paleta.textoSobreAcento.opacity(0.3) : paleta.superficieAlta, lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: CGFloat(dia.fraccion))
                        .stroke(seleccionado ? paleta.textoSobreAcento : paleta.calorias,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(Formato.numeroDia(dia.fecha))
                        .font(Tipo.pie.monospacedDigit())
                        .foregroundStyle(seleccionado ? paleta.textoSobreAcento : paleta.texto)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: l, height: l)
                Circle()
                    .fill(hoy ? (seleccionado ? paleta.textoSobreAcento : paleta.acento) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .padding(.vertical, Espacio.xs)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Radio.medio, style: .continuous)
                    .fill(seleccionado ? paleta.acento : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Formato.diaLargo(dia.fecha) + (hoy ? ", hoy" : ""))
        .accessibilityValue(dia.tieneRegistros ? "\(Formato.entero(dia.kcal)) kilocalorías" : "Sin registros")
        .accessibilityAddTraits(seleccionado ? .isSelected : [])
    }
}

// MARK: - Azulejos e íconos

/// Ícono dentro de un cuadrado redondeado con degradado suave del acento.
struct AzulejoIcono: View {
    let simbolo: String
    var tamano: CGFloat = 44
    var color: Color? = nil
    @Environment(\.paleta) private var paleta
    @ScaledMetric(relativeTo: .body) private var escala: CGFloat = 1

    var body: some View {
        let l = tamano * min(escala, 1.5)
        let base = color ?? paleta.acento
        Image(systemName: simbolo)
            .font(.system(size: l * 0.44, weight: .semibold))
            .foregroundStyle(base)
            .frame(width: l, height: l)
            .background(
                RoundedRectangle(cornerRadius: l * 0.3, style: .continuous)
                    .fill(LinearGradient(colors: [base.opacity(0.20), base.opacity(0.10)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: l * 0.3, style: .continuous)
                    .strokeBorder(base.opacity(0.18), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}

/// Barra horizontal con el reparto de energía entre proteína, carbohidratos y grasas.
struct BarraApilada: View {
    let nutrientes: Nutrientes
    var alto: CGFloat = 10
    @Environment(\.paleta) private var paleta

    var body: some View {
        let r = nutrientes.repartoEnergia
        GeometryReader { geo in
            let ancho = geo.size.width
            HStack(spacing: 2) {
                if r.proteina + r.carbohidratos + r.grasas == 0 {
                    Capsule().fill(paleta.superficieAlta)
                } else {
                    tramo(paleta.proteina, r.proteina, ancho)
                    tramo(paleta.carbohidratos, r.carbohidratos, ancho)
                    tramo(paleta.grasas, r.grasas, ancho)
                }
            }
        }
        .frame(height: alto)
        .clipShape(Capsule())
        .accessibilityElement()
        .accessibilityLabel("Reparto de energía")
        .accessibilityValue("Proteína \(Formato.entero(r.proteina * 100)) por ciento, carbohidratos \(Formato.entero(r.carbohidratos * 100)) por ciento, grasas \(Formato.entero(r.grasas * 100)) por ciento")
    }

    @ViewBuilder
    private func tramo(_ color: Color, _ fraccion: Double, _ ancho: CGFloat) -> some View {
        if fraccion > 0 {
            Rectangle().fill(color).frame(width: max(2, (ancho - 4) * CGFloat(fraccion)))
        }
    }
}

/// Leyenda de los tres macros con su porcentaje de energía.
struct LeyendaMacros: View {
    let nutrientes: Nutrientes
    @Environment(\.paleta) private var paleta

    var body: some View {
        let r = nutrientes.repartoEnergia
        FilaFlexible(espacio: Espacio.s) {
            item(.proteina, nutrientes.proteina, r.proteina)
            item(.carbohidratos, nutrientes.carbohidratos, r.carbohidratos)
            item(.grasas, nutrientes.grasas, r.grasas)
        }
    }

    private func item(_ macro: Macro, _ gramos: Double, _ fraccion: Double) -> some View {
        HStack(spacing: Espacio.xxs) {
            PuntoMacro(macro: macro)
            Text("\(macro.nombre) \(Formato.entero(gramos)) g")
                .font(Tipo.pie)
                .foregroundStyle(paleta.texto)
            Text("\(Formato.entero(fraccion * 100)) %")
                .font(Tipo.pie.monospacedDigit())
                .foregroundStyle(paleta.textoSecundario)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Medidor pequeño de confianza de la IA (0 a 1).
struct MedidorConfianza: View {
    let valor: Double
    @Environment(\.paleta) private var paleta

    var body: some View {
        let baja = valor < ItemRevision.confianzaBaja
        HStack(spacing: Espacio.xs) {
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule()
                        .fill(Double(i) < (valor * 5).rounded() ? (baja ? paleta.aviso : paleta.exito) : paleta.superficieAlta)
                        .frame(width: 10, height: 6)
                }
            }
            Text(baja ? "Confianza baja" : "Confianza \(Formato.entero(valor * 100)) %")
                .font(Tipo.micro)
                .foregroundStyle(baja ? paleta.aviso : paleta.textoSecundario)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Confianza de la IA")
        .accessibilityValue("\(Formato.entero(valor * 100)) por ciento" + (baja ? ", revisa este alimento" : ""))
    }
}

/// Número con botones − y + (porciones en gramos).
struct SelectorCantidad: View {
    @Binding var valor: Double
    var paso: Double = 10
    var unidad: String = "g"
    var rango: ClosedRange<Double> = 1...5000
    @Environment(\.paleta) private var paleta

    var body: some View {
        HStack(spacing: Espacio.s) {
            boton("minus", -paso, etiqueta: "Restar \(Formato.entero(paso)) \(unidad)")
            CampoNumero(titulo: "Cantidad", valor: $valor, unidad: unidad, decimales: 0)
            boton("plus", paso, etiqueta: "Sumar \(Formato.entero(paso)) \(unidad)")
        }
    }

    private func boton(_ simbolo: String, _ cambio: Double, etiqueta: String) -> some View {
        Button {
            valor = min(max(valor + cambio, rango.lowerBound), rango.upperBound)
        } label: {
            Image(systemName: simbolo)
                .font(Tipo.iconoFila)
                .foregroundStyle(paleta.acento)
                .frame(width: Medida.toque, height: Medida.toque)
                .background(Circle().fill(paleta.acentoSuave))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: valor)
        .accessibilityLabel(etiqueta)
    }
}

/// Fila de ajustes al estilo de iOS: azulejo, título, valor y flecha.
struct FilaAjuste<Destino: View>: View {
    let simbolo: String
    let titulo: String
    var valor: String? = nil
    var color: Color? = nil
    @ViewBuilder let destino: () -> Destino
    @Environment(\.paleta) private var paleta

    var body: some View {
        NavigationLink {
            destino()
        } label: {
            HStack(spacing: Espacio.s) {
                AzulejoIcono(simbolo: simbolo, tamano: 34, color: color)
                VStack(alignment: .leading, spacing: Espacio.xxxs) {
                    Text(titulo).font(Tipo.cuerpo).foregroundStyle(paleta.texto)
                    if let valor {
                        Text(valor).font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: Espacio.xs)
                Image(systemName: "chevron.right").font(Tipo.iconoChico).foregroundStyle(paleta.textoSecundario)
            }
            .padding(.vertical, Espacio.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

/// Grupo de filas dentro de una tarjeta, con separadores.
struct GrupoAjustes<Contenido: View>: View {
    let titulo: String
    @ViewBuilder let contenido: () -> Contenido

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.xs) {
            TituloSeccion(titulo)
            VStack(alignment: .leading, spacing: Espacio.xs) {
                contenido()
            }
            .tarjeta(relleno: Espacio.m)
        }
    }
}
