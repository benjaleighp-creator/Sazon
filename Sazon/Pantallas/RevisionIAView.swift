import SwiftUI

/// Revisión de lo que identificó la IA: corriges nombre, porción y la
/// fuente de los valores antes de guardar. Nada se guarda sin tu confirmación.
struct RevisionIAView: View {
    let identificados: [AlimentoIdentificado]
    @Binding var comida: TipoComida
    let alGuardar: ([Registro]) -> Void

    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var items: [ItemRevision] = []
    @State private var listo = false
    @State private var buscandoPara: UUID?

    var body: some View {
        let total = items.reduce(Nutrientes.cero) { $0 + $1.total }
        let hayEstimados = items.contains { $0.origen == .estimadoIA }
        let delINS = items.filter { $0.origen == .ins }.count
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.l) {
                // Resumen con degradado
                VStack(alignment: .leading, spacing: Espacio.m) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: Espacio.xxxs) {
                            Label("La IA encontró", systemImage: "sparkles")
                                .font(Tipo.pie)
                                .foregroundStyle(paleta.textoHeroSecundario)
                            Text("\(items.count) \(items.count == 1 ? "alimento" : "alimentos")")
                                .font(Tipo.titulo3)
                                .foregroundStyle(paleta.textoHero)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text((hayEstimados ? "≈ " : "") + Formato.entero(total.kcal))
                                .font(Tipo.cifra)
                                .foregroundStyle(paleta.textoHero)
                                .contentTransition(.numericText(value: total.kcal))
                            Text("kcal").font(Tipo.pie).foregroundStyle(paleta.textoHeroSecundario)
                        }
                    }
                    HStack(spacing: Espacio.s) {
                        datoHero("P", total.proteina)
                        datoHero("C", total.carbohidratos)
                        datoHero("G", total.grasas)
                    }
                    Text(delINS == items.count && !items.isEmpty
                         ? "Todos los valores salen de la tabla del INS."
                         : "\(delINS) con valores del INS · \(items.count - delINS) estimados por la IA (≈)")
                        .font(Tipo.pie)
                        .foregroundStyle(paleta.textoHeroSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .hero(relleno: Espacio.m)
                .accessibilityElement(children: .combine)

                if total.kcal > 0 {
                    VStack(alignment: .leading, spacing: Espacio.s) {
                        BarraApilada(nutrientes: total)
                        LeyendaMacros(nutrientes: total)
                    }
                    .tarjeta()
                }

                ForEach($items) { $item in
                    TarjetaItem(item: $item,
                                alElegirOtro: { buscandoPara = item.id },
                                alQuitar: { quitar(item.id) })
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }

                if items.isEmpty {
                    EstadoVacio(icono: "tray", titulo: "No queda nada para guardar",
                                texto: "Quitaste todos los alimentos. Vuelve atrás para intentarlo de nuevo.")
                }

                SelectorComidaGrande(comida: $comida)
            }
            .padding(.horizontal, Espacio.margen)
            .padding(.vertical, Espacio.m)
        }
        .fondoDePantalla()
        .navigationTitle("Revisar")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                guardar()
            } label: {
                Label("Guardar \(items.count) en \(comida.nombre.lowercased())", systemImage: "checkmark")
            }
            .buttonStyle(.principal)
            .disabled(items.isEmpty || items.contains { !$0.esValido })
            .padding(.horizontal, Espacio.margen)
            .padding(.bottom, Espacio.xs)
            .background(paleta.fondo.opacity(0.92))
        }
        .sheet(item: Binding(get: { buscandoPara.map { IdentificadorHoja(id: $0) } },
                             set: { buscandoPara = $0?.id })) { hoja in
            NavigationStack {
                BuscarView { alimento in
                    if let i = items.firstIndex(where: { $0.id == hoja.id }) {
                        items[i].ins = alimento
                        items[i].usarINS = true
                    }
                    buscandoPara = nil
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { buscandoPara = nil }
                    }
                }
            }
            .entornoSazon(almacen)
        }
        .onAppear {
            guard !listo else { return }
            listo = true
            items = identificados.map { ItemRevision(identificado: $0, coincidencia: almacen.tabla.emparejar($0.nombre)?.alimento) }
        }
    }

    private func datoHero(_ letra: String, _ gramos: Double) -> some View {
        HStack(spacing: Espacio.xxs) {
            Text(letra).font(Tipo.micro).foregroundStyle(paleta.textoHeroSecundario)
            Text("\(Formato.entero(gramos)) g").font(Tipo.cuerpoFuerte.monospacedDigit()).foregroundStyle(paleta.textoHero)
        }
        .padding(.horizontal, Espacio.s)
        .padding(.vertical, Espacio.xxs)
        .background(Capsule().fill(paleta.textoHero.opacity(0.14)))
    }

    private func quitar(_ id: UUID) {
        animar(.estandar) { items.removeAll { $0.id == id } }
    }

    private func guardar() {
        let fecha = Diario.fechaParaRegistrar(enDia: almacen.diaVisible)
        alGuardar(items.map { $0.registro(fecha: fecha, comida: comida) })
    }
}

