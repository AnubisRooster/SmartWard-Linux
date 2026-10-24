import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
import KnowledgeStore
@testable import IngestKit

/// A clock that only moves when the gate "sleeps".
final class FakeClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date
    private(set) var sleeps: [TimeInterval] = []

    init(_ start: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        current = start
    }

    var now: Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func advance(_ seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        current = current.addingTimeInterval(seconds)
    }

    func sleep(_ seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        sleeps.append(seconds)
        current = current.addingTimeInterval(seconds)
    }
}

extension PolitenessGate {
    static func testing(_ transport: FakeTransport, clock: FakeClock, interval: TimeInterval = 1) -> PolitenessGate {
        PolitenessGate(transport: transport, minimumInterval: interval,
                       now: { clock.now }, sleep: { clock.sleep($0) })
    }
}

final class RobotsRulesTests: XCTestCase {
    func testGroupsAndLongestMatch() {
        let text = """
        # comment
        User-agent: Googlebot
        Disallow: /

        User-agent: *
        Disallow: /private/
        Allow: /private/public-note
        Disallow: /*.pdf$
        Disallow:

        User-agent: SmartWard
        User-agent: OtherBot
        Disallow: /drafts
        """
        let general = RobotsRules(parsing: text, userAgent: "SomeReader")
        XCTAssertTrue(general.allows("/"))
        XCTAssertFalse(general.allows("/private/x"))
        XCTAssertTrue(general.allows("/private/public-note"))
        XCTAssertFalse(general.allows("/files/paper.pdf"))
        XCTAssertTrue(general.allows("/files/paper.pdf?download=1"))

        let ours = RobotsRules(parsing: text, userAgent: "SmartWard")
        XCTAssertTrue(ours.allows("/private/x"), "our own group replaces the * group")
        XCTAssertFalse(ours.allows("/drafts/1"))
    }

    func testWildcards() {
        XCTAssertTrue(RobotsRules.matches(pattern: "/a*b", path: "/axxb/c"))
        XCTAssertFalse(RobotsRules.matches(pattern: "/a*b$", path: "/axxb/c"))
        XCTAssertTrue(RobotsRules.matches(pattern: "/a*$", path: "/anything"))
        XCTAssertTrue(RobotsRules.matches(pattern: "*", path: "/"))
        XCTAssertFalse(RobotsRules.matches(pattern: "/b", path: "/a"))
    }
}

final class PolitenessGateTests: XCTestCase {

