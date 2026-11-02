import SwiftUI
import UIKit

/// Modo cocina: ingredientes y pasos de una receta en pantalla grande, uno
/// por página. La pantalla no se apaga mientras está abierto.
struct ModoCocinaView: View {
    let receta: Receta
    @Environment(\.paleta) private var paleta
    @Environment(\.dismiss) private var cerrar
    @State private var pagina = 0
    @State private var marcados: Set<UUID> = []

    var body: some View {
        NavigationStack {
            TabView(selection: $pagina) {
                ingredientes.tag(0)
                ForEach(Array(receta.pasos.enumerated()), id: \.offset) { i, paso in
                    paginaPaso(i, paso).tag(i + 1)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .fondoDePantalla()
            .navigationTitle(receta.nombre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { cerrar() } }
            }
            .sensoryFeedback(.selection, trigger: pagina)
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        }
    }

    private var ingredientes: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.m) {
                EncabezadoSeccion(titulo: "Ingredientes", icono: "basket.fill",
                                  detalle: "\(Formato.entero(receta.porciones)) \(receta.porciones == 1 ? "porción" : "porciones")")
                ForEach(receta.ingredientes) { ing in
                    let hecho = marcados.contains(ing.id)
                    Button {
                        if hecho { marcados.remove(ing.id) } else { marcados.insert(ing.id) }
                    } label: {
                        HStack(spacing: Espacio.s) {
                            Image(systemName: hecho ? "checkmark.circle.fill" : "circle")
                                .font(Tipo.iconoFila)
                                .foregroundStyle(hecho ? paleta.exito : paleta.textoSecundario)
                            Text(ing.nombre)
                                .font(Tipo.subtitulo)
                                .foregroundStyle(hecho ? paleta.textoSecundario : paleta.texto)
                                .strikethrough(hecho)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: Espacio.xs)
                            Text("\(Formato.entero(ing.gramos)) g")
                                .font(Tipo.subtitulo.monospacedDigit())
                                .foregroundStyle(paleta.texto)
                        }
                        .padding(.vertical, Espacio.xs)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(hecho ? .isSelected : [])
                }
                if !receta.pasos.isEmpty {
                    Label("Desliza para ver los \(receta.pasos.count) pasos", systemImage: "hand.draw")
                        .font(Tipo.nota).foregroundStyle(paleta.textoSecundario)
                }
            }
            .tarjeta()
            .padding(.horizontal, Espacio.margen)
            .padding(.vertical, Espacio.m)
            .padding(.bottom, Espacio.xxl)
        }
    }

    private func paginaPaso(_ i: Int, _ paso: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.l) {
                Text("Paso \(i + 1) de \(receta.pasos.count)")
                    .font(Tipo.nota.weight(.semibold))
                    .foregroundStyle(paleta.textoHeroSecundario)
                Text(paso)
                    .font(Tipo.titulo2)
                    .foregroundStyle(paleta.textoHero)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .hero()
            .padding(.horizontal, Espacio.margen)
            .padding(.vertical, Espacio.m)
            .padding(.bottom, Espacio.xxl)
        }
    }
}
