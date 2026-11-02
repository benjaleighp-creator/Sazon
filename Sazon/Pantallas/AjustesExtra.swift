import SwiftUI

// Pantallas de Ajustes: recordatorios, Apple Salud, agua, exportar y
// widgets.

// MARK: - Recordatorios

struct PantallaRecordatorios: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var permiso: Bool?

    var body: some View {
        @Bindable var a = almacen
        Form {
            if permiso == false {
                Section {
                    Text("Sazón no tiene permiso para enviarte notificaciones. Actívalo en Ajustes del iPhone › Notificaciones › Sazón.")
                        .foregroundStyle(paleta.aviso)
                }
            }
            Section {
                Toggle("Recordar mis comidas", isOn: $a.datos.recordatorios.comidasActivas)
                if almacen.datos.recordatorios.comidasActivas {
                    selectorHora("Desayuno", $a.datos.recordatorios.horaDesayuno)
                    selectorHora("Almuerzo", $a.datos.recordatorios.horaAlmuerzo)
                    selectorHora("Cena", $a.datos.recordatorios.horaCena)
                }
            } header: { Text("Comidas") }

            Section {
                Toggle("Recordar tomar agua", isOn: $a.datos.recordatorios.aguaActiva)
                if almacen.datos.recordatorios.aguaActiva {
                    Stepper(value: $a.datos.recordatorios.aguaCadaHoras, in: 1...4) {
                        Text("Cada \(almacen.datos.recordatorios.aguaCadaHoras) h, de 9:00 a 21:00")
                    }
                }
            } header: { Text("Agua") }

            Section {
                Toggle("Recordar pesarme", isOn: $a.datos.recordatorios.pesoActivo)
                if almacen.datos.recordatorios.pesoActivo {
                    Picker("Día", selection: $a.datos.recordatorios.pesoDiaSemana) {
                        ForEach(1...7, id: \.self) { d in
                            Text(Calendar.current.weekdaySymbols[d - 1].capitalized).tag(d)
                        }
                    }
                    selectorHora("Hora", $a.datos.recordatorios.pesoHora)
                }
            } header: { Text("Peso") }

            Section {
                Toggle("Avisar cuando termine mi ayuno", isOn: $a.datos.recordatorios.ayunoActivo)
            } header: { Text("Ayuno") }

            Section {
                Text("Son notificaciones locales: las programa tu iPhone y no pasan por ningún servidor.")
                    .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
            }
        }
        .navigationTitle("Recordatorios")
        .task { permiso = await Recordatorios.permisoConcedido() }
        .onChange(of: almacen.datos.recordatorios) { anterior, nueva in
            Task {
                let quiereAlgo = nueva.comidasActivas || nueva.aguaActiva || nueva.pesoActivo || nueva.ayunoActivo
                if quiereAlgo, permiso != true {
                    permiso = await Recordatorios.pedirPermiso()
                }
                Recordatorios.reprogramar(nueva)
            }
        }
    }

    private func selectorHora(_ titulo: String, _ minutos: Binding<Int>) -> some View {
        DatePicker(titulo, selection: Binding(
            get: { Calendar.current.date(bySettingHour: minutos.wrappedValue / 60, minute: minutos.wrappedValue % 60, second: 0, of: Date()) ?? Date() },
            set: { f in
                let c = Calendar.current.dateComponents([.hour, .minute], from: f)
                minutos.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }), displayedComponents: .hourAndMinute)
    }
}

// MARK: - Apple Salud

struct PantallaSalud: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var error: String?
    @State private var cargando = false
    @State private var pesoSalud: (kg: Double, fecha: Date)?

    var body: some View {
        @Bindable var a = almacen
        Form {
            if !Firma.salud {
                Section {
                    Label("Esta instalación no incluye el permiso de Apple Salud", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(paleta.aviso)
                    Text("Instala «Sazon-completa.ipa». Si Sideloadly no conserva el permiso con tu cuenta gratuita, esta función no estará disponible; el resto de la app funciona igual.")
                        .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
                }
            }
            Section {
                Toggle("Conectar con Apple Salud", isOn: $a.datos.saludActiva)
                    .disabled(!Firma.salud)
            } footer: {
                Text("Lee tus pasos, calorías activas y peso, y guarda en Salud el peso que anotes aquí. Los datos se quedan en tu iPhone; no se envían a la IA.")
            }
            if almacen.datos.saludActiva {
                Section("Hoy") {
                    FilaValor(titulo: "Pasos", valor: Formato.entero(almacen.pasosSalud))
                    FilaValor(titulo: "Calorías activas", valor: "\(Formato.entero(almacen.actividadSalud)) kcal")
                    Button(cargando ? "Actualizando…" : "Actualizar") { actualizar() }
                        .disabled(cargando)
                }
                Section {
                    Toggle("Sumar calorías activas a mi meta", isOn: $a.datos.sumarActividad)
                } footer: {
                    Text("Si lo activas, la meta del día sube con lo que gastas haciendo ejercicio según Salud. Úsalo solo si elegiste «Sedentario» o «Ligera» en tu actividad, para no contar el ejercicio dos veces. Los relojes y teléfonos estiman ese gasto, y puede no ser exacto.")
                }
                if let p = pesoSalud {
                    Section("Peso en Apple Salud") {
                        FilaValor(titulo: Formato.diaLargo(p.fecha), valor: "\(Formato.numero(p.kg)) kg")
                        Button("Usar este peso en Sazón") { almacen.registrarPeso(p.kg, fecha: p.fecha) }
                    }
                }
            }
            if let error {
                Section { Text(error).foregroundStyle(paleta.peligro) }
            }
        }
        .navigationTitle("Apple Salud")
        .onChange(of: almacen.datos.saludActiva) { _, activa in
            guard activa else { almacen.actividadSalud = 0; almacen.pasosSalud = 0; return }
            Task {
                error = await Salud.compartido.pedirPermiso()
                if error != nil { almacen.datos.saludActiva = false } else { actualizar() }
            }
        }
        .task { if almacen.datos.saludActiva { actualizar() } }
    }

    private func actualizar() {
        cargando = true
        Task {
            await Salud.compartido.actualizarHoy(en: almacen)
            pesoSalud = await Salud.compartido.ultimoPeso()
            cargando = false
        }
    }
}

