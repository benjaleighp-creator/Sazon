import SwiftUI

/// Elegir la porción de un alimento y guardarlo. Si `editableValores` es
/// true (a mano o estimado), también se pueden escribir nombre y valores.
struct PorcionView: View {
    let candidato: Candidato
    @Binding var comida: TipoComida
    var editableValores: Bool = false
    let alGuardar: (Registro) -> Void

    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta

    @State private var nombre = ""
    @State private var cantidad: Double = 100
    /// nil = gramos u onzas (según Ajustes); si no, la medida casera elegida.
    @State private var medida: MedidaCasera?
    @State private var valores = Nutrientes.cero
    @State private var valoresPorPorcion = false
    @State private var listo = false

    var body: some View {
        let unidad = almacen.datos.unidad
        let gramos = gramosActuales(unidad)
        let por100 = por100gActual(gramos: gramos)
        let total = por100 * (gramos / 100)
        let estimado = candidato.origen.esEstimado

        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.l) {
                // Encabezado
                VStack(alignment: .leading, spacing: Espacio.xs) {
                    if editableValores {
                        TituloSeccion("Nombre")
                        CampoTexto(titulo: "Por ejemplo: Galletas de avena", texto: $nombre)
                    } else {
                        Text(candidato.nombre)
                            .font(Tipo.titulo3)
                            .foregroundStyle(paleta.texto)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: Espacio.xs) {
                        InsigniaOrigen(origen: candidato.origen)
                        if let marca = candidato.marca { Insignia(texto: marca) }
                    }
                    if candidato.origen == .envase {
                        Text("Valores leídos por la IA de la etiqueta: compáralos con el envase antes de guardar.")
                            .font(Tipo.pie)
                            .foregroundStyle(paleta.aviso)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let codigo = candidato.codigoBarras {
                        Label("Código \(codigo) · se recordará para la próxima vez", systemImage: "barcode")
                            .font(Tipo.pie)
                            .foregroundStyle(paleta.textoSecundario)
                    }
                    if candidato.datosIncompletos {
                        Text("Open Food Facts no trae todos los macronutrientes de este producto; los que faltan quedaron en 0. Puedes corregirlos después de guardar.")
                            .font(Tipo.pie)
                            .foregroundStyle(paleta.aviso)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Porción
                VStack(alignment: .leading, spacing: Espacio.s) {
                    TituloSeccion("Porción")
                    CampoNumero(titulo: "Cantidad", valor: $cantidad, unidad: medida?.nombre ?? unidad.abreviatura)
                    FilaFlexible(espacio: Espacio.xs) {
                        Chip(texto: unidad == .gramos ? "Gramos" : "Onzas", seleccionado: medida == nil) {
                            cambiarMedida(nil, unidad: unidad)
                        }
                        ForEach(medidasDisponibles) { m in
                            Chip(texto: (m.estimada ? "≈ " : "") + "\(m.nombre) (\(Formato.numero(m.gramos)) g)",
                                 seleccionado: medida == m) {
                                cambiarMedida(m, unidad: unidad)
                            }
                        }
                    }
                    if medida != nil || unidad == .onzas {
                        Text("Equivale a \(Formato.numero(gramos, decimales: 0)) g")
                            .font(Tipo.pie)
                            .foregroundStyle(paleta.textoSecundario)
                    }
                    if !Porciones.esValido(gramos) {
                        Text("La porción debe ser mayor que 0 y de hasta 5 kg.")
                            .font(Tipo.pie)
                            .foregroundStyle(paleta.peligro)
                    }
                }

                // Valores
                if editableValores {
                    VStack(alignment: .leading, spacing: Espacio.s) {
                        TituloSeccion("Valores nutricionales")
                        Picker("Los valores son", selection: $valoresPorPorcion) {
                            Text("Por 100 g").tag(false)
                            Text("Por esta porción").tag(true)
                        }
                        .pickerStyle(.segmented)
                        CampoNumero(titulo: "Calorías", valor: $valores.kcal, unidad: "kcal", decimales: 0)
                        CampoNumero(titulo: "Proteína", valor: $valores.proteina, unidad: "g")
                        CampoNumero(titulo: "Carbohidratos", valor: $valores.carbohidratos, unidad: "g")
                        CampoNumero(titulo: "Grasas", valor: $valores.grasas, unidad: "g")
                    }
                }

                // Total
                VStack(alignment: .leading, spacing: Espacio.s) {
                    TituloSeccion("Total de esta porción")
                    FilaDatos {
                        datoMacro(.calorias, total.kcal, estimado)
                        datoMacro(.proteina, total.proteina, estimado)
                        datoMacro(.carbohidratos, total.carbohidratos, estimado)
                        datoMacro(.grasas, total.grasas, estimado)
                    }
                    Text("Por 100 g: \(Formato.entero(por100.kcal)) kcal · P \(Formato.numero(por100.proteina)) · C \(Formato.numero(por100.carbohidratos)) · G \(Formato.numero(por100.grasas))")
                        .font(Tipo.pie)
                        .foregroundStyle(paleta.textoSecundario)
                }
                .tarjeta()

                SelectorComida(comida: $comida)
            }
            .padding(.horizontal, Espacio.margen)
            .padding(.vertical, Espacio.m)
        }
        .fondoDePantalla()
        .navigationTitle(editableValores && candidato.origen == .manual ? "Agregar a mano" : "Porción")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button("Guardar en \(comida.nombre.lowercased())") {
                guardar(gramos: gramos, por100: por100)
            }
            .buttonStyle(.principal)
            .disabled(!puedeGuardar(gramos: gramos))
            .padding(.horizontal, Espacio.margen)
            .padding(.bottom, Espacio.xs)
        }
        .onAppear(perform: preparar)
    }

