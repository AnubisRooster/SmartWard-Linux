import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import IngestKit
import Pipeline
import XCTest
@testable import SmartWardCore

private func wavBytes() -> Data {
    func le32(_ v: UInt32) -> [UInt8] { [UInt8(v & 255), UInt8(v >> 8 & 255), UInt8(v >> 16 & 255), UInt8(v >> 24 & 255)] }
    var out = Data("RIFF".utf8)
    out.append(contentsOf: le32(36 + 20))
    out.append(Data("WAVEfmt ".utf8))
    out.append(contentsOf: le32(16))
    out.append(contentsOf: [1, 0, 1, 0] + le32(24_000) + le32(48_000) + [2, 0, 16, 0])
    out.append(Data("data".utf8))
    out.append(contentsOf: le32(20))
    out.append(Data(repeating: 0, count: 20))
    return out
}

/// Plays the part of the speech server and Ollama.
private final class FakeServers: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var sampleRequests: [[String: Any]] = []

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        func reply(_ body: String, _ status: Int = 200) -> (Data, HTTPURLResponse) {
            (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
        switch request.url!.path {
        case "/health": return reply("{}")
        case "/v1/voices": return reply(#"{"voices":["bf_emma","af_heart","am_adam"]}"#)
        case "/api/tags": return reply(#"{"models":[{"name":"llama3.2:3b"},{"name":"nomic-embed-text:latest"}]}"#)
        case "/v1/audio/speech":
            lock.lock()
            sampleRequests.append(try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any])
            lock.unlock()
            return (wavBytes(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        default: return reply("{}", 404)
        }
    }
}

final class SettingsTests: XCTestCase {
    private func tempStore() -> SettingsStore {
        SettingsStore(url: FileManager.default.temporaryDirectory
            .appendingPathComponent("settings-\(UUID().uuidString)/config.json"))
    }

    // MARK: Model and store

    func testDefaultsWhenThereIsNoFileAndRoundTripWhenThereIs() throws {
        let store = tempStore()
        XCTAssertEqual(try store.load(), AppSettings())
        var settings = AppSettings()
        settings.voice = "bf_emma"
        settings.speed = 1.2
        settings.profiles["commute"] = ReadingProfile(voice: "am_adam", speed: 1.4, scope: .summary)
        settings.activeProfile = "commute"
        try store.save(settings)
        XCTAssertEqual(try store.load(), settings)
        XCTAssertEqual(try settings.reading().scope, .summary)
        XCTAssertEqual(try settings.reading(profile: nil).voice, "am_adam")
    }

    func testAnOlderFileWithMissingKeysKeepsDefaults() throws {
        let store = tempStore()
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"voice":"bm_george"}"#.utf8).write(to: store.url)
        let settings = try store.load()
        XCTAssertEqual(settings.voice, "bm_george")
        XCTAssertEqual(settings.speed, 1.0)
        XCTAssertEqual(settings.chatModel, LocalModelConfig.recommendedChatModel)
    }

    func testValidationRejectsBadVoicesSpeedsAddressesAndProfiles() {
        var settings = AppSettings()
        settings.voice = "Not A Voice"
        settings.speed = 5
        settings.speechURL = "https://api.example.com"
        settings.ollamaURL = "http://192.168.1.10:11434"
        settings.profiles["x"] = ReadingProfile(voice: "af_heart", speed: 0.1)
        settings.activeProfile = "missing"
        XCTAssertThrowsError(try settings.validated()) { error in
            guard case .invalid(let problems)? = error as? SettingsError else { return XCTFail("\(error)") }
            XCTAssertEqual(problems.count, 6, "\(problems)")
        }
        XCTAssertNoThrow(try AppSettings().validated())
        XCTAssertThrowsError(try AppSettings().reading(profile: "nope"))
        XCTAssertFalse(AppSettings.isVoiceName("af"))
        XCTAssertTrue(AppSettings.isVoiceName("zm_yunxi"))
    }

    func testAnInvalidSaveLeavesTheFileAlone() throws {
        let store = tempStore()
        try store.save(AppSettings(voice: "bf_emma"))
        var bad = AppSettings()
        bad.speed = 9
        XCTAssertThrowsError(try store.save(bad))
        XCTAssertEqual(try store.load().voice, "bf_emma")
    }

    // MARK: Service

    private func service(_ store: SettingsStore, servers: FakeServers = FakeServers()) -> SettingsService {
        SettingsService(store: store, token: "secret-token-value", port: 8765, speechTransport: servers, ollamaTransport: servers)
    }

    private func request(_ method: String, _ path: String, query: [String: String] = [:], token: String? = "secret-token-value",
                         host: String? = "127.0.0.1:8765", body: Data = Data(), json: Bool = true) -> HTTPRequest {
        var headers: [String: String] = [:]
        if let token { headers["x-smartward-token"] = token }
        if let host { headers["host"] = host }
        if json && !body.isEmpty { headers["content-type"] = "application/json" }
        return HTTPRequest(method: method, path: path, query: query, headers: headers, body: body)
    }

    func testThePageNeedsTheTokenAndSendsSecurityHeaders() async {
        let service = service(tempStore())
        let denied = await service.handle(request("GET", "/", query: ["t": "wrong"]))
        XCTAssertEqual(denied.status, 403)
        let missing = await service.handle(request("GET", "/"))
        XCTAssertEqual(missing.status, 403)
        let page = await service.handle(request("GET", "/", query: ["t": "secret-token-value"]))
        XCTAssertEqual(page.status, 200)
        XCTAssertTrue(String(decoding: page.body, as: UTF8.self).contains("SmartWard settings"))
        XCTAssertEqual(page.headers["X-Frame-Options"], "DENY")
        XCTAssertTrue(page.headers["Content-Security-Policy"]?.contains("default-src 'none'") == true)
    }

    func testTheAPIRefusesMissingTokensAndForeignHosts() async {
        let service = service(tempStore())
        let noToken = await service.handle(request("GET", "/api/settings", token: nil))
        XCTAssertEqual(noToken.status, 403)
        let wrongToken = await service.handle(request("GET", "/api/settings", token: "nope"))
        XCTAssertEqual(wrongToken.status, 403)
        let rebinding = await service.handle(request("GET", "/api/settings", host: "evil.example.com:8765"))
        XCTAssertEqual(rebinding.status, 403, "a DNS-rebinding page would send its own Host")
        let noHost = await service.handle(request("GET", "/api/settings", host: nil))
        XCTAssertEqual(noHost.status, 403)
        let ok = await service.handle(request("GET", "/api/settings", host: "localhost:8765"))
        XCTAssertEqual(ok.status, 200)
    }

    func testSavingValidatesAndPersists() async throws {
        let store = tempStore()
        let service = service(store)
        var settings = AppSettings(voice: "bf_emma", speed: 1.1)
        settings.profiles["evening"] = ReadingProfile(voice: "am_adam", speed: 0.9, scope: .whole)
        let body = try JSONEncoder().encode(settings)
        let saved = await service.handle(request("PUT", "/api/settings", body: body))
        XCTAssertEqual(saved.status, 200)
        XCTAssertEqual(try store.load(), settings)

        var invalid = settings
        invalid.speed = 7
        let rejected = await service.handle(request("PUT", "/api/settings", body: try JSONEncoder().encode(invalid)))
        XCTAssertEqual(rejected.status, 400)
        XCTAssertTrue(String(decoding: rejected.body, as: UTF8.self).contains("speed"))
        XCTAssertEqual(try store.load(), settings, "the bad save changed nothing")

        let notJSON = await service.handle(request("PUT", "/api/settings", body: body, json: false))
        XCTAssertEqual(notJSON.status, 415)
        let garbage = await service.handle(request("PUT", "/api/settings", body: Data("nope".utf8)))
        XCTAssertEqual(garbage.status, 400)
    }

    func testVoicesStatusAndSamples() async throws {
        let servers = FakeServers()
        let service = service(tempStore(), servers: servers)
        let voices = await service.handle(request("GET", "/api/voices"))
        XCTAssertEqual(String(decoding: voices.body, as: UTF8.self), #"{"voices":["af_heart","am_adam","bf_emma"]}"#)

        let status = try JSONSerialization.jsonObject(with: await service.handle(request("GET", "/api/status")).body) as! [String: Any]
        XCTAssertEqual(status["speechReachable"] as? Bool, true)
        XCTAssertEqual(status["ollamaReachable"] as? Bool, true)
        XCTAssertEqual(status["installedModels"] as? [String], ["llama3.2:3b", "nomic-embed-text:latest"])

        let sample = await service.handle(request("POST", "/api/sample",
                                                   body: Data(#"{"voice":"bf_emma","speed":1.25}"#.utf8)))
        XCTAssertEqual(sample.status, 200)
        XCTAssertEqual(sample.headers["Content-Type"], "audio/wav")
        XCTAssertTrue(WAV.isWAV(sample.body))
        XCTAssertEqual(servers.sampleRequests.last?["voice"] as? String, "bf_emma")
        XCTAssertEqual(servers.sampleRequests.last?["speed"] as? Double, 1.25)
        XCTAssertEqual(servers.sampleRequests.last?["input"] as? String, SettingsService.sampleSentence)

        let bad = await service.handle(request("POST", "/api/sample", body: Data(#"{"voice":"../etc","speed":1}"#.utf8)))
        XCTAssertEqual(bad.status, 400)
    }

    // MARK: Over a real socket

    func testTheLoopbackServerAnswersOnlyOnThisMachine() async throws {
        let store = tempStore()
        let token = "secret-token-value"
        let holder = ServiceHolder()
        let server = LoopbackHTTPServer { request in await holder.service!.handle(request) }
        let port = try server.start(port: 0)
        defer { server.stop() }
        holder.service = SettingsService(store: store, token: token, port: port,
                                         speechTransport: FakeServers(), ollamaTransport: FakeServers())

        var page = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/?t=\(token)")!)
        page.timeoutInterval = 5
        let (html, response) = try await URLSession.shared.data(for: page)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertTrue(String(decoding: html, as: UTF8.self).contains("<title>SmartWard settings</title>"))

        var api = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/api/settings")!)
        api.timeoutInterval = 5
        let (_, denied) = try await URLSession.shared.data(for: api)
        XCTAssertEqual((denied as? HTTPURLResponse)?.statusCode, 403, "no token, no settings")
        api.setValue(token, forHTTPHeaderField: "X-SmartWard-Token")
        let (json, allowed) = try await URLSession.shared.data(for: api)
        XCTAssertEqual((allowed as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertNotNil(try JSONSerialization.jsonObject(with: json) as? [String: Any])
    }

    private final class ServiceHolder: @unchecked Sendable { var service: SettingsService? }
}

extension SettingsTests {
    /// Several requests at once through `URLSessionTransport` (the browser asks for settings, voices
    /// and status together); the first-use race in the shared session used to hang one of them.
    func testConcurrentRequestsThroughTheSharedTransportAllFinish() async throws {
        let server = LoopbackHTTPServer { _ in HTTPResponse(status: 200, body: Data("ok".utf8)) }
        let port = try server.start(port: 0)
        defer { server.stop() }
        let transport = URLSessionTransport()
        let url = URL(string: "http://127.0.0.1:\(port)/")!
        let results = try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<12 {
                group.addTask {
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 10
                    return try await transport.send(request).1.statusCode
                }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }
        XCTAssertEqual(results, Array(repeating: 200, count: 12))
    }
}