    func testSpacesRequestsPerHostAndSendsUserAgent() async throws {
        let clock = FakeClock()
        let transport = FakeTransport { _ in (200, [:], "ok") }
        let gate = PolitenessGate.testing(transport, clock: clock, interval: 2)

        for path in ["/a", "/b"] {
            _ = try await gate.send(URLRequest(url: URL(string: "https://feeds.example\(path)")!), checkRobots: false)
        }
        _ = try await gate.send(URLRequest(url: URL(string: "https://other.example/")!), checkRobots: false)

        XCTAssertEqual(clock.sleeps, [2], "second request to the same host waits; another host doesn't")
        XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "User-Agent"), PolitenessGate.userAgent)
    }

    func testBacksOffAfter429UsingRetryAfter() async throws {
        let clock = FakeClock()
        var status = 429
        let transport = FakeTransport { _ in (status, ["Retry-After": "120"], "") }
        let gate = PolitenessGate.testing(transport, clock: clock)
        let request = URLRequest(url: URL(string: "https://busy.example/feed")!)

        do {
            _ = try await gate.send(request, checkRobots: false)
            XCTFail("expected backoff")
        } catch let error as IngestError {
            XCTAssertEqual(error, .backingOff(host: "busy.example", until: clock.now.addingTimeInterval(120)))
        }

        clock.advance(60)
        do {
            _ = try await gate.send(request, checkRobots: false)
            XCTFail("still backing off")
        } catch IngestError.backingOff {
            XCTAssertEqual(transport.requests.count, 1, "no request is sent while backing off")
        }

        clock.advance(61)
        status = 200
        let (_, response) = try await gate.send(request, checkRobots: false)
        XCTAssertEqual(response.statusCode, 200)
    }

    func testRobotsAreFetchedOnceAndHonored() async throws {
        let clock = FakeClock()
        let transport = FakeTransport { request in
            if request.url?.path == "/robots.txt" { return (200, [:], "User-agent: *\nDisallow: /private") }
            return (200, [:], "<html></html>")
        }
        let gate = PolitenessGate.testing(transport, clock: clock)

        _ = try await gate.send(URLRequest(url: URL(string: "https://site.example/post")!), checkRobots: true)
        do {
            _ = try await gate.send(URLRequest(url: URL(string: "https://site.example/private/x")!), checkRobots: true)
            XCTFail("expected robots refusal")
        } catch IngestError.disallowedByRobots(let url) {
            XCTAssertEqual(url, "https://site.example/private/x")
        }
        XCTAssertEqual(transport.requests.map { $0.url?.path ?? "" }, ["/robots.txt", "/post"])
    }

    func testRobotsServerErrorMeansDisallowAndMissingMeansAllow() async throws {
        let clock = FakeClock()
        let transport = FakeTransport { request in
            let host = request.url?.host ?? ""
            let path = request.url?.path ?? ""
            if path != "/robots.txt" { return (200, [:], "") }
            return host == "down.example" ? (500, [:], "") : (404, [:], "")
        }
        let gate = PolitenessGate.testing(transport, clock: clock)
        _ = try await gate.send(URLRequest(url: URL(string: "https://open.example/x")!), checkRobots: true)
        do {
            _ = try await gate.send(URLRequest(url: URL(string: "https://down.example/x")!), checkRobots: true)
            XCTFail("expected refusal")
        } catch IngestError.disallowedByRobots {}
    }
}

final class SourceFetcherTests: XCTestCase {
    static let rss = """
    <rss version="2.0"><channel><title>Blog</title>
    <item><title>Hello</title><link>https://blog.example/hello</link><description>Hi there</description></item>
    </channel></rss>
    """

    func testConditionalGETAndNotModified() async throws {
        let clock = FakeClock()
        let transport = FakeTransport { request in
            request.value(forHTTPHeaderField: "If-None-Match") == "\"v1\""
                ? (304, [:], "")
                : (200, ["ETag": "\"v1\"", "Last-Modified": "Sun, 20 Sep 2026 17:59:59 GMT"], Self.rss)
        }
        let fetcher = SourceFetcher(gate: .testing(transport, clock: clock))
        var source = SourceDescriptor(kind: .rss, url: "https://blog.example/feed.xml")

        let first = try await fetcher.fetch(source)
        XCTAssertEqual(first?.title, "Blog")
        XCTAssertEqual(first?.items.map(\.url), ["https://blog.example/hello"])
        XCTAssertEqual(first?.etag, "\"v1\"")

        source.etag = first?.etag
        source.lastModified = first?.lastModified
        let second = try await fetcher.fetch(source)
        XCTAssertNil(second)
        XCTAssertEqual(transport.requests.last?.value(forHTTPHeaderField: "If-Modified-Since"),
                       "Sun, 20 Sep 2026 17:59:59 GMT")
        XCTAssertTrue(transport.requests.allSatisfy { $0.httpMethod == "GET" })
    }

