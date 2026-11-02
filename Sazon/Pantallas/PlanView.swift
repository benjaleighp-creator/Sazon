import SwiftUI

/// Plan de comidas: genera un día con la tabla del INS y tus recetas,
/// lo pasa al diario y arma la lista de compras.
struct PlanView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var dia = Calendar.current.startOfDay(for: Date())
    @State private var variante = 0
    @State private var agregando: TipoComida?
    @State private var pdf: URL?
    @State private var registrados = 0

    private var dias: [Date] {
        let hoy = Calendar.current.startOfDay(for: Date())
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: hoy) }
    }

    var body: some View {
        @Bindable var a = almacen
        let plan = almacen.planDe(dia)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Espacio.l) {
                    Text("Plan de comidas")
                        .font(Tipo.titulo1)
                        .foregroundStyle(paleta.texto)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, Espacio.s)

                    selectorDia.aparicion(0)
                    hero(plan).aparicion(1)
                    herramientas.aparicion(2)
                    if !plan.items.isEmpty {
                        EncabezadoSeccion(titulo: "Comidas del día", icono: "list.bullet.rectangle")
                    }

                    if !plan.items.isEmpty {
                        ForEach(Array(TipoComida.visibles(extra: almacen.datos.comidasExtra).enumerated()), id: \.element) { i, comida in
                            tarjetaComida(comida, plan: plan).aparicion(i + 2)
                        }
                        Toggle(isOn: $a.datos.ajustarPorcionesPlan) {
                            VStack(alignment: .leading, spacing: Espacio.xxxs) {
                                Text("Ajustar porciones al registrar").font(Tipo.nota).foregroundStyle(paleta.texto)
                                Text("Si comes más o menos de lo planeado, las porciones que faltan se ajustan para acercarte a tu meta (entre la mitad y 1,5 veces).")
                                    .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .tarjeta()
                    }

                    Text("El plan es una sugerencia automática con datos del INS (platos promediados) y tus recetas; no es una dieta indicada por un profesional.")
                        .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Espacio.margen)
                .padding(.bottom, Espacio.xxl)
            }
            .fondoDePantalla()
            .toolbar(.hidden, for: .navigationBar)
            .sensoryFeedback(.success, trigger: registrados)
            .sheet(item: $agregando) { comida in
                NavigationStack {
                    BuscarView { alimento in
                        var p = almacen.planDe(dia)
                        let gramos = alimento.medidas.first?.gramos ?? 100
                        p.items.append(ItemPlan(comida: comida, nombre: alimento.nombre, gramos: gramos, por100g: alimento.por100g,
                                                origen: alimento.codigo.contains(":") ? .manual : .ins,
                                                codigoINS: alimento.codigo.contains(":") ? nil : alimento.codigo,
                                                recetaID: alimento.codigo.hasPrefix("R:") ? UUID(uuidString: String(alimento.codigo.dropFirst(2))) : nil))
                        p.dia = Calendar.current.startOfDay(for: dia)
                        almacen.guardarPlan(p)
                        agregando = nil
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { agregando = nil } }
                    }
                }
                .entornoSazon(almacen)
            }
            .task(id: plan) { pdf = plan.items.isEmpty ? nil : PDFPlan.crear(plan, meta: almacen.meta) }
        }
    }

    private var herramientas: some View {
        let columnas = [GridItem(.flexible(), spacing: Espacio.s), GridItem(.flexible(), spacing: Espacio.s)]
        return LazyVGrid(columns: columnas, spacing: Espacio.s) {
            acceso("cart.fill", "Lista de compras", "Próximos días", paleta.grasas) { ListaComprasView() }
            acceso("book.fill", "Mis recetas", "\(almacen.datos.recetas.count) guardadas", paleta.calorias) { RecetasView() }
            acceso("carrot.fill", "Mis alimentos", "\(almacen.datos.alimentosPropios.count) creados", paleta.carbohidratos) { AlimentosPropiosView() }
            acceso("arrow.left.arrow.right", "Comparar", "Lado a lado", paleta.proteina) { ComparadorView() }
        }
    }

    private func acceso<Destino: View>(_ simbolo: String, _ titulo: String, _ detalle: String, _ color: Color,
                                       @ViewBuilder destino: @escaping () -> Destino) -> some View {
        NavigationLink(destination: destino) {
            HStack(spacing: Espacio.s) {
                AzulejoColor(simbolo: simbolo, color: color, tamano: 40)
                VStack(alignment: .leading, spacing: Espacio.xxxs) {
                    Text(titulo).font(Tipo.nota.weight(.semibold)).foregroundStyle(paleta.texto)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(detalle).font(Tipo.micro).foregroundStyle(paleta.textoSecundario).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .tarjeta(relleno: Espacio.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var selectorDia: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Espacio.xs) {
                ForEach(dias, id: \.self) { d in
                    let elegido = Calendar.current.isDate(d, inSameDayAs: dia)
                    let tienePlan = !almacen.planDe(d).items.isEmpty
                    Button {
                        animar(.seleccion) { dia = d; variante = 0 }
                    } label: {
                        VStack(spacing: Espacio.xxs) {
                            Text(Formato.inicialDia(d)).font(Tipo.micro)
                            Text(Formato.numeroDia(d)).font(Tipo.cuerpoFuerte)
                            Circle().fill(tienePlan ? (elegido ? paleta.textoSobreAcento : paleta.acento) : Color.clear)
                                .frame(width: 5, height: 5)
                        }
                        .foregroundStyle(elegido ? paleta.textoSobreAcento : paleta.texto)
                        .frame(width: 48, height: 68)
                        .background(RoundedRectangle(cornerRadius: Radio.medio, style: .continuous)
                            .fill(elegido ? paleta.acento : paleta.superficie))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Formato.diaLargo(d) + (tienePlan ? ", con plan" : ""))
                }
            }
        }
        .sensoryFeedback(.selection, trigger: dia)
    }

    private func hero(_ plan: PlanDia) -> some View {
        let total = Planificador.total(plan)
        let meta = almacen.meta
        return VStack(alignment: .leading, spacing: Espacio.s) {
            Text(Formato.diaRelativo(dia)).font(Tipo.nota).foregroundStyle(paleta.textoHeroSecundario)
            if let meta {
                HStack(alignment: .firstTextBaseline, spacing: Espacio.xs) {
                    Text(Formato.entero(total.kcal)).font(Tipo.cifraGrande).foregroundStyle(paleta.textoHero)
                    Text("de \(Formato.entero(meta.kcal)) kcal").font(Tipo.nota).foregroundStyle(paleta.textoHeroSecundario)
                }
                if !plan.items.isEmpty {
                    HStack(spacing: Espacio.s) {
                        MacroHero(macro: .proteina, consumido: total.proteina, meta: meta.proteina)
                        MacroHero(macro: .carbohidratos, consumido: total.carbohidratos, meta: meta.carbohidratos)
                        MacroHero(macro: .grasas, consumido: total.grasas, meta: meta.grasas)
                    }
                }
                HStack(spacing: Espacio.s) {
                    Button {
                        variante += 1
                        almacen.generarPlan(dia, variante: variante)
                    } label: {
                        Label(plan.items.isEmpty ? "Generar plan" : "Otro plan", systemImage: "sparkles")
                            .font(Tipo.cuerpoFuerte)
                            .foregroundStyle(paleta.heroFin)
                            .frame(maxWidth: .infinity, minHeight: Medida.toque)
                            .background(Capsule().fill(paleta.textoHero))
                    }
                    .buttonStyle(.plain)
                    if let pdf {
                        ShareLink(item: pdf) {
                            Image(systemName: "square.and.arrow.up")
                                .font(Tipo.iconoFila)
                                .foregroundStyle(paleta.textoHero)
                                .frame(width: Medida.toque, height: Medida.toque)
                                .background(Circle().fill(paleta.textoHero.opacity(0.18)))
                        }
                        .accessibilityLabel("Compartir el plan en PDF")
                    }
                }
                Text("Usa tu tipo de dieta: \(almacen.datos.perfil?.dieta.nombre ?? TipoDieta.equilibrada.nombre).")
                    .font(Tipo.pie).foregroundStyle(paleta.textoHeroSecundario)
            } else {
                Text("Configura tu meta para generar planes").font(Tipo.subtitulo).foregroundStyle(paleta.textoHero)
                Text("El plan reparte tus calorías entre desayuno, almuerzo, cena y snacks.")
                    .font(Tipo.nota).foregroundStyle(paleta.textoHeroSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .hero()
    }

    private func tarjetaComida(_ comida: TipoComida, plan: PlanDia) -> some View {
        let items = plan.items.filter { $0.comida == comida }
        let kcal = items.reduce(0) { $0 + $1.total.kcal }
        return VStack(alignment: .leading, spacing: Espacio.s) {
            HStack(spacing: Espacio.s) {
                AzulejoColor(simbolo: comida.simbolo, color: paleta.color(comida), tamano: 40)
                Text(comida.nombre).font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                Spacer()
                Text("\(Formato.entero(kcal)) kcal").font(Tipo.pie.monospacedDigit()).foregroundStyle(paleta.textoSecundario)
                Button { agregando = comida } label: {
                    Image(systemName: "plus.circle.fill").font(Tipo.iconoFila).foregroundStyle(paleta.acento)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Agregar a \(comida.nombre)")
            }
            ForEach(items) { item in
                HStack(spacing: Espacio.s) {
                    VStack(alignment: .leading, spacing: Espacio.xxxs) {
                        Text(item.nombre).font(Tipo.nota).foregroundStyle(paleta.texto)
                            .strikethrough(item.hecho, color: paleta.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(Formato.entero(item.gramos)) g · \(Formato.entero(item.total.kcal)) kcal · P \(Formato.entero(item.total.proteina)) · C \(Formato.entero(item.total.carbohidratos)) · G \(Formato.entero(item.total.grasas))")
                            .font(Tipo.micro).foregroundStyle(paleta.textoSecundario)
                    }
                    Spacer(minLength: Espacio.xs)
                    if item.hecho {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(paleta.exito)
                            .accessibilityLabel("Registrado")
                    } else {
                        Button {
                            almacen.registrarDelPlan(item, dia: dia)
                            registrados += 1
                        } label: {
                            Text("Comí").font(Tipo.pie).foregroundStyle(paleta.textoSobreAcento)
                                .padding(.horizontal, Espacio.s).padding(.vertical, Espacio.xxs)
                                .background(Capsule().fill(paleta.acento))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Registrar \(item.nombre) en el diario")
                    }
                    Menu {
                        Button("Quitar del plan", role: .destructive) {
                            var p = almacen.planDe(dia)
                            p.items.removeAll { $0.id == item.id }
                            almacen.guardarPlan(p)
                        }
                    } label: {
                        Image(systemName: "ellipsis").foregroundStyle(paleta.textoSecundario).frame(width: 28, height: 28)
                    }
                }
            }
            if items.isEmpty {
                Text("Sin alimentos").font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
            }
        }
        .tarjeta()
    }
}

// MARK: - PDF del plan

enum PDFPlan {
    @MainActor
    static func crear(_ plan: PlanDia, meta: Nutrientes?) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Plan Sazón \(Formato.numeroDia(plan.dia)).pdf")
        let renderer = ImageRenderer(content: HojaPlan(plan: plan, meta: meta).frame(width: 595))
        var ok = false
        renderer.render { tamano, dibujar in
            var caja = CGRect(origin: .zero, size: tamano)
            guard let contexto = CGContext(url as CFURL, mediaBox: &caja, nil) else { return }
            contexto.beginPDFPage(nil)
            dibujar(contexto)
            contexto.endPDFPage()
            contexto.closePDF()
            ok = true
        }
        return ok ? url : nil
    }
}

private struct HojaPlan: View {
    let plan: PlanDia
    let meta: Nutrientes?

    var body: some View {
        let total = Planificador.total(plan)
        VStack(alignment: .leading, spacing: 14) {
            Text("Plan de comidas — Sazón").font(.system(size: 22, weight: .bold))
            Text(Formato.diaLargo(plan.dia)).font(.system(size: 13)).foregroundStyle(.gray)
            Text("Total: \(Formato.entero(total.kcal)) kcal" + (meta.map { " (meta \(Formato.entero($0.kcal)) kcal)" } ?? "")
                 + " · Proteína \(Formato.entero(total.proteina)) g · Carbohidratos \(Formato.entero(total.carbohidratos)) g · Grasas \(Formato.entero(total.grasas)) g")
                .font(.system(size: 12))
            ForEach(TipoComida.allCases, id: \.self) { comida in
                let items = plan.items.filter { $0.comida == comida }
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(comida.nombre).font(.system(size: 15, weight: .semibold))
                        ForEach(items) { i in
                            HStack {
                                Text("• \(i.nombre)").font(.system(size: 11))
                                Spacer()
                                Text("\(Formato.entero(i.gramos)) g · \(Formato.entero(i.total.kcal)) kcal").font(.system(size: 11))
                            }
                        }
                    }
                }
            }
            Text("Valores estimados con las Tablas Peruanas de Composición de Alimentos (INS) y tus recetas. No es consejo médico.")
                .font(.system(size: 9)).foregroundStyle(.gray)
        }
        .foregroundStyle(.black)
        .padding(40)
        .background(Color.white)
    }
}
