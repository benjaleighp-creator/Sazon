import SwiftUI

/// Un alimento listo para elegir la porción (venga del INS, de Open Food
/// Facts, de un registro anterior o escrito a mano).
struct Candidato: Hashable {
    var nombre: String
    var por100g: Nutrientes
    var origen: OrigenDato
    var codigoINS: String? = nil
    var codigoBarras: String? = nil
    var marca: String? = nil
    var medidas: [MedidaCasera] = []
    var gramos: Double = 100
    var medida: MedidaCasera? = nil
    var cantidadMedida: Double? = nil
    /// Open Food Facts sin algún macro: se avisa.
    var datosIncompletos: Bool = false

    init(alimento: AlimentoBase) {
        nombre = alimento.nombre
        por100g = alimento.por100g
        origen = .ins
        codigoINS = alimento.codigo
        medidas = alimento.medidas
    }

    init(producto: ProductoEnvasado) {
        nombre = producto.nombre
        por100g = producto.por100g
        origen = .openFoodFacts
        codigoBarras = producto.codigo
        marca = producto.marca
        medidas = producto.porcion.map { [$0] } ?? []
        if let porcion = producto.porcion {
            gramos = porcion.gramos
            medida = porcion
            cantidadMedida = 1
        }
        datosIncompletos = producto.datosIncompletos
    }

    init(registro: Registro) {
        nombre = registro.nombre
        por100g = registro.por100g
        origen = registro.origen
        codigoINS = registro.codigoINS
        codigoBarras = registro.codigoBarras
        medidas = registro.medida.map { [$0] } ?? []
        gramos = registro.gramos
        medida = registro.medida
        cantidadMedida = registro.cantidadMedida
    }

    init(manual nombre: String) {
        self.nombre = nombre
        por100g = .cero
        origen = .manual
    }
}

/// Pantallas del flujo de registro.
enum DestinoRegistro: Hashable {
    case foto
    case texto
    case escanear
    case buscar
    case manual
    case porcion(Candidato)
}

/// Hoja para registrar comida: elige cómo (foto, texto o voz, código de
/// barras, tabla o a mano) y en qué comida.
struct AgregarView: View {
    let comidaInicial: TipoComida
    /// Si viene, se abre directo ese método (desde el botón flotante).
    var destinoInicial: DestinoRegistro? = nil
    /// Recibe los registros listos para guardar.
    let alGuardar: ([Registro]) -> Void

    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @Environment(\.dismiss) private var cerrar
    @State private var comida: TipoComida = .almuerzo
    @State private var ruta: [DestinoRegistro] = []
    @State private var pedirAviso: DestinoRegistro?
    @State private var listo = false

    private let columnas = [GridItem(.flexible(), spacing: Espacio.s), GridItem(.flexible(), spacing: Espacio.s)]

