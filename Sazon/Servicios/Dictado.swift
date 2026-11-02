import Foundation
import Speech
import AVFoundation
import Observation

/// Registro por voz con el reconocimiento de voz de Apple (gratis). Si el
/// iPhone lo permite, se hace en el propio dispositivo; si no, Apple lo
/// procesa en sus servidores (lo indica la pantalla).
@MainActor
@Observable
final class Dictado {
    var texto = ""
    var escuchando = false
    var error: String?

    private let reconocedor = SFSpeechRecognizer(locale: Locale(identifier: "es-PE")) ?? SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    private let motor = AVAudioEngine()
    private var peticion: SFSpeechAudioBufferRecognitionRequest?
    private var tarea: SFSpeechRecognitionTask?

    var enDispositivo: Bool { reconocedor?.supportsOnDeviceRecognition ?? false }

    func alternar() async {
        if escuchando { detener() } else { await empezar() }
    }

    func empezar() async {
        error = nil
        let estado = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard estado == .authorized else {
            error = "Sin permiso de reconocimiento de voz. Actívalo en Ajustes del iPhone › Sazón."
            return
        }
        let microfono = await AVAudioApplication.requestRecordPermission()
        guard microfono else {
            error = "Sin permiso de micrófono. Actívalo en Ajustes del iPhone › Sazón."
            return
        }
        guard let reconocedor, reconocedor.isAvailable else {
            error = "El reconocimiento de voz no está disponible ahora. Puedes usar el micrófono del teclado."
            return
        }
        do {
            let sesion = AVAudioSession.sharedInstance()
            try sesion.setCategory(.record, mode: .measurement, options: .duckOthers)
            try sesion.setActive(true, options: .notifyOthersOnDeactivation)

            let p = SFSpeechAudioBufferRecognitionRequest()
            p.shouldReportPartialResults = true
            if reconocedor.supportsOnDeviceRecognition { p.requiresOnDeviceRecognition = true }
            peticion = p

            let entrada = motor.inputNode
            let formato = entrada.outputFormat(forBus: 0)
            guard formato.sampleRate > 0, formato.channelCount > 0 else {
                error = "No se encontró un micrófono disponible."
                return
            }
            entrada.removeTap(onBus: 0)
            Dictado.instalarToma(entrada, formato: formato, peticion: p)
            motor.prepare()
            try motor.start()
            escuchando = true
            let base = texto.isEmpty ? "" : texto + " "
            tarea = Dictado.reconocer(reconocedor, peticion: p) { [weak self] dicho, terminado in
                Task { @MainActor in
                    guard let self else { return }
                    if let dicho { self.texto = base + dicho }
                    if terminado { self.detener() }
                }
            }
        } catch {
            self.error = "No se pudo usar el micrófono: \(error.localizedDescription)"
            detener()
        }
    }

    // Estas dos funciones no están atadas al hilo principal: el audio y el
    // reconocimiento llaman a sus bloques desde otros hilos.
    nonisolated private static func instalarToma(_ entrada: AVAudioInputNode, formato: AVAudioFormat,
                                                 peticion: SFSpeechAudioBufferRecognitionRequest) {
        entrada.installTap(onBus: 0, bufferSize: 1024, format: formato) { buffer, _ in
            peticion.append(buffer)
        }
    }

    nonisolated private static func reconocer(_ r: SFSpeechRecognizer, peticion: SFSpeechAudioBufferRecognitionRequest,
                                              alCambiar: @escaping @Sendable (String?, Bool) -> Void) -> SFSpeechRecognitionTask {
        r.recognitionTask(with: peticion) { resultado, fallo in
            alCambiar(resultado?.bestTranscription.formattedString, fallo != nil || (resultado?.isFinal ?? false))
        }
    }

    func detener() {
        guard escuchando || motor.isRunning else { return }
        motor.stop()
        motor.inputNode.removeTap(onBus: 0)
        peticion?.endAudio()
        tarea?.cancel()
        peticion = nil
        tarea = nil
        escuchando = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
