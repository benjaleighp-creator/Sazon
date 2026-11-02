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
    /// Recibe los registros listos para guardar.
    let alGuardar: ([Registro]) -> Void

    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @Environment(\.dismiss) private var cerrar
    @State private var comida: TipoComida = .almuerzo
    @State private var ruta: [DestinoRegistro] = []
    @State private var pedirAviso: DestinoRegistro?

    var body: some View {
        NavigationStack(path: $ruta) {
            ScrollView {
                VStack(alignment: .leading, spacing: Espacio.l) {
                    SelectorComida(comida: $comida)
                    VStack(alignment: .leading, spacing: Espacio.s) {
                        TituloSeccion("Con inteligencia artificial")
                        opcion("camera", "Foto del plato", "La IA identifica alimentos y porciones; tú revisas antes de guardar.") { abrirIA(.foto) }
                        opcion("text.bubble", "Escribir o dictar", "Por ejemplo «2 panes con palta y un café». Para dictar, toca el micrófono del teclado.") { abrirIA(.texto) }
                    }
                    VStack(alignment: .leading, spacing: Espacio.s) {
                        TituloSeccion("Sin inteligencia artificial")
                        opcion("barcode.viewfinder", "Escanear código de barras", "Productos envasados con datos de Open Food Facts.") { ruta.append(.escanear) }
                        opcion("magnifyingglass", "Buscar en la tabla", "Tabla del INS dentro de la app. Funciona sin internet.") { ruta.append(.buscar) }
                        opcion("square.and.pencil", "Agregar a mano", "Escribe el nombre y los valores del envase.") { ruta.append(.manual) }
                    }
                    if !almacen.datos.recientes.isEmpty {
                        VStack(alignment: .leading, spacing: Espacio.xs) {
                            TituloSeccion("Recientes")
                            VStack(spacing: 0) {
                                ForEach(almacen.datos.recientes.prefix(8)) { r in
                                    Button {
                                        ruta.append(.porcion(Candidato(registro: r)))
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: Espacio.xxxs) {
                                                Text(r.nombre).font(Tipo.cuerpo).foregroundStyle(paleta.texto)
                                                    .multilineTextAlignment(.leading)
                                                Text(Porciones.texto(gramos: r.gramos, unidad: almacen.datos.unidad, medida: r.medida, cantidadMedida: r.cantidadMedida))
                                                    .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                                            }
                                            Spacer()
                                            Text(Formato.kcal(r.total.kcal, estimado: r.origen.esEstimado))
                                                .font(Tipo.pie.monospacedDigit()).foregroundStyle(paleta.textoSecundario)
                                            Image(systemName: "chevron.right").font(Tipo.iconoChico).foregroundStyle(paleta.textoSecundario)
                                        }
                                        .padding(.vertical, Espacio.s)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityElement(children: .combine)
                                    if r.id != almacen.datos.recientes.prefix(8).last?.id {
                                        Divider().overlay(paleta.borde)
                                    }
                                }
                            }
                            .tarjeta(relleno: Espacio.m)
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
        .onAppear { comida = comidaInicial }
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

    private func opcion(_ simbolo: String, _ titulo: String, _ texto: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(alignment: .center, spacing: Espacio.s) {
                IconoCirculo(simbolo: simbolo, tamano: 40)
                VStack(alignment: .leading, spacing: Espacio.xxxs) {
                    Text(titulo).font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                    Text(texto).font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(Tipo.iconoChico).foregroundStyle(paleta.textoSecundario)
            }
            .tarjeta(relleno: Espacio.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
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
