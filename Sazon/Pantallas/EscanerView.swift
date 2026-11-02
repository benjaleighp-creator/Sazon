import SwiftUI
import VisionKit

/// Escáner de código de barras (VisionKit) + consulta en Open Food Facts.
/// Si la cámara no está disponible, se puede escribir el código a mano.
struct EscanerView: View {
    let alEncontrar: (ProductoEnvasado) -> Void
    @Environment(\.paleta) private var paleta
    @State private var codigoManual = ""
    @State private var buscando = false
    @State private var error: ErrorOpenFoodFacts?
    @State private var ultimoCodigo: String?
    @State private var tarea: Task<Void, Never>?

    private var escanerDisponible: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.l) {
                if escanerDisponible {
                    EscanerCamara { codigo in buscar(codigo, manual: false) }
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: Radio.tarjeta, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radio.tarjeta, style: .continuous)
                                .strokeBorder(paleta.borde, lineWidth: 1)
                        )
                        .accessibilityLabel("Cámara para escanear el código de barras")
                    Text("Apunta al código de barras del envase. Se busca solo, sin tocar nada.")
                        .font(Tipo.nota)
                        .foregroundStyle(paleta.textoSecundario)
                } else {
                    Aviso(icono: "camera.metering.unknown", titulo: "Escáner no disponible",
                          texto: "La cámara no está disponible o no diste permiso. Puedes activarlo en Ajustes del iPhone › Sazón › Cámara, o escribir el código abajo.")
                }

                if buscando {
                    HStack(spacing: Espacio.s) {
                        ProgressView()
                        Text("Buscando \(ultimoCodigo ?? "") en Open Food Facts…")
                            .font(Tipo.nota)
                            .foregroundStyle(paleta.textoSecundario)
                    }
                    .accessibilityElement(children: .combine)
                }

                if let error {
                    Aviso(icono: "exclamationmark.triangle", titulo: "No se pudo usar este código", texto: error.mensaje)
                }

                VStack(alignment: .leading, spacing: Espacio.s) {
                    TituloSeccion("Escribir el código")
                    CampoTexto(titulo: "Por ejemplo 7750000000000", texto: $codigoManual)
                        .keyboardType(.numberPad)
                    Button("Buscar código") { buscar(codigoManual, manual: true) }
                        .buttonStyle(.secundario)
                        .disabled(codigoManual.count < 8 || buscando)
                }

                Text("Datos de Open Food Facts (base de datos colaborativa, licencia ODbL). Revisa que coincidan con la etiqueta del envase.")
                    .font(Tipo.pie)
                    .foregroundStyle(paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Espacio.margen)
            .padding(.vertical, Espacio.m)
        }
        .fondoDePantalla()
        .navigationTitle("Código de barras")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.warning, trigger: error)
        .onDisappear { tarea?.cancel() }
    }

    private func buscar(_ codigo: String, manual: Bool) {
        let limpio = codigo.filter(\.isNumber)
        // La cámara no repite un código ya consultado (ni aunque haya fallado):
        // sin reintentos automáticos. A mano sí se puede volver a intentar.
        guard !buscando, manual || limpio != ultimoCodigo else { return }
        ultimoCodigo = limpio
        error = nil
        buscando = true
        tarea = Task {
            do {
                let producto = try await ServicioOpenFoodFacts.buscar(codigo: limpio)
                buscando = false
                alEncontrar(producto)
            } catch let e as ErrorOpenFoodFacts {
                buscando = false
                error = e
            } catch {
                buscando = false
            }
        }
    }
}

/// Envoltorio de `DataScannerViewController` para SwiftUI.
private struct EscanerCamara: UIViewControllerRepresentable {
    let alDetectar: (String) -> Void

    func makeCoordinator() -> Coordinador { Coordinador(alDetectar: alDetectar) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let escaner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        escaner.delegate = context.coordinator
        return escaner
    }

    func updateUIViewController(_ escaner: DataScannerViewController, context: Context) {
        if !escaner.isScanning {
            try? escaner.startScanning()
        }
    }

    static func dismantleUIViewController(_ escaner: DataScannerViewController, coordinator: Coordinador) {
        escaner.stopScanning()
    }

    final class Coordinador: NSObject, DataScannerViewControllerDelegate {
        let alDetectar: (String) -> Void

        init(alDetectar: @escaping (String) -> Void) {
            self.alDetectar = alDetectar
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let codigo) = item, let texto = codigo.payloadStringValue {
                    alDetectar(texto)
                    return
                }
            }
        }
    }
}
