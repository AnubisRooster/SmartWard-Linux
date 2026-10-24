import Foundation
import UIKit
import AVFoundation
import MediaPlayer
import Observation
import KnowledgeStore
import Pipeline
import VoiceLoopKit

/// Reads an article aloud, a segment at a time (`ArticleReadout`), with
/// pause, keep going, skip and back. Also reads a briefing (your top unread
/// articles, gist first, or today's digest) an item at a time, so you can
/// take in the news without looking.
///
/// - The system voice only (`AVSpeechSynthesizer`): article text, private
///   items included, is never sent to a cloud voice (D5).
/// - It never outlives the app being in front and unlocked: the reader
///   stops it when the app leaves the foreground, locks, or the screen goes
///   away. A phone call or unplugged headphones pause it.
/// - Headphone and Control Center buttons work while it's reading: play,
///   pause, next and previous (an article, in a briefing).
/// - During a briefing the screen is kept awake, so it isn't cut off by the
///   auto-lock while your hands are on the wheel.
@MainActor
@Observable
final class ArticleReadoutController {
    static let shared = ArticleReadoutController()

    private(set) var playback = ReadoutPlayback()
    /// The article being read, while there is a read-aloud of one article.
    /// (A briefing doesn't set it: leaving an article's screen must not end it.)
    private(set) var articleID: UUID?
    /// The briefing being read, if that's what this is.
    private(set) var briefing: Briefing?

    /// What a briefing is made of.
    struct Briefing {
        enum Kind { case articles([Article]), digest }
        let kind: Kind
        /// The title of the item being read now, for the screen.
        var itemTitle = ""
    }

    var isBriefing: Bool { briefing != nil }
    /// What's being said is an answer (the strategist's), not an article or a briefing.
    private(set) var isAnswer = false
    /// The article being briefed now, in a briefing of articles.
    var currentArticle: Article? {
        guard let briefing, case .articles(let articles) = briefing.kind,
              let group = playback.currentGroup, articles.indices.contains(group) else { return nil }
        return articles[group]
    }

    var isActive: Bool { playback.isActive }
    var isPaused: Bool { playback.status == .paused }
    /// Where on the reader screen the voice is, so the screen can follow.
    var currentAnchor: ReadoutSegment.Anchor? { playback.current?.anchor }
    /// The words being said right now, so the listener can tell its own voice from yours.
    var currentText: String { playback.current?.text ?? "" }

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let delegate = SpeechFinishDelegate()
    @ObservationIgnored private var currentUtterance: AVSpeechUtterance?
    @ObservationIgnored private var remoteTargets: [(command: MPRemoteCommand, token: Any)] = []
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var scheduledStop: Task<Void, Never>?
    @ObservationIgnored private var nowPlayingTitle = ""
    @ObservationIgnored private var nowPlayingSource = ""

    private init() {
        synthesizer.delegate = delegate
        delegate.onFinish = { [weak self] id in
            Task { @MainActor in self?.utteranceFinished(id) }
        }
    }

    // MARK: Control

    /// Starts reading `article` from the top, replacing any read-aloud in progress.
    func start(_ article: Article, scope: ReadoutScope = .whole, sourceName: String? = nil) {
        stop()
        let segments = ArticleReadout.segments(for: article, scope: scope, sourceName: sourceName,
                                               clean: SpeechService.speakableText)
        guard !segments.isEmpty else { return }
        articleID = article.id
        nowPlayingTitle = article.title
        nowPlayingSource = sourceName ?? ""
        playback.start(segments)
        activateAudio()
        installRemoteControls()
        speakCurrent()
    }

    /// Starts a briefing of `articles`, replacing any read-aloud in progress.
    /// Returns false when there's nothing to say.
    @discardableResult
    func startBriefing(_ articles: [Article]) -> Bool {
        stop()
        let segments = ArticleBriefing.segments(for: articles, sourceName: { $0.sourceLabel },
                                                clean: SpeechService.speakableText)
        return begin(briefing: Briefing(kind: .articles(articles)), segments: segments, title: "Your briefing")
    }

