// ARCHIVO GENERADO por herramientas/generar_temas.py a partir de
// herramientas/temas.json. Si cambias colores, edita el JSON, ejecuta
// verificar_contraste.py y luego vuelve a generar este archivo.
import SwiftUI

enum CatalogoTemas {
    static let todos: [Tema] = [
        Tema(
            id: "mercado",
            nombre: "Mercado",
            concepto: "Puestos de mercado: crema, terracota y los colores de los ingredientes.",
            estilo: EstiloTema(diseno: .redondeada, pesoTitulo: .bold, radioTarjeta: 22, radioControl: 14, sombra: .suave, transicion: .fluida, cifrasMono: false),
            claro: Paleta(
                fondo: "F7F1E8",
                superficie: "FFFCF7",
                superficieAlta: "F0E7DA",
                borde: "E2D5C3",
                texto: "2A1D14",
                textoSecundario: "6B5545",
                acento: "A8401C",
                textoSobreAcento: "FFFFFF",
                acentoSuave: "F6E1D6",
                exito: "2F7A3D",
                aviso: "8F5400",
                peligro: "B3261E",
                calorias: "C2501F",
                proteina: "7A3E9D",
                carbohidratos: "A07000",
                grasas: "4E7D2E",
                heroInicio: "923512",
                heroFin: "5E1D0C",
                textoHero: "FFF7EC",
                textoHeroSecundario: "FBE6D7"
            ),
            oscuro: Paleta(
                fondo: "17120E",
                superficie: "211A15",
                superficieAlta: "2E251E",
                borde: "433629",
                texto: "F6EEE4",
                textoSecundario: "C8B7A6",
                acento: "F08A5D",
                textoSobreAcento: "1E120B",
                acentoSuave: "3D2419",
                exito: "7BC98A",
                aviso: "F0B44C",
                peligro: "FF8A80",
                calorias: "F2875A",
                proteina: "C79BE6",
                carbohidratos: "F2C14E",
                grasas: "9CCB6E",
                heroInicio: "6E2710",
                heroFin: "3A160A",
                textoHero: "FFF1E4",
                textoHeroSecundario: "EBCDB8"
            )
        )
    ]

    static func tema(id: String) -> Tema {
        todos.first { $0.id == id } ?? todos[0]
    }
}
