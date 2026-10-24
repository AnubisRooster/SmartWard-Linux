import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import SwiftData
import KnowledgeStore

/// What one sync of a linked repo fetched (PLAN §5.8). Source code is never
/// fetched: only docs, architecture reports and dependency manifests.
public struct RepoSnapshot: Equatable, Sendable {
    public struct Document: Equatable, Sendable {
        public let path: String
        public let text: String

        public init(path: String, text: String) {
            self.path = path
            self.text = text
        }
    }

    public let repo: GitHubRepo
    public let etag: String?
    public let documents: [Document]
    public let dependencies: [Dependency]

    public init(repo: GitHubRepo, etag: String?, documents: [Document], dependencies: [Dependency]) {
        self.repo = repo
        self.etag = etag
        self.documents = documents
        self.dependencies = dependencies
    }
}

public enum RepoSync {
    /// Project-context docs worth reading, including the GitNexus and graphify
    /// reports these repos commit from CI. README is fetched separately.
    public static let trackedDocumentPaths = [
        "CLAUDE.md", "AGENTS.md", "ARCHITECTURE.md",
        "docs/ARCHITECTURE.md", "docs/PLAN.md",
        "docs/gitnexus/ARCHITECTURE.md", "docs/graphify/GRAPH_REPORT.md",
    ]
    public static let maxDocumentCharacters = 200_000

    // MARK: Fetch

    /// `nil` when the repo is unchanged since `etag` (one cheap 304).
    public static func fetch(_ fullName: String, etag: String?, client: GitHubClient) async throws -> RepoSnapshot? {
        guard let (repo, newEtag) = try await client.repository(fullName, etag: etag) else { return nil }

        // One tree listing avoids a 404 per missing file (they count against the rate limit).
        let existing = try await client.filePaths(repo.fullName, branch: repo.defaultBranch)
        let exists: (String) -> Bool = { path in existing?.contains(path) ?? true }

        var documents: [RepoSnapshot.Document] = []
        let readme = try await client.readme(repo.fullName)
        if let readme {
            documents.append(.init(path: "README.md", text: String(readme.prefix(maxDocumentCharacters))))
        }
        for path in trackedDocumentPaths {
            guard exists(path) else { continue }
            guard let text = try await client.fileText(repo.fullName, path: path) else { continue }
            documents.append(.init(path: path, text: String(text.prefix(maxDocumentCharacters))))
        }

        var dependencies: [Dependency] = []
        for path in ManifestParser.manifestPaths {
            guard exists(path) else { continue }
            guard let text = try await client.fileText(repo.fullName, path: path) else { continue }
            dependencies += ManifestParser.dependencies(path: path, text: text)
        }
        return RepoSnapshot(repo: repo, etag: newEtag, documents: documents, dependencies: dependencies)
    }

    // MARK: Apply

    public struct ApplyResult: Equatable, Sendable {
        public var articlesAdded = 0
        public var articlesUpdated = 0
        public var articlesRemoved = 0
        public var dependenciesPinned = 0
        public var sourcesSuggested = 0

        public init(articlesAdded: Int = 0, articlesUpdated: Int = 0, articlesRemoved: Int = 0,
                    dependenciesPinned: Int = 0, sourcesSuggested: Int = 0) {
            self.articlesAdded = articlesAdded
            self.articlesUpdated = articlesUpdated
            self.articlesRemoved = articlesRemoved
            self.dependenciesPinned = dependenciesPinned
            self.sourcesSuggested = sourcesSuggested
        }
    }

