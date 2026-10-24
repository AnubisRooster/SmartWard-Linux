import ArgumentParser
import Foundation
import KnowledgeStore
import Pipeline
import SmartWardCore
import SwiftData

@main
struct SmartWardCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "smartward",
        abstract: "A local-first research strategist: follow sources, search them, ask questions, get a digest.",
        discussion: "Everything runs on this machine. Models come from a local Ollama server.",
        subcommands: [Add.self, Sources.self, Ingest.self, Status.self, Search.self, Ask.self, Digest.self, Read.self,
                      Voices.self, Voice.self, Profile.self, SettingsPage.self])
}

struct Library: ParsableArguments {
    @Option(name: .long, help: "Library file. Default: ~/.local/share/smartward/default.store")
    var store: String?
    @Option(name: .long, help: "Settings file. Default: ~/.config/smartward/config.json")
    var config: String?
    @Option(name: .long, help: "Chat model served by Ollama (overrides Settings).")
    var chatModel: String?
    @Option(name: .long, help: "Embedding model served by Ollama (overrides Settings).")
    var embedModel: String?
    @Option(name: .long, help: "Ollama address; it must be on this machine (overrides Settings).")
    var ollamaURL: String?

    func settingsStore() -> SettingsStore {
        config.map { SettingsStore(url: URL(fileURLWithPath: $0)) } ?? SettingsStore()
    }

    func settings() throws -> AppSettings { try settingsStore().load() }

    func speechURL(_ settings: AppSettings) throws -> URL {
        guard let url = URL(string: settings.speechURL) else { throw ValidationError("Not a URL: \(settings.speechURL)") }
        return url
    }

    @MainActor
    func engine() throws -> SmartWardEngine {
        var models = try settings().models
        if let ollamaURL {
            guard let url = URL(string: ollamaURL) else { throw ValidationError("Not a URL: \(ollamaURL)") }
            models.baseURL = url
        }
        if let chatModel { models.chatModel = chatModel }
        if let embedModel { models.embeddingModel = embedModel }
        return try SmartWardEngine(storeURL: store.map { URL(fileURLWithPath: $0) }, models: models)
    }
}

private func say(_ text: String = "") { print(text); fflush(stdout) }
private func note(_ text: String) { FileHandle.standardError.write(Data((text + "\n").utf8)) }

