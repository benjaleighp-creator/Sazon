import Observation
import SwiftUI

// Estados comunes de las pantallas que esperan a la IA (foto, texto y
// etiqueta): la tarea en curso, la tarjeta de espera y la de error.
// Así las tres pantallas se ven y se comportan igual.

// MARK: - Tarea en curso

/// Guarda la tarea que habla con la IA para poder cancelarla de verdad
/// (botón Cancelar o al salir de la pantalla). También recuerda cuándo
/// empezó y el último aviso de progreso (reintento o modelo de respaldo).
@MainActor
@Observable
final class TareaIA {
    /// Momento en que empezó la petición actual (nil si no hay ninguna).
    private(set) var inicio: Date?
    /// Último aviso de progreso de la petición actual.
    private(set) var paso: PasoIA?

    @ObservationIgnored private var tarea: Task<Void, Never>?
    @ObservationIgnored private var actual: UUID?

    var enCurso: Bool { inicio != nil }

    /// Empieza un trabajo nuevo (cancela el anterior si seguía). El trabajo
    /// recibe la función de aviso que se pasa a `ServicioIA.proveedorActual`.
    func iniciar(_ trabajo: @escaping @MainActor (_ alAvanzar: @escaping AvisoPasoIA) async -> Void) {
        tarea?.cancel()
        let id = UUID()
        actual = id
        inicio = Date()
        paso = nil
        let aviso: AvisoPasoIA = { [weak self] nuevo in
            Task { @MainActor [weak self] in
                guard let self, self.actual == id else { return }
                self.paso = nuevo
            }
        }
        tarea = Task { @MainActor [weak self] in
            await trabajo(aviso)
            guard let self, self.actual == id else { return }
            self.limpiar()
        }
    }

    /// Cancela la petición en curso (corta la conexión y los reintentos).
    func cancelar() {
        tarea?.cancel()
        limpiar()
    }

    private func limpiar() {
        tarea = nil
        actual = nil
        inicio = nil
        paso = nil
    }
}

// MARK: - Tarjeta de espera

/// Mientras la IA trabaja: qué está haciendo, cuánto tiempo lleva, si se
/// está probando otro modelo y un botón para cancelar.
struct TarjetaEsperaIA: View {
    let titulo: String
    let inicio: Date?
    let paso: PasoIA?
    let alCancelar: () -> Void
    @Environment(\.paleta) private var paleta

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.s) {
            TimelineView(.periodic(from: inicio ?? Date(), by: 1)) { contexto in
                let transcurrido = contexto.date.timeIntervalSince(inicio ?? contexto.date)
                HStack(alignment: .top, spacing: Espacio.s) {
                    ProgressView()
                        .tint(paleta.acento)
                        .frame(minWidth: Medida.toqueMinimo / 2)
                    VStack(alignment: .leading, spacing: Espacio.xxs) {
                        Text(titulo)
                            .font(Tipo.cuerpoFuerte)
                            .foregroundStyle(paleta.texto)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Lleva \(Formato.duracionCorta(transcurrido))")
                            .font(Tipo.pie.monospacedDigit())
                            .foregroundStyle(paleta.textoSecundario)
                        if let paso {
                            Label(paso.mensaje, systemImage: "arrow.triangle.2.circlepath")
                                .font(Tipo.nota)
                                .foregroundStyle(paleta.textoSecundario)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if transcurrido >= 20 {
                            Text("Si Gemini está saturado puede tardar hasta un par de minutos.")
                                .font(Tipo.nota)
                                .foregroundStyle(paleta.textoSecundario)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(titulo + ". Lleva " + Formato.duracionHablada(transcurrido)
                                    + (paso.map { ". " + $0.mensaje } ?? ""))
            }
            Button(role: .cancel, action: alCancelar) {
                Label("Cancelar", systemImage: "xmark")
            }
            .buttonStyle(.secundario)
            .accessibilityHint("Detiene la petición a Gemini")
        }
        .tarjeta()
    }
}

// MARK: - Tarjeta de error

/// Error de la IA con salidas directas al modo manual (que no necesita IA).
struct TarjetaErrorIA: View {
    let error: ErrorIA
    var alBuscarTabla: (() -> Void)? = nil
    var alAgregarAMano: (() -> Void)? = nil
    @Environment(\.paleta) private var paleta

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.s) {
            HStack(alignment: .top, spacing: Espacio.s) {
                Image(systemName: "exclamationmark.triangle")
                    .font(Tipo.iconoFila)
                    .foregroundStyle(paleta.aviso)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Espacio.xxs) {
                    Text(error.titulo)
                        .font(Tipo.cuerpoFuerte)
                        .foregroundStyle(paleta.texto)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(error.mensaje)
                        .font(Tipo.nota)
                        .foregroundStyle(paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

            if alBuscarTabla != nil || alAgregarAMano != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Espacio.s) { salidas }
                    VStack(spacing: Espacio.s) { salidas }
                }
            }
        }
        .tarjeta()
    }

    @ViewBuilder
    private var salidas: some View {
        if let alBuscarTabla {
            Button(action: alBuscarTabla) {
                Label("Buscar en la tabla", systemImage: "magnifyingglass")
            }
            .buttonStyle(.secundario)
            .accessibilityHint("Busca el alimento en la tabla del INS, sin internet")
        }
        if let alAgregarAMano {
            Button(action: alAgregarAMano) {
                Label("Agregar a mano", systemImage: "square.and.pencil")
            }
            .buttonStyle(.secundario)
        }
    }
}