    /// Starts reading today's digest, a theme at a time.
    @discardableResult
    func startDigest(_ digest: Digest) -> Bool {
        stop()
        let segments = DigestReadout.segments(for: digest, clean: SpeechService.speakableText)
        return begin(briefing: Briefing(kind: .digest), segments: segments, title: "Today's digest")
    }

    /// Reads `text` (already cleaned for speech: the strategist's answer, say) aloud,
    /// with pause, keep going and stop.
    @discardableResult
    func startAnswer(_ text: String, title: String = "SmartWard") -> Bool {
        stop()
        let segments = SpokenAnswer.segments(text)
        guard !segments.isEmpty else { return false }
        isAnswer = true
        nowPlayingTitle = title
        nowPlayingSource = "SmartWard"
        playback.start(segments)
        activateAudio()
        installRemoteControls()
        speakCurrent()
        return true
    }

    private func begin(briefing: Briefing, segments: [ReadoutSegment], title: String) -> Bool {
        guard !segments.isEmpty else { return false }
        self.briefing = briefing
        nowPlayingTitle = title
        nowPlayingSource = "SmartWard"
        playback.start(segments)
        UIApplication.shared.isIdleTimerDisabled = true
        activateAudio()
        installRemoteControls()
        speakCurrent()
        return true
    }

