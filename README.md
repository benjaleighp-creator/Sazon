# Sazón

App personal para iPhone para registrar comidas con IA, en español (Perú).
Uso personal: no se publica en el App Store. Se compila en GitHub Actions
(sin Mac) y se instala con Sideloadly desde Windows.

## Funciones

**Registrar**
- Diario por comidas (desayuno, almuerzo, cena y snacks) con calorías, macros,
  fibra, sodio y azúcares; semana con flechas para días anteriores.
- Foto del plato, texto o **voz** (reconocimiento de voz de Apple) analizados
  con Gemini; siempre revisas antes de guardar.
- Código de barras (Open Food Facts), lectura de etiquetas con IA y
  productos recordados.
- Búsqueda en la tabla del INS sin internet, más tus alimentos y recetas.
- Mis alimentos (a mano o calculados con IA), recetas con ingredientes y
  peso cocido, comparador de alimentos.
- Agua con meta automática o manual.

**Meta**
- Mifflin-St Jeor con fórmula visible, tipo de dieta (equilibrada, alta en
  proteína, baja en carbohidratos, keto, baja en grasa) o meta a mano.
- Ajuste dinámico según cómo cambia tu peso (lo apruebas tú).
- Opcional: sumar calorías activas de Apple Salud.

**Plan**
- Plan diario automático con la tabla del INS y tus recetas, edición manual,
  «Comí» para pasarlo al diario, ajuste automático de porciones, lista de
  compras y PDF para compartir.

**Progreso**
- Peso con gráfica y tendencia, IMC, medidas corporales, % de grasa
  (fórmula de la Marina de EE. UU. o escrito a mano), fotos de progreso
  (solo en el iPhone), gráficos de nutrientes y racha.

**Ayuno**
- Temporizador 12:12 a 20:4 o personalizado, historial, racha, aviso al
  terminar, widget y Actividad en vivo en la pantalla bloqueada.

**Más**
- Coach con IA (solo envía lo que escribes; el resumen del día es opcional).
- Recordatorios locales de comidas, agua, peso y ayuno.
- Widgets de calorías y macros, agua, ayuno y pantalla bloqueada.
- Exportar comidas y pesos a CSV; respaldo completo.

Cada registro muestra su origen: INS, Open Food Facts, etiqueta del envase,
«≈ estimado por IA» o manual. Todas las cifras son estimaciones editables,
no consejo médico.

### Funciones de Fitia que no se incluyen

Necesitan servidores o cuentas de otras personas: equipos y desafíos,
planes compartidos con familia y enviar comidas a otro usuario. Tampoco
hay una base de datos de millones de alimentos verificada por
nutricionistas ni un recetario de miles de recetas: se usan la tabla del
INS, Open Food Facts y tus propias recetas.

## Datos nutricionales

- **Tabla principal:** Instituto Nacional de Salud (Perú), Centro Nacional de
  Alimentación, Nutrición y Vida Saludable. *Tablas peruanas de composición
  de alimentos*, 11.ª edición digital (TPCA 2023), marzo 2025. El documento
  indica: «Se autoriza su reproducción total o parcial, siempre y cuando se
  cite la fuente». Incluye 1073 alimentos y 567 platos preparados.
- El PDF se convierte con `herramientas/convertir_ins.py` en
  `Sazon/Datos/alimentos-ins.json`, que va dentro de la app. El script
  también deja `herramientas/alimentos-ins.csv` (para revisar a mano) y
  `herramientas/ins-revisar.txt` (filas que conviene revisar contra el PDF).
- Carbohidratos: se usan los «disponibles» (sin fibra) cuando existen; si
  no, los «totales». En los platos preparados se usa el promedio de los
  estratos socioeconómicos que trae la tabla.
- **Productos envasados:** Open Food Facts (licencia ODbL).
- **IA:** si el alimento que nombra la IA coincide con la tabla del INS,
  los valores salen de la tabla; si no, se usa la estimación de la IA
  marcada con «≈».