    /// Writes a snapshot into the store for `link`:
    /// - Docs become `Article`s under the link's `github_repo` `Source`, updated
    ///   only when their content hash changes and removed when the doc is gone.
    /// - A private repo's articles are `localOnly`, so they never reach a BYOK
    ///   provider (D5). Visibility is re-read on every sync.
    /// - Dependencies become `tool` theme nodes pinned to the project; GitHub-hosted
    ///   ones get a disabled `github_releases` source as a suggestion (dependency radar).
    @MainActor
    @discardableResult
    public static func apply(_ snapshot: RepoSnapshot, to link: ProjectLink,
                             context: ModelContext, now: Date = Date()) throws -> ApplyResult {
        var result = ApplyResult()
        let repo = snapshot.repo
        let isPrivate = repo.isPrivate

        link.repoFullName = repo.fullName
        link.isPrivate = isPrivate
        link.etag = snapshot.etag
        link.lastSyncedAt = now

        let source = try repoSource(for: link, repo: repo, context: context)

        var byURL: [String: Article] = [:]
        for article in source.articles ?? [] { byURL[article.canonicalURL] = article }

        var currentURLs = Set<String>()
        for document in snapshot.documents {
            let url = "\(repo.htmlURL)/blob/\(repo.defaultBranch)/\(document.path)"
            currentURLs.insert(url)
            let hash = contentHash(document.text)

            if let article = byURL[url] {
                article.localOnly = isPrivate
                if article.contentHash != hash {
                    article.cleanedText = document.text
                    article.contentHash = hash
                    article.stage = .cleaned
                    article.ingestedAt = now
                    result.articlesUpdated += 1
                }
            } else {
                let article = Article(canonicalURL: url, title: "\(repo.fullName)/\(document.path)",
                                      cleanedText: document.text, localOnly: isPrivate)
                article.contentHash = hash
                article.stage = .cleaned
                article.ingestedAt = now
                source.articles?.append(article)
                result.articlesAdded += 1
            }
        }
        for (url, article) in byURL where !currentURLs.contains(url) {
            context.delete(article)
            result.articlesRemoved += 1
        }

        if let project = link.project {
            let pinned = try pinDependencies(snapshot.dependencies, to: project, context: context)
            result.dependenciesPinned = pinned
        }
        result.sourcesSuggested = try suggestReleaseSources(for: snapshot.dependencies, context: context)

        try context.save()
        return result
    }

    static func repoSource(for link: ProjectLink, repo: GitHubRepo, context: ModelContext) throws -> Source {
        if let id = link.sourceID {
            let descriptor = FetchDescriptor<Source>(predicate: #Predicate { $0.id == id })
            if let existing = try context.fetch(descriptor).first { return existing }
        }
        let source = Source(kind: "github_repo", url: repo.htmlURL, title: repo.fullName)
        context.insert(source)
        link.sourceID = source.id
        return source
    }

    static func pinDependencies(_ dependencies: [Dependency], to project: Project, context: ModelContext) throws -> Int {
        let tools = try context.fetch(FetchDescriptor<ThemeNode>(predicate: #Predicate { $0.type == "tool" }))
        var byKey: [String: ThemeNode] = [:]
        for node in tools { byKey[node.normalizedKey] = node }
        let alreadyPinned = Set((project.pinnedNodes ?? []).map(\.id))

        var pinned = 0
        for dependency in dependencies {
            let key = ThemeNode.normalizedKey(type: "tool", label: dependency.name)
            let node: ThemeNode
            if let existing = byKey[key] {
                node = existing
            } else {
                node = ThemeNode(type: "tool", canonicalLabel: dependency.name)
                context.insert(node)
                byKey[key] = node
            }
            if !alreadyPinned.contains(node.id) && !(project.pinnedNodes ?? []).contains(where: { $0.id == node.id }) {
                project.pinnedNodes?.append(node)
                pinned += 1
            }
        }
        return pinned
    }

    static func suggestReleaseSources(for dependencies: [Dependency], context: ModelContext) throws -> Int {
        let existing = try context.fetch(FetchDescriptor<Source>())
        var known = Set(existing.map { $0.url.lowercased() })
        var suggested = 0
        for repo in Set(dependencies.compactMap(\.githubRepo)).sorted() {
            let url = "https://github.com/\(repo)/releases.atom"
            guard known.insert(url.lowercased()).inserted else { continue }
            let source = Source(kind: "github_releases", url: url, title: "\(repo) releases", origin: "dependency_radar")
            source.isEnabled = false
            context.insert(source)
            suggested += 1
        }
        return suggested
    }

    static func contentHash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
