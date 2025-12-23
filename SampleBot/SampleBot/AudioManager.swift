import AVFoundation
import Combine
import Foundation

class AudioManager: ObservableObject {
    private var engine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?

    private var converter: AVAudioConverter?
    private var outputBuffer: AVAudioPCMBuffer?

    @Published var isRecording = false
    @Published var inputDevices: [AVCaptureDevice] = []

    // Total channels available on the current input device
    @Published var inputChannelCount: Int = 2

    init() {
        setupSession()
    }

    func setupSession() {
        inputNode = engine.inputNode
        // Initial count
        inputChannelCount = Int(engine.inputNode.inputFormat(forBus: 0).channelCount)
    }

    func startRecording(to url: URL, isStereo: Bool, inputChannel: Int) throws {
        // Safety: Remove existing tap if any (prevents crashes on restart)
        inputNode?.removeTap(onBus: 0)

        let inputFormat = inputNode!.inputFormat(forBus: 0)

        // Update input count just in case it changed
        DispatchQueue.main.async {
            self.inputChannelCount = Int(inputFormat.channelCount)
        }

        print("DEBUG: Input Format: \(inputFormat)")
        print("DEBUG: User selected Input Channel Index: \(inputChannel)")

        // 1. Define a SAFE, STANDARD format for the file (Float32, de-interleaved)
        guard
            let standardFormat = AVAudioFormat(
                standardFormatWithSampleRate: inputFormat.sampleRate, channels: isStereo ? 2 : 1)
        else {
            throw NSError(
                domain: "SampleBot", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Could not create standard audio format"])
        }

        print("DEBUG: Output (File) Format: \(standardFormat)")

        // 2. Create the file using the standard format's settings
        audioFile = try AVAudioFile(forWriting: url, settings: standardFormat.settings)

        // 3. Reset converter
        converter = nil
        outputBuffer = nil

        inputNode!.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { (buffer, time) in
            do {
                guard let audioFile = self.audioFile else { return }

                // 4. Configure Converter if needed
                if self.converter == nil {
                    print(
                        "DEBUG: Creating Converter from \(buffer.format) to \(audioFile.processingFormat)"
                    )
                    self.converter = AVAudioConverter(
                        from: buffer.format, to: audioFile.processingFormat)

                    // ---------------------------------------------------------
                    // CHANNEL MAPPING LOGIC
                    // ---------------------------------------------------------
                    if let converter = self.converter {
                        // inputChannel is 0-indexed.
                        // For Mono: Map [inputChannel] -> [0]
                        // For Stereo: Map [inputChannel, inputChannel+1] -> [0, 1] (if available)

                        var map: [NSNumber] = []
                        if isStereo {
                            // Stereo Output (2 channels)
                            // Try to map ch, ch+1
                            let ch1 = inputChannel < buffer.format.channelCount ? inputChannel : 0
                            let ch2 =
                                (inputChannel + 1) < buffer.format.channelCount
                                ? (inputChannel + 1) : ch1  // Fallback to same channel if out of bounds?

                            // Map Input[ch1] -> Output[0]
                            // Map Input[ch2] -> Output[1]
                            map = [NSNumber(value: ch1), NSNumber(value: ch2)]
                        } else {
                            // Mono Output (1 channel)
                            let ch1 = inputChannel < buffer.format.channelCount ? inputChannel : 0
                            map = [NSNumber(value: ch1)]
                        }

                        print("DEBUG: Setting Channel Map: \(map)")
                        converter.channelMap = map
                    }
                }

                // 5. Create Output Buffer if needed
                if self.outputBuffer == nil
                    || self.outputBuffer?.frameCapacity != buffer.frameLength
                {
                    self.outputBuffer = AVAudioPCMBuffer(
                        pcmFormat: audioFile.processingFormat, frameCapacity: buffer.frameCapacity)
                }

                guard let converter = self.converter, let outputBuffer = self.outputBuffer else {
                    print("DEBUG: Converter or OutputBuffer is nil")
                    return
                }

                // 6. Convert
                var error: NSError? = nil
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }

                converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

                if let error = error {
                    print("Audio Conversion Error: \(error)")
                } else {
                    // 7. Write Converted Buffer
                    try audioFile.write(from: outputBuffer)
                }

                // 8. Debug Logging (RMS)
                if let channelData = buffer.floatChannelData {
                    let channelDataValue = channelData.pointee
                    let channelDataValueArray = stride(
                        from: 0,
                        to: Int(buffer.frameLength),
                        by: buffer.stride
                    ).map { channelDataValue[$0] }

                    let rms = sqrt(
                        channelDataValueArray.map { $0 * $0 }.reduce(0, +)
                            / Float(buffer.frameLength))
                    let avgPower = 20 * log10(rms)

                    if avgPower > -60 {
                        print("Recording Signal: \(String(format: "%.1f", avgPower)) dB")
                    }
                }

            } catch {
                print("Error processing/writing audio: \(error)")
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
        converter = nil
        outputBuffer = nil

        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
}