private struct IdentificadorHoja: Identifiable {
    let id: UUID
}

private struct TarjetaItem: View {
    @Binding var item: ItemRevision
    let alElegirOtro: () -> Void
    let alQuitar: () -> Void
    @Environment(\.paleta) private var paleta

    var body: some View {
        let t = item.total
        let est = item.origen == .estimadoIA
        VStack(alignment: .leading, spacing: Espacio.m) {
            // Cabecera: ícono, nombre editable, quitar
            HStack(alignment: .center, spacing: Espacio.s) {
                AzulejoIcono(simbolo: est ? "sparkles" : "book.closed", tamano: 40)
                VStack(alignment: .leading, spacing: Espacio.xxs) {
                    TextField("Nombre", text: $item.nombre, axis: .vertical)
                        .font(Tipo.cuerpoFuerte)
                        .foregroundStyle(paleta.texto)
                        .accessibilityLabel("Nombre del alimento")
                    MedidorConfianza(valor: item.confianza)
                }
                Spacer(minLength: 0)
                Button(action: alQuitar) {
                    Image(systemName: "xmark")
                        .font(Tipo.iconoChico)
                        .foregroundStyle(paleta.textoSecundario)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(paleta.superficieAlta))
                }
                .buttonStyle(.plain)
                .frame(minWidth: Medida.toque, minHeight: Medida.toque)
                .accessibilityLabel("Quitar \(item.nombre)")
            }

            // Porción
            VStack(alignment: .leading, spacing: Espacio.xxs) {
                SelectorCantidad(valor: $item.gramos, paso: 10, unidad: "g")
                if let medida = item.medida, let cantidad = item.cantidadMedida {
                    Label("La IA calculó \(Formato.numero(cantidad)) \(medida.nombre) ≈ \(Formato.numero(medida.gramos * cantidad, decimales: 0)) g",
                          systemImage: "info.circle")
                        .font(Tipo.pie)
                        .foregroundStyle(paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Fuente de los valores
            VStack(alignment: .leading, spacing: Espacio.xs) {
                Text("Valores nutricionales").font(Tipo.micro).foregroundStyle(paleta.textoSecundario)
                FilaFlexible(espacio: Espacio.xs) {
                    if let ins = item.ins {
                        Chip(texto: "INS: \(ins.nombre)", icono: "book.closed", seleccionado: item.usarINS) {
                            item.usarINS = true
                        }
                    }
                    Chip(texto: "≈ Estimado por IA", icono: "sparkles", seleccionado: !item.usarINS || item.ins == nil) {
                        item.usarINS = false
                    }
                }
                Button(action: alElegirOtro) {
                    Label(item.ins == nil ? "Buscar en la tabla del INS" : "Elegir otro de la tabla", systemImage: "magnifyingglass")
                }
                .buttonStyle(.texto)
                .font(Tipo.pie)
            }

            // Totales
            HStack(spacing: Espacio.s) {
                VStack(alignment: .leading, spacing: 0) {
                    Text((est ? "≈ " : "") + Formato.entero(t.kcal))
                        .font(Tipo.titulo3.monospacedDigit())
                        .foregroundStyle(paleta.texto)
                    Text("kcal").font(Tipo.micro).foregroundStyle(paleta.textoSecundario)
                }
                Spacer(minLength: Espacio.xs)
                macro(.proteina, t.proteina)
                macro(.carbohidratos, t.carbohidratos)
                macro(.grasas, t.grasas)
            }
            .padding(Espacio.s)
            .background(RoundedRectangle(cornerRadius: Radio.medio, style: .continuous).fill(paleta.superficieAlta))
            .accessibilityElement(children: .combine)
        }
        .tarjeta()
    }

    private func macro(_ m: Macro, _ valor: Double) -> some View {
        VStack(spacing: Espacio.xxxs) {
            HStack(spacing: Espacio.xxs) {
                PuntoMacro(macro: m)
                Text(String(m.nombre.prefix(1))).font(Tipo.micro).foregroundStyle(paleta.textoSecundario)
            }
            Text("\(Formato.entero(valor)) g").font(Tipo.pie.monospacedDigit()).foregroundStyle(paleta.texto)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(m.nombre) \(Formato.entero(valor)) gramos")
    }
}
