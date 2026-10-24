import AVFoundation

/// Pure helpers for turning synthesized or recorded PCM audio into per-chunk
/// amplitude "energies" — useful for driving audio-reactive UI (waveform
/// visualizers, lip-sync, speaking indicators) from TTS playback or a voice
/// recording, independent of any particular rendering approach.
public enum PCMEnergyAnalyzer {

    /// Concatenates multiple PCM buffers (e.g. `AVSpeechSynthesizer`'s
    /// per-chunk `write` callback) into one buffer for uniform processing.
    /// Returns a valid empty buffer for empty input rather than trapping.
    public nonisolated static func concatenate(_ buffers: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer {
        if buffers.isEmpty {
            // These two system initializers are guaranteed non-nil for these
            // constant, valid arguments.
            let format = AVAudioFormat(standardFormatWithSampleRate: 22050, channels: 1)!
            return AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1)!
        }
        if buffers.count == 1 { return buffers[0] }
        let totalFrames = buffers.reduce(0) { $0 + Int($1.frameLength) }
        let format = buffers[0].format
        guard format.commonFormat == .pcmFormatFloat32,
              let result = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames))
        else { return buffers[0] }
        var offset = 0
        for buf in buffers {
            let frames = Int(buf.frameLength)
            let channelCount = Int(format.channelCount)
            for ch in 0..<channelCount {
                memcpy(result.floatChannelData?[ch].advanced(by: offset), buf.floatChannelData?[ch], frames * MemoryLayout<Float>.size)
            }
            offset += frames
        }
        result.frameLength = AVAudioFrameCount(totalFrames)
        return result
    }

    /// Splits `buffer` into `chunkSize`-sample windows on channel 0 and
    /// returns each window's mean absolute amplitude, scaled by 5x and
    /// clamped to 0...1 (tuned so typical speech energies spread across the
    /// range rather than clustering near 0).
    public nonisolated static func energies(for buffer: AVAudioPCMBuffer, chunkSize: Int = 1024) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        let frameLength = Int(buffer.frameLength)
        let channel = 0
        var energies: [Float] = []
        var pos = 0
        while pos < frameLength {
            let end = min(pos + chunkSize, frameLength)
            var sum: Float = 0
            let count = end - pos
            for i in pos..<end {
                sum += abs(channelData[channel][i])
            }
            let avg = sum / Float(count)
            energies.append(min(avg * 5, 1.0))
            pos = end
        }
        return energies
    }
}
