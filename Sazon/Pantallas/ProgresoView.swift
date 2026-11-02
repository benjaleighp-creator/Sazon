import SwiftUI
import Charts
import PhotosUI

/// Progreso: peso, ajuste automático, nutrientes por día, racha,
/// composición corporal y fotos.
struct ProgresoView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var anotarPeso = false
    @State private var anotarMedidas = false
    @State private var rango = 30
    @State private var diasNutrientes = 7
    @State private var macroGrafico: Macro = .calorias
    @State private var aplicado = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Espacio.l) {
                    Text("Progreso")
                        .font(Tipo.titulo1)
                        .foregroundStyle(paleta.texto)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, Espacio.s)

                    heroPeso.aparicion(0)
                    if let ajuste = almacen.ajusteSugerido { tarjetaAjuste(ajuste).aparicion(1) }
                    graficoPeso.aparicion(2)
                    tarjetaRacha.aparicion(3)
                    graficoNutrientes.aparicion(4)
                    tarjetaCuerpo.aparicion(5)
                    FotosProgreso().aparicion(6)

                    Text("El peso, la grasa corporal y el IMC son referencias generales y no un diagnóstico. Consulta a un profesional de salud para una evaluación.")
                        .font(Tipo.pie)
                        .foregroundStyle(paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Espacio.margen)
                .padding(.bottom, Espacio.xxl)
            }
            .fondoDePantalla()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $anotarPeso) {
                AnotarPesoView().entornoSazon(almacen)
            }
            .sheet(isPresented: $anotarMedidas) {
                AnotarMedidasView().entornoSazon(almacen)
            }
            .sensoryFeedback(.success, trigger: aplicado)
        }
    }

    // MARK: Peso

    private var heroPeso: some View {
        let peso = almacen.pesoActual
        let tendencia = Cuerpo.tendenciaSemanal(almacen.datos.pesos, hasta: Date())
        let talla = almacen.datos.perfil?.tallaCm ?? 0
        return VStack(alignment: .leading, spacing: Espacio.s) {
            Text("Tu peso")
                .font(Tipo.nota)
                .foregroundStyle(paleta.textoHeroSecundario)
            HStack(alignment: .firstTextBaseline, spacing: Espacio.xs) {
                Text(peso.map { Formato.numero($0) } ?? "—")
                    .font(Tipo.cifraGrande)
                    .foregroundStyle(paleta.textoHero)
                Text("kg").font(Tipo.subtitulo).foregroundStyle(paleta.textoHeroSecundario)
                Spacer()
                if let t = tendencia {
                    Insignia(texto: (t > 0 ? "+" : "") + Formato.numero(t, decimales: 2) + " kg/sem",
                             icono: t > 0.02 ? "arrow.up.right" : (t < -0.02 ? "arrow.down.right" : "arrow.right"),
                             color: paleta.textoHero)
                }
            }
            HStack(spacing: Espacio.m) {
                if let peso, let imc = Cuerpo.imc(pesoKg: peso, tallaCm: talla) {
                    datoHero("IMC", Formato.numero(imc))
                }
                if let p = almacen.datos.perfil {
                    datoHero("Objetivo", p.objetivo.nombre)
                }
                datoHero("Pesajes", "\(almacen.datos.pesos.count)")
            }
            Button { anotarPeso = true } label: {
                Label("Anotar peso", systemImage: "plus")
                    .font(Tipo.cuerpoFuerte)
                    .foregroundStyle(paleta.heroFin)
                    .frame(maxWidth: .infinity, minHeight: Medida.toque)
                    .background(Capsule().fill(paleta.textoHero))
            }
            .buttonStyle(.plain)
        }
        .hero()
    }

    private func datoHero(_ titulo: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: Espacio.xxxs) {
            Text(titulo).font(Tipo.micro).foregroundStyle(paleta.textoHeroSecundario)
            Text(valor).font(Tipo.cuerpoFuerte).foregroundStyle(paleta.textoHero).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tarjetaAjuste(_ a: AjusteSugerido) -> some View {
        VStack(alignment: .leading, spacing: Espacio.s) {
            HStack(spacing: Espacio.s) {
                AzulejoIcono(simbolo: "wand.and.stars", tamano: 38)
                VStack(alignment: .leading, spacing: Espacio.xxxs) {
                    Text("Ajuste sugerido de tu meta").font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                    Text("Ajuste total: \(a.nuevoAjuste > 0 ? "+" : "")\(Formato.entero(a.nuevoAjuste)) kcal/día")
                        .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                }
            }
            Text(a.explicacion)
                .font(Tipo.nota).foregroundStyle(paleta.texto)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Espacio.s) {
                Button("Aplicar") {
                    almacen.aplicarAjuste(a)
                    aplicado += 1
                }
                .buttonStyle(.principal)
            }
            Text("Es una aproximación (1 kg ≈ 7700 kcal); tu cuerpo puede responder distinto. Puedes quitar el ajuste en Meta diaria.")
                .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .tarjeta()
    }

    private var graficoPeso: some View {
        let desde = Calendar.current.date(byAdding: .day, value: -rango, to: Date()) ?? Date()
        let puntos = Cuerpo.ordenados(almacen.datos.pesos).filter { $0.fecha >= desde }
        return VStack(alignment: .leading, spacing: Espacio.s) {
            HStack {
                Text("Evolución del peso").font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                Spacer()
                NavigationLink {
                    HistorialPesos()
                } label: {
                    Text("Historial").font(Tipo.pie)
                }
            }
            Picker("Rango", selection: $rango) {
                Text("30 días").tag(30)
                Text("90 días").tag(90)
                Text("1 año").tag(365)
            }
            .pickerStyle(.segmented)
            if puntos.count < 2 {
                Text("Anota tu peso al menos dos veces para ver la gráfica. Lo ideal es pesarte a la misma hora, por ejemplo al despertar.")
                    .font(Tipo.nota).foregroundStyle(paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                let minimo = (puntos.map(\.kg).min() ?? 0) - 1
                let maximo = (puntos.map(\.kg).max() ?? 0) + 1
                Chart(puntos) { p in
                    AreaMark(x: .value("Fecha", p.fecha), yStart: .value("Base", minimo), yEnd: .value("Peso", p.kg))
                        .foregroundStyle(LinearGradient(colors: [paleta.acento.opacity(0.25), paleta.acento.opacity(0.02)],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Fecha", p.fecha), y: .value("Peso", p.kg))
                        .foregroundStyle(paleta.acento)
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    PointMark(x: .value("Fecha", p.fecha), y: .value("Peso", p.kg))
                        .foregroundStyle(paleta.acento)
                        .symbolSize(30)
                }
                .chartYScale(domain: minimo...maximo)
                .frame(height: 200)
                .accessibilityLabel("Gráfica de peso con \(puntos.count) registros")
            }
        }
        .tarjeta()
    }

    private var tarjetaRacha: some View {
        let racha = Series.racha(almacen.datos.registros, hoy: Date())
        let semana = Series.nutrientesPorDia(almacen.datos.registros, hasta: Date(), dias: 7)
        return HStack(spacing: Espacio.m) {
            AzulejoIcono(simbolo: "flame.fill", tamano: 48, color: paleta.calorias)
            VStack(alignment: .leading, spacing: Espacio.xxxs) {
                Text("\(racha) \(racha == 1 ? "día" : "días") seguidos")
                    .font(Tipo.subtitulo).foregroundStyle(paleta.texto)
                Text("registrando tus comidas")
                    .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
            }
            Spacer()
            HStack(spacing: Espacio.xxs) {
                ForEach(semana, id: \.fecha) { d in
                    VStack(spacing: Espacio.xxxs) {
                        Circle()
                            .fill(d.total.kcal > 0 ? paleta.calorias : paleta.borde)
                            .frame(width: 10, height: 10)
                        Text(Formato.inicialDia(d.fecha)).font(Tipo.micro).foregroundStyle(paleta.textoSecundario)
                    }
                }
            }
            .accessibilityHidden(true)
        }
        .tarjeta()
        .accessibilityElement(children: .combine)
    }

    private var graficoNutrientes: some View {
        let dias = Series.nutrientesPorDia(almacen.datos.registros, hasta: Date(), dias: diasNutrientes)
        let promedio = Series.promedio(dias)
        let meta = almacen.meta.map { macroGrafico.valor($0) }
        return VStack(alignment: .leading, spacing: Espacio.s) {
            Text("Nutrientes por día").font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
            Picker("Días", selection: $diasNutrientes) {
                Text("7 días").tag(7)
                Text("30 días").tag(30)
            }
            .pickerStyle(.segmented)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Espacio.xs) {
                    ForEach(Macro.allCases) { m in
                        Chip(texto: m.nombre, seleccionado: macroGrafico == m) {
                            animar(.seleccion) { macroGrafico = m }
                        }
                    }
                }
            }
            Chart {
                ForEach(dias, id: \.fecha) { d in
                    BarMark(x: .value("Día", d.fecha, unit: .day), y: .value(macroGrafico.nombre, macroGrafico.valor(d.total)))
                        .foregroundStyle(paleta.color(macroGrafico))
                        .cornerRadius(4)
                }
                if let meta, meta > 0 {
                    RuleMark(y: .value("Meta", meta))
                        .foregroundStyle(paleta.textoSecundario)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Meta \(Formato.entero(meta)) \(macroGrafico.unidad)")
                                .font(Tipo.micro).foregroundStyle(paleta.textoSecundario)
                        }
                }
            }
            .frame(height: 180)
            HStack {
                Text("Promedio de los días con registros")
                    .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                Spacer()
                Text("\(Formato.entero(macroGrafico.valor(promedio))) \(macroGrafico.unidad)")
                    .font(Tipo.cuerpoFuerte.monospacedDigit()).foregroundStyle(paleta.texto)
            }
            if promedio.kcal > 0 {
                HStack {
                    Text("Fibra promedio").font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                    Spacer()
                    Text("\(Formato.numero(promedio.fibra)) g").font(Tipo.pie.monospacedDigit()).foregroundStyle(paleta.texto)
                }
                HStack {
                    Text("Sodio promedio").font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                    Spacer()
                    Text("\(Formato.entero(promedio.sodio)) mg").font(Tipo.pie.monospacedDigit()).foregroundStyle(paleta.texto)
                }
                Text("La fibra y el sodio solo cuentan los alimentos que traen ese dato.")
                    .font(Tipo.micro).foregroundStyle(paleta.textoSecundario)
            }
        }
        .tarjeta()
    }

    // MARK: Cuerpo

    private var tarjetaCuerpo: some View {
        let ultima = almacen.datos.medidas.sorted { $0.fecha < $1.fecha }.last
        let grasa = ultima.flatMap { Cuerpo.grasa(de: $0, perfil: almacen.datos.perfil) }
        return VStack(alignment: .leading, spacing: Espacio.s) {
            HStack {
                Text("Composición corporal").font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                Spacer()
                Button { anotarMedidas = true } label: {
                    Label("Medidas", systemImage: "plus").font(Tipo.pie)
                }
            }
            if let ultima {
                HStack(spacing: Espacio.m) {
                    VStack(alignment: .leading, spacing: Espacio.xxxs) {
                        Text("Grasa corporal ≈").font(Tipo.micro).foregroundStyle(paleta.textoSecundario)
                        Text(grasa.map { Formato.numero($0) + " %" } ?? "—")
                            .font(Tipo.cifra).foregroundStyle(paleta.texto)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: Espacio.xxxs) {
                        Text(Formato.diaRelativo(ultima.fecha)).font(Tipo.micro).foregroundStyle(paleta.textoSecundario)
                        if ultima.grasaManual == nil {
                            Text("Fórmula de la Marina de EE. UU.").font(Tipo.micro).foregroundStyle(paleta.textoSecundario)
                        } else {
                            Text("Escrita a mano").font(Tipo.micro).foregroundStyle(paleta.textoSecundario)
                        }
                    }
                }
                FilaFlexible {
                    medida("Cintura", ultima.cintura)
                    medida("Cuello", ultima.cuello)
                    medida("Cadera", ultima.cadera)
                    medida("Pecho", ultima.pecho)
                    medida("Brazo", ultima.brazo)
                    medida("Muslo", ultima.muslo)
                }
                NavigationLink { HistorialMedidas() } label: { Text("Ver historial de medidas").font(Tipo.pie) }
            } else {
                Text("Anota tu cintura y cuello (y cadera, si eres mujer) con una cinta métrica para estimar tu grasa corporal.")
                    .font(Tipo.nota).foregroundStyle(paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tarjeta()
    }

    @ViewBuilder
    private func medida(_ nombre: String, _ valor: Double?) -> some View {
        if let valor {
            Insignia(texto: "\(nombre) \(Formato.numero(valor)) cm")
        }
    }
}

// MARK: - Anotar peso

struct AnotarPesoView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @Environment(\.dismiss) private var cerrar
    @State private var kg: Double = 0
    @State private var fecha = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CampoNumero(titulo: "Peso", valor: $kg, unidad: "kg")
                    DatePicker("Fecha", selection: $fecha, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                } footer: {
                    Text("Tu peso actualiza tu perfil y la meta se recalcula. Si conectaste Apple Salud, también se guarda allí.")
                }
            }
            .navigationTitle("Anotar peso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        almacen.registrarPeso(kg, fecha: fecha)
                        cerrar()
                    }
                    .disabled(!(20...400).contains(kg))
                }
            }
            .onAppear { kg = almacen.pesoActual ?? 0 }
        }
        .presentationDetents([.medium])
    }
}

