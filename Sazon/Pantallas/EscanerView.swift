import SwiftUI
import VisionKit

/// Escáner de código de barras (VisionKit). Primero busca en tus productos
/// guardados (sin internet) y luego en Open Food Facts. Si no lo encuentra,
/// ofrece leer la etiqueta con IA, agregarlo a mano o buscar en la tabla.
struct EscanerView: View {
    /// Producto listo para elegir la porción.
    let alResolver: (Candidato) -> Void
    /// Leer la tabla nutricional del envase con IA (recibe el código).
    let alLeerEtiqueta: (String) -> Void
    /// Buscar en la tabla del INS.
    let alBuscarTabla: () -> Void

    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var codigoManual = ""
    @State private var buscando = false
    @State private var resultado: ResultadoEscaneo?
    @State private var ultimoCodigo: String?
    @State private var tarea: Task<Void, Never>?
    @State private var detectados = 0

    private var escanerDisponible: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.l) {
                if escanerDisponible {
                    ZStack(alignment: .bottom) {
                        EscanerCamara { codigo in buscar(codigo, manual: false) }
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: Radio.grande, style: .continuous))
                        Label(buscando ? "Buscando \(ultimoCodigo ?? "")…" : "Apunta al código de barras",
                              systemImage: buscando ? "hourglass" : "barcode.viewfinder")
                            .font(Tipo.pie)
                            .foregroundStyle(paleta.textoHero)
                            .padding(.horizontal, Espacio.s)
                            .padding(.vertical, Espacio.xs)
                            .background(Capsule().fill(paleta.heroFin.opacity(0.85)))
                            .padding(Espacio.s)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Cámara para escanear el código de barras")
                } else {
                    Aviso(icono: "camera.metering.unknown", titulo: "Escáner no disponible",
                          texto: "La cámara no está disponible o no diste permiso. Actívalo en Ajustes del iPhone › Sazón › Cámara, o escribe el código abajo.")
                }

                if let resultado {
                    TarjetaResultado(resultado: resultado,
                                     alLeerEtiqueta: { alLeerEtiqueta(resultado.codigo) },
                                     alAMano: { alResolver(Candidato(manual: "", codigoBarras: resultado.codigo)) },
                                     alBuscarTabla: alBuscarTabla,
                                     alReintentar: { buscar(resultado.codigo, manual: true) })
                }

                VStack(alignment: .leading, spacing: Espacio.s) {
                    TituloSeccion("Escribir el código")
                    HStack(spacing: Espacio.s) {
                        CampoTexto(titulo: "Números debajo de las barras", texto: $codigoManual)
                            .keyboardType(.numberPad)
                        Button {
                            buscar(codigoManual, manual: true)
                        } label: {
                            Image(systemName: "arrow.right")
                                .font(Tipo.iconoFila)
                                .foregroundStyle(paleta.textoSobreAcento)
                                .frame(width: Medida.toque, height: Medida.toque)
                                .background(Circle().fill(paleta.acento))
                        }
                        .buttonStyle(.plain)
                        .disabled(codigoManual.filter(\.isNumber).count < 8 || buscando)
                        .accessibilityLabel("Buscar código")
                    }
                }

                Text("Primero se busca en los productos que ya registraste (sin internet) y luego en Open Food Facts, una base de datos colaborativa con licencia ODbL. Revisa que los datos coincidan con la etiqueta.")
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
        .sensoryFeedback(.selection, trigger: detectados)
        .sensoryFeedback(.warning, trigger: resultado?.problema)
        .onDisappear { tarea?.cancel() }
    }

    private func buscar(_ codigo: String, manual: Bool) {
        let limpio = codigo.filter(\.isNumber)
        // La cámara no repite un código ya consultado: sin reintentos
        // automáticos. A mano (o con "Intentar de nuevo") sí.
        guard !buscando, manual || limpio != ultimoCodigo else { return }
        ultimoCodigo = limpio
        detectados += 1
        resultado = nil

        // 1. Productos que ya registraste.
        if let guardado = Productos.buscar(limpio, en: almacen.datos.productos) {
            alResolver(Candidato(guardado: guardado))
            return
        }
        guard LectorOpenFoodFacts.codigoValido(limpio) != nil else {
            resultado = ResultadoEscaneo(codigo: limpio, problema: .codigoInvalido)
            return
        }
        // 2. Open Food Facts.
        buscando = true
        tarea = Task {
            do {
                let producto = try await ServicioOpenFoodFacts.buscar(codigo: limpio)
                buscando = false
                alResolver(Candidato(producto: producto))
            } catch let e as ErrorOpenFoodFacts {
                buscando = false
                resultado = ResultadoEscaneo(codigo: limpio, problema: e)
            } catch {
                buscando = false
            }
        }
    }
}

