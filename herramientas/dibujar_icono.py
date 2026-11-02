#!/usr/bin/env python3
# Uso: python3 herramientas/dibujar_icono.py Sazon/Assets.xcassets/AppIcon.appiconset/icono-1024.png
"""Ícono de Sazón: anillo de progreso en cuatro tramos (calorías y macros)
alrededor de un cuenco, sobre un degradado terracota. Se dibuja a 4× y se
reduce para bordes suaves."""
import math, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

N = 1024
S = 4
W = N * S
salida = sys.argv[1]

def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))

# 1. Fondo: degradado diagonal + brillo radial arriba a la izquierda.
arriba = (206, 92, 48)
abajo = (122, 38, 16)
fondo = Image.new("RGB", (W, W))
px = []
paso = 8
lin = Image.new("RGB", (W // paso, W // paso))
lp = lin.load()
for y in range(W // paso):
    for x in range(W // paso):
        t = (x * 0.35 + y * 0.65) / (W // paso)
        lp[x, y] = lerp(arriba, abajo, min(1, max(0, t)))
fondo = lin.resize((W, W), Image.BICUBIC)
brillo = Image.new("L", (W, W), 0)
ImageDraw.Draw(brillo).ellipse((-W * 0.25, -W * 0.35, W * 0.75, W * 0.55), fill=90)
brillo = brillo.filter(ImageFilter.GaussianBlur(W * 0.12))
fondo = Image.composite(Image.new("RGB", (W, W), (235, 128, 78)), fondo, brillo)

def sombra(mascara, desplazamiento, desenfoque, opacidad):
    s = mascara.filter(ImageFilter.GaussianBlur(desenfoque))
    s = ImageChops.offset(s, 0, desplazamiento)
    return s.point(lambda v: int(v * opacidad))

cx, cy = W / 2, W * 0.5
crema = (255, 247, 236)

# 2. Anillo en cuatro tramos.
R = W * 0.335          # radio medio
G = W * 0.056          # grosor
colores = [(255, 168, 118), (214, 176, 246), (255, 212, 100), (174, 220, 126)]
tramos = 4
hueco = 16              # grados entre tramos
mascara_anillo = Image.new("L", (W, W), 0)
capa_anillo = Image.new("RGB", (W, W), (0, 0, 0))
for i, c in enumerate(colores):
    ini = -90 + i * 360 / tramos + hueco / 2
    fin = ini + 360 / tramos - hueco
    m = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(m)
    d.arc((cx - R, cy - R, cx + R, cy + R), ini, fin, fill=255, width=int(G))
    # Puntas redondeadas.
    for ang in (ini, fin):
        a = math.radians(ang)
        r_c = R - G / 2
        x, y = cx + r_c * math.cos(a), cy + r_c * math.sin(a)
        d.ellipse((x - G / 2, y - G / 2, x + G / 2, y + G / 2), fill=255)
    capa_anillo.paste(Image.new("RGB", (W, W), c), mask=m)
    mascara_anillo = ImageChops.lighter(mascara_anillo, m)

# 3. Cuenco con cuchara, en crema.
mascara_cuenco = Image.new("L", (W, W), 0)
d = ImageDraw.Draw(mascara_cuenco)
rb = W * 0.178
yb = cy + W * 0.005
d.pieslice((cx - rb, yb - rb * 0.92, cx + rb, yb + rb * 0.92), 0, 180, fill=255)
d.rounded_rectangle((cx - rb * 1.1, yb - W * 0.016, cx + rb * 1.1, yb + W * 0.012), radius=W * 0.012, fill=255)
d.rounded_rectangle((cx - rb * 0.42, yb + rb * 0.84, cx + rb * 0.42, yb + rb * 0.98), radius=W * 0.012, fill=255)
# Hoja que sale del cuenco (frescura).
hoja = Image.new("L", (W, W), 0)
hd = ImageDraw.Draw(hoja)
hx, hy = cx + W * 0.03, yb - W * 0.105
L, A = W * 0.15, W * 0.075
puntos = []
for t in range(0, 181):
    a = math.radians(t)
    puntos.append((hx + (t / 180 - 0.5) * L, hy - math.sin(a) * A / 2))
for t in range(180, -1, -1):
    a = math.radians(t)
    puntos.append((hx + (t / 180 - 0.5) * L, hy + math.sin(a) * A / 2))
hoja_rot = Image.new("L", (W, W), 0)
ImageDraw.Draw(hoja_rot).polygon(puntos, fill=255)
hoja_rot = hoja_rot.rotate(32, center=(hx, hy), resample=Image.BICUBIC)
# Nervio central de la hoja (se resta).
nervio = Image.new("L", (W, W), 0)
ImageDraw.Draw(nervio).line([(hx - L * 0.42, hy), (hx + L * 0.42, hy)], fill=255, width=int(W * 0.007))
nervio = nervio.rotate(32, center=(hx, hy), resample=Image.BICUBIC)
hoja_final = hoja_rot
# Tallo
tallo = Image.new("L", (W, W), 0)
ImageDraw.Draw(tallo).line([(cx - W * 0.03, yb - W * 0.01), (hx - L * 0.36, hy + W * 0.035)], fill=255, width=int(W * 0.012))

verde = (176, 222, 128)
glifo = Image.new("RGB", (W, W), crema)

# 4. Composición con sombras suaves.
lienzo = fondo.copy()
pista = Image.new("L", (W, W), 0)
ImageDraw.Draw(pista).ellipse((cx - R, cy - R, cx + R, cy + R), outline=255, width=int(G))
lienzo = Image.composite(Image.new("RGB", (W, W), (112, 32, 12)), lienzo, pista.point(lambda v: int(v * 0.55)))
s1 = sombra(mascara_anillo, int(W * 0.012), W * 0.02, 0.45)
lienzo = Image.composite(Image.new("RGB", (W, W), (70, 18, 6)), lienzo, s1)
lienzo.paste(capa_anillo, mask=mascara_anillo)
s2 = sombra(ImageChops.lighter(mascara_cuenco, hoja_final), int(W * 0.014), W * 0.022, 0.5)
lienzo = Image.composite(Image.new("RGB", (W, W), (70, 18, 6)), lienzo, s2)
lienzo.paste(Image.new("RGB", (W, W), (150, 196, 104)), mask=tallo)
lienzo.paste(Image.new("RGB", (W, W), verde), mask=hoja_final)
lienzo.paste(Image.new("RGB", (W, W), (214, 240, 186)), mask=ImageChops.multiply(nervio, hoja_final).point(lambda v: int(v * 0.8)))
lienzo.paste(glifo, mask=mascara_cuenco)
# Brillo sutil en el borde superior del cuenco.
borde = Image.new("L", (W, W), 0)
ImageDraw.Draw(borde).rounded_rectangle((cx - rb * 1.1, yb - W * 0.016, cx + rb * 1.1, yb - W * 0.004), radius=W * 0.006, fill=255)
lienzo.paste(Image.new("RGB", (W, W), (255, 255, 255)), mask=borde)

final = lienzo.resize((N, N), Image.LANCZOS)
final.save(salida)
print("ok", salida)