struct HistorialPesos: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta

    var body: some View {
        List {
            let pesos = Cuerpo.ordenados(almacen.datos.pesos).reversed()
            if pesos.isEmpty {
                Text("Aún no hay pesos.").foregroundStyle(paleta.textoSecundario)
            }
            ForEach(Array(pesos)) { p in
                HStack {
                    Text(Formato.diaLargo(p.fecha)).foregroundStyle(paleta.texto)
                    Spacer()
                    Text("\(Formato.numero(p.kg)) kg").monospacedDigit().foregroundStyle(paleta.texto)
                }
                .swipeActions {
                    Button(role: .destructive) { almacen.eliminarPeso(p) } label: { Label("Borrar", systemImage: "trash") }
                }
            }
        }
        .navigationTitle("Historial de peso")
    }
}

// MARK: - Medidas

struct AnotarMedidasView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var cintura: Double = 0
    @State private var cuello: Double = 0
    @State private var cadera: Double = 0
    @State private var pecho: Double = 0
    @State private var brazo: Double = 0
    @State private var muslo: Double = 0
    @State private var grasa: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CampoNumero(titulo: "Cintura (a la altura del ombligo)", valor: $cintura, unidad: "cm")
                    CampoNumero(titulo: "Cuello", valor: $cuello, unidad: "cm")
                    CampoNumero(titulo: "Cadera", valor: $cadera, unidad: "cm")
                } header: {
                    Text("Para estimar la grasa")
                } footer: {
                    Text("Con cintura y cuello (y cadera en mujeres) se estima el % de grasa con la fórmula de la Marina de EE. UU. Es una aproximación.")
                }
                Section("Otras medidas (opcionales)") {
                    CampoNumero(titulo: "Pecho", valor: $pecho, unidad: "cm")
                    CampoNumero(titulo: "Brazo", valor: $brazo, unidad: "cm")
                    CampoNumero(titulo: "Muslo", valor: $muslo, unidad: "cm")
                }
                Section {
                    CampoNumero(titulo: "% de grasa medido", valor: $grasa, unidad: "%")
                } header: {
                    Text("Si lo mediste con otro método")
                } footer: {
                    Text("Por ejemplo, una balanza de bioimpedancia. Si lo escribes, se usa en lugar de la fórmula.")
                }
            }
            .navigationTitle("Medidas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        func v(_ x: Double) -> Double? { x > 0 ? x : nil }
                        almacen.registrarMedidas(RegistroMedidas(fecha: Date(), cuello: v(cuello), cintura: v(cintura), cadera: v(cadera),
                                                                 pecho: v(pecho), brazo: v(brazo), muslo: v(muslo), grasaManual: v(grasa)))
                        cerrar()
                    }
                    .disabled([cintura, cuello, cadera, pecho, brazo, muslo, grasa].allSatisfy { $0 <= 0 })
                }
            }
        }
    }
}

