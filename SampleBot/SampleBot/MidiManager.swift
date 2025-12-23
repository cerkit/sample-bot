import Combine
import CoreMIDI
import Foundation

class MidiManager: ObservableObject {
    @Published var destinations: [MidiDestination] = []
    @Published var selectedDestinationIndex: Int = 0

    private var midiClient = MIDIClientRef()
    private var outPort = MIDIPortRef()
    private var virtualSource = MIDIEndpointRef()

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

        // Create a virtual source that other apps can see as an input
        status = MIDISourceCreate(midiClient, "SampleBot MIDI" as CFString, &virtualSource)
        if status != noErr {
            print("Error creating MIDI virtual source: \(status)")
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
        // Prepare MIDI packet
        var packet = MIDIPacket()
        packet.timeStamp = 0  // Immediate
        packet.length = 3
        packet.data.0 = 0x90  // Note On channel 1
        packet.data.1 = note
        packet.data.2 = velocity

        var packetList = MIDIPacketList(numPackets: 1, packet: packet)

        // 1. Send to Virtual Source (so DAW sees it)
        MIDIReceived(virtualSource, &packetList)

        // 2. Send to Selected Destination (Hardware) if selected
        if destinations.indices.contains(selectedDestinationIndex) {
            let endpoint = destinations[selectedDestinationIndex].endpointRef
            MIDISend(outPort, endpoint, &packetList)
        }
    }

    func sendNoteOff(note: UInt8) {
        // Prepare MIDI packet
        var packet = MIDIPacket()
        packet.timeStamp = 0
        packet.length = 3
        packet.data.0 = 0x80  // Note Off channel 1
        packet.data.1 = note
        packet.data.2 = 0

        var packetList = MIDIPacketList(numPackets: 1, packet: packet)

        // 1. Send to Virtual Source (so DAW sees it)
        MIDIReceived(virtualSource, &packetList)

        // 2. Send to Selected Destination (Hardware) if selected
        if destinations.indices.contains(selectedDestinationIndex) {
            let endpoint = destinations[selectedDestinationIndex].endpointRef
            MIDISend(outPort, endpoint, &packetList)
        }
    }
}
