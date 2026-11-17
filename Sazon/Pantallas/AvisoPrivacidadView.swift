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
                    punto("photo", "Qué se envía", "Solo lo que pides analizar: la foto del plato o de la etiqueta (reducida, sin ubicación ni datos de la cámara), el texto que escribes o dictas, o el nombre de un alimento propio. Al coach: tus últimos mensajes con él y, solo si lo activas, el resumen de hoy (calorías, macros, agua, tu meta, tu objetivo y tu tipo de dieta). Nunca tu nombre, tu peso, tus medidas, tus fotos de progreso ni tu historial.")
                    punto("building.2", "A quién", "A Google, mediante la API de Gemini con tu propia clave del plan gratuito. Si pones una clave de Groq, Groq recibe lo mismo solo cuando Gemini no responde. Las etiquetas se intentan leer antes en tu iPhone, sin enviar nada.")
                    punto("exclamationmark.bubble", "Qué pueden hacer con eso", "En el plan gratuito de Gemini, Google usa lo que envías y sus respuestas para mejorar y desarrollar sus productos y su IA, y personas pueden leerlo (sin vincularlo a tu cuenta). Google pide no enviar datos sensibles, confidenciales o personales. Groq dice que no entrena con lo que envías y que por defecto no lo guarda (salvo registros de hasta 30 días por fallos o abuso). No envíes fotos con personas, documentos ni datos privados.")
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
