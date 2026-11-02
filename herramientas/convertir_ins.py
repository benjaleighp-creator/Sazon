#!/usr/bin/env python3
"""Convierte el PDF de las Tablas Peruanas de Composición de Alimentos (INS)
al archivo que lee la app sin internet: Sazon/Datos/alimentos-ins.json.

Uso (desde la carpeta raíz del repositorio):
    pip install pdfplumber
    python3 herramientas/convertir_ins.py RUTA/AL/PDF.pdf

Fuente: Instituto Nacional de Salud (Perú), Centro Nacional de Alimentación,
Nutrición y Vida Saludable. Tablas peruanas de composición de alimentos.
11.ª edición digital, marzo 2025 (TPCA 2023). El documento indica: «Se
autoriza su reproducción total o parcial, siempre y cuando se cite la fuente».

Cómo lee el PDF:
- Lee cada página por líneas de texto. Una fila de datos es una línea con el
  código del alimento (por ejemplo «A 12») y sus columnas numéricas («•»
  significa dato no disponible).
- Si el nombre ocupa dos líneas, las líneas de solo texto se unen a la fila
  de datos más cercana.
- Grupo S (alimentos preparados): cada plato tiene 5 filas, una por estrato
  socioeconómico (A a E). La app usa el promedio de los estratos con datos.
- Carbohidratos: «disponibles» (sin fibra) cuando existen; si no, «totales».
  Es el mismo criterio que usa el INS para calcular la energía. Si la
  energía declarada cuadra mucho mejor con los totales (hay filas con
  «disponibles» = 0,0 por error), se usan los totales.
- Revisión: las kcal deben parecerse a 4×proteína + 4×carbohidratos +
  9×grasa. El INS usa factores de Atwater específicos, así que se tolera una
  diferencia; las filas que se alejan mucho se listan en
  herramientas/ins-revisar.txt para revisarlas contra el PDF.
"""
import csv, json, os, re, sys

try:
    import pdfplumber
except ImportError:
    sys.exit("Falta pdfplumber. Instálalo con: pip install pdfplumber")

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESTINO_JSON = os.path.join(RAIZ, "Sazon", "Datos", "alimentos-ins.json")
DESTINO_CSV = os.path.join(RAIZ, "herramientas", "alimentos-ins.csv")
DESTINO_REVISAR = os.path.join(RAIZ, "herramientas", "ins-revisar.txt")

FUENTE = ("Instituto Nacional de Salud (Perú), Centro Nacional de Alimentación, Nutrición y "
          "Vida Saludable. Tablas peruanas de composición de alimentos. 11.ª edición digital "
          "(TPCA 2023), marzo 2025. Valores por 100 g de parte comestible; en los platos "
          "preparados, promedio de los estratos socioeconómicos.")

ENCABEZADO = re.compile(r"^([A-Z])\s*-\s*(.+?)\s+Composición en 100 g", re.MULTILINE)
NUMERO = re.compile(r"^(•|-?\d+(?:[.,]\d+)?)$")

# Columnas numéricas por fila: 22 en los grupos de alimentos y 21 en el
# grupo S (no trae β-caroteno). En ambos, las primeras 8 son:
# kcal, kJ, agua, proteínas, grasa, carbohidratos totales, disponibles, fibra.
COLUMNAS_ALIMENTOS = 22
COLUMNAS_PREPARADOS = 21


def numero(t):
    t = t.strip().replace(",", ".")
    if t in ("", "•"):
        return None
    try:
        return float(t)
    except ValueError:
        return None


def limpiar_nombre(texto):
    t = re.sub(r"\s+", " ", texto).strip(" ,*")
    t = t.replace("fortiticado", "fortificado")
    return t


def grupo_bonito(nombre):
    t = nombre.strip().lower()
    return t[:1].upper() + t[1:]


def es_numero(tok):
    return bool(NUMERO.match(tok))


def separar_cola_numerica(tokens, cantidad):
    """Devuelve (texto_antes, numeros) si los últimos `cantidad` tokens son números."""
    if len(tokens) < cantidad:
        return None
    cola = tokens[-cantidad:]
    if not all(es_numero(t) for t in cola):
        return None
    return tokens[:-cantidad], cola


