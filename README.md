# SampleBot

SampleBot is a macOS utility designed to automate the process of sampling hardware synthesizers. It sends MIDI Note On/Off messages to your external gear and simultaneously records the audio output, creating perfectly named and organized sample files.

## Features

- **Automated Sampling**: Automatically triggers notes across a specified range and records the audio.
- **Velocity Layers**: Supports sampling at multiple velocity levels (Soft: 64, Medium: 100, Hard: 127).
- **Flexible Configuration**: Set start/end notes, step size (stride), and note durations.
- **Audio Processing**:
    - **Normalization**: Automatically normalizes recording levels.
    - **Trimming**: Option to trim silence/latency from the start of the sample.
    - **Stereo/Mono**: Choose between stereo or mono recording.
- **Organization**: Custom filename prefixes for easy sample management.

## Usage

### Prerequisites
> [!IMPORTANT]
> **Audio Device Selection**: SampleBot uses the system default audio input. Please ensure your audio interface is selected as the **Input** device in **System Settings -> Sound** before launching the app.

### Steps
1.  **Select Output Folder**: Click "Select Folder" to choose where your `.wav` files will be saved.
2.  **MIDI Settings**:
    - Choose your hardware synthesizer from the "Destination" dropdown.
    - Click "Refresh Destinations" if your device isn't listed.
3.  **Audio Settings**:
    - Select the **Input Channel** corresponding to your synth's connection on your audio interface.
    - Toggle "Stereo Recording" if your synth is connected in stereo.
4.  **Configuration**:
    - **Range**: Set the Start Note and End Note (MIDI note numbers).
    - **Step**: Set how many semitones to skip (e.g., 1 for every note, 12 for octaves).
    - **Velocity**: Select which velocity layers to capture.
    - **Timing**: Adjust "Note Duration" (how long the key is held) and "Tail Duration" (how long to record release tails).
5.  **Start Sampling**: Click the "Start Sampling" button. The app will iterate through your settings, recording each note automatically.

## Technical Details

- **Built with**: SwiftUI, AVFoundation, CoreMIDI.
- **Format**: Records 32-bit Float WAV files (de-interleaved), suitable for high-quality audio production.