    /// Ends the briefing after `seconds` (SmartWard's lock-after period, for one
    /// started from the lock screen), unless it's cancelled (the app came back in
    /// front) or a different reading has started since.
    func stopBriefing(after seconds: TimeInterval) {
        cancelScheduledStop()
        scheduledStop = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
            guard !Task.isCancelled, let self, self.isBriefing else { return }
            self.stop()
        }
    }

    func cancelScheduledStop() {
        scheduledStop?.cancel()
        scheduledStop = nil
    }

    /// Says the segment being read again, so a new speed applies now, not at the next one.
    func restartSegment() {
        guard playback.status == .playing else { return }
        speakCurrent()
    }

    /// Skips to the next article of a briefing; the article you skip stays unread.
    func nextItem() {
        playback.nextGroup()
        continueAfterSkip()
    }

    func previousItem() {
        playback.previousGroup()
        continueAfterSkip()
    }

    /// Says the current item again from its start.
    func repeatItem() {
        playback.restartGroup()
        continueAfterSkip()
    }

    /// Swaps the gist of the article being briefed for the whole article.
    /// Returns false when there's no such article.
    @discardableResult
    func expandCurrentToFull() -> Bool {
        guard let article = currentArticle else { return false }
        let full = ArticleReadout.segments(for: article, scope: .whole, sourceName: article.sourceLabel,
                                           clean: SpeechService.speakableText)
        guard !full.isEmpty else { return false }
        playback.replaceCurrentGroup(with: full)
        continueAfterSkip()
        return true
    }

    func pause() {
        guard playback.status == .playing else { return }
        playback.pause()
        synthesizer.pauseSpeaking(at: .word)
        updateNowPlaying()
    }

    /// "Keep going".
    func resume() {
        guard playback.status == .paused else { return }
        playback.resume()
        // A call or another app may have taken the audio session meanwhile.
        AppAudio.shared.configure(speaking: true)
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        } else {
            speakCurrent()
        }
        updateNowPlaying()
    }

    func next() {
        playback.next()
        continueAfterSkip()
    }

    func previous() {
        playback.previous()
        continueAfterSkip()
    }

    func stop() {
        guard articleID != nil || briefing != nil || playback.status != .idle else { return }
        playback.stop()
        articleID = nil
        isAnswer = false
        cancelScheduledStop()
        endBriefing()
        currentUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        tearDown()
    }

    // MARK: Speaking

    private func continueAfterSkip() {
        switch playback.status {
        case .playing: speakCurrent()
        case .finished: finish()
        default: break
        }
        updateNowPlaying()
    }

    private func speakCurrent() {
        guard playback.status == .playing, let segment = playback.current else { return }
        followBriefingItem()
        let config = VoiceSettings.current
        // The active reading profile's voice and rate, if there is one.
        let reading = VoiceSettings.reading
        let utterance = AVSpeechUtterance(string: segment.text)
        utterance.rate = reading.rate
        utterance.pitchMultiplier = config.ttsPitch
        utterance.voice = VoiceSettings.voice(for: reading.voiceID)
        // The old utterance stays referenced until this point, so the new
        // one can't share its identity with a callback still on its way.
        currentUtterance = utterance
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    private func utteranceFinished(_ id: ObjectIdentifier) {
        guard let current = currentUtterance, ObjectIdentifier(current) == id,
              playback.status == .playing else { return }
        let group = playback.currentGroup
        playback.segmentFinished()
        // An article heard to its end is read; one skipped stays unread.
        if playback.currentGroup != group || playback.status == .finished { markHeard(group) }
        if playback.status == .playing {
            speakCurrent()
        } else {
            finish()
        }
    }

    /// Read to the end.
    private func finish() {
        playback.stop()
        articleID = nil
        isAnswer = false
        endBriefing()
        currentUtterance = nil
        tearDown()
    }

    // MARK: Briefing

    /// Keeps the lock-screen title and the screen's view of "what's being
    /// read" on the item now being said.
    private func followBriefingItem() {
        guard let kind = briefing?.kind else { return }
        let title: String
        switch kind {
        case .articles: title = currentArticle?.title ?? "Your briefing"
        case .digest: title = "Today's digest"
        }
        briefing?.itemTitle = title
        nowPlayingTitle = title
    }

    private func markHeard(_ group: Int?) {
        guard let briefing, case .articles(let articles) = briefing.kind,
              let group, articles.indices.contains(group) else { return }
        articles[group].isRead = true
    }

    private func endBriefing() {
        guard briefing != nil else { return }
        briefing = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: Audio session, interruptions, headphone buttons

    private func activateAudio() {
        AppAudio.shared.configure(speaking: true)
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil,
                                            queue: .main) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap { AVAudioSession.InterruptionType(rawValue: $0) }
            guard type == .began else { return }
            Task { @MainActor in self?.pause() }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil,
                                            queue: .main) { [weak self] note in
            let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                .flatMap { AVAudioSession.RouteChangeReason(rawValue: $0) }
            // Headphones pulled out: don't start blaring from the speaker.
            guard reason == .oldDeviceUnavailable else { return }
            Task { @MainActor in self?.pause() }
        })
    }

    private func installRemoteControls() {
        let center = MPRemoteCommandCenter.shared()
        func add(_ command: MPRemoteCommand, _ action: @escaping @MainActor (ArticleReadoutController) -> Void) {
            command.isEnabled = true
            let token = command.addTarget { [weak self] _ in
                Task { @MainActor in
                    if let self { action(self) }
                }
                return .success
            }
            remoteTargets.append((command, token))
        }
        add(center.playCommand) { $0.resume() }
        add(center.pauseCommand) { $0.pause() }
        add(center.togglePlayPauseCommand) { $0.isPaused ? $0.resume() : $0.pause() }
        add(center.nextTrackCommand) { $0.isBriefing ? $0.nextItem() : $0.next() }
        add(center.previousTrackCommand) { $0.isBriefing ? $0.previousItem() : $0.previous() }
        updateNowPlaying()
    }

    private func updateNowPlaying() {
        guard articleID != nil || briefing != nil || isAnswer else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: nowPlayingTitle,
            MPMediaItemPropertyArtist: nowPlayingSource.isEmpty ? "SmartWard" : nowPlayingSource,
            MPNowPlayingInfoPropertyPlaybackRate: isPaused ? 0.0 : 1.0,
        ]
    }

    /// Gives back the audio session and the headphone buttons, so other
    /// apps' audio isn't left ducked and the buttons go back to them.
    private func tearDown() {
        for target in remoteTargets { target.command.removeTarget(target.token) }
        remoteTargets = []
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        AppAudio.shared.releaseIfIdle()
    }
}

/// `AVSpeechSynthesizer` keeps its delegate weakly and wants an `NSObject`.
final class SpeechFinishDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: ((ObjectIdentifier) -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?(ObjectIdentifier(utterance))
    }
}
