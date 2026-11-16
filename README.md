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
- Código de barras (Open Food Facts), lectura de etiquetas (primero en el
  iPhone, sin internet; si no alcanza, con IA) y productos recordados.
- Sin internet: la foto o el texto se guarda y se analiza solo cuando
  vuelve la red; lo revisas desde el Diario antes de guardarlo.
- Recuerda las porciones que corriges a la IA y las propone la próxima vez.
- Búsqueda en la tabla del INS sin internet, más tus alimentos y recetas.
- Mis alimentos (a mano o calculados con IA), recetas con ingredientes y
  peso cocido, comparador de alimentos.
- Agua con meta automática o manual.
- Copiar una comida o el día entero a otra fecha, y comidas favoritas que
  se agregan en un toque.
- Media mañana y media tarde opcionales (Ajustes › Comidas del día).
- Animación al analizar la foto: puntos sobre la foto mientras la IA
  trabaja; luego se juntan sobre cada alimento (cajas «box_2d» de Gemini,
  validadas) o en la lista debajo si no hay caja. Con VoiceOver se anuncian
  los alimentos detectados; con «Reducir movimiento» solo hay un fundido.
- Mientras la IA trabaja se ve cuánto tiempo lleva, un aviso si se prueba
  otro modelo y un botón **Cancelar** (salir de la pantalla también corta
  la petición). A los 20 s aparecen **Buscar en la tabla** y **Agregar a
  mano** (sin cancelar); a los 30 s se cancela sola. Si la IA falla, el
  aviso trae los mismos botones. La revisión dice quién respondió (memoria,
  iPhone, Gemini o Groq) y en cuántos segundos.

**Meta**
- Mifflin-St Jeor con fórmula visible, tipo de dieta (equilibrada, alta en
  proteína, baja en carbohidratos, keto, baja en grasa) o meta a mano.
- Ajuste dinámico según cómo cambia tu peso (lo apruebas tú).
- Meta distinta según el día de la semana (por ejemplo, más el sábado).
- Opcional: sumar calorías activas de Apple Salud.

**Plan**
- Modo cocina: ingredientes y pasos en pantalla grande, sin que se apague.
- Plan diario automático con la tabla del INS y tus recetas, edición manual,
  «Comí» para pasarlo al diario, ajuste automático de porciones, lista de
  compras y PDF para compartir.

**Progreso**
- Peso con línea de tendencia suavizada, gasto calórico estimado con tus
  datos, resumen de la semana y «lo que más te aporta» (calorías o sodio).
- Peso con gráfica y tendencia, IMC, medidas corporales, % de grasa
  (fórmula de la Marina de EE. UU. o escrito a mano), fotos de progreso
  (solo en el iPhone), gráficos de nutrientes y racha.

**Ayuno**
- Temporizador 12:12 a 20:4 o personalizado, historial, racha, aviso al
  terminar, widget y Actividad en vivo en la pantalla bloqueada.

**Más**
- Coach con IA (solo envía lo que escribes; el resumen del día es opcional).
- Recordatorios locales de comidas, agua, peso y ayuno.
- Widgets de calorías y macros, agua, ayuno y pantalla bloqueada (su letra
  sigue el tamaño de texto del iPhone, con un tope para que quepa).
  **Widgets con botones** (iOS 17): «+ agua» y «Repetir favorito» sin abrir
  la app (necesitan la versión completa del .ipa, con App Group).
- **Siri y Atajos**: «Oye Siri, agrega un vaso de agua en Sazón» y «Oye
  Siri, repite mi desayuno en Sazón» (usa tu favorito de esa comida o lo
  que comiste en ella el último día).
- **Apple Salud** (opcional, versión completa): lee pasos, calorías activas
  y peso; guarda tu peso y, si lo activas, las calorías y macros de cada
  comida.
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
  cite la fuente». La app trae 1692 entradas: 1125 alimentos y 567 platos
  preparados (contadas en `Sazon/Datos/alimentos-ins.json`).
- **Micronutrientes (pendiente):** la app ya puede mostrar hierro, calcio,
  zinc, vitaminas A y C, etc. si la tabla los trae, pero el archivo aún no
  los incluye. Para agregarlos hay que confirmar en el PDF oficial del INS
  en qué columna está cada uno y completarlo en `herramientas/convertir_ins.py`
  (`COLUMNAS_MICROS`). No se inventan valores.
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

## IA: capas, tiempos y privacidad

La IA trabaja por capas (de la más rápida y privada a la nube):

1. **Memoria del iPhone**: si analizas la misma foto o el mismo texto en
   24 h, la respuesta sale de aquí, sin internet ni cuota (se guarda solo
   la respuesta, con una huella del contenido; máximo 80 respuestas).
2. **En el iPhone**: las etiquetas nutricionales se leen con Vision de
   Apple (`VNRecognizeTextRequest`), sin red. Si no se encuentran con
   seguridad las calorías y los macros, se usa la nube. El dictado se hace
   en el iPhone cuando el iPhone lo permite (`requiresOnDeviceRecognition`).
   El modelo de Apple Intelligence no se usa (pide iPhone 15 Pro o posterior).