/// Lo que pasó con un código escaneado que no se pudo usar directamente.
struct ResultadoEscaneo: Equatable {
    let codigo: String
    let problema: ErrorOpenFoodFacts
}

private struct TarjetaResultado: View {
    let resultado: ResultadoEscaneo
    let alLeerEtiqueta: () -> Void
    let alAMano: () -> Void
    let alBuscarTabla: () -> Void
    let alReintentar: () -> Void
    @Environment(\.paleta) private var paleta

    var body: some View {
        let interno = LectorOpenFoodFacts.esCodigoInterno(resultado.codigo)
        VStack(alignment: .leading, spacing: Espacio.m) {
            HStack(alignment: .top, spacing: Espacio.s) {
                AzulejoIcono(simbolo: "barcode", tamano: 40, color: paleta.aviso)
                VStack(alignment: .leading, spacing: Espacio.xxs) {
                    Text("Código \(resultado.codigo)")
                        .font(Tipo.cuerpoFuerte.monospacedDigit())
                        .foregroundStyle(paleta.texto)
                    Text(mensaje(interno: interno))
                        .font(Tipo.nota)
                        .foregroundStyle(paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

            if resultado.problema == .sinInternet || isServidor {
                Button("Intentar de nuevo", action: alReintentar)
                    .buttonStyle(.secundario)
            } else {
                Text("¿Cómo quieres agregarlo?")
                    .font(Tipo.micro)
                    .foregroundStyle(paleta.textoSecundario)
                opcion("doc.text.viewfinder", "Leer la etiqueta con IA",
                       "Toma una foto de la tabla nutricional del envase. Se guardará con este código.", destacada: true, accion: alLeerEtiqueta)
                opcion("square.and.pencil", "Escribir los datos del envase",
                       "Calorías y macros por 100 g o por porción. También queda guardado.", destacada: false, accion: alAMano)
                opcion("magnifyingglass", "Buscar algo parecido en la tabla",
                       "Tabla del INS, sin internet.", destacada: false, accion: alBuscarTabla)
            }
        }
        .tarjeta()
    }

    private var isServidor: Bool {
        if case .servidor = resultado.problema { return true }
        return false
    }

    private func mensaje(interno: Bool) -> String {
        if interno && (resultado.problema == .noEncontrado) {
            return "Es un código interno de la tienda (empieza con 2): se usa para productos pesados o etiquetados en el local y no está en ninguna base pública."
        }
        switch resultado.problema {
        case .noEncontrado:
            return "Este producto todavía no está en Open Food Facts. Pasa con productos locales o artesanales."
        default:
            return resultado.problema.mensaje
        }
    }

    private func opcion(_ simbolo: String, _ titulo: String, _ detalle: String, destacada: Bool, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: Espacio.s) {
                AzulejoIcono(simbolo: simbolo, tamano: 36)
                VStack(alignment: .leading, spacing: Espacio.xxxs) {
                    HStack(spacing: Espacio.xxs) {
                        Text(titulo).font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                        if destacada {
                            Image(systemName: "sparkles").font(Tipo.iconoChico).foregroundStyle(paleta.acento)
                                .accessibilityHidden(true)
                        }
                    }
                    Text(detalle).font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(Tipo.iconoChico).foregroundStyle(paleta.textoSecundario)
            }
            .padding(Espacio.s)
            .background(
                RoundedRectangle(cornerRadius: Radio.medio, style: .continuous)
                    .fill(destacada ? paleta.acentoSuave : paleta.superficieAlta)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
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
