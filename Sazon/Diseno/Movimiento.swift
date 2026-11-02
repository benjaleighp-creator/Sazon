import SwiftUI
import UIKit

/// Guía de movimiento de Sazón (misma estructura que Remanso).
///
/// | Tipo      | Valor base (fluido)                  | Uso                                    |
/// |-----------|--------------------------------------|----------------------------------------|
/// | micro     | 0,12 s · ease-out                    | Presionar botones                      |
/// | seleccion | resorte 0,30 s · amortiguación 0,80  | Chips, interruptores, pestañas         |
/// | estandar  | resorte 0,40 s · amortiguación 0,86  | Aparición de tarjetas, cambios         |
/// | pantalla  | 0,45 s · ease-in-out                 | Cambio de día, de pantalla o de tema   |
/// | enfasis   | resorte 0,55 s · amortiguación 0,68  | Cifras que cambian, meta cumplida      |
/// | progreso  | 0,80 s · ease-out                    | Anillo de calorías y barras de macros  |
///
/// Hápticos (siempre `sensoryFeedback`, nunca sonidos):
///
/// | Momento                           | Háptico            |
/// |-----------------------------------|--------------------|
/// | Elegir una opción, chip o pestaña | `.selection`       |
/// | Empezar algo (enviar a la IA)     | `.impact(.light)`  |
/// | Completar algo (guardar comida)   | `.success`         |
/// | Error o límite alcanzado          | `.warning`         |
///
/// Con "Reducir movimiento" todo pasa a un fundido de 0,2 s. Con el ahorro
/// de batería (de la app o el modo de bajo consumo) también.
enum Movimiento {
    case micro, seleccion, estandar, pantalla, enfasis, progreso

    var animacion: Animation {
        let personalidad = EstiloActivo.actual.transicion
        switch self {
        case .micro: return .easeOut(duration: 0.12)
        case .seleccion:
            switch personalidad {
            case .elastica: return .spring(response: 0.32, dampingFraction: 0.62)
            case .fluida: return .spring(response: 0.30, dampingFraction: 0.80)
            case .lenta: return .spring(response: 0.42, dampingFraction: 0.88)
            case .nitida: return .easeOut(duration: 0.16)
            }
        case .estandar:
            switch personalidad {
            case .elastica: return .spring(response: 0.42, dampingFraction: 0.66)
            case .fluida: return .spring(response: 0.40, dampingFraction: 0.86)
            case .lenta: return .spring(response: 0.55, dampingFraction: 0.90)
            case .nitida: return .easeOut(duration: 0.22)
            }
        case .pantalla:
            switch personalidad {
            case .elastica: return .spring(response: 0.50, dampingFraction: 0.75)
            case .fluida: return .easeInOut(duration: 0.45)
            case .lenta: return .easeInOut(duration: 0.60)
            case .nitida: return .easeInOut(duration: 0.30)
            }
        case .enfasis:
            switch personalidad {
            case .elastica: return .spring(response: 0.55, dampingFraction: 0.55)
            case .fluida: return .spring(response: 0.55, dampingFraction: 0.68)
            case .lenta: return .spring(response: 0.70, dampingFraction: 0.80)
            case .nitida: return .spring(response: 0.30, dampingFraction: 0.90)
            }
        case .progreso: return .easeOut(duration: 0.8)
        }
    }

    /// Versión accesible: fundido corto.
    static let reducida: Animation = .easeInOut(duration: 0.2)

    /// Indica si el sistema pide reducir movimiento (para código fuera de vistas).
    static var reducirActivo: Bool { UIAccessibility.isReduceMotionEnabled }

    func animacion(reducir: Bool) -> Animation {
        reducir ? Movimiento.reducida : animacion
    }
}

/// Ejecuta un cambio con la animación indicada, respetando "Reducir movimiento".
func animar(_ tipo: Movimiento, _ cambio: () -> Void) {
    withAnimation(tipo.animacion(reducir: Movimiento.reducirActivo), cambio)
}

// MARK: - Modificadores

private struct AnimacionSazon<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reducir
    @Environment(\.ahorroActivo) private var ahorro
    let tipo: Movimiento
    let valor: V

    func body(content: Content) -> some View {
        content.animation(tipo.animacion(reducir: reducir || ahorro), value: valor)
    }
}

/// Aparición escalonada: cada elemento sube 12 pt con un pequeño retraso
/// según su índice. Con movimiento reducido o ahorro, solo un fundido.
private struct Aparicion: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reducir
    @Environment(\.ahorroActivo) private var ahorro
    let indice: Int
    @State private var visible = false

    func body(content: Content) -> some View {
        let simple = reducir || ahorro
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || simple ? 0 : 12)
            .onAppear {
                let retraso = simple ? 0 : Double(min(indice, 8)) * 0.05
                withAnimation(Movimiento.estandar.animacion(reducir: simple).delay(retraso)) {
                    visible = true
                }
            }
    }
}

extension View {
    /// Anima los cambios de `valor` con el tipo indicado.
    func animacion<V: Equatable>(_ tipo: Movimiento, valor: V) -> some View {
        modifier(AnimacionSazon(tipo: tipo, valor: valor))
    }

    /// Aparición escalonada de listas y tarjetas.
    func aparicion(_ indice: Int) -> some View {
        modifier(Aparicion(indice: indice))
    }
}
