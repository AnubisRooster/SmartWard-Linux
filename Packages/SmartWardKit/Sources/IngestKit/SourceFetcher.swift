import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import KnowledgeStore

/// Turns what a user (or the onboarding proposal) typed for a source into the
/// URL that is actually fetched. Lenient on purpose: "cs.CL", an arXiv
/// listing URL and a full API query all work for arXiv.
public enum SourceEndpoint {
    public static let hfDailyPapers = URL(string: "https://huggingface.co/api/daily_papers")!
    static let arxivAPI = "https://export.arxiv.org/api/query"
    static let hnSearch = "https://hn.algolia.com/api/v1/search_by_date"
    static let hnFrontPage = "https://hn.algolia.com/api/v1/search"

    public static func fetchURL(kind: SourceKind, input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .hfPapers:
            return hfDailyPapers
        case .arxiv:
            return arxivURL(for: trimmed)
        case .hn:
            return hackerNewsURL(for: trimmed)
        case .githubReleases:
            guard let repo = githubRepo(from: trimmed) else { return nil }
            return URL(string: "https://github.com/\(repo)/releases.atom")
        case .rss, .site, .githubRepo, .manual:
            return webURL(trimmed)
        }
    }

    /// What a `Source` stores for `input`: arXiv and Hacker News keep what
    /// was typed (their fetch URL is rebuilt from it), the rest keep the URL
    /// that's fetched.
    public static func storedAddress(kind: SourceKind, input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let endpoint = fetchURL(kind: kind, input: trimmed) else { return nil }
        switch kind {
        case .arxiv, .hn: return trimmed
        default: return endpoint.absoluteString
        }
    }

    /// An http(s) URL with a dotted host; adds `https://` when the scheme is missing.
    public static func webURL(_ input: String) -> URL? {
        let text = input.contains("://") ? input : "https://" + input
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, host.contains(".") else { return nil }
        return url
    }

    // MARK: arXiv

    /// The arXiv API `search_query` for `input`, or `nil` when `input` is
    /// already a full API URL or can't be read.
    public static func arxivQuery(for input: String) -> String? {
        guard !input.isEmpty else { return nil }
        if input.contains("://") || input.hasPrefix("arxiv.org") {
            guard let url = webURL(input) else { return nil }
            let parts = url.path.split(separator: "/").map(String.init)
            if parts.count >= 2, parts[0] == "list" { return "cat:\(parts[1])" }
            return nil
        }
        if input.contains(":") { return input }

        let terms = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !terms.isEmpty, terms.allSatisfy(isArxivCategory) {
            return terms.map { "cat:\($0)" }.joined(separator: " OR ")
        }
        return input.contains(" ") ? "all:\"\(input)\"" : "all:\(input)"
    }

    static func isArxivCategory(_ text: String) -> Bool {
        text.range(of: #"^[a-z-]+(\.[A-Za-z-]+)?$"#, options: .regularExpression) != nil
            && (text.contains(".") || ["cs", "econ", "eess", "math", "physics", "q-bio", "q-fin", "stat"].contains(text))
    }

    static func arxivURL(for input: String) -> URL? {
        if let url = webURL(input), url.host?.hasSuffix("arxiv.org") == true, url.path.hasPrefix("/api/query") {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.scheme = "https"
            return components?.url
        }
        guard let query = arxivQuery(for: input) else { return nil }
        var components = URLComponents(string: arxivAPI)!
        components.queryItems = [
            URLQueryItem(name: "search_query", value: query),
            URLQueryItem(name: "sortBy", value: "submittedDate"),
            URLQueryItem(name: "sortOrder", value: "descending"),
            URLQueryItem(name: "max_results", value: "50"),
        ]
        return components.url
    }

    // MARK: Hacker News

    /// Front page for an empty input or a news.ycombinator.com link; otherwise
    /// the newest stories matching the text with at least a few points.
    static func hackerNewsURL(for input: String) -> URL? {
        if input.contains("://") || input.hasPrefix("hn.algolia.com") || input.hasPrefix("news.ycombinator.com") {
            guard let url = webURL(input) else { return nil }
            if url.host == "hn.algolia.com" { return url }
            if url.host == "news.ycombinator.com" { return hackerNewsURL(for: "") }
        }
        if input.isEmpty {
            var components = URLComponents(string: hnFrontPage)!
            components.queryItems = [URLQueryItem(name: "tags", value: "front_page"),
                                     URLQueryItem(name: "hitsPerPage", value: "50")]
            return components.url
        }
        var components = URLComponents(string: hnSearch)!
        components.queryItems = [
            URLQueryItem(name: "query", value: input),
            URLQueryItem(name: "tags", value: "story"),
            URLQueryItem(name: "numericFilters", value: "points>=5"),
            URLQueryItem(name: "hitsPerPage", value: "30"),
        ]
        return components.url
    }

    // MARK: GitHub

    static func githubRepo(from input: String) -> String? {
        if let fullName = ProjectLink.githubRepoFullName(from: input) { return fullName }
        if input.range(of: #"^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil {
            return input
        }
        return nil
    }
}

