import AVFoundation
import Combine
import Foundation

class AudioManager: ObservableObject {
    private var engine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?

    @Published var inputDevices: [AVCaptureDevice] = []  // Note: macOS audio input enumeration is tricky, AVAudioEngine uses "default input". To select specific, we might need CoreAudio.
    // For simplicity in this iteration, we will rely on the System Default Input, or try to enumerate via AVCaptureDevice if permitted, OR use CoreAudio AudioObject.
    // Let's stick to simple "Default Input" for now, or implement basic CoreAudio device listing if needed.

    // Changing approach: Use CoreAudio to list devices for better macOS support than AVCaptureDevice (which is often camera/mic-centric).
    // Actually, simply using AVAudioEngine uses the system default. Proper device switching requires setting the AudioUnit of the InputNode.
    // For MVP: Use system default input.

    @Published var isRecording = false

    init() {
        setupSession()
    }

    func setupSession() {
        // macOS doesn't need AVAudioSession, but we should prepare the engine.
        // engine.inputNode accesses the hardware input.
        inputNode = engine.inputNode
    }

    func startRecording(to url: URL) throws {
        // Prepare to record
        let format = inputNode!.inputFormat(forBus: 0)
        let settings = format.settings

        audioFile = try AVAudioFile(forWriting: url, settings: settings)

        inputNode!.installTap(onBus: 0, bufferSize: 4096, format: format) { (buffer, time) in
            do {
                try self.audioFile?.write(from: buffer)
            } catch {
                print("Error writing audio: \(error)")
            }
        }

        try engine.start()
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }

    func stopRecording() {
        inputNode?.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil  // Close file

        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
}
