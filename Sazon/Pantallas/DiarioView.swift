import SwiftUI

/// Diario del día: resumen frente a la meta y las cuatro comidas.
struct DiarioView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var agregarEn: TipoComida?
    @State private var editando: Registro?
    @State private var mostrarMeta = false
    @State private var guardados = 0

    var body: some View {
        let resumen = almacen.resumenVisible
        NavigationStack {
            ScrollView {
                VStack(spacing: Espacio.l) {
                    EncabezadoDia()
                    if let meta = almacen.meta {
                        TarjetaResumen(resumen: resumen, meta: meta)
                            .aparicion(0)
                    } else {
                        tarjetaSinMeta
                    }
                    ForEach(Array(TipoComida.allCases.enumerated()), id: \.element) { indice, comida in
                        SeccionComida(
                            comida: comida,
                            registros: resumen.registros(comida),
                            total: resumen.totales(comida),
                            alAgregar: { agregarEn = comida },
                            alTocar: { editando = $0 }
                        )
                        .aparicion(indice + 1)
                    }
                    if resumen.incluyeEstimados {
                        Text("≈ Las cifras con este signo son estimaciones de la IA. Todas las calorías son estimaciones generales y no reemplazan el consejo de un profesional de salud.")
                            .font(Tipo.pie)
                            .foregroundStyle(paleta.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Espacio.margen)
                .padding(.top, Espacio.s)
                .padding(.bottom, Espacio.xxl)
            }
            .fondoDePantalla()
            .navigationTitle("Sazón")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    agregarEn = almacen.esHoy ? almacen.comidaSugerida : .almuerzo
                } label: {
                    Label("Registrar comida", systemImage: "plus")
                }
                .buttonStyle(.principal)
                .padding(.horizontal, Espacio.margen)
                .padding(.bottom, Espacio.xs)
                .sensoryFeedback(.impact(weight: .light), trigger: agregarEn)
            }
            .sheet(item: $agregarEn) { comida in
                AgregarView(comidaInicial: comida) { nuevos in
                    almacen.agregar(nuevos)
                    guardados += 1
                    agregarEn = nil
                }
                .entornoSazon(almacen)
            }
            .sheet(item: $editando) { registro in
                EditarRegistroView(original: registro)
                    .entornoSazon(almacen)
            }
            .sheet(isPresented: $mostrarMeta) {
                NavigationStack { MetaView() }
                    .entornoSazon(almacen)
            }
            .sensoryFeedback(.success, trigger: guardados)
        }
    }

    private var tarjetaSinMeta: some View {
        VStack(alignment: .leading, spacing: Espacio.s) {
            HStack(spacing: Espacio.s) {
                IconoCirculo(simbolo: "target")
                Text("Configura tu meta")
                    .font(Tipo.subtitulo)
                    .foregroundStyle(paleta.texto)
            }
            Text("Con tu peso, talla, edad y actividad calculo una meta de calorías y macros. Puedes ver la fórmula y cambiar los números a mano.")
                .font(Tipo.nota)
                .foregroundStyle(paleta.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
            Button("Configurar meta") { mostrarMeta = true }
                .buttonStyle(.secundario)
        }
        .tarjeta()
    }
}

// MARK: - Encabezado con el día

