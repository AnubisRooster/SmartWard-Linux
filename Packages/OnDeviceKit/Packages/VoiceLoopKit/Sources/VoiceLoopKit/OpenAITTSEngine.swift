import Foundation
import AVFoundation

/// Text-to-speech via OpenAI's `/v1/audio/speech` endpoint — a second
/// cloud-TTS alternative to the on-device `SpeechService`, alongside
/// `ElevenLabsTTSEngine`.
///
/// Synthesizes the reply to MP3, decodes it to compute amplitude energies
/// (via `PCMEnergyAnalyzer`) for lip-sync/waveform UI, plays it back, and
/// drives progress callbacks against the playback clock. The network fetch
/// and decode happen off the main actor; playback and callbacks run on the
/// main actor.
@MainActor
public final class OpenAITTSEngine: NSObject {
    public enum TTSError: LocalizedError, Sendable {
        case missingKey
        case http(Int, String)
        case emptyAudio
        case decodeFailed

        public var errorDescription: String? {
            switch self {
            case .missingKey: return "No OpenAI API key configured."
            case .http(let code, let body): return "OpenAI error \(code): \(body)"
            case .emptyAudio: return "OpenAI returned no audio."
            case .decodeFailed: return "Could not decode the synthesized audio."
            }
        }
    }

    /// OpenAI has no list-voices endpoint — this is the fixed set of built-in voices.
    public static let availableVoices: [String] = [
        "alloy", "ash", "coral", "echo", "fable", "onyx", "nova", "sage", "shimmer",
    ]
    public static let availableModels: [String] = ["tts-1", "tts-1-hd", "gpt-4o-mini-tts"]
    public static let defaultVoice = "alloy"
    public static let defaultModel = "tts-1"

    /// A clip synthesized ahead of time via `prefetch(...)`, ready to play
    /// immediately with no further network wait via `play(_:...)`.
    public struct PrefetchedClip: Sendable {
        let url: URL
        let text: String
        let energies: [Float]
        let duration: TimeInterval
    }

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private var currentToken: UInt64 = 0
    private var onProgress: ((NSRange) -> Void)?
    private var completion: (() -> Void)?
    private var spokenText = ""
    private var clipDuration: TimeInterval = 0

    public override init() {
        super.init()
    }

