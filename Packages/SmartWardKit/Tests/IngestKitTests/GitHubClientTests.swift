import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import IngestKit

/// Answers requests from a handler and records them.
final class FakeTransport: HTTPTransport, @unchecked Sendable {
    typealias Reply = (status: Int, headers: [String: String], body: String)
    private let handler: (URLRequest) -> Reply
    private(set) var requests: [URLRequest] = []
    private let lock = NSLock()

    init(_ handler: @escaping (URLRequest) -> Reply) {
        self.handler = handler
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.lock()
        requests.append(request)
        lock.unlock()
        let reply = handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status,
                                       httpVersion: "HTTP/1.1", headerFields: reply.headers)!
        return (Data(reply.body.utf8), response)
    }
}

final class GitHubClientTests: XCTestCase {

    func testRequestsAreGETWithVersionedHeaders() async throws {
        let transport = FakeTransport { _ in (200, [:], #"{"login":"octo"}"#) }
        let user = try await GitHubClient(token: " tok ", transport: transport).currentUser()

        XCTAssertEqual(user.login, "octo")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "https://api.github.com/user")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-GitHub-Api-Version"), "2022-11-28")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")
        XCTAssertNil(request.httpBody)
    }

    func testUnauthenticatedClientSendsNoAuthorization() async throws {
        let transport = FakeTransport { _ in (200, ["ETag": "\"abc\""], #"{"full_name":"a/b","private":false,"default_branch":"main","html_url":"https://github.com/a/b"}"#) }
        let client = GitHubClient(token: "  ", transport: transport)
        XCTAssertFalse(client.isAuthenticated)

        let result = try await client.repository("a/b")
        XCTAssertEqual(result?.repo.fullName, "a/b")
        XCTAssertEqual(result?.etag, "\"abc\"")
        XCTAssertNil(transport.requests.first?.value(forHTTPHeaderField: "Authorization"))
    }

    func testRepositoriesListsEveryPage() async throws {
        func repos(_ range: Range<Int>) -> String {
            "[" + range.map { #"{"full_name":"me/r\#($0)","private":false,"default_branch":"main","html_url":"https://github.com/me/r\#($0)"}"# }
                .joined(separator: ",") + "]"
        }
        let transport = FakeTransport { request in
            let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "page" }?.value
            return (200, [:], page == "1" ? repos(0..<100) : repos(100..<130))
        }
        let all = try await GitHubClient(token: "t", transport: transport).repositories()
        XCTAssertEqual(all.count, 130)
        XCTAssertEqual(all.last?.fullName, "me/r129")
        XCTAssertEqual(transport.requests.count, 2, "stops at the first short page")
    }

    func testNotModifiedReturnsNilAndSendsIfNoneMatch() async throws {
        let transport = FakeTransport { _ in (304, [:], "") }
        let result = try await GitHubClient(transport: transport).repository("a/b", etag: "\"abc\"")
        XCTAssertNil(result)
        XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "If-None-Match"), "\"abc\"")
    }

    func testMissingFilesAreNilNotErrors() async throws {
        let transport = FakeTransport { request in
            request.url?.path == "/repos/a/b/contents/CLAUDE.md" ? (200, [:], "# Rules") : (404, [:], #"{"message":"Not Found"}"#)
        }
        let client = GitHubClient(transport: transport)
        let found = try await client.fileText("a/b", path: "CLAUDE.md")
        let missing = try await client.fileText("a/b", path: "AGENTS.md")
        let readme = try await client.readme("a/b")

        XCTAssertEqual(found, "# Rules")
        XCTAssertNil(missing)
        XCTAssertNil(readme)
        XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "Accept"), "application/vnd.github.raw")
    }

    func testErrorMapping() async {
        let cases: [(FakeTransport.Reply, GitHubError)] = [
            ((401, [:], "{}"), .unauthorized),
            ((404, [:], "{}"), .notFound),
            ((403, ["X-RateLimit-Remaining": "0", "X-RateLimit-Reset": "1800000000"], "{}"),
             .rateLimited(resetAt: Date(timeIntervalSince1970: 1_800_000_000))),
            ((429, [:], "{}"), .rateLimited(resetAt: nil)),
            ((403, ["X-RateLimit-Remaining": "12"], #"{"message":"Resource not accessible"}"#),
             .http(status: 403, message: "Resource not accessible")),
        ]
        for (reply, expected) in cases {
            let client = GitHubClient(transport: FakeTransport { _ in reply })
            do {
                _ = try await client.currentUser()
                XCTFail("expected \(expected)")
            } catch {
                XCTAssertEqual(error as? GitHubError, expected)
            }
        }
    }

    func testTreeListingAndTruncation() async throws {
        let tree = #"{"tree":[{"path":"README.md","type":"blob"},{"path":"docs","type":"tree"},{"path":"docs/PLAN.md","type":"blob"}],"truncated":false}"#
        let paths = try await GitHubClient(transport: FakeTransport { _ in (200, [:], tree) }).filePaths("a/b", branch: "main")
        XCTAssertEqual(paths, ["README.md", "docs/PLAN.md"])

        let truncated = #"{"tree":[],"truncated":true}"#
        let none = try await GitHubClient(transport: FakeTransport { _ in (200, [:], truncated) }).filePaths("a/b", branch: "main")
        XCTAssertNil(none)
    }
}