## IA: Google Gemini (plan gratuito)

- Modelo por defecto: `gemini-3.8-flash` (gratuito en la página de precios
  de Gemini al 1 de noviembre de 2026). Se puede cambiar en Ajustes.
- La clave de API se pega una vez en Ajustes y se guarda en el **Llavero**
  del iPhone. Nunca va en este repositorio ni en el código.
- Una sola llamada por registro, sin reintentos automáticos. Las fotos se
  reducen a 1024 px y se envían sin metadatos.
- En el plan gratuito, Google puede usar lo enviado para mejorar sus
  productos. La app lo avisa la primera vez.
- Toda la conexión con la IA está en `Sazon/Servicios/ServicioIA.swift`.

### Crear la clave

1. Entra a <https://aistudio.google.com> con tu cuenta de Google.
2. Acepta los términos si te los pide.
3. Abre «Get API key» y pulsa «Create API key».
4. Copia la clave y pégala en Sazón › Ajustes › Inteligencia artificial.
5. No configures facturación (así te quedas en el plan gratuito).
6. Tus límites reales se ven en AI Studio, en la sección de uso y límites.

## Instalar en el iPhone

1. En GitHub, pestaña **Actions**, abre la última ejecución en verde de
   «Compilar IPA».
2. Descarga el artefacto `Sazon-ipa-version-N` y descomprímelo. Trae dos
   archivos:
   - `Sazon-completa.ipa`: con widgets, Actividad en vivo y Apple Salud.
   - `Sazon-sencilla.ipa`: sin widgets ni Apple Salud (todo lo demás igual).
3. Arrastra primero `Sazon-completa.ipa` a Sideloadly, elige tu iPhone y tu
   Apple ID, y pulsa Start.
4. Si Sideloadly da error por los permisos o por el límite de apps o de
   identificadores de la cuenta gratuita, instala `Sazon-sencilla.ipa`.
5. Deja activada la renovación automática.
6. En Sazón › Ajustes › Widgets puedes ver qué quedó activo en tu firma.

Por verificar: con una cuenta gratuita, la extensión de widgets puede
contar dentro del límite de 3 apps y usar un identificador más; y no está
confirmado que Sideloadly conserve el permiso de Apple Salud. Tus datos se
guardan en la app, así que instalar una versión encima de la otra no los
borra (sí se borran si eliminas la app).

## Estructura

```
Sazon/App          Entrada de la app y vista raíz
Sazon/Modelo       Datos (Modelos.swift) y almacén JSON local (Almacen.swift)
Sazon/Logica       Lógica pura con pruebas: metas, sumas del día, porciones,
                   búsqueda en la tabla, lectura del JSON de la IA y de Open Food Facts
Sazon/Servicios    Gemini, Open Food Facts, Llavero, fotos, tabla del INS, respaldo
Sazon/Diseno       Sistema de diseño: espaciado, tipografía, movimiento, temas, componentes
Sazon/Pantallas    Una vista por pantalla
Compartido         Código que comparten la app y los widgets
SazonWidget        Widgets y Actividad en vivo del ayuno
Sazon/Datos        alimentos-ins.json (tabla del INS)
Pruebas            Pruebas automáticas de la lógica
herramientas       Temas (temas.json), generador, verificador de contraste, conversor del INS y dibujo del ícono
Marca              Ícono de la app
```

## Herramientas

```
python3 herramientas/verificar_contraste.py    # contraste WCAG de los temas (0 fallos)
python3 herramientas/generar_temas.py          # genera Sazon/Diseno/CatalogoTemas.swift
python3 herramientas/convertir_ins.py RUTA.pdf # vuelve a generar la tabla del INS
```

El sistema de diseño, el workflow y el patrón de pruebas se adaptaron de
Remanso; los temas, colores, íconos y textos de Sazón son propios.