def leer_lineas(pagina):
    """Líneas debajo de la fila de unidades (kcal kJ g …) y sin el pie."""
    lineas = pagina.extract_text_lines()
    inicio = None
    for l in lineas:
        if l["text"].startswith("kcal kJ"):
            inicio = l["bottom"]
            break
    if inicio is None:
        return []
    return [l for l in lineas if l["top"] > inicio and "Centro Nacional de Alimentación" not in l["text"]]


def filas_de_pagina(pagina, preparados, categoria=None):
    """Filas de datos de una página con su nombre completo.
    Cada fila: dict(codigo|None, estrato|None, nombre, valores, top, categoria)."""
    columnas = COLUMNAS_PREPARADOS if preparados else COLUMNAS_ALIMENTOS
    filas, textos = [], []
    for l in leer_lineas(pagina):
        tokens = l["text"].split()
        if preparados:
            # Puede terminar con «… 0 C SE 18» (estrato + código repetido).
            codigo = None
            if len(tokens) >= 2 and re.fullmatch(r"S[A-Z]", tokens[-2]) and tokens[-1].isdigit():
                codigo = tokens[-2] + tokens[-1]
                tokens = tokens[:-2]
            if tokens and re.fullmatch(r"[A-E]", tokens[-1]):
                estrato = tokens[-1]
                partes = separar_cola_numerica(tokens[:-1], columnas)
                if partes:
                    antes, nums = partes
                    if len(antes) >= 2 and re.fullmatch(r"S[A-Z]", antes[0]) and antes[1].isdigit():
                        codigo = antes[0] + antes[1]
                        antes = antes[2:]
                    filas.append(dict(codigo=codigo, estrato=estrato, nombre=" ".join(antes),
                                      valores=nums, top=l["top"], categoria=categoria, extra=[]))
                    continue
            # Platos con un solo valor (sin estrato, marcados con «*»):
            # «SS 335 [nombre] 111 465 … SS 335».
            # Estas filas traen 22 columnas, como los grupos de alimentos.
            if codigo and len(tokens) >= 2 and re.fullmatch(r"S[A-Z]", tokens[0]) and tokens[1].isdigit():
                partes = separar_cola_numerica(tokens[2:], COLUMNAS_ALIMENTOS)
                if partes:
                    antes, nums = partes
                    filas.append(dict(codigo=codigo, estrato="U", nombre=" ".join(antes),
                                      valores=nums, top=l["top"], categoria=categoria, extra=[]))
                    continue
            # Línea con solo el código («SE 18 SE 18»).
            m = re.fullmatch(r"(S[A-Z]) (\d+)(?: \1 \2)?", " ".join(tokens) if not codigo else f"{codigo[:2]} {codigo[2:]}")
            if m:
                filas.append(dict(codigo=m.group(1) + m.group(2), estrato=None, nombre="", valores=None,
                                  top=l["top"], categoria=categoria, extra=[]))
                continue
            texto = " ".join(tokens)
            if texto and texto.upper() == texto and not any(ch.isdigit() for ch in texto):
                categoria = grupo_bonito(texto)   # ENTRADAS, SEGUNDOS…
                continue
            if texto and not any(es_numero(t) for t in tokens):
                textos.append(dict(texto=texto, top=l["top"]))
            continue

        # Grupos de alimentos: «A 12 Nombre … 22 números … A 12».
        if len(tokens) >= 2 and re.fullmatch(r"[A-Z]", tokens[0]) and tokens[1].isdigit():
            cuerpo = tokens[2:]
            if len(cuerpo) >= 2 and cuerpo[-2] == tokens[0] and cuerpo[-1] == tokens[1]:
                cuerpo = cuerpo[:-2]
            partes = separar_cola_numerica(cuerpo, columnas)
            if partes:
                antes, nums = partes
                filas.append(dict(codigo=tokens[0] + tokens[1], estrato=None, nombre=" ".join(antes),
                                  valores=nums, top=l["top"], categoria=None, extra=[]))
                continue
        if tokens and not any(es_numero(t) for t in tokens):
            textos.append(dict(texto=" ".join(tokens), top=l["top"]))

    # Cada línea de solo texto se une a la fila de datos más cercana.
    con_datos = [f for f in filas if f["valores"] is not None]
    for t in textos:
        if not con_datos:
            break
        cercana = min(con_datos, key=lambda f: abs(f["top"] - t["top"]))
        if abs(cercana["top"] - t["top"]) < 24:
            cercana["extra"].append(t)
    for f in con_datos:
        arriba = [t["texto"] for t in sorted(f["extra"], key=lambda t: t["top"]) if t["top"] < f["top"]]
        abajo = [t["texto"] for t in sorted(f["extra"], key=lambda t: t["top"]) if t["top"] >= f["top"]]
        f["nombre"] = limpiar_nombre(" ".join(arriba + [f["nombre"]] + abajo))
    return filas, categoria