    var body: some View {
        NavigationStack(path: $ruta) {
            ScrollView {
                VStack(alignment: .leading, spacing: Espacio.l) {
                    SelectorComidaGrande(comida: $comida)

                    // Destacado: foto con IA.
                    Button { abrirIA(.foto) } label: {
                        HStack(spacing: Espacio.m) {
                            VStack(alignment: .leading, spacing: Espacio.xs) {
                                Label("Con IA", systemImage: "sparkles")
                                    .font(Tipo.micro)
                                    .foregroundStyle(paleta.heroFin)
                                    .padding(.horizontal, Espacio.xs)
                                    .padding(.vertical, Espacio.xxs)
                                    .background(Capsule().fill(paleta.textoHero))
                                Text("Foto del plato")
                                    .font(Tipo.titulo3)
                                    .foregroundStyle(paleta.textoHero)
                                Text("Toma una foto y la IA identifica alimentos y porciones. Tú revisas antes de guardar.")
                                    .font(Tipo.nota)
                                    .foregroundStyle(paleta.textoHeroSecundario)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "camera.fill")
                                .font(Tipo.iconoGrande)
                                .foregroundStyle(paleta.textoHero)
                                .frame(width: 64, height: 64)
                                .background(Circle().fill(paleta.textoHero.opacity(0.16)))
                                .accessibilityHidden(true)
                        }
                        .hero(relleno: Espacio.m)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)

                    LazyVGrid(columns: columnas, spacing: Espacio.s) {
                        azulejo("text.bubble", "Escribir o dictar", "Con IA", ia: true) { abrirIA(.texto) }
                        azulejo("barcode.viewfinder", "Escanear código", "Open Food Facts", ia: false) { ruta.append(.escanear) }
                        azulejo("magnifyingglass", "Buscar en la tabla", "INS · sin internet", ia: false) { ruta.append(.buscar) }
                        azulejo("square.and.pencil", "Agregar a mano", "Datos del envase", ia: false) { ruta.append(.manual) }
                    }

                    if !almacen.datos.recientes.isEmpty {
                        VStack(alignment: .leading, spacing: Espacio.s) {
                            TituloSeccion("Recientes")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Espacio.s) {
                                    ForEach(almacen.datos.recientes.prefix(10)) { r in
                                        TarjetaReciente(registro: r, unidad: almacen.datos.unidad) {
                                            ruta.append(.porcion(Candidato(registro: r)))
                                        }
                                    }
                                }
                                .padding(.vertical, Espacio.xxs)
                            }
                        }
                    }
                }
                .padding(.horizontal, Espacio.margen)
                .padding(.vertical, Espacio.m)
            }
            .fondoDePantalla()
            .navigationTitle("Registrar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { cerrar() }
                }
            }
            .navigationDestination(for: DestinoRegistro.self) { destino in
                switch destino {
                case .foto:
                    RegistroFotoView(comida: $comida, alGuardar: guardar)
                case .texto:
                    RegistroTextoView(comida: $comida, alGuardar: guardar)
                case .escanear:
                    EscanerView { producto in ruta.append(.porcion(Candidato(producto: producto))) }
                case .buscar:
                    BuscarView { alimento in ruta.append(.porcion(Candidato(alimento: alimento))) }
                case .manual:
                    PorcionView(candidato: Candidato(manual: ""), comida: $comida, editableValores: true, alGuardar: guardarUno)
                case .porcion(let candidato):
                    PorcionView(candidato: candidato, comida: $comida,
                                editableValores: candidato.origen == .manual || candidato.origen == .estimadoIA,
                                alGuardar: guardarUno)
                }
            }
            .sheet(item: $pedirAviso) { destino in
                AvisoPrivacidadView {
                    almacen.datos.avisoIAAceptado = true
                    pedirAviso = nil
                    ruta.append(destino)
                }
                .entornoSazon(almacen)
            }
        }
        .onAppear {
            guard !listo else { return }
            listo = true
            comida = comidaInicial
            if let destinoInicial {
                switch destinoInicial {
                case .foto, .texto: abrirIA(destinoInicial)
                default: ruta.append(destinoInicial)
                }
            }
        }
    }

    private func abrirIA(_ destino: DestinoRegistro) {
        if almacen.datos.avisoIAAceptado {
            ruta.append(destino)
        } else {
            pedirAviso = destino
        }
    }

    private func guardar(_ registros: [Registro]) {
        alGuardar(registros)
    }

    private func guardarUno(_ registro: Registro) {
        alGuardar([registro])
    }

    private func azulejo(_ simbolo: String, _ titulo: String, _ detalle: String, ia: Bool, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            VStack(alignment: .leading, spacing: Espacio.s) {
                HStack(alignment: .top) {
                    AzulejoIcono(simbolo: simbolo, tamano: 44)
                    Spacer(minLength: 0)
                    if ia {
                        Image(systemName: "sparkles")
                            .font(Tipo.iconoChico)
                            .foregroundStyle(paleta.acento)
                            .accessibilityHidden(true)
                    }
                }
                VStack(alignment: .leading, spacing: Espacio.xxxs) {
                    Text(titulo)
                        .font(Tipo.cuerpoFuerte)
                        .foregroundStyle(paleta.texto)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detalle)
                        .font(Tipo.pie)
                        .foregroundStyle(paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
            .tarjeta(relleno: Espacio.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

/// Tarjeta pequeña de un alimento reciente (carrusel horizontal).
private struct TarjetaReciente: View {
    let registro: Registro
    let unidad: UnidadPorcion
    let accion: () -> Void
    @Environment(\.paleta) private var paleta
    @ScaledMetric(relativeTo: .body) private var ancho: CGFloat = 150

    var body: some View {
        Button(action: accion) {
            VStack(alignment: .leading, spacing: Espacio.xs) {
                Text(registro.nombre)
                    .font(Tipo.nota.weight(.semibold))
                    .foregroundStyle(paleta.texto)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                Text(Formato.kcal(registro.total.kcal, estimado: registro.origen.esEstimado))
                    .font(Tipo.cuerpoFuerte.monospacedDigit())
                    .foregroundStyle(paleta.acento)
                Text(Porciones.texto(gramos: registro.gramos, unidad: unidad))
                    .font(Tipo.micro)
                    .foregroundStyle(paleta.textoSecundario)
            }
            .frame(width: min(ancho, 230), height: 120, alignment: .topLeading)
            .tarjeta(relleno: Espacio.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Toca para elegir la porción y agregarlo")
    }
}

/// Selector de comida con íconos grandes (en la hoja de registro).
struct SelectorComidaGrande: View {
    @Binding var comida: TipoComida
    @Environment(\.paleta) private var paleta

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.xs) {
            TituloSeccion("¿En qué comida?")
            HStack(spacing: Espacio.xs) {
                ForEach(TipoComida.allCases) { c in
                    let elegido = comida == c
                    Button { animar(.seleccion) { comida = c } } label: {
                        VStack(spacing: Espacio.xxs) {
                            Image(systemName: c.simbolo)
                                .font(Tipo.iconoFila)
                            Text(c.nombre)
                                .font(Tipo.micro)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(elegido ? paleta.textoSobreAcento : paleta.texto)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(
                            RoundedRectangle(cornerRadius: Radio.medio, style: .continuous)
                                .fill(elegido ? paleta.acento : paleta.superficie)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radio.medio, style: .continuous)
                                .strokeBorder(elegido ? Color.clear : paleta.borde, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(elegido ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: comida)
        }
    }
}

extension DestinoRegistro: Identifiable {
    var id: String {
        switch self {
        case .foto: return "foto"
        case .texto: return "texto"
        case .escanear: return "escanear"
        case .buscar: return "buscar"
        case .manual: return "manual"
        case .porcion(let c): return "porcion-\(c.nombre)-\(c.codigoINS ?? "")-\(c.codigoBarras ?? "")"
        }
    }
}

/// Chips para elegir la comida.
struct SelectorComida: View {
    @Binding var comida: TipoComida

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.xs) {
            TituloSeccion("Comida")
            FilaFlexible(espacio: Espacio.xs) {
                ForEach(TipoComida.allCases) { c in
                    Chip(texto: c.nombre, icono: c.simbolo, seleccionado: comida == c) { comida = c }
                }
            }
        }
    }
}
