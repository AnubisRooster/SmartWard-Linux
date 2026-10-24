import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// A parsed RSS 2.0, RSS 1.0 (RDF) or Atom document, including arXiv's API
/// responses and GitHub's `releases.atom`. Item text is still raw (often
/// HTML); `SourceFetcher` cleans it.
public struct ParsedFeed: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public var link: String?
        public var id: String?
        public var title = ""
        public var summary = ""
        public var content = ""
        public var author: String?
        public var published: String?
        public var updated: String?

        public init() {}

        /// The entry's URL: its link, or an id that is itself a URL (RSS guids, arXiv ids).
        public var url: String? {
            if let link, !link.isEmpty { return link }
            if let id, id.hasPrefix("http://") || id.hasPrefix("https://") { return id }
            return nil
        }
    }

    public var title = ""
    public var entries: [Entry] = []

    public init(title: String = "", entries: [Entry] = []) {
        self.title = title
        self.entries = entries
    }
}

public enum FeedParser {
    /// `nil` when `data` isn't a feed (e.g. an HTML page or malformed XML).
    public static func parse(_ data: Data) -> ParsedFeed? {
        let parser = XMLParser(data: data)
        let delegate = FeedXMLDelegate()
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false
        let succeeded = parser.parse()
        // Keep what parsed before a late error: many real feeds have a stray
        // bad entity near the end.
        guard delegate.sawFeedRoot, succeeded || !delegate.feed.entries.isEmpty else { return nil }
        return delegate.feed
    }
}

private final class FeedXMLDelegate: NSObject, XMLParserDelegate {
    private(set) var feed = ParsedFeed()
    private(set) var sawFeedRoot = false

    private var path: [String] = []
    private var entry: ParsedFeed.Entry?
    private var text = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = elementName.lowercased()
        if path.isEmpty, name == "rss" || name == "feed" || name == "rdf:rdf" {
            sawFeedRoot = true
        }
        path.append(name)
        text = ""

        switch name {
        case "item", "entry":
            entry = ParsedFeed.Entry()
        case "link":
            // Atom: <link rel="alternate" href="..."/>. The first alternate wins.
            if var current = entry, let href = attributeDict["href"] {
                let rel = attributeDict["rel"] ?? "alternate"
                if rel == "alternate", current.link == nil {
                    current.link = href
                    entry = current
                }
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let name = elementName.lowercased()
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parent = path.count >= 2 ? path[path.count - 2] : ""
        defer {
            if !path.isEmpty { path.removeLast() }
            text = ""
        }

        guard var current = entry else {
            if name == "title", feed.title.isEmpty, parent == "channel" || parent == "feed" {
                feed.title = value
            }
            return
        }

        switch name {
        case "item", "entry":
            feed.entries.append(current)
            entry = nil
            return
        case "title" where parent == "item" || parent == "entry":
            current.title = value
        case "link":
            // RSS: <link>https://...</link>
            if current.link == nil, !value.isEmpty { current.link = value }
        case "guid", "id":
            if current.id == nil { current.id = value }
        case "pubdate", "published", "dc:date", "issued":
            if current.published == nil { current.published = value }
        case "updated", "modified":
            if current.updated == nil { current.updated = value }
        case "description", "summary":
            if current.summary.isEmpty { current.summary = value }
        case "content:encoded", "content":
            if current.content.isEmpty { current.content = value }
        case "dc:creator":
            if current.author == nil, !value.isEmpty { current.author = value }
        case "author":
            // RSS puts the author inline; Atom nests <name>, handled below.
            if current.author == nil, !value.isEmpty { current.author = value }
        case "name" where parent == "author":
            if !value.isEmpty {
                current.author = current.author.map { "\($0), \(value)" } ?? value
            }
        default:
            break
        }
        entry = current
    }
}