    func testDiscoversFeedFromAHomePage() async throws {
        let clock = FakeClock()
        let transport = FakeTransport { request in
            if request.url?.path == "/feed.xml" { return (200, [:], Self.rss) }
            return (200, ["Content-Type": "text/html; charset=utf-8"],
                    #"<html><head><link rel="alternate" type="application/rss+xml" href="/feed.xml"></head></html>"#)
        }
        let fetcher = SourceFetcher(gate: .testing(transport, clock: clock))
        let result = try await fetcher.fetch(SourceDescriptor(kind: .rss, url: "blog.example"))
        XCTAssertEqual(result?.discoveredFeedURL, "https://blog.example/feed.xml")
        XCTAssertEqual(result?.items.count, 1)
    }

    func testPageWithoutAFeedIsAnError() async throws {
        let transport = FakeTransport { _ in (200, ["Content-Type": "text/html"], "<html><body>no feed</body></html>") }
        let fetcher = SourceFetcher(gate: .testing(transport, clock: FakeClock()))
        do {
            _ = try await fetcher.fetch(SourceDescriptor(kind: .rss, url: "https://nofeed.example"))
            XCTFail("expected notAFeed")
        } catch let error as IngestError {
            XCTAssertEqual(error, .notAFeed)
        }
    }

    func testARefusedRedirectIsSaidToBeOneNotAnHTTPError() async throws {
        let transport = FakeTransport { _ in (301, ["Location": "http://127.0.0.1:8080/feed.xml"], "") }
        let fetcher = SourceFetcher(gate: .testing(transport, clock: FakeClock()))
        do {
            _ = try await fetcher.fetch(SourceDescriptor(kind: .rss, url: "https://blog.example/feed.xml"))
            XCTFail("expected redirectedAway")
        } catch let error as IngestError {
            XCTAssertEqual(error, .redirectedAway(host: "127.0.0.1"))
        }

        let missing = FakeTransport { _ in (404, [:], "") }
        do {
            _ = try await SourceFetcher(gate: .testing(missing, clock: FakeClock()))
                .fetch(SourceDescriptor(kind: .rss, url: "https://blog.example/gone.xml"))
            XCTFail("expected http")
        } catch let error as IngestError {
            XCTAssertEqual(error, .http(status: 404), "other statuses are unchanged")
        }
    }

    func testHackerNewsAndHuggingFaceParsing() throws {
        let hn = """
        {"hits":[
          {"objectID":"1","title":"Show HN: a thing","url":"https://thing.example/?utm_medium=hn","author":"pg","created_at":"2026-09-20T17:59:59Z"},
          {"objectID":"2","title":"Ask HN: agents?","url":null,"author":"dang","created_at":"2026-09-20T17:59:59Z","story_text":"<p>What do you use?</p>"},
          {"objectID":"3","title":null,"url":"https://x.example"}
        ]}
        """
        let hnItems = try SourceFetcher.hackerNewsItems(Data(hn.utf8))
        XCTAssertEqual(hnItems.map(\.url), ["https://thing.example/", "https://news.ycombinator.com/item?id=2"])
        XCTAssertEqual(hnItems[1].summary, "What do you use?")

        let hf = """
        [{"paper":{"id":"2409.01234","title":"Agents That Plan","summary":"We study planning.","publishedAt":"2026-09-20T17:59:59.000Z",
          "authors":[{"name":"A"},{"name":"B"}]},"title":"Agents That Plan","publishedAt":"2026-09-21T00:00:00.000Z"}]
        """
        let hfItems = try SourceFetcher.huggingFaceItems(Data(hf.utf8))
        XCTAssertEqual(hfItems.first?.url, "https://arxiv.org/abs/2409.01234", "dedupes with the arXiv source")
        XCTAssertEqual(hfItems.first?.author, "A, B")
        XCTAssertEqual(hfItems.first?.publishedAt, Date(timeIntervalSince1970: 1_789_927_199))

        XCTAssertThrowsError(try SourceFetcher.hackerNewsItems(Data("nope".utf8)))
    }

    func testSitePagesCheckRobots() async throws {
        let transport = FakeTransport { request in
            if request.url?.path == "/robots.txt" { return (200, [:], "User-agent: *\nDisallow: /") }
            return (200, [:], "<html></html>")
        }
        let fetcher = SourceFetcher(gate: .testing(transport, clock: FakeClock()))
        do {
            _ = try await fetcher.fetch(SourceDescriptor(kind: .site, url: "https://closed.example/page"))
            XCTFail("expected robots refusal")
        } catch IngestError.disallowedByRobots {}
        XCTAssertEqual(transport.requests.count, 1, "only robots.txt was requested")
    }
}
