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
                grasas: "4E7D2E"
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
                grasas: "9CCB6E"
            )
        ),
        Tema(
            id: "chicha",
            nombre: "Chicha",
            concepto: "Morado de maíz, noche limeña y un toque de ají.",
            estilo: EstiloTema(diseno: .redondeada, pesoTitulo: .heavy, radioTarjeta: 26, radioControl: 16, sombra: .suave, transicion: .elastica, cifrasMono: false),
            claro: Paleta(
                fondo: "F6F2F8",
                superficie: "FFFFFF",
                superficieAlta: "EEE6F3",
                borde: "DCCFE6",
                texto: "21142B",
                textoSecundario: "5E4E6B",
                acento: "6D2F8E",
                textoSobreAcento: "FFFFFF",
                acentoSuave: "EEE1F5",
                exito: "2C7A43",
                aviso: "8F5A00",
                peligro: "B0262B",
                calorias: "B5481F",
                proteina: "6D2F8E",
                carbohidratos: "9C7000",
                grasas: "3F7A33"
            ),
            oscuro: Paleta(
                fondo: "140E19",
                superficie: "1E1625",
                superficieAlta: "2A2033",
                borde: "3F3249",
                texto: "F4EEF8",
                textoSecundario: "C3B5CF",
                acento: "C49BE3",
                textoSobreAcento: "1C1024",
                acentoSuave: "33243F",
                exito: "7DCB92",
                aviso: "F0B44C",
                peligro: "FF8C8C",
                calorias: "F2875A",
                proteina: "C49BE3",
                carbohidratos: "F0C24B",
                grasas: "9ACB6C"
            )
        )
    ]

    static func tema(id: String) -> Tema {
        todos.first { $0.id == id } ?? todos[0]
    }
}
