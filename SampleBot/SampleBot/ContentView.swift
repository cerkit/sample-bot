import SwiftUI

struct ContentView: View {
    @StateObject var midiManager = MidiManager()
    @StateObject var audioManager = AudioManager()
    @StateObject var engine: SamplingEngine

    init() {
        let midi = MidiManager()
        let audio = AudioManager()
        _midiManager = StateObject(wrappedValue: midi)
        _audioManager = StateObject(wrappedValue: audio)
        _engine = StateObject(wrappedValue: SamplingEngine(midiManager: midi, audioManager: audio))
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Sample Bot")
                .font(.largeTitle)
                .bold()

            // Output Folder
            HStack {
                Text(engine.outputURL?.path ?? "No Output Folder Selected")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(5)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(5)

                Button("Select Folder") {
                    selectFolder()
                }
            }
            .padding(.horizontal)

            Divider()

            // Settings
            Form {
                Section(header: Text("MIDI Settings")) {
                    Picker("Destination", selection: $midiManager.selectedDestinationIndex) {
                        ForEach(midiManager.destinations) { dest in
                            Text(dest.name).tag(dest.id)
                        }
                    }
                    Button("Refresh Destinations") {
                        midiManager.refreshDestinations()
                    }
                }

                Section(header: Text("Range & Velocity")) {
                    HStack {
                        TextField(
                            "Start Note", value: $engine.startNote, formatter: NumberFormatter())
                        TextField("End Note", value: $engine.endNote, formatter: NumberFormatter())
                    }
                    Stepper("Step: \(engine.step)", value: $engine.step, in: 1...12)

                    // Velocities
                    VStack(alignment: .leading) {
                        Text("Velocity Layers:")
                        HStack {
                            Toggle("Soft (64)", isOn: $engine.useLowVelocity)
                            Toggle("Med (100)", isOn: $engine.useMidVelocity)
                            Toggle("Hard (127)", isOn: $engine.useHighVelocity)
                        }
                    }
                }

                Section(header: Text("Timing & Format")) {
                    TextField("Note Duration (s)", value: $engine.noteDuration, format: .number)
                    TextField("Tail Duration (s)", value: $engine.tailDuration, format: .number)
                    Toggle("Stereo Recording", isOn: $engine.isStereo)
                    Toggle("Normalize Audio", isOn: $engine.shouldNormalize)

                    Picker("Input Channel", selection: $engine.inputChannel) {
                        // Show available channels based on audio manager logic (or hardcode reasonable range if async update is slow)
                        // Note: range 0..<audioManager.inputChannelCount might crash if count is 0.
                        // Let's assume at least 2 or use a safe range.
                        ForEach(0..<max(2, audioManager.inputChannelCount), id: \.self) { ch in
                            Text("Channel \(ch + 1)").tag(ch)
                        }
                    }
                }
            }

            Divider()

            // Status & Control
            VStack {
                Text(engine.currentStatus)
                    .font(.headline)
                    .foregroundColor(engine.isRunning ? .green : .primary)

                // Progress Bar logic could go here

                Button(action: {
                    if engine.isRunning {
                        engine.stopSampling()
                    } else {
                        engine.startSampling()
                    }
                }) {
                    Text(engine.isRunning ? "Stop Sampling" : "Start Sampling")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(engine.outputURL == nil)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK {
            engine.outputURL = panel.url
        }
    }
}
