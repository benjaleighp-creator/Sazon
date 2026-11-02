#!/usr/bin/env python3
"""Verifica el contraste (WCAG 2.x) de todas las paletas de Sazón.
Uso: python3 herramientas/verificar_contraste.py

Mínimos (adaptados de Remanso):
 - texto principal sobre fondo/superficie/superficieAlta: 7.0 (AAA)
 - texto secundario sobre fondo/superficie/superficieAlta: 4.5 (AA)
 - texto sobre acento: 4.5 (AA)
 - acento sobre fondo: 3.0; sobre superficie y acentoSuave: 4.5 (texto de botones)
 - éxito/aviso/peligro sobre superficie: 4.5 (se usan como texto pequeño)
 - texto del encabezado (y su versión secundaria) sobre los dos extremos
   del degradado: 4.5 (AA)
 - colores de datos (calorías y macros) sobre superficie y superficieAlta: 3.0
   (WCAG 1.4.11, objetos gráficos: anillos y barras sobre su pista).
   Los nombres de los macros NUNCA se escriben con su color: van con el
   color de texto y un punto de color al lado.
"""
import json, os, sys

def lum(h):
    r, g, b = (int(h[i:i+2], 16) / 255 for i in (0, 2, 4))
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)

def ratio(a, b):
    la, lb = sorted([lum(a), lum(b)], reverse=True)
    return (la + 0.05) / (lb + 0.05)

ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)), "temas.json")
datos = json.load(open(ruta, encoding="utf-8"))
campos = datos["campos"]
fallos = 0
filas = []
for t in datos["temas"]:
    for variante in ("claro", "oscuro"):
        if len(t[variante]) != len(campos):
            print(f"FALLA {t['nombre']} ({variante}): tiene {len(t[variante])} colores, se esperaban {len(campos)}")
            fallos += 1
            continue
        p = dict(zip(campos, t[variante]))
        pruebas = []
        for f in ("fondo", "superficie", "superficieAlta"):
            pruebas.append((f"texto/{f}", ratio(p["texto"], p[f]), 7.0))
            pruebas.append((f"textoSecundario/{f}", ratio(p["textoSecundario"], p[f]), 4.5))
        pruebas.append(("textoSobreAcento/acento", ratio(p["textoSobreAcento"], p["acento"]), 4.5))
        pruebas.append(("acento/fondo", ratio(p["acento"], p["fondo"]), 3.0))
        pruebas.append(("acento/superficie", ratio(p["acento"], p["superficie"]), 4.5))
        pruebas.append(("acento/acentoSuave", ratio(p["acento"], p["acentoSuave"]), 4.5))
        for f in ("exito", "aviso", "peligro"):
            pruebas.append((f"{f}/superficie", ratio(p[f], p["superficie"]), 4.5))
        for f in ("calorias", "proteina", "carbohidratos", "grasas"):
            pruebas.append((f"{f}/superficie", ratio(p[f], p["superficie"]), 3.0))
            pruebas.append((f"{f}/superficieAlta", ratio(p[f], p["superficieAlta"]), 3.0))
        # Encabezado con degradado: texto claro sobre ambos extremos.
        for f in ("heroInicio", "heroFin"):
            pruebas.append((f"textoHero/{f}", ratio(p["textoHero"], p[f]), 4.5))
            pruebas.append((f"textoHeroSecundario/{f}", ratio(p["textoHeroSecundario"], p[f]), 4.5))
        for nombre, r, m in pruebas:
            if r < m:
                fallos += 1
                print(f"FALLA {t['nombre']} ({variante}) {nombre}: {r:.2f} < {m}")
        peor_dato = min(ratio(p[f], p["superficieAlta"]) for f in ("calorias", "proteina", "carbohidratos", "grasas"))
        filas.append((t["nombre"], variante,
                      ratio(p["texto"], p["fondo"]),
                      ratio(p["textoSecundario"], p["superficie"]),
                      ratio(p["textoSobreAcento"], p["acento"]),
                      peor_dato))
print("\n| Tema | Variante | Texto/fondo | Secundario/superficie | Texto sobre acento | Dato (peor, sobre pista) |")
print("|---|---|---|---|---|---|")
for n, v, a, b, c, d in filas:
    print(f"| {n} | {v} | {a:.1f} | {b:.1f} | {c:.1f} | {d:.1f} |")
print(f"\nFallos: {fallos}")
sys.exit(1 if fallos else 0)
