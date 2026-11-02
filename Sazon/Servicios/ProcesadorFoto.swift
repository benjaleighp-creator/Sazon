import UIKit

/// Reduce las fotos antes de enviarlas a la IA: lado mayor de 1024 px y
/// JPEG con calidad 0,6. Así la petición pesa poco (y gasta menos del plan
/// gratuito) y no viaja nada más que la imagen del plato: al redibujarla se
/// descartan los metadatos (ubicación GPS, fecha, modelo del teléfono).
enum ProcesadorFoto {

    static func prepararParaIA(_ imagen: UIImage, ladoMaximo: CGFloat = Medida.ladoFotoIA, calidad: CGFloat = 0.6) -> Data? {
        let ancho = imagen.size.width
        let alto = imagen.size.height
        guard ancho > 0, alto > 0 else { return nil }
        let escala = min(1, ladoMaximo / max(ancho, alto))
        let destino = CGSize(width: (ancho * escala).rounded(), height: (alto * escala).rounded())

        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1          // píxeles reales, no puntos de pantalla
        formato.opaque = true
        let reducida = UIGraphicsImageRenderer(size: destino, format: formato).image { _ in
            imagen.draw(in: CGRect(origin: .zero, size: destino))
        }
        return reducida.jpegData(compressionQuality: calidad)
    }
}
