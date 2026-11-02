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
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.l) {
                Text("Revisa y corrige. Los valores salen de la tabla del INS cuando hay coincidencia; si no, son estimaciones de la IA (≈).")
                    .font(Tipo.nota)
                    .foregroundStyle(paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach($items) { $item in
                    TarjetaItem(item: $item,
                                alElegirOtro: { buscandoPara = item.id },
                                alQuitar: { quitar(item.id) })
                }

                if items.isEmpty {
                    EstadoVacio(icono: "tray", titulo: "No queda nada para guardar",
                                texto: "Quitaste todos los alimentos. Vuelve atrás para intentarlo de nuevo.")
                } else {
                    HStack {
                        Text("Total").font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                        Spacer()
                        Text(Formato.kcal(total.kcal, estimado: hayEstimados))
                            .font(Tipo.cuerpoFuerte.monospacedDigit())
                            .foregroundStyle(paleta.texto)
                    }
                    .tarjeta()
                    .accessibilityElement(children: .combine)
                }

                SelectorComida(comida: $comida)
            }
            .padding(.horizontal, Espacio.margen)
            .padding(.vertical, Espacio.m)
        }
        .fondoDePantalla()
        .navigationTitle("Revisar")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button("Guardar \(items.count) en \(comida.nombre.lowercased())") { guardar() }
                .buttonStyle(.principal)
                .disabled(items.isEmpty || items.contains { !$0.esValido })
                .padding(.horizontal, Espacio.margen)
                .padding(.bottom, Espacio.xs)
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
        VStack(alignment: .leading, spacing: Espacio.s) {
            HStack(alignment: .top) {
                CampoTexto(titulo: "Nombre", texto: $item.nombre)
                Button(action: alQuitar) {
                    Image(systemName: "trash")
                        .font(Tipo.iconoFila)
                        .foregroundStyle(paleta.peligro)
                        .frame(minWidth: Medida.toque, minHeight: Medida.toque)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Quitar \(item.nombre)")
            }

            if item.confianzaEsBaja {
                Label("La IA no está segura de este alimento o de su porción: revísalo.", systemImage: "exclamationmark.circle")
                    .font(Tipo.pie)
                    .foregroundStyle(paleta.aviso)
                    .fixedSize(horizontal: false, vertical: true)
            }

            CampoNumero(titulo: "Gramos", valor: $item.gramos, unidad: "g", decimales: 0)
            if let medida = item.medida, let cantidad = item.cantidadMedida {
                Text("La IA calculó \(Formato.numero(cantidad)) \(medida.nombre) ≈ \(Formato.numero(medida.gramos * cantidad, decimales: 0)) g")
                    .font(Tipo.pie)
                    .foregroundStyle(paleta.textoSecundario)
            }

            // Fuente de los valores
            VStack(alignment: .leading, spacing: Espacio.xs) {
                if let ins = item.ins {
                    Chip(texto: "Tabla INS: \(ins.nombre)", icono: "book.closed", seleccionado: item.usarINS) {
                        item.usarINS = true
                    }
                }
                Chip(texto: "≈ Estimado por IA", icono: "sparkles", seleccionado: !item.usarINS || item.ins == nil) {
                    item.usarINS = false
                }
                Button(item.ins == nil ? "Buscar en la tabla del INS" : "Elegir otro de la tabla", action: alElegirOtro)
                    .buttonStyle(.texto)
                    .font(Tipo.pie)
            }

            Text("\(Formato.kcal(t.kcal, estimado: est)) · P \(Formato.entero(t.proteina)) g · C \(Formato.entero(t.carbohidratos)) g · G \(Formato.entero(t.grasas)) g")
                .font(Tipo.nota.monospacedDigit())
                .foregroundStyle(paleta.texto)
        }
        .tarjeta()
    }
}
