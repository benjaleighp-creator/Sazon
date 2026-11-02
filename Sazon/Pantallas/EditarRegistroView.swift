import SwiftUI

/// Corregir o eliminar un registro guardado.
struct EditarRegistroView: View {
    let original: Registro
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @Environment(\.dismiss) private var cerrar

    @State private var registro: Registro?
    @State private var confirmarBorrado = false

    var body: some View {
        NavigationStack {
            Group {
                if let actual = registro {
                    contenido(actual)
                } else {
                    ProgressView()
                }
            }
            .fondoDePantalla()
            .navigationTitle("Corregir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }
                        .disabled(!(registro.map { Porciones.esValido($0.gramos) && !$0.nombre.trimmingCharacters(in: .whitespaces).isEmpty } ?? false))
                }
            }
            .confirmationDialog("¿Eliminar este registro?", isPresented: $confirmarBorrado, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) {
                    almacen.eliminar(original)
                    cerrar()
                }
            }
        }
        .onAppear { if registro == nil { registro = original } }
    }

    private func contenido(_ actual: Registro) -> some View {
        let enlace = Binding<Registro>(get: { registro ?? original }, set: { registro = $0 })
        let t = actual.total
        let est = actual.origen.esEstimado
        return ScrollView {
            VStack(alignment: .leading, spacing: Espacio.l) {
                VStack(alignment: .leading, spacing: Espacio.xs) {
                    TituloSeccion("Nombre")
                    CampoTexto(titulo: "Nombre", texto: enlace.nombre)
                    HStack(spacing: Espacio.xs) {
                        InsigniaOrigen(origen: actual.origen)
                        if let confianza = actual.confianzaIA {
                            Insignia(texto: "Confianza IA \(Int((confianza * 100).rounded())) %")
                        }
                    }
                }
                VStack(alignment: .leading, spacing: Espacio.s) {
                    TituloSeccion("Porción en gramos")
                    CampoNumero(titulo: "Gramos", valor: enlace.gramos, unidad: "g", decimales: 0)
                }
                VStack(alignment: .leading, spacing: Espacio.s) {
                    TituloSeccion("Valores por 100 g")
                    Text("Si cambias estos valores, el registro queda marcado como corregido a mano.")
                        .font(Tipo.pie)
                        .foregroundStyle(paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                    CampoNumero(titulo: "Calorías", valor: enlace.por100g.kcal, unidad: "kcal", decimales: 0)
                    CampoNumero(titulo: "Proteína", valor: enlace.por100g.proteina, unidad: "g")
                    CampoNumero(titulo: "Carbohidratos", valor: enlace.por100g.carbohidratos, unidad: "g")
                    CampoNumero(titulo: "Grasas", valor: enlace.por100g.grasas, unidad: "g")
                }
                VStack(alignment: .leading, spacing: Espacio.xs) {
                    TituloSeccion("Total")
                    Text("\(Formato.kcal(t.kcal, estimado: est)) · P \(Formato.entero(t.proteina)) g · C \(Formato.entero(t.carbohidratos)) g · G \(Formato.entero(t.grasas)) g")
                        .font(Tipo.cuerpo.monospacedDigit())
                        .foregroundStyle(paleta.texto)
                }
                .tarjeta()
                SelectorComida(comida: enlace.comida)
                Button("Eliminar registro", role: .destructive) { confirmarBorrado = true }
                    .buttonStyle(EstiloBotonTexto(color: paleta.peligro))
            }
            .padding(.horizontal, Espacio.margen)
            .padding(.vertical, Espacio.m)
        }
    }

    private func guardar() {
        guard var nuevo = registro else { return }
        if nuevo.por100g != original.por100g {
            nuevo.editado = true
            // Si cambiaste los valores, ya no son de la fuente original.
            nuevo.origen = .manual
        }
        if nuevo.gramos != original.gramos, let m = nuevo.medida, let c = nuevo.cantidadMedida,
           abs(m.gramos * c - nuevo.gramos) >= 0.5 {
            nuevo.medida = nil
            nuevo.cantidadMedida = nil
        }
        nuevo.nombre = nuevo.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        almacen.actualizar(nuevo)
        cerrar()
    }
}