/// A `Source` read into a value, so fetching can run off the main actor.
public struct SourceDescriptor: Equatable, Sendable {
    public var id: UUID
    public var kind: SourceKind
    public var url: String
    public var etag: String?
    public var lastModified: String?

    public init(id: UUID = UUID(), kind: SourceKind, url: String, etag: String? = nil, lastModified: String? = nil) {
        self.id = id
        self.kind = kind
        self.url = url
        self.etag = etag
        self.lastModified = lastModified
    }

    public init(_ source: Source) {
        self.init(id: source.id, kind: source.sourceKind, url: source.url,
                  etag: source.etag, lastModified: source.lastModified)
    }
}

/// What one fetch of a source returned.
public struct FetchedSource: Equatable, Sendable {
    public var items: [RawItem]
    /// The feed's own title, for naming a new source.
    public var title: String
    public var etag: String?
    public var lastModified: String?
    /// Set when the source URL was a web page advertising a feed: the feed's URL.
    public var discoveredFeedURL: String?

    public init(items: [RawItem], title: String = "", etag: String? = nil,
                lastModified: String? = nil, discoveredFeedURL: String? = nil) {
        self.items = items
        self.title = title
        self.etag = etag
        self.lastModified = lastModified
        self.discoveredFeedURL = discoveredFeedURL
    }
}

/// Fetches and parses sources through the `PolitenessGate`. GET only.
public struct SourceFetcher: Sendable {
    public static let maxResponseBytes = 5 * 1024 * 1024

    private let gate: PolitenessGate

    public init(gate: PolitenessGate) {
        self.gate = gate
    }

    /// `nil` when the server says nothing changed since the last fetch (304).
    public func fetch(_ source: SourceDescriptor) async throws -> FetchedSource? {
        guard let url = SourceEndpoint.fetchURL(kind: source.kind, input: source.url) else {
            throw IngestError.invalidURL(source.url)
        }
        guard source.kind.isPolled else { return FetchedSource(items: []) }

        let checkRobots = source.kind == .site
        guard let (data, response) = try await get(url, etag: source.etag,
                                                    lastModified: source.lastModified,
                                                    checkRobots: checkRobots) else { return nil }
        let etag = response.value(forHTTPHeaderField: "ETag")
        let lastModified = response.value(forHTTPHeaderField: "Last-Modified")

        switch source.kind {
        case .hn:
            return FetchedSource(items: try Self.hackerNewsItems(data), title: "Hacker News",
                                 etag: etag, lastModified: lastModified)
        case .hfPapers:
            return FetchedSource(items: try Self.huggingFaceItems(data), title: "Hugging Face daily papers",
                                 etag: etag, lastModified: lastModified)
        case .site:
            let page = try ArticleExtractor.extract(html: Self.decodeText(data, response: response), url: url)
            return FetchedSource(items: [Self.item(from: page, url: url)], title: page.title,
                                 etag: etag, lastModified: lastModified)
        default:
            if let feed = FeedParser.parse(data) {
                return FetchedSource(items: Self.items(from: feed, baseURL: url), title: feed.title,
                                     etag: etag, lastModified: lastModified)
            }
            // A blog's home page instead of its feed: follow the advertised feed.
            guard source.kind == .rss, Self.looksLikeHTML(data, response: response),
                  let feedURLString = ArticleExtractor.feedLinks(inHTML: Self.decodeText(data, response: response),
                                                                 baseURL: url).first,
                  let feedURL = URL(string: feedURLString) else {
                throw IngestError.notAFeed
            }
            guard let (feedData, feedResponse) = try await get(feedURL, etag: nil, lastModified: nil,
                                                                checkRobots: false),
                  let feed = FeedParser.parse(feedData) else {
                throw IngestError.notAFeed
            }
            return FetchedSource(items: Self.items(from: feed, baseURL: feedURL), title: feed.title,
                                 etag: feedResponse.value(forHTTPHeaderField: "ETag"),
                                 lastModified: feedResponse.value(forHTTPHeaderField: "Last-Modified"),
                                 discoveredFeedURL: feedURL.absoluteString)
        }
    }

    /// A single web page's readable text, for "Load full article" and the
    /// pipeline's full-text stage. Honors robots.txt.
    public func fetchArticle(_ url: URL) async throws -> ExtractedArticle {
        guard let (data, response) = try await get(url, etag: nil, lastModified: nil, checkRobots: true) else {
            throw IngestError.invalidResponse
        }
        return try ArticleExtractor.extract(html: Self.decodeText(data, response: response), url: url)
    }

    // MARK: Transport

