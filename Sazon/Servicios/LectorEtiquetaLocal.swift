import UIKit
import Vision

/// Lee el texto de la foto de una etiqueta EN EL IPHONE, sin red ni cuota,
/// con `VNRecognizeTextRequest` (Vision, iOS 13+; verificado en
/// developer.apple.com el 16-nov-2026). No necesita ningún permiso especial.
/// Si el texto no alcanza para sacar las cifras, la app usa la IA en la nube.
enum LectorEtiquetaLocal {

    /// Intenta leer la etiqueta. nil si no se pudo con seguridad.
    static func leer(_ imagen: UIImage) async -> EtiquetaLeida? {
        let filas = await filas(de: imagen)
        return ParserEtiqueta.leer(filas)
    }

    /// Filas de texto de la imagen (de arriba abajo).
    static func filas(de imagen: UIImage) async -> [String] {
        guard let cg = imagen.cgImage else { return [] }
        let orientacion = orientacionVision(imagen.imageOrientation)
        return await withCheckedContinuation { (cont: CheckedContinuation<[String], Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let peticion = VNRecognizeTextRequest()
                peticion.recognitionLevel = .accurate
                peticion.usesLanguageCorrection = false
                if let idiomas = try? peticion.supportedRecognitionLanguages() {
                    let preferidos = ["es-ES", "es-MX", "en-US"].filter { idiomas.contains($0) }
                    if !preferidos.isEmpty { peticion.recognitionLanguages = preferidos }
                }
                let manejador = VNImageRequestHandler(cgImage: cg, orientation: orientacion, options: [:])
                do {
                    try manejador.perform([peticion])
                } catch {
                    cont.resume(returning: [])
                    return
                }
                let piezas: [PiezaTexto] = (peticion.results ?? []).compactMap { o in
                    guard let texto = o.topCandidates(1).first?.string else { return nil }
                    let caja = o.boundingBox
                    return PiezaTexto(x: Double(caja.minX), y: Double(caja.midY), alto: Double(caja.height), texto: texto)
                }
                cont.resume(returning: ParserEtiqueta.filas(piezas))
            }
        }
    }

    private static func orientacionVision(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
