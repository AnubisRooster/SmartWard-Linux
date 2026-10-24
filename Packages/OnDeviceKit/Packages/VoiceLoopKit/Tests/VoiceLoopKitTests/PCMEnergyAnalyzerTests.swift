import XCTest
import AVFoundation
@testable import VoiceLoopKit

final class PCMEnergyAnalyzerTests: XCTestCase {

    /// Builds a mono float32 PCM buffer containing exactly `samples`.
    private func makeBuffer(samples: [Float], sampleRate: Double = 22050) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for (i, sample) in samples.enumerated() {
            buffer.floatChannelData![0][i] = sample
        }
        return buffer
    }

    // MARK: - concatenate

    func testConcatenateEmptyReturnsValidEmptyBuffer() {
        let result = PCMEnergyAnalyzer.concatenate([])
        XCTAssertEqual(result.frameLength, 0)
        XCTAssertEqual(result.format.sampleRate, 22050)
        XCTAssertEqual(result.format.channelCount, 1)
    }

    func testConcatenateSingleBufferPassesThrough() {
        let buffer = makeBuffer(samples: [0.1, 0.2, 0.3])
        let result = PCMEnergyAnalyzer.concatenate([buffer])
        XCTAssertEqual(result.frameLength, 3)
    }

    func testConcatenateMergesBuffersInOrder() {
        let first = makeBuffer(samples: [0.5, 0.5])
        let second = makeBuffer(samples: [-0.25, -0.25, -0.25])
        let result = PCMEnergyAnalyzer.concatenate([first, second])

        XCTAssertEqual(result.frameLength, 5)
        let data = result.floatChannelData![0]
        XCTAssertEqual(data[0], 0.5)
        XCTAssertEqual(data[1], 0.5)
        XCTAssertEqual(data[2], -0.25)
        XCTAssertEqual(data[3], -0.25)
        XCTAssertEqual(data[4], -0.25)
    }

    // MARK: - energies

    func testEnergiesOnEmptyBufferReturnsEmptyArray() {
        let buffer = makeBuffer(samples: [])
        XCTAssertEqual(PCMEnergyAnalyzer.energies(for: buffer), [])
    }

    func testEnergiesForConstantSignalMatchesExpectedScaledAmplitude() {
        // 1024 samples of constant amplitude 0.1 → mean abs = 0.1 → *5 = 0.5.
        let buffer = makeBuffer(samples: Array(repeating: 0.1, count: 1024))
        let energies = PCMEnergyAnalyzer.energies(for: buffer, chunkSize: 1024)
        XCTAssertEqual(energies.count, 1)
        XCTAssertEqual(energies[0], 0.5, accuracy: 1e-4)
    }

    func testEnergiesClampsToOne() {
        // Constant amplitude 0.5 → mean abs 0.5 → *5 = 2.5, clamped to 1.0.
        let buffer = makeBuffer(samples: Array(repeating: 0.5, count: 512))
        let energies = PCMEnergyAnalyzer.energies(for: buffer, chunkSize: 512)
        XCTAssertEqual(energies, [1.0])
    }

    func testEnergiesHandlesPartialFinalChunk() {
        // 1500 samples, chunk size 1024 → 2 chunks (1024 + 476).
        let buffer = makeBuffer(samples: Array(repeating: 0.1, count: 1500))
        let energies = PCMEnergyAnalyzer.energies(for: buffer, chunkSize: 1024)
        XCTAssertEqual(energies.count, 2)
        XCTAssertEqual(energies[0], 0.5, accuracy: 1e-4)
        XCTAssertEqual(energies[1], 0.5, accuracy: 1e-4)
    }

    func testEnergiesOfSilenceIsZero() {
        let buffer = makeBuffer(samples: Array(repeating: 0, count: 256))
        let energies = PCMEnergyAnalyzer.energies(for: buffer, chunkSize: 256)
        XCTAssertEqual(energies, [0.0])
    }
}
