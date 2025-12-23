import AVFoundation
import Foundation

class SamplingEngine: ObservableObject {
    var midiManager: MidiManager
    var audioManager: AudioManager

    // Parameters
    @Published var startNote: Int = 36  // C1
    @Published var endNote: Int = 60  // C3
    @Published var velocityLayers: [Int] = [64, 100, 127]
    @Published var step: Int = 1
    @Published var noteDuration: Double = 2.0
    @Published var tailDuration: Double = 1.0

    @Published var outputURL: URL? = nil
    @Published var isRunning = false
    @Published var currentStatus: String = "Ready"
    @Published var progress: Double = 0.0

    private var tasks: [DispatchWorkItem] = []

    init(midiManager: MidiManager, audioManager: AudioManager) {
        self.midiManager = midiManager
        self.audioManager = audioManager
    }

    func startSampling() {
        guard let outputURL = outputURL else {
            currentStatus = "Please select an output folder."
            return
        }

        isRunning = true
        progress = 0.0
        currentStatus = "Starting..."

        // Generate sampling queue
        var queue: [SampleEvent] = []
        for note in stride(from: startNote, through: endNote, by: step) {
            for velocity in velocityLayers {
                queue.append(SampleEvent(note: note, velocity: velocity))
            }
        }

        // Process queue strictly sequentially
        processQueue(queue: queue, outputBasURL: outputURL) {
            DispatchQueue.main.async {
                self.isRunning = false
                self.currentStatus = "Done!"
                self.progress = 1.0
            }
        }
    }

    private struct SampleEvent {
        let note: Int
        let velocity: Int
    }

    private func processQueue(
        queue: [SampleEvent], outputBasURL: URL, completion: @escaping () -> Void
    ) {
        var mutableQueue = queue
        guard !mutableQueue.isEmpty, isRunning else {
            completion()
            return
        }

        let event = mutableQueue.removeFirst()
        let note = event.note
        let velocity = event.velocity

        // Update Status
        DispatchQueue.main.async {
            self.currentStatus = "Sampling Note \(note) Vel \(velocity)"
            // Progress update logic could be better (needing initial count), but this is MVP
        }

        // File Naming: Instrument_Note_Velocity.wav
        // Note: Kontakt logic often prefers MIDI Note numbers or logical names.
        // Let's use: Sample_NNN_VVV.wav
        let filename = String(format: "Sample_%03d_%03d.wav", note, velocity)
        let fileURL = outputBasURL.appendingPathComponent(filename)

        // 1. Start Record
        do {
            try audioManager.startRecording(to: fileURL)
        } catch {
            print("Failed to start recording: \(error)")
            // abort or skip? Skip for now.
        }

        // 2. Note On
        // Wait a tiny bit for audio to spin up/open file? 100ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.midiManager.sendNoteOn(note: UInt8(note), velocity: UInt8(velocity))

            // 3. Wait Note Duration
            DispatchQueue.main.asyncAfter(deadline: .now() + self.noteDuration) {
                // 4. Note Off
                self.midiManager.sendNoteOff(note: UInt8(note))

                // 5. Wait Tail
                DispatchQueue.main.asyncAfter(deadline: .now() + self.tailDuration) {
                    // 6. Stop Record
                    self.audioManager.stopRecording()

                    // 7. Next
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.processQueue(
                            queue: mutableQueue, outputBasURL: outputBasURL, completion: completion)
                    }
                }
            }
        }
    }

    func stopSampling() {
        isRunning = false
        // Will stop at next queue check
        // Also cleanup current recording if needed?
        audioManager.stopRecording()
        midiManager.sendNoteOff(note: 60)  // Panic? Need a panic function.
    }
}
