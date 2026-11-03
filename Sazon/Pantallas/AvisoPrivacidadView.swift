import SwiftUI

/// Aviso que se muestra la primera vez que usas la IA.
struct AvisoPrivacidadView: View {
    let alAceptar: () -> Void
    @Environment(\.paleta) private var paleta
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Espacio.l) {
                    IconoCirculo(simbolo: "hand.raised", tamano: 56)
                    Text("Antes de usar la IA")
                        .font(Tipo.titulo2)
                        .foregroundStyle(paleta.texto)
                        .accessibilityAddTraits(.isHeader)
                    punto("photo", "Qué se envía", "Solo la foto del plato (reducida y sin ubicación) o el texto que escribes o dictas. Nada más: ni tu perfil, ni tu peso, ni tu meta, ni tu historial.")
                    punto("building.2", "A quién", "A Google, mediante la API de Gemini con tu propia clave del plan gratuito de Google AI Studio.")
                    punto("exclamationmark.bubble", "Qué puede hacer Google", "En el plan gratuito, Google puede usar lo que envías para mejorar sus productos, y personas pueden revisarlo. No envíes fotos con personas ni datos privados.")
                    punto("checkmark.seal", "Tú decides", "La IA solo propone; revisas y corriges antes de guardar. Sus cifras se marcan con ≈ y son estimaciones, no consejo médico.")
                }
                .padding(.horizontal, Espacio.margen)
                .padding(.vertical, Espacio.l)
            }
            .fondoDePantalla()
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: Espacio.xs) {
                    Button("Entendido, usar la IA", action: alAceptar)
                        .buttonStyle(.principal)
                    Button("Ahora no") { cerrar() }
                        .buttonStyle(.texto)
                }
                .padding(.horizontal, Espacio.margen)
                .padding(.bottom, Espacio.xs)
                .barraInferior()
                .background(paleta.fondo)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { cerrar() }
                }
            }
        }
    }

    private func punto(_ simbolo: String, _ titulo: String, _ texto: String) -> some View {
        HStack(alignment: .top, spacing: Espacio.s) {
            IconoCirculo(simbolo: simbolo, tamano: 32)
            VStack(alignment: .leading, spacing: Espacio.xxs) {
                Text(titulo).font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                Text(texto).font(Tipo.nota).foregroundStyle(paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
