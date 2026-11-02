import SwiftUI

/// Búsqueda en la tabla del INS (sin internet).
struct BuscarView: View {
    let alElegir: (AlimentoBase) -> Void
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var consulta = ""
    @State private var resultados: [Coincidencia] = []

    var body: some View {
        List {
            if let error = almacen.tabla.error {
                Aviso(icono: "exclamationmark.triangle", titulo: "Tabla no disponible", texto: error, color: paleta.peligro)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            } else if consulta.trimmingCharacters(in: .whitespaces).isEmpty {
                EstadoVacio(icono: "magnifyingglass", titulo: "Busca un alimento",
                            texto: "\(almacen.tabla.alimentos.count) alimentos y platos de las Tablas Peruanas de Composición de Alimentos (INS). Prueba «palta», «pan francés» o «ají de gallina».")
                    .listRowBackground(Color.clear)
            } else if resultados.isEmpty {
                EstadoVacio(icono: "questionmark.circle", titulo: "Sin resultados",
                            texto: "Prueba con otra palabra o agrégalo a mano.")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(resultados, id: \.alimento.codigo) { r in
                    Button { alElegir(r.alimento) } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: Espacio.xxxs) {
                                Text(r.alimento.nombre)
                                    .font(Tipo.cuerpo)
                                    .foregroundStyle(paleta.texto)
                                    .multilineTextAlignment(.leading)
                                Text(r.alimento.grupo + " · " + r.alimento.codigo)
                                    .font(Tipo.pie)
                                    .foregroundStyle(paleta.textoSecundario)
                            }
                            Spacer(minLength: Espacio.xs)
                            Text("\(Formato.entero(r.alimento.por100g.kcal)) kcal/100 g")
                                .font(Tipo.pie.monospacedDigit())
                                .foregroundStyle(paleta.textoSecundario)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(paleta.superficie)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .listStyle(.insetGrouped)
        .fondoDePantalla()
        .navigationTitle("Tabla del INS")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $consulta, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar alimento o plato")
        .autocorrectionDisabled()
        .task(id: consulta) {
            // Pequeña espera para no buscar en cada letra.
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            resultados = almacen.tabla.buscar(consulta)
        }
    }
}