struct HistorialMedidas: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta

    var body: some View {
        List {
            ForEach(almacen.datos.medidas.sorted { $0.fecha > $1.fecha }) { m in
                VStack(alignment: .leading, spacing: Espacio.xxs) {
                    Text(Formato.diaLargo(m.fecha)).font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                    Text(texto(m)).font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                }
                .swipeActions {
                    Button(role: .destructive) { almacen.eliminarMedidas(m) } label: { Label("Borrar", systemImage: "trash") }
                }
            }
        }
        .navigationTitle("Medidas")
    }

    private func texto(_ m: RegistroMedidas) -> String {
        var partes: [String] = []
        if let g = Cuerpo.grasa(de: m, perfil: almacen.datos.perfil) { partes.append("Grasa ≈ \(Formato.numero(g)) %") }
        let lista: [(String, Double?)] = [("cintura", m.cintura), ("cuello", m.cuello), ("cadera", m.cadera),
                                          ("pecho", m.pecho), ("brazo", m.brazo), ("muslo", m.muslo)]
        for (n, v) in lista { if let v { partes.append("\(n) \(Formato.numero(v)) cm") } }
        return partes.joined(separator: " · ")
    }
}

// MARK: - Fotos

struct FotosProgreso: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var elegida: PhotosPickerItem?
    @State private var viendo: FotoProgreso?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.s) {
            HStack {
                Text("Fotos de progreso").font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                Spacer()
                PhotosPicker(selection: $elegida, matching: .images) {
                    Label("Agregar", systemImage: "plus").font(Tipo.pie)
                }
            }
            if almacen.datos.fotos.isEmpty {
                Text("Se guardan solo en tu iPhone, dentro de Sazón. No se envían a la IA ni a ningún servidor.")
                    .font(Tipo.nota).foregroundStyle(paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Espacio.s) {
                        ForEach(almacen.datos.fotos.sorted { $0.fecha > $1.fecha }) { f in
                            Button { viendo = f } label: {
                                VStack(spacing: Espacio.xxs) {
                                    miniatura(f)
                                    Text(Formato.diaRelativo(f.fecha)).font(Tipo.micro).foregroundStyle(paleta.textoSecundario)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            if let error { Text(error).font(Tipo.pie).foregroundStyle(paleta.peligro) }
        }
        .tarjeta()
        .onChange(of: elegida) { _, item in
            guard let item else { return }
            Task {
                if let datos = try? await item.loadTransferable(type: Data.self), let imagen = UIImage(data: datos),
                   almacen.agregarFoto(imagen) {
                    error = nil
                } else {
                    error = "No se pudo guardar la foto."
                }
                elegida = nil
            }
        }
        .sheet(item: $viendo) { f in
            VistaFoto(foto: f).entornoSazon(almacen)
        }
    }

    @ViewBuilder
    private func miniatura(_ f: FotoProgreso) -> some View {
        if let img = almacen.imagen(de: f) {
            Image(uiImage: img).resizable().scaledToFill()
                .frame(width: 96, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: Radio.medio, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: Radio.medio, style: .continuous).fill(paleta.superficieAlta)
                .frame(width: 96, height: 128)
        }
    }
}

struct VistaFoto: View {
    let foto: FotoProgreso
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            Group {
                if let img = almacen.imagen(de: foto) {
                    Image(uiImage: img).resizable().scaledToFit()
                } else {
                    Text("No se encontró la imagen.")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationTitle(Formato.diaLargo(foto.fecha))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { cerrar() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        almacen.eliminarFoto(foto)
                        cerrar()
                    } label: { Image(systemName: "trash") }
                }
            }
        }
    }
}
