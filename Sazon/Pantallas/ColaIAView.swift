import SwiftUI

/// Aviso en el Diario: hay fotos o textos guardados sin conexión.
struct AvisoColaIA: View {
    let cola: [PendienteIA]
    let alAbrir: () -> Void
    @Environment(\.paleta) private var paleta

    var body: some View {
        let listos = cola.filter { $0.estado == .listo }.count
        let esperando = cola.filter { $0.estado == .esperando }.count
        Button(action: alAbrir) {
            HStack(spacing: Espacio.s) {
                Image(systemName: listos > 0 ? "checkmark.circle" : "tray.full")
                    .font(Tipo.iconoFila)
                    .foregroundStyle(listos > 0 ? paleta.exito : paleta.aviso)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Espacio.xxxs) {
                    Text(listos > 0 ? "\(listos) listo\(listos == 1 ? "" : "s") para revisar" : "\(esperando) esperando internet")
                        .font(Tipo.cuerpoFuerte)
                        .foregroundStyle(paleta.texto)
                    Text("Fotos y textos que guardaste sin conexión")
                        .font(Tipo.pie)
                        .foregroundStyle(paleta.textoSecundario)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(paleta.textoSecundario)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tarjeta()
    }
}

/// Lista de lo guardado sin conexión: esperando, listo para revisar o con error.
struct ColaIAView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @Environment(\.dismiss) private var cerrar
    @State private var revisando: PendienteIA?
    @State private var comida: TipoComida = .almuerzo

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(almacen.datos.colaIA) { p in
                        fila(p)
                            .listRowBackground(paleta.superficie)
                    }
                } footer: {
                    Text("Se analizan solos cuando hay internet y la app está abierta (máximo 3 intentos y 30 s cada uno). Nada pasa al diario hasta que lo revises.")
                }
            }
            .listStyle(.insetGrouped)
            .fondoDePantalla()
            .navigationTitle("Guardados sin conexión")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { cerrar() } }
                ToolbarItem(placement: .primaryAction) {
                    if ColaIA.compartida.procesando {
                        ProgressView()
                    } else {
                        Button("Analizar ahora") { ColaIA.compartida.procesar(almacen) }
                            .disabled(!almacen.datos.colaIA.contains { $0.estado == .esperando })
                    }
                }
            }
            .navigationDestination(item: $revisando) { p in
                if let analisis = p.respuesta.flatMap({ try? LectorIA.analisis(desde: $0) }) {
                    RevisionIAView(identificados: analisis.alimentos, posiblesOcultos: analisis.posiblesOcultos,
                                   comida: $comida, capa: p.capa.flatMap(CapaIA.init(clave:))) { nuevos in
                        almacen.agregar(nuevos.map { r in
                            var r = r
                            r.fecha = p.creado
                            return r
                        })
                        ColaIA.compartida.quitar(p, de: almacen)
                        revisando = nil
                    }
                } else {
                    EstadoVacio(icono: "exclamationmark.triangle", titulo: "No se pudo abrir", texto: "Bórralo y vuelve a registrarlo.")
                }
            }
        }
    }

    private func fila(_ p: PendienteIA) -> some View {
        HStack(alignment: .top, spacing: Espacio.s) {
            AzulejoIcono(simbolo: p.tipo == .foto ? "camera" : "text.bubble", tamano: 34)
            VStack(alignment: .leading, spacing: Espacio.xxs) {
                Text(p.tipo == .foto ? "Foto · \(p.comida.nombre)" : "«\(p.texto)» · \(p.comida.nombre)")
                    .font(Tipo.cuerpo).foregroundStyle(paleta.texto)
                    .lineLimit(2)
                Text(Formato.diaRelativo(p.creado) + ", " + Formato.hora(p.creado))
                    .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                switch p.estado {
                case .esperando:
                    Label("Esperando internet", systemImage: "wifi.slash")
                        .font(Tipo.pie).foregroundStyle(paleta.aviso)
                case .listo:
                    Button("Revisar y guardar") {
                        comida = p.comida
                        revisando = p
                    }
                    .buttonStyle(.secundario)
                case .fallo:
                    Text(p.error ?? "La IA no pudo analizarlo.")
                        .font(Tipo.pie).foregroundStyle(paleta.peligro)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Reintentar") { ColaIA.compartida.reintentar(p, en: almacen) }
                        .buttonStyle(.secundario)
                }
            }
        }
        .padding(.vertical, Espacio.xxs)
        .swipeActions {
            Button("Borrar", role: .destructive) { ColaIA.compartida.quitar(p, de: almacen) }
        }
        .accessibilityElement(children: .contain)
    }
}
