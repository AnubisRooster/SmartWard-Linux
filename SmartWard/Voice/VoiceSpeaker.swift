import AVFoundation

/// Says short things back ("Opening Reading", "I couldn't find that"),
/// with the system voice only and the voice settings from Settings → Voice
/// conversation. Article text is read by `ArticleReadoutController`, not this.
@MainActor
final class VoiceSpeaker {
    static let shared = VoiceSpeaker()

    private let synthesizer = AVSpeechSynthesizer()
    private let delegate = SpeechFinishDelegate()

    /// What it said last, so the listener can tell its voice from yours.
    private(set) var lastSpoken = ""
    private var lastFinishedAt = Date.distantPast
    /// Said, but the synthesizer hasn't reported speaking yet.
    private var pending = false

    /// Speaking now, or only just finished: the microphone is still hearing
    /// the tail of it, and what it said (the help mentions the wake word)
    /// must never be taken as a command.
    var isBusy: Bool {
        pending || synthesizer.isSpeaking || Date().timeIntervalSince(lastFinishedAt) < 1.5
    }

    private init() {
        synthesizer.delegate = delegate
        delegate.onFinish = { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.pending = false
                self.lastFinishedAt = Date()
                // Stop ducking other apps' audio, and give the session back if nothing else has it.
                if !self.synthesizer.isSpeaking { AppAudio.shared.releaseIfIdle() }
            }
        }
    }

    func say(_ text: String) {
        let config = VoiceSettings.current
        say(text, voiceID: config.voiceID, rate: config.ttsRate)
    }

    /// With a given voice and rate: Settings uses it to let you hear a
    /// reading profile before you pick it.
    func say(_ text: String, voiceID: String, rate: Float) {
        guard !text.isEmpty else { return }
        AppAudio.shared.configure(speaking: true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = VoiceSettings.current.ttsPitch
        utterance.voice = VoiceSettings.voice(for: voiceID)
        lastSpoken = text
        pending = true
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    func stop() {
        pending = false
        lastFinishedAt = Date()
        synthesizer.stopSpeaking(at: .immediate)
    }
}
