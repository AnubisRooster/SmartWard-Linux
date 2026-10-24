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
        subcommands: [Add.self, Sources.self, Ingest.self, Status.self, Search.self, Ask.self, Digest.self])
}

struct Library: ParsableArguments {
    @Option(name: .long, help: "Library file. Default: ~/.local/share/smartward/default.store")
    var store: String?
    @Option(name: .long, help: "Chat model served by Ollama.")
    var chatModel: String = LocalModelConfig.recommendedChatModel
    @Option(name: .long, help: "Embedding model served by Ollama.")
    var embedModel: String = LocalModelConfig.recommendedEmbeddingModel
    @Option(name: .long, help: "Ollama address; it must be on this machine.")
    var ollamaURL: String = OllamaClient.defaultBaseURL.absoluteString

    @MainActor
    func engine() throws -> SmartWardEngine {
        guard let url = URL(string: ollamaURL) else { throw ValidationError("Not a URL: \(ollamaURL)") }
        return try SmartWardEngine(storeURL: store.map { URL(fileURLWithPath: $0) },
                                   models: LocalModelConfig(baseURL: url, chatModel: chatModel, embeddingModel: embedModel))
    }
}

private func say(_ text: String = "") { print(text) }
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
}
