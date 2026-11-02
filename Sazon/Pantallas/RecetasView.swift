import SwiftUI

// Recetas, alimentos propios, lista de compras y comparador.

// MARK: - Recetas

struct RecetasView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var editando: Receta?

    var body: some View {
        List {
            if almacen.datos.recetas.isEmpty {
                EstadoVacio(icono: "book", titulo: "Sin recetas",
                            texto: "Crea una receta con sus ingredientes y Sazón calcula las calorías por porción. Luego aparece en la búsqueda y en el plan.")
                    .listRowBackground(Color.clear)
            }
            ForEach(almacen.datos.recetas.sorted { $0.nombre < $1.nombre }) { r in
                Button { editando = r } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: Espacio.xxxs) {
                            Text(r.nombre).font(Tipo.cuerpo).foregroundStyle(paleta.texto)
                            Text("\(r.ingredientes.count) ingredientes · \(Formato.numero(r.porciones, decimales: 1)) porciones")
                                .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                        }
                        Spacer()
                        Text("\(Formato.entero(Recetas.porPorcion(r).kcal)) kcal/porción")
                            .font(Tipo.pie.monospacedDigit()).foregroundStyle(paleta.textoSecundario)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(paleta.superficie)
                .swipeActions {
                    Button(role: .destructive) { almacen.eliminarReceta(r) } label: { Label("Borrar", systemImage: "trash") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .fondoDePantalla()
        .navigationTitle("Mis recetas")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editando = Receta(nombre: "") } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Nueva receta")
            }
        }
        .sheet(item: $editando) { r in
            EditorReceta(receta: r).entornoSazon(almacen)
        }
    }
}

struct EditorReceta: View {
    @State var receta: Receta
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @Environment(\.dismiss) private var cerrar
    @State private var buscando = false
    @State private var pesoFinal: Double = 0
    @State private var nuevoPaso = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre (por ejemplo, Lomo saltado de casa)", text: $receta.nombre)
                    Stepper(value: $receta.porciones, in: 1...50, step: 1) {
                        Text("Porciones: \(Formato.entero(receta.porciones))")
                    }
                    CampoNumero(titulo: "Peso final cocido (opcional)", valor: $pesoFinal, unidad: "g", decimales: 0)
                } footer: {
                    Text("Si pesas la olla ya cocida (sin la olla), el cálculo por 100 g es más exacto, porque al cocinar se pierde o gana agua.")
                }

                Section("Ingredientes") {
                    ForEach($receta.ingredientes) { $ing in
                        VStack(alignment: .leading, spacing: Espacio.xxs) {
                            Text(ing.nombre).font(Tipo.nota)
                            HStack {
                                CampoNumero(titulo: "Gramos", valor: $ing.gramos, unidad: "g", decimales: 0)
                                Text("\(Formato.entero(ing.total.kcal)) kcal").font(Tipo.pie.monospacedDigit())
                                    .foregroundStyle(paleta.textoSecundario)
                            }
                        }
                    }
                    .onDelete { receta.ingredientes.remove(atOffsets: $0) }
                    Button { buscando = true } label: { Label("Agregar ingrediente", systemImage: "plus") }
                }

                Section("Preparación (opcional)") {
                    ForEach(Array(receta.pasos.enumerated()), id: \.offset) { i, paso in
                        Text("\(i + 1). \(paso)")
                    }
                    .onDelete { receta.pasos.remove(atOffsets: $0) }
                    HStack {
                        TextField("Nuevo paso", text: $nuevoPaso, axis: .vertical)
                        Button("Añadir") {
                            let t = nuevoPaso.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !t.isEmpty { receta.pasos.append(t); nuevoPaso = "" }
                        }
                    }
                }

                if !receta.ingredientes.isEmpty {
                    Section("Resultado") {
                        let porcion = Recetas.porPorcion(receta)
                        FilaValor(titulo: "Total", valor: "\(Formato.entero(Recetas.total(receta).kcal)) kcal")
                        FilaValor(titulo: "Por porción (\(Formato.entero(Recetas.gramosPorPorcion(receta))) g)",
                                  valor: "\(Formato.entero(porcion.kcal)) kcal")
                        FilaValor(titulo: "Proteína / Carbos / Grasas por porción",
                                  valor: "\(Formato.entero(porcion.proteina)) / \(Formato.entero(porcion.carbohidratos)) / \(Formato.entero(porcion.grasas)) g")
                    }
                }
            }
            .navigationTitle(receta.nombre.isEmpty ? "Nueva receta" : receta.nombre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        receta.pesoFinal = pesoFinal > 0 ? pesoFinal : nil
                        receta.nombre = receta.nombre.trimmingCharacters(in: .whitespaces)
                        almacen.guardarReceta(receta)
                        cerrar()
                    }
                    .disabled(receta.nombre.trimmingCharacters(in: .whitespaces).isEmpty || receta.ingredientes.isEmpty)
                }
            }
            .onAppear { pesoFinal = receta.pesoFinal ?? 0 }
            .sheet(isPresented: $buscando) {
                NavigationStack {
                    BuscarView { a in
                        // Una receta no puede incluirse a sí misma.
                        guard a.codigo != "R:\(receta.id.uuidString)" else { return }
                        receta.ingredientes.append(Ingrediente(nombre: a.nombre, gramos: a.medidas.first?.gramos ?? 100,
                                                               por100g: a.por100g, origen: a.codigo.contains(":") ? .manual : .ins,
                                                               codigoINS: a.codigo.contains(":") ? nil : a.codigo))
                        buscando = false
                    }
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { buscando = false } } }
                }
                .entornoSazon(almacen)
            }
        }
    }
}