// MARK: - Agua

struct PantallaAgua: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var manual: Double = 0
    @State private var usarManual = false

    var body: some View {
        @Bindable var a = almacen
        Form {
            Section {
                Toggle("Escribir mi meta a mano", isOn: $usarManual)
                if usarManual {
                    CampoNumero(titulo: "Meta de agua", valor: $manual, unidad: "ml", decimales: 0)
                }
            } footer: {
                Text(usarManual ? "Tu meta: \(Formato.entero(manual)) ml." : "Meta automática: \(Formato.entero(Agua.meta(almacen.datos))) ml (35 ml por kg de peso, entre 1,5 y 4 litros). Es una regla general; si haces mucho ejercicio o hace calor puedes necesitar más.")
            }
            Section("Tamaño del vaso") {
                Picker("Vaso", selection: $a.datos.vasoMl) {
                    Text("200 ml").tag(200.0)
                    Text("250 ml").tag(250.0)
                    Text("330 ml").tag(330.0)
                    Text("500 ml").tag(500.0)
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("Agua")
        .onAppear {
            usarManual = almacen.datos.metaAguaManual != nil
            manual = almacen.datos.metaAguaManual ?? Agua.meta(almacen.datos)
        }
        .onDisappear {
            almacen.datos.metaAguaManual = usarManual && manual >= 500 ? manual : nil
        }
    }
}

// MARK: - Exportar

struct PantallaExportar: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var archivoComidas: URL?
    @State private var archivoPesos: URL?

    var body: some View {
        Form {
            Section {
                if let archivoComidas {
                    ShareLink(item: archivoComidas) { Label("Comidas (\(almacen.datos.registros.count) registros)", systemImage: "tablecells") }
                }
                if let archivoPesos {
                    ShareLink(item: archivoPesos) { Label("Pesos (\(almacen.datos.pesos.count) registros)", systemImage: "scalemass") }
                }
            } footer: {
                Text("Archivos CSV que se abren en Excel, Numbers o Google Sheets. El respaldo completo de la app está en Ajustes › Respaldo.")
            }
        }
        .navigationTitle("Exportar")
        .task {
            archivoComidas = escribir("Sazón comidas.csv", Exportar.csvRegistros(almacen.datos.registros))
            archivoPesos = escribir("Sazón pesos.csv", Exportar.csvPesos(almacen.datos.pesos))
        }
    }

    private func escribir(_ nombre: String, _ texto: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nombre)
        do {
            try Data(texto.utf8).write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Widgets

struct PantallaWidgets: View {
    @Environment(\.paleta) private var paleta

    var body: some View {
        Form {
            Section("Estado de esta instalación") {
                FilaValor(titulo: "Extensión de widgets", valor: Firma.widgets ? "Incluida" : "No incluida")
                FilaValor(titulo: "Datos compartidos (App Group)", valor: ContenedorCompartido.grupoDisponible ? "Activos" : "No disponibles")
                FilaValor(titulo: "Apple Salud", valor: Firma.salud ? "Permitido" : "No permitido")
            }
            Section("Cómo agregar un widget") {
                Text("1. Mantén presionada la pantalla de inicio hasta que los íconos se muevan.")
                Text("2. Toca «Editar» (arriba a la izquierda) › «Agregar widget».")
                Text("3. Busca «Sazón» y elige calorías, agua o ayuno.")
                Text("En la pantalla bloqueada: mantén presionado el reloj › Personalizar › Pantalla bloqueada › toca debajo de la hora.")
            }
            Section {
                Text("Si dice «No disponibles», los widgets muestran datos de ejemplo: tu firma no incluyó el App Group. Por verificar: con una cuenta gratuita, la extensión de widgets puede contar dentro del límite de 3 apps y usa un identificador más (App ID). Si te falta espacio, instala «Sazon-sencilla.ipa».")
                    .font(Tipo.pie).foregroundStyle(paleta.textoSecundario)
            }
        }
        .navigationTitle("Widgets")
    }
}