3. **Google Gemini** con tu clave. Modelo por defecto `gemini-3.8-flash`;
   si está saturado o sin cuota se prueban `gemini-3.5-flash-lite`,
   `gemini-3.6-flash` y `gemini-3.1-flash-lite` (todos gratuitos en
   <https://ai.google.dev/gemini-api/docs/pricing>, consultada el 16-nov-2026).
   Cada tarea tiene un prompt corto propio y el razonamiento va al mínimo
   que admite cada modelo (`low` en 3.8-flash; `minimal` en los demás).
4. **Groq (opcional)**: si pones una segunda clave, se usa solo cuando
   Gemini está saturado o sin cuota (modelo `qwen/qwen3.8-27b`, que Groq
   marca como «Preview»). Sin esa clave, todo funciona igual.

**Reintentos reales** (por cada registro): como máximo **3 llamadas** entre
todos los modelos y proveedores (con clave de Groq: 2 a Gemini y 1 a Groq),
espera creciente con algo de azar entre intentos, y **corte total a los
30 s** (también se corta la petición en curso). Un 429 con cuota diaria
agotada deja ese modelo sin usar hasta la medianoche hora del Pacífico
(2:00 o 3:00 a. m. en Lima); un 400 no se reintenta con otros modelos.
A los 20 s la pantalla ofrece «Buscar en la tabla» y «Agregar a mano».

**Claves**: se pegan en Ajustes › Inteligencia artificial y se guardan en
el **Llavero** del iPhone (solo con el iPhone desbloqueado y nunca se
copian a otro dispositivo). Nunca van en este repositorio, en el código, en
los registros ni en el respaldo.

**Privacidad** (fuentes consultadas el 16-nov-2026):
- Gemini, plan gratuito: Google usa lo que envías y las respuestas para
  mejorar sus productos, y **revisores humanos pueden leerlo**; Google pide
  no enviar información sensible
  (<https://ai.google.dev/gemini-api/terms>). Por eso solo se envía la foto
  (reducida y sin ubicación) o el texto; el resumen del día al coach es
  opcional.
- Groq: según <https://console.groq.com/docs/your-data>, por defecto no
  guarda lo que envías para responder (puede guardar registros hasta 30
  días si hay fallos o abuso).
- Toda la conexión con la IA está en `Sazon/Servicios/ServicioIA.swift` y
  `Sazon/Servicios/ProveedorGroq.swift`; las reglas, en
  `Sazon/Logica/PoliticaIA.swift`.

### Crear la clave de Gemini

1. Entra a <https://aistudio.google.com> con tu cuenta de Google.
2. Acepta los términos si te los pide.
3. Abre «Get API key» y pulsa «Create API key».
4. Copia la clave y pégala en Sazón › Ajustes › Inteligencia artificial.
5. No configures facturación (así te quedas en el plan gratuito).
6. Tus límites reales se ven en AI Studio, en la sección de uso y límites.

### Crear la clave de Groq (opcional, respaldo)

1. Entra a <https://console.groq.com> y crea una cuenta gratuita (con tu
   correo o tu cuenta de Google).
2. En el menú, abre «API Keys» y toca «Create API Key».
3. Ponle un nombre (por ejemplo «Sazón») y copia la clave: Groq la muestra
   una sola vez.
4. En Sazón › Ajustes › Inteligencia artificial › «Respaldo opcional:
   Groq», pégala y toca «Guardar clave de Groq».
5. No agregues tarjeta. Tus límites reales se ven en la consola de Groq.

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
5. En Sazón › Ajustes › Widgets puedes ver qué quedó activo en tu firma.
6. Guarda una copia de los `.ipa` en tu PC: GitHub los borra a los 14 días
   (`retention-days: 14` en `.github/workflows/compilar.yml`).

Por verificar: con una cuenta gratuita, la extensión de widgets puede
contar dentro del límite de 3 apps y usar un identificador más; y no está
confirmado que Sideloadly conserve el permiso de Apple Salud. Tus datos se
guardan en la app, así que instalar una versión encima de la otra no los
borra (sí se borran si eliminas la app).

### Renovar cada 7 días (gratis)

Con un Apple ID gratuito, la app deja de abrir a los 7 días de firmarla.
Pon un recordatorio **cada 6 días** para renovarla a tiempo.

**Opción A (recomendada): repetir Sideloadly.**
1. Antes, en Sazón › Ajustes › Respaldo, toca «Exportar» y guarda el
   respaldo en Archivos (por si algo sale mal).
2. Conecta el iPhone a la PC y abre Sideloadly.
3. Usa **el mismo `.ipa`** (la copia que guardaste) y **el mismo Apple ID**,
   y pulsa Start. **No borres la app antes**: se instala encima y tus datos
   se conservan.

Nota: la FAQ oficial de Sideloadly (https://sideloadly.io/faq.html,
consultada el 16-nov-2026) describe una renovación automática con
«Sideloadly Daemon» y la PC encendida, sin mencionar pago; pero, según la
experiencia del dueño, hoy solo funciona para miembros de Patreon. No se
pudo confirmar en una fuente oficial, así que esta guía no depende de ella.

**Opción B: AltStore Classic con AltServer.**
Según su FAQ (https://faq.altstore.io/altstore-classic/altserver,
consultada el 16-nov-2026), AltStore intenta renovar las apps durante la
semana si el iPhone está en la misma Wi-Fi que la PC con AltServer abierto
(o conectado por cable); recomiendan que AltServer se abra al iniciar la PC.
Ten en cuenta que AltStore ocupa uno de los 3 lugares de apps de la cuenta
gratuita. Por verificar: que funcione con iOS 26.5 y que conserve el App
Group (widgets) y el permiso de Apple Salud.

## Estructura

```
Sazon/App          Entrada de la app y vista raíz
Sazon/Modelo       Datos (Modelos.swift) y almacén JSON local (Almacen.swift)
Sazon/Logica       Lógica pura con pruebas: metas, sumas del día, porciones,
                   búsqueda en la tabla, lectura del JSON de la IA y de Open Food Facts
Sazon/Servicios    Gemini y Groq (IA), Open Food Facts, Llavero, fotos, etiquetas con Vision,
                   cola sin conexión, Siri y Atajos, Apple Salud, tabla del INS, respaldo
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