    public nonisolated static func isValidKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        return trimmed.count > 20 && !trimmed.contains(" ")
    }

    /// Synthesizes and speaks `text`. Calls `onStart` (with decoded energies
    /// + duration) the moment playback begins, `onProgress` as the playback
    /// clock advances, `completion` when finished, and `onError` if
    /// synthesis fails.
    ///
    /// `speed` (0.25...4.0) is applied server-side by OpenAI during
    /// synthesis — unlike `ElevenLabsTTSEngine`'s `rate`, this is not also
    /// applied to `AVAudioPlayer.rate`, which would double the effect.
    public func speak(_ text: String,
                      voice: String,
                      model: String,
                      apiKey: String,
                      speed: Double = 1.0,
                      onStart: @escaping ([Float], TimeInterval) -> Void,
                      onProgress: @escaping (NSRange) -> Void,
                      completion: @escaping () -> Void,
                      onError: @escaping (Error) -> Void) {
        stop()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { completion(); return }
        guard Self.isValidKey(apiKey) else { onError(TTSError.missingKey); return }

        currentToken &+= 1
        let token = currentToken
        let clampedSpeed = max(0.25, min(speed, 4.0))

        Task.detached(priority: .userInitiated) {
            do {
                let audio = try await Self.synthesize(text: trimmed, voice: voice, model: model,
                                                       apiKey: apiKey, speed: clampedSpeed)
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("openai_tts_\(token).mp3")
                try audio.write(to: url)
                let (energies, duration) = Self.decodeEnergies(from: url)
                await MainActor.run {
                    guard self.currentToken == token else { return }
                    self.beginPlayback(url: url, text: trimmed, energies: energies, duration: duration,
                                       onStart: onStart, onProgress: onProgress, completion: completion, onError: onError)
                }
            } catch {
                await MainActor.run {
                    guard self.currentToken == token else { return }
                    onError(error)
                }
            }
        }
    }

    public func stop() {
        currentToken &+= 1
        progressTimer?.invalidate()
        progressTimer = nil
        player?.stop()
        player = nil
        completion = nil
        onProgress = nil
    }

    /// Synthesizes `text` to a playable clip without starting playback.
    /// Lets a caller kick off the network round trip for a sentence while a
    /// reply is still being generated, then play the result later via
    /// `play(_:...)` with no further wait. Throws the same `TTSError` cases
    /// `speak(...)` would report through `onError`.
    public nonisolated static func prefetch(_ text: String,
                                            voice: String,
                                            model: String,
                                            apiKey: String,
                                            speed: Double = 1.0) async throws -> PrefetchedClip {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TTSError.emptyAudio }
        guard isValidKey(apiKey) else { throw TTSError.missingKey }

        let clampedSpeed = max(0.25, min(speed, 4.0))
        let audio = try await synthesize(text: trimmed, voice: voice, model: model,
                                         apiKey: apiKey, speed: clampedSpeed)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("openai_tts_prefetch_\(UUID().uuidString).mp3")
        try audio.write(to: url)
        let (energies, duration) = decodeEnergies(from: url)
        return PrefetchedClip(url: url, text: trimmed, energies: energies, duration: duration)
    }

    /// Plays a clip already synthesized by `prefetch(...)`. Same callback
    /// contract as `speak(...)`, minus the network/synthesis wait.
    public func play(_ clip: PrefetchedClip,
                     onStart: @escaping ([Float], TimeInterval) -> Void,
                     onProgress: @escaping (NSRange) -> Void,
                     completion: @escaping () -> Void,
                     onError: @escaping (Error) -> Void) {
        stop()
        beginPlayback(url: clip.url, text: clip.text, energies: clip.energies, duration: clip.duration,
                     onStart: onStart, onProgress: onProgress, completion: completion, onError: onError)
    }

    // MARK: - Playback (main actor)

    private func beginPlayback(url: URL, text: String, energies: [Float], duration: TimeInterval,
                               onStart: ([Float], TimeInterval) -> Void,
                               onProgress: @escaping (NSRange) -> Void,
                               completion: @escaping () -> Void,
                               onError: (Error) -> Void) {
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            guard p.prepareToPlay() else { onError(TTSError.decodeFailed); return }
            player = p
            spokenText = text
            clipDuration = p.duration > 0 ? p.duration : duration
            self.onProgress = onProgress
            self.completion = completion

            onStart(energies, clipDuration)
            p.play()
            startProgressTimer()
        } catch {
            onError(error)
        }
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tickProgress() }
        }
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
    }

    private func tickProgress() {
        guard let player, clipDuration > 0 else { return }
        // Drive beat progress by playback fraction so callers keying beats to
        // character offsets fire in step with the audio.
        let fraction = min(max(player.currentTime / clipDuration, 0), 1)
        let location = Int(fraction * Double(spokenText.count))
        onProgress?(NSRange(location: location, length: 0))
    }

    // MARK: - Networking & decode (off main)

    private nonisolated static func synthesize(text: String, voice: String, model: String,
                                                apiKey: String, speed: Double) async throws -> Data {
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/speech")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model.isEmpty ? defaultModel : model,
            "input": text,
            "voice": voice.isEmpty ? defaultVoice : voice,
            "response_format": "mp3",
            "speed": speed,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 30

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            throw TTSError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard !data.isEmpty else { throw TTSError.emptyAudio }
        return data
    }

    /// Decodes the MP3 to PCM and computes per-chunk amplitude energies via
    /// `PCMEnergyAnalyzer`, so cloud and on-device playback drive the same
    /// energy-consuming UI consistently.
    private nonisolated static func decodeEnergies(from url: URL) -> ([Float], TimeInterval) {
        guard let file = try? AVAudioFile(forReading: url) else { return ([], 0) }
        let format = file.processingFormat
        let frames = AVAudioFrameCount(file.length)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              (try? file.read(into: buffer)) != nil else { return ([], 0) }
        let energies = PCMEnergyAnalyzer.energies(for: buffer)
        let duration = Double(file.length) / format.sampleRate
        return (energies, duration)
    }
}

extension OpenAITTSEngine: AVAudioPlayerDelegate {
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        progressTimer?.invalidate()
        progressTimer = nil
        let done = completion
        completion = nil
        onProgress = nil
        done?()
    }
}
