import SwiftUI
import UniformTypeIdentifiers

/// Ajustes: meta, IA, porciones, apariencia, batería, respaldo y fuentes.
struct AjustesView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Espacio.l) {
                    seccionMeta
                    SeccionIA()
                    seccionPorciones
                    seccionApariencia
                    seccionBateria
                    SeccionRespaldo()
                    seccionAcercaDe
                    if let error = almacen.errorGuardado {
                        Aviso(icono: "externaldrive.badge.exclamationmark", titulo: "Error al guardar", texto: error, color: paleta.peligro)
                    }
                }
                .padding(.horizontal, Espacio.margen)
                .padding(.vertical, Espacio.m)
                .padding(.bottom, Espacio.xl)
            }
            .fondoDePantalla()
            .navigationTitle("Ajustes")
        }
    }

    // MARK: Meta

    private var seccionMeta: some View {
        VStack(alignment: .leading, spacing: Espacio.xs) {
            TituloSeccion("Meta diaria")
            NavigationLink {
                MetaView()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: Espacio.xxxs) {
                        if let meta = almacen.meta {
                            Text("\(Formato.entero(meta.kcal)) kcal · P \(Formato.entero(meta.proteina)) · C \(Formato.entero(meta.carbohidratos)) · G \(Formato.entero(meta.grasas)) g")
                                .font(Tipo.cuerpo).foregroundStyle(paleta.texto)
                            Text(almacen.datos.metaManual != nil ? "Escrita a mano" : (almacen.datos.perfil?.objetivo.nombre ?? ""))
                                .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                        } else {
                            Text("Configurar mi meta").font(Tipo.cuerpo).foregroundStyle(paleta.texto)
                            Text("Bajar grasa, mantener o ganar músculo").font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(Tipo.iconoChico).foregroundStyle(paleta.textoSecundario)
                }
                .tarjeta()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Porciones

    private var seccionPorciones: some View {
        @Bindable var a = almacen
        return VStack(alignment: .leading, spacing: Espacio.xs) {
            TituloSeccion("Porciones")
            VStack(alignment: .leading, spacing: Espacio.s) {
                Picker("Unidad", selection: $a.datos.unidad) {
                    ForEach(UnidadPorcion.allCases) { Text($0.nombre).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("Todo se guarda en gramos; esto solo cambia cómo lo ves y escribes. También puedes usar medidas caseras al registrar.")
                    .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .tarjeta()
        }
    }

    // MARK: Apariencia

    private var seccionApariencia: some View {
        @Bindable var a = almacen
        return VStack(alignment: .leading, spacing: Espacio.xs) {
            TituloSeccion("Apariencia")
            VStack(alignment: .leading, spacing: Espacio.s) {
                ForEach(CatalogoTemas.todos) { tema in
                    Button {
                        animar(.pantalla) { almacen.datos.temaID = tema.id }
                    } label: {
                        HStack(spacing: Espacio.s) {
                            MuestraTema(tema: tema)
                            VStack(alignment: .leading, spacing: Espacio.xxxs) {
                                Text(tema.nombre).font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                                Text(tema.concepto).font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            if almacen.datos.temaID == tema.id {
                                Image(systemName: "checkmark.circle.fill").font(Tipo.iconoFila).foregroundStyle(paleta.acento)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(almacen.datos.temaID == tema.id ? .isSelected : [])
                    .sensoryFeedback(.selection, trigger: almacen.datos.temaID)
                }
                Picker("Modo", selection: $a.datos.apariencia) {
                    ForEach(Apariencia.allCases) { Text($0.nombre).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .tarjeta()
        }
    }

    // MARK: Batería

    private var seccionBateria: some View {
        @Bindable var a = almacen
        return VStack(alignment: .leading, spacing: Espacio.xs) {
            TituloSeccion("Batería")
            Toggle(isOn: $a.datos.ahorroBateria) {
                VStack(alignment: .leading, spacing: Espacio.xxxs) {
                    Text("Ahorro de batería").font(Tipo.cuerpo).foregroundStyle(paleta.texto)
                    Text("Quita las animaciones. Se activa solo con el modo de bajo consumo del iPhone.")
                        .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(paleta.acento)
            .tarjeta()
        }
    }

    // MARK: Acerca de

    private var seccionAcercaDe: some View {
        VStack(alignment: .leading, spacing: Espacio.xs) {
            TituloSeccion("Acerca de")
            VStack(alignment: .leading, spacing: Espacio.s) {
                FilaValor(titulo: "Versión", valor: versionApp)
                Divider().overlay(paleta.borde)
                textoFuente("Tabla de alimentos", almacen.tabla.fuente.isEmpty ? (almacen.tabla.error ?? "") : almacen.tabla.fuente + " Se autoriza su reproducción citando la fuente.")
                textoFuente("Productos envasados", "Open Food Facts (openfoodfacts.org), base de datos colaborativa con licencia Open Database License (ODbL).")
                textoFuente("Inteligencia artificial", "Google Gemini con tu clave del plan gratuito. Sus cifras son estimaciones (≈).")
                textoFuente("Importante", "Las calorías y los macros son estimaciones generales y editables, no consejo médico.")
            }
            .tarjeta()
        }
    }

    private func textoFuente(_ titulo: String, _ texto: String) -> some View {
        VStack(alignment: .leading, spacing: Espacio.xxxs) {
            Text(titulo).font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
            Text(texto).font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    /// Versión y número de compilación (el número coincide con el de GitHub Actions).
    private var versionApp: String {
        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
        let compilacion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1"
        return "\(version) (compilación \(compilacion))"
    }
}

/// Muestra de colores de un tema (decorativa).
private struct MuestraTema: View {
    let tema: Tema
    @Environment(\.colorScheme) private var esquema
    @ScaledMetric(relativeTo: .body) private var lado: CGFloat = 40

    var body: some View {
        let p = tema.paleta(esquema)
        let l = min(lado, 64)
        ZStack {
            RoundedRectangle(cornerRadius: l * 0.3, style: .continuous).fill(p.fondo)
            HStack(spacing: 2) {
                ForEach([p.calorias, p.proteina, p.carbohidratos, p.grasas], id: \.self) { c in
                    Capsule().fill(c).frame(width: l * 0.12, height: l * 0.5)
                }
            }
        }
        .frame(width: l, height: l)
        .overlay(RoundedRectangle(cornerRadius: l * 0.3, style: .continuous).strokeBorder(p.borde, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

// MARK: - Inteligencia artificial

private struct SeccionIA: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var claveOculta = Llavero.claveOculta()
    @State private var nuevaClave = ""
    @State private var mensaje: String?
    @State private var mostrarPasos = false

    var body: some View {
        @Bindable var a = almacen
        VStack(alignment: .leading, spacing: Espacio.xs) {
            TituloSeccion("Inteligencia artificial")
            VStack(alignment: .leading, spacing: Espacio.s) {
                FilaValor(titulo: "Clave de Gemini", valor: claveOculta ?? "Sin clave")
                SecureField(claveOculta == nil ? "Pega tu clave de API" : "Reemplazar clave", text: $nuevaClave)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, Espacio.m)
                    .frame(minHeight: Medida.toque)
                    .background(RoundedRectangle(cornerRadius: Radio.medio, style: .continuous).fill(paleta.superficieAlta))
                    .accessibilityLabel("Clave de API de Gemini")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Espacio.s) { botonesClave }
                    VStack(spacing: Espacio.s) { botonesClave }
                }
                if let mensaje {
                    Text(mensaje).font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                }
                Text("Se guarda cifrada en el Llavero de este iPhone. No va en el respaldo ni en el código.")
                    .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)

                Divider().overlay(paleta.borde)

                VStack(alignment: .leading, spacing: Espacio.xxs) {
                    Text("Modelo").font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                    CampoTexto(titulo: DatosApp.modeloPorDefecto, texto: $a.datos.modeloIA)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Text("Por defecto \(DatosApp.modeloPorDefecto), que en noviembre de 2026 figuraba como gratuito en la página de precios de Gemini. Si Google lo cambia, escribe aquí el nombre nuevo.")
                        .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                    if almacen.datos.modeloIA != DatosApp.modeloPorDefecto {
                        Button("Volver a \(DatosApp.modeloPorDefecto)") { almacen.datos.modeloIA = DatosApp.modeloPorDefecto }
                            .buttonStyle(.texto)
                            .font(Tipo.pie)
                    }
                }
                VStack(alignment: .leading, spacing: Espacio.xxs) {
                    Text("Formato de petición").font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                    Picker("Formato de petición", selection: $a.datos.formatoPeticionIA) {
                        ForEach(FormatoPeticionIA.allCases) { Text($0 == .actual ? "Actual" : "Clásico").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text("Cámbialo solo si Gemini rechaza la petición mencionando «responseFormat» o un campo desconocido.")
                        .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider().overlay(paleta.borde)

                DisclosureGroup("Cómo crear tu clave gratis", isExpanded: $mostrarPasos) {
                    VStack(alignment: .leading, spacing: Espacio.xs) {
                        ForEach(Array(pasosClave.enumerated()), id: \.offset) { i, paso in
                            HStack(alignment: .top, spacing: Espacio.xs) {
                                Text("\(i + 1).").font(Tipo.pie.monospacedDigit()).foregroundStyle(paleta.textoSecundario)
                                Text(paso).font(Tipo.pie).foregroundStyle(paleta.texto)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if let url = URL(string: "https://aistudio.google.com/apikey") {
                            Link("Abrir Google AI Studio", destination: url)
                                .font(Tipo.cuerpoFuerte)
                        }
                    }
                    .padding(.top, Espacio.xs)
                }
                .font(Tipo.cuerpo)
                .foregroundStyle(paleta.texto)
                .tint(paleta.acento)

                Toggle(isOn: $a.datos.avisoIAAceptado) {
                    Text("Aviso de privacidad aceptado").font(Tipo.cuerpo).foregroundStyle(paleta.texto)
                }
                .tint(paleta.acento)
            }
            .tarjeta()
        }
    }

    @ViewBuilder
    private var botonesClave: some View {
        Button("Guardar clave") {
            if Llavero.guardarClave(nuevaClave) {
                nuevaClave = ""
                claveOculta = Llavero.claveOculta()
                mensaje = "Clave guardada."
            } else {
                mensaje = "No se pudo guardar en el Llavero."
            }
        }
        .buttonStyle(.secundario)
        .disabled(nuevaClave.trimmingCharacters(in: .whitespaces).isEmpty)
        if claveOculta != nil {
            Button("Borrar clave", role: .destructive) {
                Llavero.borrarClave()
                claveOculta = nil
                mensaje = "Clave borrada de este iPhone."
            }
            .buttonStyle(EstiloBotonTexto(color: paleta.peligro))
        }
    }

    private let pasosClave = [
        "Entra a aistudio.google.com con tu cuenta de Google (debes tener 18 años o más).",
        "Acepta los términos si te los pide.",
        "Abre «Get API key» y pulsa «Create API key».",
        "Copia la clave y pégala arriba. No configures facturación: así te quedas en el plan gratuito.",
        "Tus límites reales (peticiones por minuto y por día) se ven en AI Studio, en la sección de uso y límites. El límite diario se reinicia a medianoche hora del Pacífico."
    ]
}

// MARK: - Respaldo

private struct SeccionRespaldo: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var exportando = false
    @State private var importando = false
    @State private var documento: DocumentoRespaldo?
    @State private var pendiente: DatosApp?
    @State private var mensaje: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.xs) {
            TituloSeccion("Respaldo")
            VStack(alignment: .leading, spacing: Espacio.s) {
                Text("Guarda una copia de tus registros y ajustes en Archivos (por ejemplo, antes de reinstalar). La clave de la IA no se incluye.")
                    .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Espacio.s) { botones }
                    VStack(spacing: Espacio.s) { botones }
                }
                if let mensaje {
                    Text(mensaje).font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                }
            }
            .tarjeta()
        }
        .fileExporter(isPresented: $exportando, document: documento, contentType: .json, defaultFilename: almacen.nombreRespaldo) { resultado in
            switch resultado {
            case .success: mensaje = "Respaldo guardado."
            case .failure(let e): mensaje = "No se pudo guardar: \(e.localizedDescription)"
            }
        }
        .fileImporter(isPresented: $importando, allowedContentTypes: [.json]) { resultado in
            switch resultado {
            case .success(let url):
                let acceso = url.startAccessingSecurityScopedResource()
                defer { if acceso { url.stopAccessingSecurityScopedResource() } }
                if let datos = try? Data(contentsOf: url), let leidos = almacen.leerRespaldo(datos) {
                    pendiente = leidos
                } else {
                    mensaje = "Ese archivo no es un respaldo válido de Sazón."
                }
            case .failure(let e):
                mensaje = "No se pudo abrir: \(e.localizedDescription)"
            }
        }
        .confirmationDialog("¿Reemplazar tus datos actuales por los del respaldo?",
                            isPresented: Binding(get: { pendiente != nil }, set: { if !$0 { pendiente = nil } }),
                            titleVisibility: .visible) {
            Button("Reemplazar", role: .destructive) {
                if let p = pendiente {
                    almacen.restaurar(p)
                    mensaje = "Respaldo restaurado: \(p.registros.count) registros."
                }
                pendiente = nil
            }
        }
    }

    @ViewBuilder
    private var botones: some View {
        Button("Exportar") {
            documento = almacen.exportarRespaldo()
            exportando = documento != nil
        }
        .buttonStyle(.secundario)
        Button("Importar") { importando = true }
            .buttonStyle(.secundario)
    }
}