    private func get(_ url: URL, etag: String?, lastModified: String?,
                     checkRobots: Bool) async throws -> (Data, HTTPURLResponse)? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        if let lastModified { request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since") }

        let (data, response) = try await gate.send(request, checkRobots: checkRobots)
        switch response.statusCode {
        case 200...299:
            guard data.count <= Self.maxResponseBytes else { throw IngestError.tooLarge }
            return (data, response)
        case 304:
            return nil
        case 300...399:
            // The transport follows redirects to public hosts only, so a
            // redirect that reaches here was refused (or can't be followed).
            let host = response.value(forHTTPHeaderField: "Location").flatMap { URL(string: $0)?.host }
            throw IngestError.redirectedAway(host: host)
        default:
            throw IngestError.http(status: response.statusCode)
        }
    }

    // MARK: Parsing

    static func items(from feed: ParsedFeed, baseURL: URL) -> [RawItem] {
        feed.entries.compactMap { entry in
            guard let raw = entry.url, let url = CanonicalURL.canonicalize(raw, relativeTo: baseURL) else {
                return nil
            }
            let summary = ArticleExtractor.plainText(fromHTML: entry.summary)
            let content = ArticleExtractor.plainText(fromHTML: entry.content)
            var title = ArticleExtractor.cleanInline(ArticleExtractor.plainText(fromHTML: entry.title))
            if title.isEmpty { title = String((summary.isEmpty ? content : summary).prefix(90)) }
            if title.isEmpty { title = url }
            return RawItem(url: url, title: title, summary: summary, content: content,
                           author: entry.author,
                           publishedAt: FeedDate.parse(entry.published) ?? FeedDate.parse(entry.updated))
        }
    }

    static func item(from page: ExtractedArticle, url: URL) -> RawItem {
        let canonical = CanonicalURL.canonicalize(url.absoluteString) ?? url.absoluteString
        let firstParagraph = page.text.components(separatedBy: "\n\n").first ?? ""
        return RawItem(url: canonical, title: page.title.isEmpty ? canonical : page.title,
                       summary: String(firstParagraph.prefix(400)), content: page.text,
                       author: page.byline, publishedAt: page.publishedAt)
    }

    static func hackerNewsItems(_ data: Data) throws -> [RawItem] {
        struct Response: Decodable {
            struct Hit: Decodable {
                let objectID: String
                let title: String?
                let url: String?
                let author: String?
                let created_at: String?
                let story_text: String?
            }
            let hits: [Hit]
        }
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
            throw IngestError.invalidResponse
        }
        return response.hits.compactMap { hit in
            let discussion = "https://news.ycombinator.com/item?id=\(hit.objectID)"
            let link = (hit.url?.isEmpty == false ? hit.url : nil) ?? discussion
            guard let url = CanonicalURL.canonicalize(link),
                  let title = hit.title, !title.isEmpty else { return nil }
            return RawItem(url: url, title: ArticleExtractor.cleanInline(title),
                           summary: ArticleExtractor.plainText(fromHTML: hit.story_text ?? ""),
                           author: hit.author, publishedAt: FeedDate.parse(hit.created_at))
        }
    }

    /// Daily papers are arXiv papers, so they use the arXiv abstract URL and
    /// dedupe against the same paper from an arXiv source.
    static func huggingFaceItems(_ data: Data) throws -> [RawItem] {
        struct Entry: Decodable {
            struct Paper: Decodable {
                struct Author: Decodable { let name: String? }
                let id: String
                let title: String?
                let summary: String?
                let publishedAt: String?
                let authors: [Author]?
            }
            let paper: Paper
            let title: String?
            let publishedAt: String?
        }
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            throw IngestError.invalidResponse
        }
        return entries.compactMap { entry in
            let paper = entry.paper
            guard let url = CanonicalURL.canonicalize("https://arxiv.org/abs/\(paper.id)"),
                  let title = paper.title ?? entry.title, !title.isEmpty else { return nil }
            let authors = (paper.authors ?? []).compactMap(\.name).prefix(8).joined(separator: ", ")
            return RawItem(url: url, title: ArticleExtractor.cleanInline(title),
                           summary: ArticleExtractor.sanitize(paper.summary ?? ""),
                           author: authors.isEmpty ? nil : authors,
                           publishedAt: FeedDate.parse(paper.publishedAt ?? entry.publishedAt))
        }
    }

    // MARK: Text decoding

    static func looksLikeHTML(_ data: Data, response: HTTPURLResponse) -> Bool {
        if let type = response.value(forHTTPHeaderField: "Content-Type")?.lowercased(), type.contains("html") {
            return true
        }
        let head = String(decoding: data.prefix(512), as: UTF8.self).lowercased()
        return head.contains("<!doctype html") || head.contains("<html")
    }

    /// Honors a Latin-1/Windows-1252 charset; everything else is read as UTF-8.
    static func decodeText(_ data: Data, response: HTTPURLResponse) -> String {
        let type = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        if type.contains("charset=iso-8859-1") || type.contains("charset=latin1") {
            return String(data: data, encoding: .isoLatin1) ?? String(decoding: data, as: UTF8.self)
        }
        if type.contains("charset=windows-1252") {
            return String(data: data, encoding: .windowsCP1252) ?? String(decoding: data, as: UTF8.self)
        }
        return String(decoding: data, as: UTF8.self)
    }
}
