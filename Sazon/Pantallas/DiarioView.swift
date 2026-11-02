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
    @State private var mostrarCoach = false
    @State private var guardados = 0

    var body: some View {
        let resumen = almacen.resumenVisible
        let semana = Diario.semana(de: almacen.diaVisible, en: almacen.datos.registros, meta: almacen.meta)
        NavigationStack {
            ScrollView {
                VStack(spacing: Espacio.l) {
                    Saludo()

                    // 1. Lo más importante: cuánto te queda hoy.
                    if let meta = almacen.meta {
                        HeroResumen(resumen: resumen, meta: meta,
                                    racha: Series.racha(almacen.datos.registros, hoy: Date()))
                            .aparicion(0)
                    } else {
                        heroSinMeta.aparicion(0)
                    }

                    // 2. La semana, compacta.
                    VStack(spacing: Espacio.s) {
                        CabeceraSemana()
                        TiraSemana(dias: semana, seleccionado: almacen.diaVisible) { dia in
                            animar(.pantalla) { almacen.diaVisible = Calendar.current.startOfDay(for: dia) }
                        }
                    }
                    .tarjeta(relleno: Espacio.s)
                    .aparicion(1)

                    // 3. Las comidas.
                    VStack(spacing: Espacio.s) {
                        EncabezadoSeccion(titulo: "Tus comidas", icono: "fork.knife",
                                          detalle: resumen.total.kcal > 0 ? Formato.kcal(resumen.total.kcal, estimado: resumen.incluyeEstimados) : nil) {
                            if !resumen.total.kcal.isZero {
                                MenuCopiar(titulo: "Copiar el día", alElegir: { dia in
                                    almacen.copiarDia(a: dia)
                                    guardados += 1
                                })
                            }
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
                            .aparicion(indice + 2)
                        }
                    }

                    // 4. Complementos del día.
                    VStack(spacing: Espacio.s) {
                        EncabezadoSeccion(titulo: "Tu día", icono: "sun.max")
                        HStack(spacing: Espacio.s) {
                            TarjetaAgua()
                            BotonCoach { mostrarCoach = true }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        if resumen.total.kcal > 0 {
                            VStack(alignment: .leading, spacing: Espacio.s) {
                                Text("Reparto de energía").font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                                BarraApilada(nutrientes: resumen.total)
                                LeyendaMacros(nutrientes: resumen.total)
                            }
                            .tarjeta()
                        }
                    }
                    .aparicion(6)

                    Text(resumen.incluyeEstimados
                         ? "≈ = estimado por la IA. Todas las cifras son estimaciones, no consejo médico."
                         : "Todas las cifras son estimaciones, no consejo médico.")
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
            .sheet(isPresented: $mostrarCoach) {
                CoachView().entornoSazon(almacen)
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
    let racha: Int
    @Environment(\.paleta) private var paleta
    @ScaledMetric(relativeTo: .largeTitle) private var diametro: CGFloat = 128

    var body: some View {
        let p = Diario.progreso(resumen.total, meta: meta)
        let kcal = p.kcal
        let est = resumen.incluyeEstimados
        VStack(alignment: .leading, spacing: Espacio.m) {
            HStack(alignment: .center, spacing: Espacio.m) {
                VStack(alignment: .leading, spacing: Espacio.xxs) {
                    Label(kcal.excedido ? "Te pasaste" : "Te quedan", systemImage: kcal.excedido ? "exclamationmark.circle" : "flame.fill")
                        .font(Tipo.nota)
                        .foregroundStyle(paleta.textoHeroSecundario)
                    Text((est ? "≈ " : "") + Formato.entero(abs(kcal.restante)))
                        .font(Tipo.cifraGrande)
                        .foregroundStyle(paleta.textoHero)
                        .contentTransition(.numericText(value: kcal.restante))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("kcal de \(Formato.entero(kcal.meta))")
                        .font(Tipo.nota)
                        .foregroundStyle(paleta.textoHeroSecundario)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: Espacio.xs)
                anillo(kcal, est)
            }
            HStack(spacing: Espacio.xs) {
                capsula("fork.knife", "Comiste \(est ? "≈ " : "")\(Formato.entero(kcal.consumido)) kcal")
                if racha > 0 { capsula("flame", "\(racha) \(racha == 1 ? "día" : "días") seguidos") }
            }
            Rectangle().fill(paleta.textoHero.opacity(Opacidad.pistaHero)).frame(height: 1).accessibilityHidden(true)
            HStack(alignment: .top, spacing: Espacio.xs) {
                MacroHero(macro: .proteina, consumido: resumen.total.proteina, meta: meta.proteina, estimado: est)
                MacroHero(macro: .carbohidratos, consumido: resumen.total.carbohidratos, meta: meta.carbohidratos, estimado: est)
                MacroHero(macro: .grasas, consumido: resumen.total.grasas, meta: meta.grasas, estimado: est)
            }
        }
        .hero()
    }

    private func capsula(_ icono: String, _ texto: String) -> some View {
        Label(texto, systemImage: icono)
            .font(Tipo.pie.monospacedDigit())
            .foregroundStyle(paleta.textoHero)
            .padding(.horizontal, Espacio.s)
            .padding(.vertical, Espacio.xxs)
            .background(Capsule().fill(paleta.textoHero.opacity(Opacidad.capsulaHero)))
            .lineLimit(1)
    }

    private func anillo(_ kcal: Progreso, _ est: Bool) -> some View {
        let lado = min(diametro, 200)
        return ZStack {
            AnilloHero(valor: kcal.fraccion, grosor: Medida.grosorAnillo)
            VStack(spacing: 0) {
                Text(Formato.entero(kcal.fraccion * 100) + "%")
                    .font(Tipo.subtitulo.monospacedDigit())
                    .foregroundStyle(paleta.textoHero)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("de tu meta")
                    .font(Tipo.micro)
                    .foregroundStyle(paleta.textoHeroSecundario)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(Medida.grosorAnillo + Espacio.xxs)
        }
        .frame(width: lado, height: lado)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progreso de calorías")
        .accessibilityValue("\(est ? "aproximadamente " : "")\(Formato.entero(kcal.consumido)) de \(Formato.entero(kcal.meta)), \(Formato.entero(kcal.fraccion * 100)) por ciento")
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

    @State private var pedirNombre = false
    @State private var nombreFavorito = ""
    @State private var hechos = 0

    var body: some View {
        let estimado = registros.contains { $0.origen.esEstimado }
        let color = paleta.color(comida)
        VStack(alignment: .leading, spacing: Espacio.s) {
            HStack(spacing: Espacio.s) {
                AzulejoColor(simbolo: comida.simbolo, color: color, tamano: 48)
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
                if let meta = metaComida, !registros.isEmpty {
                    ZStack {
                        AnilloProgreso(valor: Progreso(consumido: total.kcal, meta: meta).fraccion, grosor: 5, color: color)
                        Text(Formato.entero(Progreso(consumido: total.kcal, meta: meta).fraccion * 100) + "%")
                            .font(Tipo.micro.monospacedDigit())
                            .foregroundStyle(paleta.texto)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(width: Medida.anilloComida, height: Medida.anilloComida)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(Formato.entero(Progreso(consumido: total.kcal, meta: meta).fraccion * 100)) por ciento de lo sugerido para \(comida.nombre.lowercased())")
                }
                if !registros.isEmpty {
                    MenuCopiar(titulo: nil, extra: {
                        Button {
                            nombreFavorito = Copiado.nombreSugerido(registros, comida: comida)
                            pedirNombre = true
                        } label: { Label("Guardar como favorito", systemImage: "star") }
                    }, alElegir: { dia in
                        almacen.copiarComida(comida, a: dia)
                        hechos += 1
                    })
                }
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
        .sensoryFeedback(.success, trigger: hechos)
        .alert("Guardar como favorito", isPresented: $pedirNombre) {
            TextField("Nombre", text: $nombreFavorito)
            Button("Guardar") {
                almacen.guardarFavorito(nombre: nombreFavorito, registros: registros, comida: comida)
                hechos += 1
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Lo encontrarás al registrar, en «Favoritos», para agregarlo en un toque.")
        }
    }
}

/// Menú «⋯» para copiar a hoy, mañana u otro día (con selector de fecha).
struct MenuCopiar<Extra: View>: View {
    let titulo: String?
    @ViewBuilder var extra: () -> Extra
    let alElegir: (Date) -> Void
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var eligiendo = false
    @State private var fecha = Date()

    var body: some View {
        let hoy = Calendar.current.startOfDay(for: Date())
        let manana = Calendar.current.date(byAdding: .day, value: 1, to: hoy) ?? hoy
        Menu {
            Section(titulo ?? "Copiar") {
                if !almacen.esHoy {
                    Button { alElegir(hoy) } label: { Label("Copiar a hoy", systemImage: "arrow.uturn.forward") }
                }
                Button { alElegir(manana) } label: { Label("Copiar a mañana", systemImage: "calendar.badge.plus") }
                Button { fecha = Date(); eligiendo = true } label: { Label("Copiar a otro día…", systemImage: "calendar") }
            }
            extra()
        } label: {
            Image(systemName: titulo == nil ? "ellipsis" : "doc.on.doc")
                .font(Tipo.iconoChico)
                .foregroundStyle(paleta.textoSecundario)
                .frame(width: Medida.toque, height: Medida.toque)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(titulo ?? "Más opciones")
        .sheet(isPresented: $eligiendo) {
            NavigationStack {
                Form {
                    DatePicker("Día", selection: $fecha, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
                .navigationTitle("Copiar a…")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { eligiendo = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Copiar") {
                            alElegir(Calendar.current.startOfDay(for: fecha))
                            eligiendo = false
                        }
                    }
                }
            }
            .presentationDetents([.large])
            .entornoSazon(almacen)
        }
    }
}

extension MenuCopiar where Extra == EmptyView {
    init(titulo: String?, alElegir: @escaping (Date) -> Void) {
        self.titulo = titulo
        self.extra = { EmptyView() }
        self.alElegir = alElegir
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
        case .envase: return "doc.text.viewfinder"
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

// MARK: - Agua y coach

private struct TarjetaAgua: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta

    var body: some View {
        let ml = almacen.aguaVisible
        let meta = almacen.metaAgua
        VStack(alignment: .leading, spacing: Espacio.s) {
            HStack {
                Label("Agua", systemImage: "drop.fill")
                    .font(Tipo.cuerpoFuerte)
                    .foregroundStyle(paleta.texto)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: Espacio.xxs) {
                Text(Formato.numero(ml / 1000))
                    .font(Tipo.cifra)
                    .foregroundStyle(paleta.texto)
                    .contentTransition(.numericText())
                Text("/ \(Formato.numero(meta / 1000)) L").font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
            }
            BarraProgreso(valor: meta > 0 ? ml / meta : 0, color: paleta.proteina)
            HStack(spacing: Espacio.xs) {
                Button {
                    animar(.enfasis) { almacen.quitarAgua() }
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(paleta.superficieAlta))
                }
                .disabled(ml <= 0)
                .accessibilityLabel("Quitar un vaso")
                Button {
                    animar(.enfasis) { almacen.agregarAgua(almacen.datos.vasoMl) }
                } label: {
                    Label("\(Formato.entero(almacen.datos.vasoMl)) ml", systemImage: "plus")
                        .font(Tipo.pie)
                        .foregroundStyle(paleta.textoSobreAcento)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Capsule().fill(paleta.acento))
                }
                .accessibilityLabel("Sumar un vaso de \(Formato.entero(almacen.datos.vasoMl)) mililitros")
            }
            .buttonStyle(.plain)
            .foregroundStyle(paleta.acento)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .tarjeta()
        .sensoryFeedback(.impact(weight: .light), trigger: ml)
    }
}

private struct BotonCoach: View {
    let accion: () -> Void
    @Environment(\.paleta) private var paleta

    var body: some View {
        Button(action: accion) {
            VStack(alignment: .leading, spacing: Espacio.s) {
                AzulejoIcono(simbolo: "sparkles", tamano: 40)
                Spacer(minLength: 0)
                Text("Coach IA").font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                Text("Pregunta qué comer o cómo llegar a tu meta")
                    .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .tarjeta()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 150)
    }
}
