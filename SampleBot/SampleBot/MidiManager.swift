import Combine
import CoreMIDI
import Foundation

class MidiManager: ObservableObject {
    @Published var destinations: [MidiDestination] = []
    @Published var selectedDestinationIndex: Int = 0

    private var midiClient = MIDIClientRef()
    private var outPort = MIDIPortRef()

    struct MidiDestination: Identifiable, Hashable {
        let id: Int
        let name: String
        let endpointRef: MIDIEndpointRef
    }

    init() {
        setupMidi()
        refreshDestinations()
    }

    func setupMidi() {
        var status = MIDIClientCreate("SampleBot" as CFString, nil, nil, &midiClient)
        if status != noErr {
            print("Error creating MIDI client: \(status)")
            return
        }

        status = MIDIOutputPortCreate(midiClient, "Output" as CFString, &outPort)
        if status != noErr {
            print("Error creating MIDI output port: \(status)")
            return
        }
    }

    func refreshDestinations() {
        var newDestinations: [MidiDestination] = []
        let count = MIDIGetNumberOfDestinations()

        for i in 0..<count {
            let endpoint = MIDIGetDestination(i)
            var name: Unmanaged<CFString>?
            _ = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name)
            let destName = (name?.takeRetainedValue() as String?) ?? "Unknown"

            newDestinations.append(MidiDestination(id: i, name: destName, endpointRef: endpoint))
        }

        DispatchQueue.main.async {
            self.destinations = newDestinations
            // If checking previously selected, can optimize. For now default to first.
            if self.destinations.isEmpty == false
                && self.selectedDestinationIndex >= self.destinations.count
            {
                self.selectedDestinationIndex = 0
            }
        }
    }

    func sendNoteOn(note: UInt8, velocity: UInt8) {
        guard destinations.indices.contains(selectedDestinationIndex) else { return }
        let endpoint = destinations[selectedDestinationIndex].endpointRef

        var packet = MIDIPacket()
        packet.timeStamp = 0  // Immediate
        packet.length = 3
        packet.data.0 = 0x90  // Note On channel 1
        packet.data.1 = note
        packet.data.2 = velocity

        var packetList = MIDIPacketList(numPackets: 1, packet: packet)
        MIDISend(outPort, endpoint, &packetList)
    }

    func sendNoteOff(note: UInt8) {
        guard destinations.indices.contains(selectedDestinationIndex) else { return }
        let endpoint = destinations[selectedDestinationIndex].endpointRef

        var packet = MIDIPacket()
        packet.timeStamp = 0
        packet.length = 3
        packet.data.0 = 0x80  // Note Off channel 1
        packet.data.1 = note
        packet.data.2 = 0

        var packetList = MIDIPacketList(numPackets: 1, packet: packet)
        MIDISend(outPort, endpoint, &packetList)
    }
}
