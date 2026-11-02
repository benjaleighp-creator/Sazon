import SwiftUI
import UniformTypeIdentifiers

/// Ajustes: meta, IA, preferencias, respaldo y fuentes.
struct AjustesView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var hayClave = Llavero.hayClave

    var body: some View {
        @Bindable var a = almacen
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Espacio.l) {
                    Text("Ajustes")
                        .font(Tipo.titulo1)
                        .foregroundStyle(paleta.texto)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, Espacio.s)

                    heroMeta

                    GrupoAjustes(titulo: "Perfil") {
                        HStack(spacing: Espacio.s) {
                            AzulejoIcono(simbolo: "person", tamano: 34)
                            TextField("Tu nombre (para el saludo)", text: $a.datos.nombre)
                                .font(Tipo.cuerpo)
                                .foregroundStyle(paleta.texto)
                                .textContentType(.givenName)
                        }
                        .padding(.vertical, Espacio.xs)
                        Divider().overlay(paleta.borde)
                        FilaAjuste(simbolo: "target", titulo: "Meta diaria", valor: textoMeta) { MetaView() }
                    }

                    GrupoAjustes(titulo: "Inteligencia artificial") {
                        FilaAjuste(simbolo: "sparkles", titulo: "Google Gemini",
                                   valor: hayClave ? "Clave guardada · \(almacen.datos.modeloIA)" : "Falta tu clave de API",
                                   color: hayClave ? paleta.exito : paleta.aviso) {
                            PantallaIA()
                        }
                    }

                    GrupoAjustes(titulo: "Porciones") {
                        Picker("Unidad", selection: $a.datos.unidad) {
                            ForEach(UnidadPorcion.allCases) { Text($0.nombre).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Text("Todo se guarda en gramos; esto solo cambia cómo lo ves y escribes. Al registrar también puedes usar medidas caseras.")
                            .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: Espacio.xs) {
                        TituloSeccion("Apariencia")
                        HStack(spacing: Espacio.s) {
                            ForEach(CatalogoTemas.todos) { tema in
                                TarjetaTema(tema: tema, elegido: almacen.datos.temaID == tema.id) {
                                    animar(.pantalla) { almacen.datos.temaID = tema.id }
                                }
                            }
                        }
                        .sensoryFeedback(.selection, trigger: almacen.datos.temaID)
                        Picker("Modo", selection: $a.datos.apariencia) {
                            ForEach(Apariencia.allCases) { Text($0.nombre).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.top, Espacio.xs)
                    }

                    GrupoAjustes(titulo: "Batería") {
                        Toggle(isOn: $a.datos.ahorroBateria) {
                            HStack(spacing: Espacio.s) {
                                AzulejoIcono(simbolo: "battery.75percent", tamano: 34)
                                VStack(alignment: .leading, spacing: Espacio.xxxs) {
                                    Text("Ahorro de batería").font(Tipo.cuerpo).foregroundStyle(paleta.texto)
                                    Text("Quita las animaciones. Se activa solo con el modo de bajo consumo.")
                                        .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .tint(paleta.acento)
                    }

                    GrupoAjustes(titulo: "Datos") {
                        FilaAjuste(simbolo: "externaldrive", titulo: "Respaldo",
                                   valor: "\(almacen.datos.registros.count) registros guardados en este iPhone") {
                            PantallaRespaldo()
                        }
                        Divider().overlay(paleta.borde)
                        FilaAjuste(simbolo: "info.circle", titulo: "Acerca de y fuentes", valor: versionApp) {
                            PantallaAcercaDe(version: versionApp)
                        }
                    }

                    if let error = almacen.errorGuardado {
                        Aviso(icono: "externaldrive.badge.exclamationmark", titulo: "Error al guardar", texto: error, color: paleta.peligro)
                    }
                }
                .padding(.horizontal, Espacio.margen)
                .padding(.bottom, Espacio.xxl)
            }
            .fondoDePantalla()
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { hayClave = Llavero.hayClave }
        }
    }

    private var textoMeta: String {
        guard let meta = almacen.meta else { return "Sin configurar" }
        return "\(Formato.entero(meta.kcal)) kcal · " + (almacen.datos.metaManual != nil ? "escrita a mano" : (almacen.datos.perfil?.objetivo.nombre.lowercased() ?? ""))
    }

    @ViewBuilder
    private var heroMeta: some View {
        NavigationLink {
            MetaView()
        } label: {
            VStack(alignment: .leading, spacing: Espacio.s) {
                HStack {
                    Label(almacen.datos.perfil?.objetivo.nombre ?? "Tu meta diaria", systemImage: "target")
                        .font(Tipo.pie)
                        .foregroundStyle(paleta.textoHeroSecundario)
                    Spacer()
                    Image(systemName: "chevron.right").font(Tipo.iconoChico).foregroundStyle(paleta.textoHeroSecundario)
                }
                if let meta = almacen.meta {
                    HStack(alignment: .firstTextBaseline, spacing: Espacio.xs) {
                        Text(Formato.entero(meta.kcal))
                            .font(Tipo.cifraGrande)
                            .foregroundStyle(paleta.textoHero)
                        Text("kcal al día").font(Tipo.nota).foregroundStyle(paleta.textoHeroSecundario)
                    }
                    FilaFlexible(espacio: Espacio.xs) {
                        capsula("Proteína", meta.proteina)
                        capsula("Carbohidratos", meta.carbohidratos)
                        capsula("Grasas", meta.grasas)
                    }
                } else {
                    Text("Configura tu meta")
                        .font(Tipo.titulo3)
                        .foregroundStyle(paleta.textoHero)
                    Text("Calcula tus calorías y macros según tu objetivo.")
                        .font(Tipo.nota)
                        .foregroundStyle(paleta.textoHeroSecundario)
                }
            }
            .hero(relleno: Espacio.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func capsula(_ nombre: String, _ gramos: Double) -> some View {
        Text("\(nombre) \(Formato.entero(gramos)) g")
            .font(Tipo.pie.monospacedDigit())
            .foregroundStyle(paleta.textoHero)
            .padding(.horizontal, Espacio.s)
            .padding(.vertical, Espacio.xxs)
            .background(Capsule().fill(paleta.textoHero.opacity(0.14)))
    }

    /// Versión y número de compilación (el número coincide con el de GitHub Actions).
    private var versionApp: String {
        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
        let compilacion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1"
        return "Versión \(version) (compilación \(compilacion))"
    }
}

/// Vista previa de un tema para elegirlo.
private struct TarjetaTema: View {
    let tema: Tema
    let elegido: Bool
    let accion: () -> Void
    @Environment(\.paleta) private var paleta
    @Environment(\.colorScheme) private var esquema

    var body: some View {
        let p = tema.paleta(esquema)
        Button(action: accion) {
            VStack(alignment: .leading, spacing: Espacio.s) {
                // Mini encabezado del tema
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: Radio.medio, style: .continuous)
                        .fill(p.degradadoHero)
                        .frame(height: 64)
                    HStack(spacing: 4) {
                        ForEach([p.calorias, p.proteina, p.carbohidratos, p.grasas], id: \.self) { c in
                            Circle().fill(c).frame(width: 12, height: 12)
                                .overlay(Circle().strokeBorder(p.textoHero.opacity(0.6), lineWidth: 1))
                        }
                    }
                    .padding(Espacio.xs)
                }
                .accessibilityHidden(true)
                HStack {
                    VStack(alignment: .leading, spacing: Espacio.xxxs) {
                        Text(tema.nombre).font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                        Text(tema.concepto).font(Tipo.micro).foregroundStyle(paleta.textoSecundario)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: elegido ? "checkmark.circle.fill" : "circle")
                        .font(Tipo.iconoFila)
                        .foregroundStyle(elegido ? paleta.acento : paleta.textoSecundario)
                        .accessibilityHidden(true)
                }
            }
            .padding(Espacio.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radio.tarjeta, style: .continuous).fill(paleta.superficie))
            .overlay(
                RoundedRectangle(cornerRadius: Radio.tarjeta, style: .continuous)
                    .strokeBorder(elegido ? paleta.acento : paleta.borde, lineWidth: elegido ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tema \(tema.nombre)")
        .accessibilityAddTraits(elegido ? .isSelected : [])
    }
}

// MARK: - Pantallas de detalle

private struct PantallaIA: View {
    var body: some View {
        ScrollView {
            SeccionIA()
                .padding(.horizontal, Espacio.margen)
                .padding(.vertical, Espacio.m)
        }
        .fondoDePantalla()
        .navigationTitle("Inteligencia artificial")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PantallaRespaldo: View {
    var body: some View {
        ScrollView {
            SeccionRespaldo()
                .padding(.horizontal, Espacio.margen)
                .padding(.vertical, Espacio.m)
        }
        .fondoDePantalla()
        .navigationTitle("Respaldo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PantallaAcercaDe: View {
    let version: String
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.l) {
                VStack(spacing: Espacio.s) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .accessibilityHidden(true)
                    Text("Sazón").font(Tipo.titulo2).foregroundStyle(paleta.texto)
                    Text(version).font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: Espacio.m) {
                    fuente("book.closed", "Tabla de alimentos",
                           almacen.tabla.fuente.isEmpty ? (almacen.tabla.error ?? "") : almacen.tabla.fuente + " Se autoriza su reproducción citando la fuente.")
                    fuente("barcode", "Productos envasados", "Open Food Facts (openfoodfacts.org), base de datos colaborativa con licencia Open Database License (ODbL).")
                    fuente("sparkles", "Inteligencia artificial", "Google Gemini con tu clave del plan gratuito. Sus cifras son estimaciones (≈).")
                    fuente("heart.text.square", "Importante", "Las calorías y los macros son estimaciones generales y editables, no consejo médico.")
                }
                .tarjeta()
            }
            .padding(.horizontal, Espacio.margen)
            .padding(.vertical, Espacio.m)
        }
        .fondoDePantalla()
        .navigationTitle("Acerca de")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fuente(_ simbolo: String, _ titulo: String, _ texto: String) -> some View {
        HStack(alignment: .top, spacing: Espacio.s) {
            AzulejoIcono(simbolo: simbolo, tamano: 34)
            VStack(alignment: .leading, spacing: Espacio.xxxs) {
                Text(titulo).font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                Text(texto).font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
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
