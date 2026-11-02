#!/usr/bin/env python3
"""Genera Sazon/Diseno/CatalogoTemas.swift a partir de herramientas/temas.json.
Uso (desde la carpeta raíz del repositorio):
    python3 herramientas/verificar_contraste.py && python3 herramientas/generar_temas.py
Así la paleta vive en un solo lugar y el contraste se verifica antes de
generar el código. Nunca edites CatalogoTemas.swift a mano."""
import json, os
base = os.path.dirname(os.path.abspath(__file__))
raiz = os.path.dirname(base)
datos = json.load(open(os.path.join(base, "temas.json"), encoding="utf-8"))
campos = datos["campos"]

def paleta(valores):
    args = ",\n                ".join(f'{c}: "{v}"' for c, v in zip(campos, valores))
    return f"Paleta(\n                {args}\n            )"

def estilo(e):
    return (f"EstiloTema(diseno: .{e['diseno']}, pesoTitulo: .{e['pesoTitulo']}, "
            f"radioTarjeta: {e['radioTarjeta']}, radioControl: {e['radioControl']}, "
            f"sombra: .{e['sombra']}, transicion: .{e['transicion']}, "
            f"cifrasMono: {'true' if e['cifrasMono'] else 'false'})")

bloques = []
for t in datos["temas"]:
    bloques.append(f'''        Tema(
            id: "{t['id']}",
            nombre: "{t['nombre']}",
            concepto: "{t['concepto']}",
            estilo: {estilo(t['estilo'])},
            claro: {paleta(t['claro'])},
            oscuro: {paleta(t['oscuro'])}
        )''')

swift = '''// ARCHIVO GENERADO por herramientas/generar_temas.py a partir de
// herramientas/temas.json. Si cambias colores, edita el JSON, ejecuta
// verificar_contraste.py y luego vuelve a generar este archivo.
import SwiftUI

enum CatalogoTemas {
    static let todos: [Tema] = [
''' + ",\n".join(bloques) + '''
    ]

    static func tema(id: String) -> Tema {
        todos.first { $0.id == id } ?? todos[0]
    }
}
'''
destino = os.path.join(raiz, "Sazon", "Diseno", "CatalogoTemas.swift")
open(destino, "w", encoding="utf-8").write(swift)
print("Generado Sazon/Diseno/CatalogoTemas.swift")