def macros(valores):
    kcal = numero(valores[0])
    prot = numero(valores[3])
    grasa = numero(valores[4])
    cho_tot = numero(valores[5])
    cho_disp = numero(valores[6])
    cho = elegir_carbohidratos(kcal, prot, grasa, cho_tot, cho_disp)
    return kcal, prot, cho, grasa


def elegir_carbohidratos(kcal, prot, grasa, cho_tot, cho_disp):
    """Disponibles si existen; pero si la energía declarada cuadra mucho
    mejor con los totales (por ejemplo, «disponibles» = 0,0 por un error del
    documento), se usan los totales."""
    if cho_disp is None:
        return cho_tot
    if cho_tot is None or kcal is None:
        return cho_disp
    base = 4 * (prot or 0) + 9 * (grasa or 0)
    error_disp = abs(base + 4 * cho_disp - kcal)
    error_tot = abs(base + 4 * cho_tot - kcal)
    return cho_tot if error_tot + 10 < error_disp else cho_disp


def main(ruta_pdf):
    alimentos = {}
    grupos = {}
    filas_s = []
    categoria_s = None
    with pdfplumber.open(ruta_pdf) as pdf:
        for n, pagina in enumerate(pdf.pages, start=1):
            texto = pagina.extract_text() or ""
            m = ENCABEZADO.search(texto)
            if not m:
                continue
            letra = m.group(1)
            grupos[letra] = grupo_bonito(m.group(2))
            if letra == "S":
                filas_pagina, categoria_s = filas_de_pagina(pagina, preparados=True, categoria=categoria_s)
                for f in filas_pagina:
                    f["pagina"] = n
                    filas_s.append(f)
                continue
            # Nombres según la tabla de la página: a veces son más completos
            # cuando el nombre ocupa tres líneas.
            nombres_tabla = {}
            for tabla in pagina.extract_tables():
                for fila in tabla:
                    if fila and len(fila) > 2 and fila[0] and fila[1] and fila[2]:
                        if re.fullmatch(r"[A-Z]", fila[0].strip()) and fila[1].strip().isdigit():
                            nombres_tabla[fila[0].strip() + fila[1].strip()] = limpiar_nombre(fila[2])
            for f in filas_de_pagina(pagina, preparados=False)[0]:
                kcal, prot, cho, grasa = macros(f["valores"])
                otro = nombres_tabla.get(f["codigo"], "")
                if len(otro) > len(f["nombre"]):
                    f["nombre"] = otro
                if kcal is None or not f["nombre"]:
                    continue
                alimentos[f["codigo"]] = dict(
                    codigo=f["codigo"], nombre=f["nombre"], grupo=grupos[letra],
                    kcal=kcal, prot=prot, cho=cho, grasa=grasa, pagina=n, estratos=1)

    # Grupo S: agrupar las filas de cada plato (estratos A→E) y su código.
    platos = []
    actual = None
    avisos = []
    for f in filas_s:
        if f["valores"] is None:            # línea con solo el código
            if actual is not None and actual["codigo"] is None:
                actual["codigo"] = f["codigo"]
            elif actual is not None and actual["codigo"] != f["codigo"]:
                avisos.append(f"Código {f['codigo']} (p.{f['pagina']}) cayó en el plato {actual['codigo']}: revisar.")
            continue
        def clave(nombre):
            return re.sub(r"\W+", "", nombre.lower())
        nombre_previo = next((x["nombre"] for x in reversed(actual["filas"]) if x["nombre"]), "") if actual else ""
        nuevo = (actual is None or f["estrato"] == "U" or actual["ultimo"] == "U" or f["estrato"] <= actual["ultimo"] or
                 (actual["codigo"] is not None and f["codigo"] is not None and f["codigo"] != actual["codigo"]) or
                 (f["nombre"] and nombre_previo and clave(f["nombre"]) != clave(nombre_previo)))
        if nuevo:
            actual = dict(codigo=None, filas=[], ultimo="", categoria=f["categoria"], pagina=f["pagina"])
            platos.append(actual)
        actual["filas"].append(f)
        actual["ultimo"] = f["estrato"]
        if f["codigo"]:
            actual["codigo"] = f["codigo"]

    sin_codigo = 0
    for p in platos:
        if not p["codigo"]:
            sin_codigo += 1
            continue
        nombres = [f["nombre"] for f in p["filas"] if f["nombre"]]
        if not nombres:
            continue
        nombre = max(set(nombres), key=lambda x: (nombres.count(x), len(x)))
        valores = [macros(f["valores"]) for f in p["filas"]]
        def promedio(i):
            datos = [v[i] for v in valores if v[i] is not None]
            return round(sum(datos) / len(datos), 1) if datos else None
        kcal = promedio(0)
        if kcal is None:
            continue
        categoria = p["categoria"]
        grupo = grupos["S"] + (f" · {categoria}" if categoria else "")
        alimentos[p["codigo"]] = dict(
            codigo=p["codigo"], nombre=nombre, grupo=grupo,
            kcal=round(kcal), prot=promedio(1), cho=promedio(2), grasa=promedio(3),
            pagina=p["pagina"], estratos=len(p["filas"]))

    def orden(c):
        m = re.fullmatch(r"([A-Z]+)(\d+)", c)
        return (m.group(1), int(m.group(2)))

    lista = [alimentos[c] for c in sorted(alimentos, key=orden)]

    revisar = []
    for a in lista:
        faltan = [k for k, v in (("proteína", a["prot"]), ("grasa", a["grasa"]), ("carbohidratos", a["cho"])) if v is None]
        p, c, g = a["prot"] or 0.0, a["cho"] or 0.0, a["grasa"] or 0.0
        calculado = 4 * p + 4 * c + 9 * g
        diferencia = abs(calculado - a["kcal"])
        if faltan:
            revisar.append(f"{a['codigo']:>6}  p.{a['pagina']:<3}  {a['nombre']}  — faltan: {', '.join(faltan)} (se usó 0)")
        elif a["kcal"] > 20 and diferencia > max(25, 0.20 * a["kcal"]):
            revisar.append(f"{a['codigo']:>6}  p.{a['pagina']:<3}  {a['nombre']}  — kcal {a['kcal']:.0f} vs macros {calculado:.0f}")

    salida = {
        "fuente": FUENTE,
        "alimentos": [{
            "codigo": a["codigo"],
            "nombre": a["nombre"],
            "grupo": a["grupo"],
            "por100g": {
                "kcal": a["kcal"],
                "proteina": a["prot"] if a["prot"] is not None else 0.0,
                "carbohidratos": a["cho"] if a["cho"] is not None else 0.0,
                "grasas": a["grasa"] if a["grasa"] is not None else 0.0,
            },
        } for a in lista],
    }
    os.makedirs(os.path.dirname(DESTINO_JSON), exist_ok=True)
    with open(DESTINO_JSON, "w", encoding="utf-8") as f:
        json.dump(salida, f, ensure_ascii=False, separators=(",", ":"))
    with open(DESTINO_CSV, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["codigo", "nombre", "grupo", "kcal", "proteina", "carbohidratos", "grasas", "pagina", "filas_promediadas"])
        for a in lista:
            w.writerow([a["codigo"], a["nombre"], a["grupo"], a["kcal"], a["prot"], a["cho"], a["grasa"], a["pagina"], a["estratos"]])
    with open(DESTINO_REVISAR, "w", encoding="utf-8") as f:
        f.write("Filas para revisar contra el PDF (no son necesariamente errores).\n\n")
        f.write("\n".join(revisar) + "\n")

    por_grupo = {}
    for a in lista:
        clave = re.match(r"[A-Z]", a["codigo"]).group(0)
        por_grupo[clave] = por_grupo.get(clave, 0) + 1
    print(f"Alimentos y platos: {len(lista)}")
    for letra in sorted(por_grupo):
        print(f"  {letra} {grupos.get(letra, '?')}: {por_grupo[letra]}")
    print(f"Platos del grupo S sin código (descartados): {sin_codigo}")
    for a in avisos:
        print("  AVISO:", a)
    print(f"Para revisar: {len(revisar)} (ver herramientas/ins-revisar.txt)")
    print(f"Escrito: {os.path.relpath(DESTINO_JSON, RAIZ)} ({os.path.getsize(DESTINO_JSON) // 1024} KB)")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Uso: python3 herramientas/convertir_ins.py RUTA/AL/PDF.pdf")
    main(sys.argv[1])