    // MARK: - Lógica de la pantalla

    private var medidasDisponibles: [MedidaCasera] {
        Porciones.medidasDisponibles(base: candidato.medidas, adicional: candidato.medida)
    }

    private func preparar() {
        guard !listo else { return }
        listo = true
        nombre = candidato.nombre
        valores = candidato.por100g
        if let m = candidato.medida, let c = candidato.cantidadMedida, c > 0 {
            medida = m
            cantidad = c
        } else {
            medida = nil
            cantidad = (Porciones.desdeGramos(candidato.gramos, a: almacen.datos.unidad) * 10).rounded() / 10
        }
    }

    private func gramosActuales(_ unidad: UnidadPorcion) -> Double {
        if let medida { return Porciones.gramos(cantidad: cantidad, de: medida) }
        return Porciones.aGramos(cantidad, desde: unidad)
    }

    private func por100gActual(gramos: Double) -> Nutrientes {
        guard editableValores else { return candidato.por100g }
        if valoresPorPorcion {
            guard gramos > 0 else { return .cero }
            return valores * (100 / gramos)
        }
        return valores
    }

    private func cambiarMedida(_ nueva: MedidaCasera?, unidad: UnidadPorcion) {
        let gramos = gramosActuales(unidad)
        medida = nueva
        // Se mantiene la misma cantidad en gramos al cambiar de unidad.
        if let nueva {
            cantidad = max(1, (gramos / nueva.gramos).rounded())
        } else {
            cantidad = (Porciones.desdeGramos(gramos, a: unidad) * 10).rounded() / 10
        }
    }

    private func puedeGuardar(gramos: Double) -> Bool {
        guard Porciones.esValido(gramos) else { return false }
        if editableValores {
            return !nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && valores.kcal >= 0
        }
        return true
    }

    private func guardar(gramos: Double, por100: Nutrientes) {
        let nombreFinal = editableValores ? nombre.trimmingCharacters(in: .whitespacesAndNewlines) : candidato.nombre
        let registro = Registro(
            fecha: Diario.fechaParaRegistrar(enDia: almacen.diaVisible),
            comida: comida,
            nombre: nombreFinal,
            gramos: gramos,
            por100g: por100,
            origen: candidato.origen,
            codigoINS: candidato.codigoINS,
            codigoBarras: candidato.codigoBarras,
            medida: medida,
            cantidadMedida: medida == nil ? nil : cantidad
        )
        alGuardar(registro)
    }

    private func datoMacro(_ macro: Macro, _ valor: Double, _ estimado: Bool) -> some View {
        VStack(alignment: .leading, spacing: Espacio.xxs) {
            HStack(spacing: Espacio.xxs) {
                PuntoMacro(macro: macro)
                Text(macro.nombre).font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
            }
            Text((estimado ? "≈ " : "") + Formato.entero(valor) + " " + macro.unidad)
                .font(Tipo.subtitulo.monospacedDigit())
                .foregroundStyle(paleta.texto)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