extension SmartWardCLI {
    struct Add: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Follow a source.",
            discussion: "KIND is one of: " + SmartWardEngine.kindNames.map(\.name).joined(separator: ", ")
                + ". ADDRESS is a feed or page URL, an arXiv search, a Hacker News search, or owner/repo for GitHub releases.")
        @OptionGroup var library: Library
        @Argument(help: "rss, site, arxiv, hn, github-releases or hf-papers") var kind: String
        @Argument(help: "The address.") var address: String
        @Option(name: .long, help: "A name for the source.") var title: String?

        @MainActor func run() async throws {
            guard let sourceKind = SmartWardEngine.kind(named: kind) else {
                throw ValidationError("Unknown kind \"\(kind)\". Use one of: "
                    + SmartWardEngine.kindNames.map(\.name).joined(separator: ", "))
            }
            let source = try library.engine().addSource(kind: sourceKind, address: address, title: title)
            say("Following \(source.title) (\(kind)). Run `smartward ingest` to fetch it.")
        }
    }

    struct Sources: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List the sources you follow.")
        @OptionGroup var library: Library

        @MainActor func run() async throws {
            let sources = try library.engine().sources()
            if sources.isEmpty { return say("No sources yet. Add one with `smartward add rss https://…`.") }
            for source in sources {
                let state = source.lastError.map { "failed: \($0)" }
                    ?? source.lastFetchedAt.map { "fetched \($0.formatted(date: .abbreviated, time: .shortened))" }
                    ?? "not fetched yet"
                say("\(source.isEnabled ? "•" : "○") \(source.title)  [\(source.kind)]  \(state)")
                say("    \(source.url)")
            }
        }
    }

    struct Ingest: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Fetch your sources, then index what's new.",
            discussion: "Indexing triages, embeds, summarizes and links each article with the local model, "
                + "so it can take a while. It stops after --minutes and picks up where it left off next time.")
        @OptionGroup var library: Library
        @Option(name: .long, help: "Stop indexing after this many minutes.") var minutes: Double = 10
        @Flag(name: .long, help: "Don't fetch sources; only index what's already there.") var skipFetch = false
        @Flag(name: .long, help: "Fetch only; don't index.") var fetchOnly = false

        @MainActor func run() async throws {
            let engine = try library.engine()
            if !skipFetch {
                let summary = try await engine.refresh()
                say("Fetched \(summary.sources) source(s): \(summary.added) new item(s).")
                for failure in summary.failures { say("  ! \(failure)") }
            }
            if fetchOnly { return }
            var last = -1
            let report = try await engine.process(budget: minutes * 60) { completed, total in
                guard total > 0, completed != last else { return }
                last = completed
                note("\rindexing \(completed)/\(total)")
            }
            note("")
            say("Indexed: \(report.triaged) kept, \(report.triagedOut) off-topic, \(report.embedded) embedded, "
                + "\(report.linked) linked, \(report.summarized) summarized.")
            if report.remaining > 0 { say("\(report.remaining) article(s) still waiting; run `smartward ingest --skip-fetch` again.") }
        }
    }

    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "What's in the library and which models are available.")
        @OptionGroup var library: Library

        @MainActor func run() async throws {
            let status = try await library.engine().status()
            say("Sources:  \(status.sources)")
            say("Articles: \(status.articles) (\(status.searchable) searchable)")
            say("Waiting:  \(status.backlog.notSearchable) to index, \(status.backlog.graphPending) to link, "
                + "\(status.backlog.graphSkipped) left out of the graph")
            say("Ollama:   \(status.ollamaReachable ? "running" : "not reachable")")
            say("Chat:     \(status.chatModel ?? "unavailable")")
            say("Embeds:   \(status.embeddingModel ?? "unavailable (search uses keywords only)")")
        }
    }

    struct Search: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Search everything you've read, by words and meaning.")
        @OptionGroup var library: Library
        @Option(name: .shortAndLong, help: "How many results.") var limit: Int = 8
        @Argument(help: "What to look for.") var query: [String]

        @MainActor func run() async throws {
            let results = try await library.engine().search(query.joined(separator: " "), limit: limit)
            if results.isEmpty { return say("No matches.") }
            for (index, result) in results.enumerated() {
                say("\(index + 1). \(result.title)")
                say("   \(result.source.isEmpty ? "" : result.source + " · ")\(result.matchedBy) · \(result.url)")
                say("   \(result.snippet.replacingOccurrences(of: "\n", with: " "))")
            }
        }
    }

    struct Ask: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Ask a question; the answer cites your library.")
        @OptionGroup var library: Library
        @Argument(help: "Your question.") var question: [String]

        @MainActor func run() async throws {
            let answer = try await library.engine().ask(question.joined(separator: " "))
            say(answer.text)
            if !answer.sources.isEmpty {
                say("\nSources:")
                for source in answer.sources { say("  [\(source.id)] \(source.title) — \(source.why)") }
            }
        }
    }

    struct Digest: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "What's new since the last digest, grouped by theme.")
        @OptionGroup var library: Library

        @MainActor func run() async throws {
            guard let digest = try await library.engine().digest() else {
                return say("Nothing new to digest yet. Run `smartward ingest` first.")
            }
            say("Digest for \(digest.periodStart.formatted(date: .abbreviated, time: .omitted)) – "
                + "\(digest.periodEnd.formatted(date: .abbreviated, time: .omitted))\n")
            for cluster in digest.clusters {
                say("## \(cluster.title)")
                say(cluster.summary.isEmpty ? cluster.themes.joined(separator: ", ") : cluster.summary)
                if !cluster.projects.isEmpty { say("Projects: " + cluster.projects.map(\.name).joined(separator: ", ")) }
                for article in cluster.articles { say("  - \(article.title) \(article.url)") }
                say()
            }
        }
    }

    struct Read: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Read an article aloud with a local voice.",
            discussion: "Picks the best search match for WORDS (or the newest article if you give none) and reads it "
                + "through a local text-to-speech server that speaks the OpenAI /v1/audio/speech API, such as "
                + "Kokoro-FastAPI or tools/kokoro-server in this repository. The server must be on this machine. "
                + "Voice, speed and how much is read come from the default profile or voice in Settings; the options below override them.")
        @OptionGroup var library: Library
        @Option(name: .long, help: "A saved reading profile (see `smartward profile`).") var profile: String?
        @Flag(name: .long, help: "Read only the title and the five-question summary.") var summary = false
        @Option(name: .long, help: "Voice name (see `smartward voices`).") var voice: String?
        @Option(name: .long, help: "Speaking speed, 1.0 is normal.") var speed: Double?
        @Option(name: .long, help: "Speech server address; it must be on this machine.") var ttsURL: String?
        @Option(name: .long, help: "Also save the reading to this WAV file.") var out: String?
        @Flag(name: .long, help: "Don't play it; only save (use with --out).") var noPlay = false
        @Argument(help: "Words to find the article by.") var words: [String] = []

        @MainActor func run() async throws {
            let settings = try library.settings()
            let reading = try settings.reading(profile: profile)
            let address = ttsURL ?? settings.speechURL
            guard let url = URL(string: address) else { throw ValidationError("Not a URL: \(address)") }
            if noPlay && out == nil { throw ValidationError("--no-play needs --out.") }
            let chosenVoice = voice ?? reading.voice
            guard AppSettings.isVoiceName(chosenVoice) else { throw ValidationError("\"\(chosenVoice)\" isn't a voice name like af_heart.") }
            let speech = try SpeechClient(baseURL: url, voice: chosenVoice, speed: speed ?? reading.speed)
            guard await speech.isReachable() else {
                throw ValidationError("No speech server at \(address). See tools/kokoro-server/README.md to start one.")
            }
            var player: CommandAudioPlayer?
            if !noPlay {
                player = CommandAudioPlayer.detect()
                if player == nil {
                    throw ValidationError("No audio player found. Install pipewire-utils, pulseaudio-utils, alsa-utils, "
                        + "ffmpeg or mpv, or use --out with --no-play.")
                }
            }
            let scope = summary ? ReadoutScope.summaryOnly : reading.scope.readoutScope
            let result = try await library.engine().read(
                words.joined(separator: " "), scope: scope,
                speech: speech, player: player, keepAudio: out != nil) { number, count, text in
                    note("[\(number)/\(count)] \(text.prefix(90))")
                }
            if let out, let audio = result.audio {
                try audio.write(to: URL(fileURLWithPath: out))
                say("Saved \(result.segments) piece(s) of \"\(result.title)\" to \(out).")
            } else {
                say("Read \"\(result.title)\".")
            }
        }
    }

    // MARK: Voice and settings

    struct Voices: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List the voices the speech server offers.")
        @OptionGroup var library: Library

        @MainActor func run() async throws {
            let settings = try library.settings()
            let speech = try SpeechClient(baseURL: try library.speechURL(settings))
            let names = try await speech.voices()
            var groups: [String: [String]] = [:]
            for name in names { groups[String(name.prefix(2)), default: []].append(String(name.dropFirst(3))) }
            for (prefix, voices) in groups.sorted(by: { $0.key < $1.key }) {
                say("\(prefix)_  \(voices.joined(separator: " "))")
            }
            say("\nCurrent default: \(settings.voice) at \(settings.speed)×. Hear one with `smartward voice sample NAME`.")
        }
    }

    struct Voice: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Choose or hear the reading voice.",
            subcommands: [Use.self, Sample.self])

        struct Use: AsyncParsableCommand {
            static let configuration = CommandConfiguration(abstract: "Save a voice (and optionally a speed) as the default.")
            @OptionGroup var library: Library
            @Argument(help: "A voice name such as af_heart or bf_emma.") var name: String
            @Option(name: .long, help: "Speed, 0.5 to 2.0.") var speed: Double?

            @MainActor func run() async throws {
                var settings = try library.settings()
                settings.voice = name
                if let speed { settings.speed = speed }
                settings.activeProfile = nil
                try library.settingsStore().save(settings)
                say("Default voice: \(settings.voice) at \(settings.speed)×.")
            }
        }

        struct Sample: AsyncParsableCommand {
            static let configuration = CommandConfiguration(abstract: "Hear a voice read one sentence.")
            @OptionGroup var library: Library
            @Argument(help: "A voice name.") var name: String
            @Option(name: .long, help: "Speed, 0.5 to 2.0.") var speed: Double?

            @MainActor func run() async throws {
                let settings = try library.settings()
                let speech = try SpeechClient(baseURL: try library.speechURL(settings), voice: name, speed: speed ?? settings.speed)
                guard AppSettings.isVoiceName(name) else { throw ValidationError("\"\(name)\" isn't a voice name like af_heart.") }
                guard await speech.isReachable() else { throw ValidationError("No speech server at \(settings.speechURL).") }
                guard let player = CommandAudioPlayer.detect() else { throw ValidationError("No audio player found.") }
                try await player.play(try await speech.synthesize(SettingsService.sampleSentence))
            }
        }
    }

    struct Profile: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Named ways of reading: a voice, a speed and how much to read.",
            subcommands: [List.self, Set.self, Remove.self, Use.self],
            defaultSubcommand: List.self)

        struct List: AsyncParsableCommand {
            static let configuration = CommandConfiguration(abstract: "Show the saved profiles.")
            @OptionGroup var library: Library

            @MainActor func run() async throws {
                let settings = try library.settings()
                if settings.profiles.isEmpty { return say("No profiles yet. Add one with `smartward profile set commute --voice bf_emma --speed 1.2 --scope summary`.") }
                for (name, profile) in settings.profiles.sorted(by: { $0.key < $1.key }) {
                    say("\(settings.activeProfile == name ? "*" : " ") \(name): \(profile.voice), \(profile.speed)×, reads \(profile.scope == .whole ? "the whole article" : "title and summary")")
                }
            }
        }

        struct Set: AsyncParsableCommand {
            static let configuration = CommandConfiguration(abstract: "Create or change a profile.")
            @OptionGroup var library: Library
            @Argument(help: "The profile's name.") var name: String
            @Option(name: .long, help: "Voice name.") var voice: String?
            @Option(name: .long, help: "Speed, 0.5 to 2.0.") var speed: Double?
            @Option(name: .long, help: "whole or summary.") var scope: ReadingProfile.Scope?

            @MainActor func run() async throws {
                var settings = try library.settings()
                var profile = settings.profiles[name] ?? ReadingProfile(voice: settings.voice, speed: settings.speed)
                if let voice { profile.voice = voice }
                if let speed { profile.speed = speed }
                if let scope { profile.scope = scope }
                settings.profiles[name] = profile
                try library.settingsStore().save(settings)
                say("Saved profile \"\(name)\": \(profile.voice), \(profile.speed)×, reads \(profile.scope.rawValue).")
            }
        }

        struct Remove: AsyncParsableCommand {
            static let configuration = CommandConfiguration(abstract: "Delete a profile.")
            @OptionGroup var library: Library
            @Argument(help: "The profile's name.") var name: String

            @MainActor func run() async throws {
                var settings = try library.settings()
                guard settings.profiles.removeValue(forKey: name) != nil else { throw SettingsError.unknownProfile(name) }
                if settings.activeProfile == name { settings.activeProfile = nil }
                try library.settingsStore().save(settings)
                say("Removed \"\(name)\".")
            }
        }

        struct Use: AsyncParsableCommand {
            static let configuration = CommandConfiguration(abstract: "Make a profile the default (or `none` to clear it).")
            @OptionGroup var library: Library
            @Argument(help: "The profile's name, or none.") var name: String

            @MainActor func run() async throws {
                var settings = try library.settings()
                if name.lowercased() == "none" {
                    settings.activeProfile = nil
                } else {
                    guard settings.profiles[name] != nil else { throw SettingsError.unknownProfile(name) }
                    settings.activeProfile = name
                }
                try library.settingsStore().save(settings)
                say(settings.activeProfile.map { "Default profile: \($0)." } ?? "No default profile; the saved voice is used.")
            }
        }
    }

    struct SettingsPage: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "settings",
            abstract: "Open the Settings page in your browser.",
            discussion: "Serves a page on 127.0.0.1 only, protected by a random token in the address. "
                + "Choose the voice (with a Listen button), speed, reading profiles and models. Press Ctrl-C to stop.")
        @OptionGroup var library: Library
        @Option(name: .long, help: "Port to listen on.") var port: Int = 8765
        @Flag(name: .long, help: "Print the address but don't open a browser.") var noOpen = false

        @MainActor func run() async throws {
            var generator = SystemRandomNumberGenerator()
            let token = (0..<24).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max, using: &generator)) }.joined()
            let store = library.settingsStore()
            let box = ServiceBox()
            let server = LoopbackHTTPServer { request in await box.service?.handle(request) ?? HTTPResponse(status: 503) }
            let bound: Int
            do { bound = try server.start(port: port) } catch { bound = try server.start(port: 0) }
            box.service = SettingsService(store: store, token: token, port: bound)
            let address = "http://127.0.0.1:\(bound)/?t=\(token)"
            say("Settings: \(address)")
            say("Config file: \(store.url.path)\nPress Ctrl-C to stop.")
            if !noOpen {
                let opener = Process()
                opener.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                opener.arguments = ["xdg-open", address]
                opener.standardOutput = FileHandle.nullDevice
                opener.standardError = FileHandle.nullDevice
                try? opener.run()
            }
            while true { try await Task.sleep(nanoseconds: 3_600_000_000_000) }
        }
    }

    private final class ServiceBox: @unchecked Sendable { var service: SettingsService? }
}

extension ReadingProfile.Scope: ExpressibleByArgument {}
