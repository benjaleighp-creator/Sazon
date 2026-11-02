import SwiftUI

/// Pedido para abrir la hoja de registro (con la comida y, opcionalmente,
/// directo en un método: foto, texto, escáner…).
struct SolicitudRegistro: Identifiable {
    let id = UUID()
    let comida: TipoComida
    var destino: DestinoRegistro? = nil
}

/// Diario: saludo, semana, resumen con degradado, reparto de macros y comidas.
struct DiarioView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var solicitud: SolicitudRegistro?
    @State private var editando: Registro?
    @State private var mostrarMeta = false
    @State private var guardados = 0

    var body: some View {
        let resumen = almacen.resumenVisible
        let semana = Diario.semana(de: almacen.diaVisible, en: almacen.datos.registros, meta: almacen.meta)
        NavigationStack {
            ScrollView {
                VStack(spacing: Espacio.l) {
                    Saludo()
                    VStack(spacing: Espacio.s) {
                        CabeceraSemana()
                        TiraSemana(dias: semana, seleccionado: almacen.diaVisible) { dia in
                            animar(.pantalla) { almacen.diaVisible = Calendar.current.startOfDay(for: dia) }
                        }
                    }
                    .tarjeta(relleno: Espacio.s)
                    .aparicion(0)

                    if let meta = almacen.meta {
                        HeroResumen(resumen: resumen, meta: meta)
                            .aparicion(1)
                    } else {
                        heroSinMeta.aparicion(1)
                    }

                    if resumen.total.kcal > 0 {
                        VStack(alignment: .leading, spacing: Espacio.s) {
                            HStack {
                                Text("Reparto de energía").font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                                Spacer()
                                Text(Formato.kcal(resumen.total.kcal, estimado: resumen.incluyeEstimados))
                                    .font(Tipo.pie.monospacedDigit()).foregroundStyle(paleta.textoSecundario)
                            }
                            BarraApilada(nutrientes: resumen.total)
                            LeyendaMacros(nutrientes: resumen.total)
                        }
                        .tarjeta()
                        .aparicion(2)
                    }

                    ForEach(Array(TipoComida.allCases.enumerated()), id: \.element) { indice, comida in
                        TarjetaComida(
                            comida: comida,
                            registros: resumen.registros(comida),
                            total: resumen.totales(comida),
                            metaComida: almacen.meta.map { $0.kcal * comida.parteSugerida },
                            alAgregar: { solicitud = SolicitudRegistro(comida: comida) },
                            alTocar: { editando = $0 }
                        )
                        .aparicion(indice + 3)
                    }

                    Text(resumen.incluyeEstimados
                         ? "≈ Las cifras con este signo son estimaciones de la IA. Todas las calorías son estimaciones generales y no reemplazan el consejo de un profesional de salud."
                         : "Las calorías y los macros son estimaciones generales, no consejo médico.")
                        .font(Tipo.pie)
                        .foregroundStyle(paleta.textoSecundario)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Espacio.margen)
                .padding(.top, Espacio.xs)
                .padding(.bottom, Espacio.xxl * 2)
            }
            .fondoDePantalla()
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) {
                BotonFlotante { destino in
                    let comida = almacen.esHoy ? almacen.comidaSugerida : .almuerzo
                    solicitud = SolicitudRegistro(comida: comida, destino: destino)
                }
                .padding(.trailing, Espacio.margen)
                .padding(.bottom, Espacio.m)
            }
            .sheet(item: $solicitud) { s in
                AgregarView(comidaInicial: s.comida, destinoInicial: s.destino) { nuevos in
                    almacen.agregar(nuevos)
                    guardados += 1
                    solicitud = nil
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

    private var heroSinMeta: some View {
        VStack(alignment: .leading, spacing: Espacio.s) {
            Image(systemName: "target")
                .font(Tipo.iconoGrande)
                .foregroundStyle(paleta.textoHero)
                .accessibilityHidden(true)
            Text("Configura tu meta")
                .font(Tipo.titulo3)
                .foregroundStyle(paleta.textoHero)
            Text("Con tu peso, talla, edad y actividad calculo tus calorías y macros. Verás la fórmula y podrás cambiar los números a mano.")
                .font(Tipo.nota)
                .foregroundStyle(paleta.textoHeroSecundario)
                .fixedSize(horizontal: false, vertical: true)
            Button { mostrarMeta = true } label: {
                Text("Configurar meta")
                    .font(Tipo.cuerpoFuerte)
                    .foregroundStyle(paleta.heroFin)
                    .frame(maxWidth: .infinity, minHeight: Medida.toque)
                    .background(Capsule().fill(paleta.textoHero))
            }
            .buttonStyle(.plain)
        }
        .hero()
    }
}

extension TipoComida {
    /// Parte orientativa de las calorías del día para cada comida (suma 1).
    /// Solo sirve para la barrita de cada tarjeta; no es una regla.
    var parteSugerida: Double {
        switch self {
        case .desayuno: return 0.25
        case .almuerzo: return 0.35
        case .cena: return 0.25
        case .snacks: return 0.15
        }
    }
}

// MARK: - Saludo y semana

private struct Saludo: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta

    var body: some View {
        let hora = Calendar.current.component(.hour, from: Date())
        let nombre = almacen.datos.nombre.trimmingCharacters(in: .whitespaces)
        HStack(alignment: .center, spacing: Espacio.s) {
            VStack(alignment: .leading, spacing: Espacio.xxxs) {
                Text(Formato.saludo(hora: hora) + (nombre.isEmpty ? "" : ", \(nombre)"))
                    .font(Tipo.titulo2)
                    .foregroundStyle(paleta.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(Formato.diaLargo(almacen.diaVisible))
                    .font(Tipo.nota)
                    .foregroundStyle(paleta.textoSecundario)
            }
            Spacer(minLength: Espacio.xs)
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Espacio.s)
    }
}

private struct CabeceraSemana: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta

    var body: some View {
        let lunes = Diario.inicioSemana(almacen.diaVisible)
        HStack(spacing: Espacio.xs) {
            flecha("chevron.left", "Semana anterior", -7)
            Spacer(minLength: 0)
            VStack(spacing: Espacio.xxxs) {
                Text(Formato.diaRelativo(almacen.diaVisible))
                    .font(Tipo.cuerpoFuerte)
                    .foregroundStyle(paleta.texto)
                Text("Semana del \(Formato.numeroDia(lunes)) " + mesCorto(lunes))
                    .font(Tipo.micro)
                    .foregroundStyle(paleta.textoSecundario)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            if !almacen.esHoy {
                Button("Hoy") { animar(.pantalla) { almacen.irAHoy() } }
                    .font(Tipo.pie)
                    .buttonStyle(.texto)
            }
            flecha("chevron.right", "Semana siguiente", 7)
        }
    }

    private func mesCorto(_ fecha: Date) -> String {
        let f = DateFormatter()
        f.locale = Formato.locale
        f.dateFormat = "MMMM"
        return f.string(from: fecha)
    }

    private func flecha(_ simbolo: String, _ etiqueta: String, _ dias: Int) -> some View {
        Button {
            animar(.pantalla) { almacen.moverDia(dias) }
        } label: {
            Image(systemName: simbolo)
                .font(Tipo.iconoChico)
                .foregroundStyle(paleta.acento)
                .frame(width: 40, height: 40)
                .background(Circle().fill(paleta.acentoSuave))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(etiqueta)
    }
}

// MARK: - Resumen con degradado

private struct HeroResumen: View {
    let resumen: ResumenDia
    let meta: Nutrientes
    @Environment(\.paleta) private var paleta
    @ScaledMetric(relativeTo: .largeTitle) private var diametro: CGFloat = 150

    var body: some View {
        let p = Diario.progreso(resumen.total, meta: meta)
        let est = resumen.incluyeEstimados
        VStack(spacing: Espacio.l) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Espacio.l) {
                    anillo(p.kcal, est)
                    datos(p.kcal, est)
                }
                VStack(spacing: Espacio.m) {
                    anillo(p.kcal, est)
                    datos(p.kcal, est)
                }
            }
            Rectangle().fill(paleta.textoHero.opacity(0.18)).frame(height: 1).accessibilityHidden(true)
            HStack(alignment: .top, spacing: Espacio.xs) {
                MacroHero(macro: .proteina, consumido: resumen.total.proteina, meta: meta.proteina, estimado: est)
                MacroHero(macro: .carbohidratos, consumido: resumen.total.carbohidratos, meta: meta.carbohidratos, estimado: est)
                MacroHero(macro: .grasas, consumido: resumen.total.grasas, meta: meta.grasas, estimado: est)
            }
        }
        .hero()
    }

    private func anillo(_ kcal: Progreso, _ est: Bool) -> some View {
        let lado = min(diametro, 230)
        return ZStack {
            AnilloHero(valor: kcal.fraccion, grosor: Medida.grosorAnillo)
            VStack(spacing: Espacio.xxxs) {
                Image(systemName: "flame.fill")
                    .font(Tipo.iconoDato)
                    .foregroundStyle(paleta.textoHero)
                Text((est ? "≈ " : "") + Formato.entero(kcal.consumido))
                    .font(Tipo.cifra)
                    .foregroundStyle(paleta.textoHero)
                    .contentTransition(.numericText(value: kcal.consumido))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("kcal")
                    .font(Tipo.pie)
                    .foregroundStyle(paleta.textoHeroSecundario)
            }
            .padding(Medida.grosorAnillo + Espacio.xs)
        }
        .frame(width: lado, height: lado)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calorías consumidas")
        .accessibilityValue("\(est ? "aproximadamente " : "")\(Formato.entero(kcal.consumido)) de \(Formato.entero(kcal.meta))")
    }

    private func datos(_ kcal: Progreso, _ est: Bool) -> some View {
        VStack(alignment: .leading, spacing: Espacio.s) {
            fila("target", "Meta", Formato.kcal(kcal.meta))
            fila("fork.knife", "Consumidas", Formato.kcal(kcal.consumido, estimado: est))
            fila(kcal.excedido ? "exclamationmark.circle" : "hourglass",
                 kcal.excedido ? "Sobre la meta" : "Quedan",
                 Formato.kcal(abs(kcal.restante)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fila(_ simbolo: String, _ titulo: String, _ valor: String) -> some View {
        HStack(spacing: Espacio.s) {
            Image(systemName: simbolo)
                .font(Tipo.iconoDato)
                .foregroundStyle(paleta.textoHero)
                .frame(width: 32, height: 32)
                .background(Circle().fill(paleta.textoHero.opacity(0.16)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(titulo).font(Tipo.pie).foregroundStyle(paleta.textoHeroSecundario)
                Text(valor).font(Tipo.cuerpoFuerte.monospacedDigit()).foregroundStyle(paleta.textoHero)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Comidas

private struct TarjetaComida: View {
    let comida: TipoComida
    let registros: [Registro]
    let total: Nutrientes
    let metaComida: Double?
    let alAgregar: () -> Void
    let alTocar: (Registro) -> Void
    @Environment(\.paleta) private var paleta
    @Environment(Almacen.self) private var almacen

    var body: some View {
        let estimado = registros.contains { $0.origen.esEstimado }
        VStack(alignment: .leading, spacing: Espacio.s) {
            HStack(spacing: Espacio.s) {
                AzulejoIcono(simbolo: comida.simbolo, tamano: 44)
                VStack(alignment: .leading, spacing: Espacio.xxxs) {
                    Text(comida.nombre)
                        .font(Tipo.subtitulo)
                        .foregroundStyle(paleta.texto)
                        .accessibilityAddTraits(.isHeader)
                    Text(registros.isEmpty
                         ? (metaComida.map { "Sugerido ≈ \(Formato.entero($0)) kcal" } ?? "Sin registros")
                         : "\(Formato.kcal(total.kcal, estimado: estimado)) · \(registros.count) \(registros.count == 1 ? "alimento" : "alimentos")")
                        .font(Tipo.pie)
                        .foregroundStyle(paleta.textoSecundario)
                }
                Spacer(minLength: Espacio.xs)
                Button(action: alAgregar) {
                    Image(systemName: "plus")
                        .font(Tipo.iconoFila)
                        .foregroundStyle(paleta.textoSobreAcento)
                        .frame(width: Medida.toque, height: Medida.toque)
                        .background(Circle().fill(paleta.acento))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Agregar a \(comida.nombre.lowercased())")
            }

            if let meta = metaComida, !registros.isEmpty {
                BarraProgreso(valor: Progreso(consumido: total.kcal, meta: meta).fraccion, color: paleta.calorias, alto: 6)
            }

            if registros.isEmpty {
                Button(action: alAgregar) {
                    HStack(spacing: Espacio.xs) {
                        Image(systemName: "plus.circle")
                        Text("Agregar \(comida.nombre.lowercased())")
                    }
                    .font(Tipo.nota)
                    .foregroundStyle(paleta.acento)
                    .frame(maxWidth: .infinity, minHeight: Medida.toque)
                    .background(
                        RoundedRectangle(cornerRadius: Radio.medio, style: .continuous)
                            .strokeBorder(paleta.acento.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 0) {
                    ForEach(registros) { r in
                        FilaRegistro(registro: r, unidad: almacen.datos.unidad) { alTocar(r) }
                        if r.id != registros.last?.id {
                            Divider().overlay(paleta.borde).padding(.leading, 44)
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
            HStack(alignment: .center, spacing: Espacio.s) {
                AzulejoIcono(simbolo: simboloOrigen, tamano: 32, color: paleta.textoSecundario)
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
                }
                Spacer(minLength: Espacio.xs)
                VStack(alignment: .trailing, spacing: 0) {
                    Text((est ? "≈ " : "") + Formato.entero(t.kcal))
                        .font(Tipo.cuerpoFuerte.monospacedDigit())
                        .foregroundStyle(paleta.texto)
                    Text("kcal").font(Tipo.micro).foregroundStyle(paleta.textoSecundario)
                }
            }
            .padding(.vertical, Espacio.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(registro.nombre), \(Formato.kcal(t.kcal, estimado: est)), origen \(registro.origen.etiqueta)")
        .accessibilityHint("Toca para corregir o eliminar")
    }

    private var simboloOrigen: String {
        switch registro.origen {
        case .ins: return "book.closed"
        case .openFoodFacts: return "barcode"
        case .estimadoIA: return "sparkles"
        case .manual: return "pencil"
        }
    }
}

// MARK: - Botón flotante

/// Botón "+" flotante. Un toque abre el registro; mantenerlo pulsado
/// muestra los atajos (foto, texto o voz, escáner, tabla, a mano).
private struct BotonFlotante: View {
    let alElegir: (DestinoRegistro?) -> Void
    @Environment(\.paleta) private var paleta
    @Environment(\.colorScheme) private var esquema
    @ScaledMetric(relativeTo: .title) private var lado: CGFloat = 64

    var body: some View {
        let l = min(lado, 84)
        let sombra = Sombra.elevada(esquema)
        Menu {
            Button { alElegir(.foto) } label: { Label("Foto del plato", systemImage: "camera") }
            Button { alElegir(.texto) } label: { Label("Escribir o dictar", systemImage: "text.bubble") }
            Button { alElegir(.escanear) } label: { Label("Escanear código", systemImage: "barcode.viewfinder") }
            Button { alElegir(.buscar) } label: { Label("Buscar en la tabla", systemImage: "magnifyingglass") }
            Button { alElegir(.manual) } label: { Label("Agregar a mano", systemImage: "square.and.pencil") }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: l * 0.4, weight: .bold))
                .foregroundStyle(paleta.textoHero)
                .frame(width: l, height: l)
                .background(Circle().fill(paleta.degradadoHero))
                .overlay(Circle().strokeBorder(paleta.textoHero.opacity(0.25), lineWidth: 1))
                .shadow(color: paleta.heroFin.opacity(0.45), radius: sombra.radio, x: 0, y: sombra.y)
        } primaryAction: {
            alElegir(nil)
        }
        .accessibilityLabel("Registrar comida")
        .accessibilityHint("Mantén pulsado para elegir foto, texto, escáner o tabla")
    }
}