// MARK: - Mis alimentos

struct AlimentosPropiosView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var editando: AlimentoPropio?

    var body: some View {
        List {
            if almacen.datos.alimentosPropios.isEmpty {
                EstadoVacio(icono: "carrot", titulo: "Sin alimentos propios",
                            texto: "Crea un alimento con sus valores por 100 g (por ejemplo, de una etiqueta). Aparece en la búsqueda junto a la tabla del INS.")
                    .listRowBackground(Color.clear)
            }
            ForEach(almacen.datos.alimentosPropios.sorted { $0.nombre < $1.nombre }) { a in
                Button { editando = a } label: {
                    HStack {
                        Text(a.nombre).font(Tipo.cuerpo).foregroundStyle(paleta.texto)
                        Spacer()
                        Text("\(Formato.entero(a.por100g.kcal)) kcal/100 g").font(Tipo.pie.monospacedDigit())
                            .foregroundStyle(paleta.textoSecundario)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(paleta.superficie)
                .swipeActions {
                    Button(role: .destructive) { almacen.eliminarAlimentoPropio(a) } label: { Label("Borrar", systemImage: "trash") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .fondoDePantalla()
        .navigationTitle("Mis alimentos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editando = AlimentoPropio(nombre: "", por100g: .cero) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Nuevo alimento")
            }
        }
        .sheet(item: $editando) { a in
            EditorAlimentoPropio(alimento: a).entornoSazon(almacen)
        }
    }
}

struct EditorAlimentoPropio: View {
    @State var alimento: AlimentoPropio
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var nombreMedida = ""
    @State private var gramosMedida: Double = 0
    @State private var calculando = false
    @State private var errorIA: ErrorIA?
    @State private var estimadoIA = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $alimento.nombre)
                }
                Section {
                    Button {
                        calcularConIA()
                    } label: {
                        if calculando {
                            HStack { ProgressView(); Text("Calculando…") }
                        } else {
                            Label("Calcular los valores con IA", systemImage: "sparkles")
                        }
                    }
                    .disabled(calculando || alimento.nombre.trimmingCharacters(in: .whitespaces).count < 2)
                    if let errorIA {
                        Text(errorIA.mensaje).font(Tipo.pie).foregroundStyle(.red)
                    }
                    if estimadoIA {
                        Text("≈ Valores estimados por la IA a partir del nombre. Revísalos y corrígelos si tienes la etiqueta.")
                            .font(Tipo.pie)
                    }
                } footer: {
                    Text("Escribe el nombre con detalle (por ejemplo «causa limeña de pollo, 1 porción») y Gemini estima calorías y macros. Solo se envía ese nombre.")
                }
                Section("Por 100 g") {
                    CampoNumero(titulo: "Calorías", valor: $alimento.por100g.kcal, unidad: "kcal", decimales: 0)
                    CampoNumero(titulo: "Proteína", valor: $alimento.por100g.proteina, unidad: "g")
                    CampoNumero(titulo: "Carbohidratos", valor: $alimento.por100g.carbohidratos, unidad: "g")
                    CampoNumero(titulo: "Grasas", valor: $alimento.por100g.grasas, unidad: "g")
                    CampoNumero(titulo: "Fibra (opcional)", valor: $alimento.por100g.fibra, unidad: "g")
                    CampoNumero(titulo: "Sodio (opcional)", valor: $alimento.por100g.sodio, unidad: "mg", decimales: 0)
                    CampoNumero(titulo: "Azúcares (opcional)", valor: $alimento.por100g.azucar, unidad: "g")
                }
                Section {
                    ForEach(alimento.medidas) { m in
                        FilaValor(titulo: m.nombre, valor: "\(Formato.entero(m.gramos)) g")
                    }
                    .onDelete { alimento.medidas.remove(atOffsets: $0) }
                    TextField("Nombre (por ejemplo, 1 unidad)", text: $nombreMedida)
                    CampoNumero(titulo: "Gramos de esa medida", valor: $gramosMedida, unidad: "g", decimales: 0)
                    Button("Agregar medida") {
                        alimento.medidas.append(MedidaCasera(nombre: nombreMedida.trimmingCharacters(in: .whitespaces), gramos: gramosMedida, estimada: false))
                        nombreMedida = ""; gramosMedida = 0
                    }
                    .disabled(nombreMedida.trimmingCharacters(in: .whitespaces).isEmpty || gramosMedida <= 0)
                } header: {
                    Text("Medidas caseras")
                }
            }
            .navigationTitle(alimento.nombre.isEmpty ? "Nuevo alimento" : alimento.nombre)
            .sensoryFeedback(.success, trigger: estimadoIA)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        alimento.nombre = alimento.nombre.trimmingCharacters(in: .whitespaces)
                        almacen.guardarAlimentoPropio(alimento)
                        cerrar()
                    }
                    .disabled(alimento.nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func calcularConIA() {
        errorIA = nil
        calculando = true
        let pedido = alimento.nombre
        Task {
            defer { calculando = false }
            do {
                let proveedor = try ServicioIA.proveedorActual(almacen.datos)
                let lista = try await proveedor.analizar(texto: pedido).alimentos
                let gramos = lista.reduce(0) { $0 + $1.gramos }
                guard gramos > 0 else { throw ErrorIA.sinAlimentos }
                let total = lista.reduce(Nutrientes.cero) { $0 + $1.por100g * ($1.gramos / 100) }
                alimento.por100g = total * (100 / gramos)
                if !alimento.medidas.contains(where: { $0.nombre == "porción" }) {
                    alimento.medidas.append(MedidaCasera(nombre: "porción", gramos: gramos.rounded(), estimada: true))
                }
                estimadoIA = true
            } catch let e as ErrorIA {
                errorIA = e
            } catch {
                errorIA = .desconocido(error.localizedDescription)
            }
        }
    }
}

