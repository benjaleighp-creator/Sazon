# Sazón

App personal para iPhone para registrar comidas con IA, en español (Perú).
Uso personal: no se publica en el App Store. Se compila en GitHub Actions
(sin Mac) y se instala con Sideloadly desde Windows.

## Funciones (versión 1)

1. **Diario del día** por comidas (desayuno, almuerzo, cena y snacks), con
   calorías, proteínas, carbohidratos y grasas frente a la meta. Flechas
   para ver y corregir días anteriores.
2. **Foto del plato**: Gemini identifica alimentos y porciones; tú revisas
   y corriges antes de guardar.
3. **Texto o voz**: escribe o dicta («2 panes con palta y un café») con el
   micrófono del teclado de iOS.
4. **Código de barras** con Open Food Facts (sin IA).
5. **Búsqueda en la tabla del INS**, dentro de la app y sin internet.
6. **Meta** en Ajustes (bajar grasa, mantener o ganar músculo), con la
   fórmula visible y la opción de escribir la meta a mano.

Cada registro muestra su origen: INS, Open Food Facts, «≈ estimado por IA»
o manual. Todas las cifras son estimaciones editables, no consejo médico.

### Posibles funciones futuras (no incluidas)

Plan de comidas automático, recetas, lista de compras, ayuno, agua, peso,
Apple Salud, widgets, comunidad y coach.

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
2. Descarga el artefacto `Sazon-ipa-version-N` y descomprímelo.
3. Arrastra `Sazon.ipa` a Sideloadly, elige tu iPhone y tu Apple ID.
4. Deja activado el botón redondo de flechas azules (renovación automática).
5. En Advanced Options deja «Use automatic bundle ID».
6. El número de compilación se ve en Sazón › Ajustes › Acerca de.

Usa 1 espacio de app y 1 identificador (`pe.benjamin.sazon`), sin extensiones.

## Estructura

```
Sazon/App          Entrada de la app y vista raíz
Sazon/Modelo       Datos (Modelos.swift) y almacén JSON local (Almacen.swift)
Sazon/Logica       Lógica pura con pruebas: metas, sumas del día, porciones,
                   búsqueda en la tabla, lectura del JSON de la IA y de Open Food Facts
Sazon/Servicios    Gemini, Open Food Facts, Llavero, fotos, tabla del INS, respaldo
Sazon/Diseno       Sistema de diseño: espaciado, tipografía, movimiento, temas, componentes
Sazon/Pantallas    Una vista por pantalla
Sazon/Datos        alimentos-ins.json (tabla del INS)
Pruebas            Pruebas automáticas de la lógica
herramientas       Temas (temas.json), generador, verificador de contraste y conversor del INS
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