private struct EncabezadoDia: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @Environment(\.accessibilityReduceMotion) private var reducir

    var body: some View {
        let dia = almacen.diaVisible
        HStack(spacing: Espacio.s) {
            botonFlecha("chevron.left", etiqueta: "Día anterior") { almacen.moverDia(-1) }
            Spacer(minLength: 0)
            VStack(spacing: Espacio.xxxs) {
                Text(Formato.diaRelativo(dia))
                    .font(Tipo.titulo3)
                    .foregroundStyle(paleta.texto)
                    .contentTransition(.opacity)
                // "Hoy", "Ayer" y "Mañana" van acompañados de la fecha completa.
                if Calendar.current.isDateInToday(dia) || Calendar.current.isDateInYesterday(dia) || Calendar.current.isDateInTomorrow(dia) {
                    Text(Formato.diaLargo(dia))
                        .font(Tipo.pie)
                        .foregroundStyle(paleta.textoSecundario)
                }
                if !almacen.esHoy {
                    Button("Volver a hoy") { animar(.pantalla) { almacen.irAHoy() } }
                        .buttonStyle(.texto)
                        .font(Tipo.pie)
                }
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            botonFlecha("chevron.right", etiqueta: "Día siguiente") { almacen.moverDia(1) }
        }
        .animacion(.pantalla, valor: dia)
    }

    private func botonFlecha(_ simbolo: String, etiqueta: String, accion: @escaping () -> Void) -> some View {
        Button {
            animar(.pantalla) { accion() }
        } label: {
            Image(systemName: simbolo)
                .font(Tipo.iconoFila)
                .foregroundStyle(paleta.acento)
                .frame(minWidth: Medida.toque, minHeight: Medida.toque)
                .background(Circle().fill(paleta.acentoSuave))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(etiqueta)
        .sensoryFeedback(.selection, trigger: almacen.diaVisible)
    }
}

// MARK: - Resumen del día

struct TarjetaResumen: View {
    let resumen: ResumenDia
    let meta: Nutrientes
    @Environment(\.paleta) private var paleta
    @ScaledMetric(relativeTo: .largeTitle) private var diametro: CGFloat = Medida.anillo

    var body: some View {
        let p = Diario.progreso(resumen.total, meta: meta)
        let aprox = resumen.incluyeEstimados ? "≈ " : ""
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: Espacio.l) {
                anillo(p.kcal, aprox: aprox)
                barras
            }
            VStack(spacing: Espacio.l) {
                anillo(p.kcal, aprox: aprox)
                barras
            }
        }
        .tarjeta()
    }

    private func anillo(_ kcal: Progreso, aprox: String) -> some View {
        let lado = min(diametro, 260)
        return ZStack {
            AnilloProgreso(valor: kcal.fraccion, color: paleta.calorias)
            VStack(spacing: Espacio.xxxs) {
                Text(aprox + Formato.entero(kcal.consumido))
                    .font(Tipo.cifra)
                    .foregroundStyle(paleta.texto)
                    .contentTransition(.numericText(value: kcal.consumido))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("de \(Formato.entero(kcal.meta)) kcal")
                    .font(Tipo.pie)
                    .foregroundStyle(paleta.textoSecundario)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(kcal.excedido ? "+\(Formato.entero(-kcal.restante)) sobre la meta" : "Quedan \(Formato.entero(kcal.restante))")
                    .font(Tipo.micro)
                    .foregroundStyle(kcal.excedido ? paleta.aviso : paleta.textoSecundario)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(Medida.grosorAnillo + Espacio.xxs)
        }
        .frame(width: lado, height: lado)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calorías")
        .accessibilityValue(kcal.excedido
            ? "\(aprox)\(Formato.entero(kcal.consumido)) de \(Formato.entero(kcal.meta)); pasaste la meta por \(Formato.entero(-kcal.restante))"
            : "\(aprox)\(Formato.entero(kcal.consumido)) de \(Formato.entero(kcal.meta)); quedan \(Formato.entero(kcal.restante))")
    }

    private var barras: some View {
        VStack(alignment: .leading, spacing: Espacio.s) {
            ForEach([Macro.proteina, .carbohidratos, .grasas]) { macro in
                FilaMacro(macro: macro, consumido: macro.valor(resumen.total), meta: macro.valor(meta),
                          estimado: resumen.incluyeEstimados)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct FilaMacro: View {
    let macro: Macro
    let consumido: Double
    let meta: Double
    var estimado: Bool = false
    @Environment(\.paleta) private var paleta

    var body: some View {
        let p = Progreso(consumido: consumido, meta: meta)
        VStack(alignment: .leading, spacing: Espacio.xxs) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Espacio.xs) {
                    PuntoMacro(macro: macro)
                    Text(macro.nombre).font(Tipo.nota).foregroundStyle(paleta.texto)
                    Spacer(minLength: Espacio.xs)
                    cifras
                }
                VStack(alignment: .leading, spacing: Espacio.xxxs) {
                    HStack(spacing: Espacio.xs) {
                        PuntoMacro(macro: macro)
                        Text(macro.nombre).font(Tipo.nota).foregroundStyle(paleta.texto)
                    }
                    cifras
                }
            }
            BarraProgreso(valor: p.fraccion, color: paleta.color(macro))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(macro.nombre)
        .accessibilityValue("\(estimado ? "aproximadamente " : "")\(Formato.entero(consumido)) de \(Formato.entero(meta)) gramos")
    }

    private var cifras: some View {
        Text("\(estimado ? "≈ " : "")\(Formato.entero(consumido)) / \(Formato.entero(meta)) g")
            .font(Tipo.pie.monospacedDigit())
            .foregroundStyle(p.excedido ? paleta.aviso : paleta.textoSecundario)
    }

    private var p: Progreso { Progreso(consumido: consumido, meta: meta) }
}

// MARK: - Comidas

private struct SeccionComida: View {
    let comida: TipoComida
    let registros: [Registro]
    let total: Nutrientes
    let alAgregar: () -> Void
    let alTocar: (Registro) -> Void
    @Environment(\.paleta) private var paleta
    @Environment(Almacen.self) private var almacen

    var body: some View {
        let estimado = registros.contains { $0.origen.esEstimado }
        VStack(alignment: .leading, spacing: Espacio.s) {
            HStack(spacing: Espacio.s) {
                IconoCirculo(simbolo: comida.simbolo, tamano: 32)
                VStack(alignment: .leading, spacing: Espacio.xxxs) {
                    Text(comida.nombre)
                        .font(Tipo.subtitulo)
                        .foregroundStyle(paleta.texto)
                        .accessibilityAddTraits(.isHeader)
                    if !registros.isEmpty {
                        Text(Formato.kcal(total.kcal, estimado: estimado))
                            .font(Tipo.pie)
                            .foregroundStyle(paleta.textoSecundario)
                    }
                }
                Spacer(minLength: Espacio.xs)
                Button(action: alAgregar) {
                    Image(systemName: "plus")
                        .font(Tipo.iconoFila)
                        .foregroundStyle(paleta.acento)
                        .frame(minWidth: Medida.toque, minHeight: Medida.toque)
                        .background(Circle().fill(paleta.acentoSuave))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Agregar a \(comida.nombre.lowercased())")
            }
            if registros.isEmpty {
                Text("Sin registros")
                    .font(Tipo.nota)
                    .foregroundStyle(paleta.textoSecundario)
            } else {
                VStack(spacing: 0) {
                    ForEach(registros) { r in
                        FilaRegistro(registro: r, unidad: almacen.datos.unidad) { alTocar(r) }
                        if r.id != registros.last?.id {
                            Divider().overlay(paleta.borde)
                        }
                    }
                }
            }
        }
        .tarjeta()
    }
}

struct FilaRegistro: View {
    let registro: Registro
    let unidad: UnidadPorcion
    let alTocar: () -> Void
    @Environment(\.paleta) private var paleta

    var body: some View {
        let t = registro.total
        let est = registro.origen.esEstimado
        Button(action: alTocar) {
            HStack(alignment: .firstTextBaseline, spacing: Espacio.s) {
                VStack(alignment: .leading, spacing: Espacio.xxxs) {
                    Text(registro.nombre)
                        .font(Tipo.cuerpo)
                        .foregroundStyle(paleta.texto)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(Porciones.texto(gramos: registro.gramos, unidad: unidad, medida: registro.medida, cantidadMedida: registro.cantidadMedida)
                         + " · P \(Formato.entero(t.proteina)) · C \(Formato.entero(t.carbohidratos)) · G \(Formato.entero(t.grasas))")
                        .font(Tipo.pie)
                        .foregroundStyle(paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                    InsigniaOrigen(origen: registro.origen)
                }
                Spacer(minLength: Espacio.xs)
                Text(Formato.kcal(t.kcal, estimado: est))
                    .font(Tipo.cuerpoFuerte.monospacedDigit())
                    .foregroundStyle(paleta.texto)
            }
            .padding(.vertical, Espacio.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Toca para corregir o eliminar")
    }
}
