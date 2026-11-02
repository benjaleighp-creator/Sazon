import SwiftUI

/// Meta diaria: perfil, objetivo, fórmula visible y edición manual.
struct MetaView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @Environment(\.dismiss) private var cerrar

    @State private var perfil = Perfil()
    @State private var usarManual = false
    @State private var manual = Nutrientes(kcal: 2000, proteina: 120, carbohidratos: 230, grasas: 65)
    @State private var listo = false

    var body: some View {
        let calculada = CalculoMeta.meta(perfil)
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.l) {
                VStack(alignment: .leading, spacing: Espacio.s) {
                    TituloSeccion("Objetivo")
                    FilaFlexible(espacio: Espacio.xs) {
                        ForEach(Objetivo.allCases) { o in
                            Chip(texto: o.nombre, seleccionado: perfil.objetivo == o) { perfil.objetivo = o }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Espacio.s) {
                    TituloSeccion("Tus datos")
                    Text("Se guardan solo en este iPhone y nunca se envían a la IA.")
                        .font(Tipo.pie)
                        .foregroundStyle(paleta.textoSecundario)
                    FilaFlexible(espacio: Espacio.xs) {
                        ForEach(Sexo.allCases) { s in
                            Chip(texto: s.nombre, seleccionado: perfil.sexo == s) { perfil.sexo = s }
                        }
                    }
                    Stepper(value: $perfil.edad, in: 14...100) {
                        FilaValor(titulo: "Edad", valor: "\(perfil.edad) años")
                    }
                    CampoNumero(titulo: "Peso", valor: $perfil.pesoKg, unidad: "kg")
                    CampoNumero(titulo: "Talla", valor: $perfil.tallaCm, unidad: "cm", decimales: 0)
                    Text("Actividad física").font(Tipo.cuerpoFuerte).foregroundStyle(paleta.texto)
                    VStack(spacing: Espacio.xs) {
                        ForEach(NivelActividad.allCases) { n in
                            Button { perfil.actividad = n } label: {
                                HStack(alignment: .top, spacing: Espacio.s) {
                                    Image(systemName: perfil.actividad == n ? "largecircle.fill.circle" : "circle")
                                        .font(Tipo.iconoFila)
                                        .foregroundStyle(paleta.acento)
                                    VStack(alignment: .leading, spacing: Espacio.xxxs) {
                                        Text("\(n.nombre) (× \(Formato.numero(n.factor, decimales: 3)))")
                                            .font(Tipo.cuerpo).foregroundStyle(paleta.texto)
                                        Text(n.descripcion).font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                                    }
                                    .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, Espacio.xxs)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(perfil.actividad == n ? .isSelected : [])
                            .sensoryFeedback(.selection, trigger: perfil.actividad)
                        }
                    }
                }

                // Fórmula
                VStack(alignment: .leading, spacing: Espacio.s) {
                    TituloSeccion("Cómo se calcula")
                    ForEach(Array(CalculoMeta.explicacion(perfil).enumerated()), id: \.offset) { i, paso in
                        HStack(alignment: .top, spacing: Espacio.xs) {
                            Text("\(i + 1).").font(Tipo.pie.monospacedDigit()).foregroundStyle(paleta.textoSecundario)
                            Text(paso).font(Tipo.pie).foregroundStyle(paleta.texto)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Text("Son estimaciones generales para adultos, no consejo médico. Si tienes una condición de salud, consulta a un profesional.")
                        .font(Tipo.pie)
                        .foregroundStyle(paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .tarjeta()

                // Manual
                VStack(alignment: .leading, spacing: Espacio.s) {
                    Toggle(isOn: $usarManual) {
                        VStack(alignment: .leading, spacing: Espacio.xxxs) {
                            Text("Escribir mi meta a mano").font(Tipo.cuerpo).foregroundStyle(paleta.texto)
                            Text("Reemplaza el cálculo de arriba.").font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                        }
                    }
                    .tint(paleta.acento)
                    if usarManual {
                        CampoNumero(titulo: "Calorías", valor: $manual.kcal, unidad: "kcal", decimales: 0)
                        CampoNumero(titulo: "Proteína", valor: $manual.proteina, unidad: "g", decimales: 0)
                        CampoNumero(titulo: "Carbohidratos", valor: $manual.carbohidratos, unidad: "g", decimales: 0)
                        CampoNumero(titulo: "Grasas", valor: $manual.grasas, unidad: "g", decimales: 0)
                        let diferencia = manual.kcalPorMacros - manual.kcal
                        if manual.kcal > 0 && abs(diferencia) > max(50, manual.kcal * 0.05) {
                            Text("Tus macros suman \(Formato.entero(manual.kcalPorMacros)) kcal (proteína y carbohidratos × 4, grasas × 9), no \(Formato.entero(manual.kcal)). Puedes guardarlo igual.")
                                .font(Tipo.pie)
                                .foregroundStyle(paleta.aviso)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                // Resultado
                let vigente = usarManual ? manual : calculada
                VStack(alignment: .leading, spacing: Espacio.s) {
                    TituloSeccion(usarManual ? "Tu meta (manual)" : "Tu meta (calculada)")
                    FilaDatos {
                        Dato(valor: Formato.entero(vigente.kcal), etiqueta: "kcal")
                        Dato(valor: Formato.entero(vigente.proteina) + " g", etiqueta: "Proteína")
                        Dato(valor: Formato.entero(vigente.carbohidratos) + " g", etiqueta: "Carbohidratos")
                        Dato(valor: Formato.entero(vigente.grasas) + " g", etiqueta: "Grasas")
                    }
                }
                .tarjeta()
            }
            .padding(.horizontal, Espacio.margen)
            .padding(.vertical, Espacio.m)
        }
        .fondoDePantalla()
        .navigationTitle("Meta diaria")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") { guardar() }
                    .disabled(!datosValidos)
            }
        }
        .onAppear {
            guard !listo else { return }
            listo = true
            if let p = almacen.datos.perfil { perfil = p }
            if let m = almacen.datos.metaManual {
                manual = m
                usarManual = true
            } else {
                manual = CalculoMeta.meta(perfil)
            }
        }
    }

    private var datosValidos: Bool {
        (30...300).contains(perfil.pesoKg) && (120...230).contains(perfil.tallaCm) &&
        (!usarManual || (manual.kcal >= 800 && manual.kcal <= 6000))
    }

    private func guardar() {
        var d = almacen.datos
        d.perfil = perfil
        d.metaManual = usarManual ? manual : nil
        almacen.datos = d
        cerrar()
    }
}

/// Dato numérico con etiqueta.
struct Dato: View {
    let valor: String
    let etiqueta: String
    @Environment(\.paleta) private var paleta

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.xxs) {
            Text(valor)
                .font(Tipo.subtitulo.monospacedDigit())
                .foregroundStyle(paleta.texto)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(etiqueta)
                .font(Tipo.pie)
                .foregroundStyle(paleta.textoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