final class GitHubDeviceFlowTests: XCTestCase {

    func testStartPostsFormToDeviceCodeEndpoint() async throws {
        let transport = FakeTransport { _ in
            (200, [:], #"{"device_code":"dc","user_code":"ABCD-1234","verification_uri":"https://github.com/login/device","expires_in":900,"interval":5}"#)
        }
        let flow = GitHubDeviceFlow(clientID: "Iv1.abc", includePrivateRepos: false, transport: transport)
        let code = try await flow.start()

        XCTAssertEqual(code.userCode, "ABCD-1234")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://github.com/login/device/code")
        XCTAssertEqual(String(decoding: request.httpBody ?? Data(), as: UTF8.self), "client_id=Iv1.abc&scope=read:user")
        XCTAssertEqual(GitHubDeviceFlow(clientID: "x", includePrivateRepos: true).scope, "repo read:user")
    }

    func testStartWithoutClientIDIsNotConfigured() async {
        do {
            _ = try await GitHubDeviceFlow(clientID: "", includePrivateRepos: false).start()
            XCTFail("expected notConfigured")
        } catch {
            XCTAssertEqual(error as? GitHubDeviceFlowError, .notConfigured)
        }
    }

    func testParsePoll() throws {
        XCTAssertEqual(try GitHubDeviceFlow.parsePoll(Data(#"{"error":"authorization_pending"}"#.utf8)), .pending)
        XCTAssertEqual(try GitHubDeviceFlow.parsePoll(Data(#"{"error":"slow_down"}"#.utf8)), .slowDown)
        XCTAssertEqual(try GitHubDeviceFlow.parsePoll(Data(#"{"access_token":"gho_x","token_type":"bearer"}"#.utf8)), .token("gho_x"))
        XCTAssertThrowsError(try GitHubDeviceFlow.parsePoll(Data(#"{"error":"access_denied"}"#.utf8))) {
            XCTAssertEqual($0 as? GitHubDeviceFlowError, .denied)
        }
        XCTAssertThrowsError(try GitHubDeviceFlow.parsePoll(Data(#"{"error":"expired_token"}"#.utf8))) {
            XCTAssertEqual($0 as? GitHubDeviceFlowError, .expired)
        }
    }

    func testWaitForTokenPollsUntilApproved() async throws {
        var replies = [#"{"error":"authorization_pending"}"#, #"{"error":"slow_down"}"#, #"{"access_token":"gho_ok"}"#]
        let lock = NSLock()
        let transport = FakeTransport { _ in
            lock.lock(); defer { lock.unlock() }
            return (200, [:], replies.removeFirst())
        }
        let flow = GitHubDeviceFlow(clientID: "id", includePrivateRepos: false, transport: transport, sleep: { _ in })
        let code = GitHubDeviceCodeFixture.make(interval: 5, expiresIn: 900)

        let token = try await flow.waitForToken(code)
        XCTAssertEqual(token, "gho_ok")
        XCTAssertEqual(transport.requests.count, 3)
        XCTAssertEqual(transport.requests.first?.url?.absoluteString, "https://github.com/login/oauth/access_token")
    }
}

enum GitHubDeviceCodeFixture {
    static func make(interval: Int, expiresIn: Int) -> GitHubDeviceCode {
        let json = #"{"device_code":"dc","user_code":"U","verification_uri":"https://github.com/login/device","expires_in":\#(expiresIn),"interval":\#(interval)}"#
        return try! JSONDecoder().decode(GitHubDeviceCode.self, from: Data(json.utf8))
    }
}