// MARK: - Lista de compras

struct ListaComprasView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var dias = 7

    var body: some View {
        let hoy = Calendar.current.startOfDay(for: Date())
        let hasta = Calendar.current.date(byAdding: .day, value: dias, to: hoy) ?? hoy
        let planes = almacen.datos.plan.filter { $0.dia >= hoy && $0.dia < hasta }
        let lista = Planificador.listaCompras(planes, recetas: almacen.datos.recetas)
        let grupos = Dictionary(grouping: lista, by: \.grupo).sorted { $0.key < $1.key }
        List {
            Section {
                Picker("Días", selection: $dias) {
                    Text("3 días").tag(3)
                    Text("7 días").tag(7)
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Suma lo de \(planes.count) \(planes.count == 1 ? "día planeado" : "días planeados"). Las recetas se abren en sus ingredientes. Los gramos son de alimento listo para comer, así que compra un poco más si se pela o se cocina.")
            }
            if lista.isEmpty {
                Text("Genera planes en la pestaña Plan para armar tu lista.")
                    .foregroundStyle(paleta.textoSecundario)
            }
            ForEach(grupos, id: \.key) { grupo in
                Section(grupo.key) {
                    ForEach(grupo.value) { e in
                        let marcado = almacen.datos.comprasMarcadas.contains(e.clave)
                        Button { almacen.alternarCompra(e.clave) } label: {
                            HStack {
                                Image(systemName: marcado ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(marcado ? paleta.exito : paleta.textoSecundario)
                                Text(e.nombre).foregroundStyle(marcado ? paleta.textoSecundario : paleta.texto)
                                    .strikethrough(marcado)
                                Spacer()
                                Text("\(Formato.entero(e.gramos)) g").monospacedDigit().foregroundStyle(paleta.textoSecundario)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !almacen.datos.comprasMarcadas.isEmpty {
                Button("Desmarcar todo") { almacen.datos.comprasMarcadas = [] }
            }
        }
        .navigationTitle("Lista de compras")
        .sensoryFeedback(.selection, trigger: almacen.datos.comprasMarcadas)
    }
}

// MARK: - Comparador

struct ComparadorView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var a: AlimentoBase?
    @State private var b: AlimentoBase?
    @State private var eligiendo: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: Espacio.m) {
                HStack(spacing: Espacio.s) {
                    selector(a, 1)
                    selector(b, 2)
                }
                if let a, let b {
                    VStack(spacing: Espacio.s) {
                        Text("Por 100 g").font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                        fila("Calorías", a.por100g.kcal, b.por100g.kcal, "kcal", menosEsMejor: nil)
                        fila("Proteína", a.por100g.proteina, b.por100g.proteina, "g", menosEsMejor: false)
                        fila("Carbohidratos", a.por100g.carbohidratos, b.por100g.carbohidratos, "g", menosEsMejor: nil)
                        fila("Grasas", a.por100g.grasas, b.por100g.grasas, "g", menosEsMejor: nil)
                        fila("Fibra", a.por100g.fibra, b.por100g.fibra, "g", menosEsMejor: false)
                        fila("Sodio", a.por100g.sodio, b.por100g.sodio, "mg", menosEsMejor: true)
                        fila("Azúcares", a.por100g.azucar, b.por100g.azucar, "g", menosEsMejor: true)
                    }
                    .tarjeta()
                    Text("Se resalta la mayor proteína y fibra y el menor sodio y azúcar (la tabla del INS no informa azúcares: ahí verás 0). Calorías, carbohidratos y grasas dependen de tu objetivo.")
                        .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, Espacio.margen)
            .padding(.vertical, Espacio.m)
        }
        .fondoDePantalla()
        .navigationTitle("Comparar")
        .sheet(item: Binding(get: { eligiendo.map { ElegidoComparar(id: $0) } }, set: { eligiendo = $0?.id })) { e in
            NavigationStack {
                BuscarView { x in
                    if e.id == 1 { a = x } else { b = x }
                    eligiendo = nil
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { eligiendo = nil } } }
            }
            .entornoSazon(almacen)
        }
    }

    private func selector(_ x: AlimentoBase?, _ n: Int) -> some View {
        Button { eligiendo = n } label: {
            VStack(spacing: Espacio.xs) {
                Image(systemName: x == nil ? "plus.magnifyingglass" : "checkmark.seal").font(Tipo.iconoMedio).foregroundStyle(paleta.acento)
                Text(x?.nombre ?? "Elegir alimento \(n)").font(Tipo.nota).foregroundStyle(paleta.texto)
                    .multilineTextAlignment(.center).lineLimit(3)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .tarjeta(relleno: Espacio.s)
        }
        .buttonStyle(.plain)
    }

    private func fila(_ nombre: String, _ va: Double, _ vb: Double, _ unidad: String, menosEsMejor: Bool?) -> some View {
        let ganaA: Bool? = {
            guard let menos = menosEsMejor, va != vb else { return nil }
            return menos ? va < vb : va > vb
        }()
        return HStack {
            Text("\(Formato.numero(va)) \(unidad)").monospacedDigit()
                .fontWeight(ganaA == true ? .bold : .regular)
                .foregroundStyle(ganaA == true ? paleta.exito : paleta.texto)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(nombre).font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
            Text("\(Formato.numero(vb)) \(unidad)").monospacedDigit()
                .fontWeight(ganaA == false ? .bold : .regular)
                .foregroundStyle(ganaA == false ? paleta.exito : paleta.texto)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(Tipo.nota)
    }
}

private struct ElegidoComparar: Identifiable {
    let id: Int
}
