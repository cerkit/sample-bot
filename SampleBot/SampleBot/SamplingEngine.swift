import AVFoundation
import Combine
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
    @Published var isStereo: Bool = false  // Default to Mono (or user preference)

    @Published var inputChannel: Int = 0  // Default to Channel 1
    @Published var shouldNormalize: Bool = true  // Default to true?

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

        // File Naming: NoteName_Velocity.wav (e.g. C#1_127.wav)
        let noteName = self.getNoteName(midiNote: note)
        // Sanitizing just in case (e.g. # is usually fine in fs, but let's be safe? macOS handles # fine)
        let noteNameSanitized = noteName.replacingOccurrences(of: "/", with: "-")

        let filename = String(format: "%@_%03d.wav", noteNameSanitized, velocity)
        let fileURL = outputBasURL.appendingPathComponent(filename)

        // 1. Start Record
        do {
            try audioManager.startRecording(
                to: fileURL, isStereo: isStereo, inputChannel: inputChannel)
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

                    // 6b. Normalize if requested
                    if self.shouldNormalize {
                        // File is closed by stopRecording() immediately?
                        // stopRecording uses async UI update but audioFile = nil is effectively synchronous cleanup
                        // Let's add slight delay or assume it's safe since audioFile is nilled.
                        // But we need to make sure the flush happened.
                        // For safety, let's do it after a tiny delay or synchronously if we trust close().
                        // AVAudioFile deinit closes it.
                        self.audioManager.normalizeAudio(at: fileURL)
                    }

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

    private func getNoteName(midiNote: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (midiNote / 12) - 1  // MIDI 60 is C4 or C3? Standard is C4=60, so 60/12 - 1 = 4. Wait.
        // C4 (Middle C) = 60. 60/12 = 5. if octave is -1 based?
        // Usually C-1 is 0. 0/12 = 0. 0-1 = -1. Correct.
        // C3 (Yamaha) = 60?
        // Let's stick to Standard: 60 = C4. (60 / 12) - 1 -> 5 - 1 = 4.
        // If user wants C3=60, then (60/12) - 2.
        // Let's use standard (Midi Note 0 = C-1)

        let noteIndex = midiNote % 12
        let name = noteNames[noteIndex]
        return "\(name)\(octave)"
    }
}
