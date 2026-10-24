import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import IngestKit
import KnowledgeStore
import Pipeline
import SwiftData
import XCTest
@testable import SmartWardCore

/// A mono 16-bit 24 kHz WAV of `frames` silent frames.
private func wav(frames: Int, placeholderSizes: Bool = false) -> Data {
    func le32(_ v: UInt32) -> [UInt8] { [UInt8(v & 255), UInt8(v >> 8 & 255), UInt8(v >> 16 & 255), UInt8(v >> 24 & 255)] }
    let dataSize = UInt32(frames * 2)
    var out = Data("RIFF".utf8)
    out.append(contentsOf: le32(placeholderSizes ? 0xFFFF_FFFF : 36 + dataSize))
    out.append(Data("WAVEfmt ".utf8))
    out.append(contentsOf: le32(16))
    out.append(contentsOf: [1, 0, 1, 0] + le32(24_000) + le32(48_000) + [2, 0, 16, 0])
    out.append(Data("data".utf8))
    out.append(contentsOf: le32(placeholderSizes ? 0xFFFF_FFFF : dataSize))
    out.append(Data(repeating: 0, count: frames * 2))
    return out
}

private final class FakeSpeechServer: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var inputs: [String] = []
    private(set) var voices: [String] = []

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        func response(_ status: Int) -> HTTPURLResponse {
            HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        }
        if request.url?.path == "/health" { return (Data(), response(200)) }
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let text = body["input"] as! String
        lock.lock(); inputs.append(text); voices.append(body["voice"] as! String); lock.unlock()
        return (wav(frames: text.count), response(200))
    }
}

private final class RecordingPlayer: AudioPlaying, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var played: [Int] = []
    func play(_ wav: Data) async throws { lock.lock(); played.append(wav.count); lock.unlock() }
}

@MainActor
final class ReaderTests: XCTestCase {
    private func engineWithArticle() throws -> SmartWardEngine {
        let engine = try SmartWardEngine(inMemory: true)
        let article = Article(canonicalURL: "https://example.com/a", title: "Speculative decoding explained",
                              cleanedText: "First paragraph about decoding.\n\nSecond paragraph about drafts.")
        engine.context.insert(article)
        try engine.context.save()
        return engine
    }

    func testReadsTheTitleFirstThenEachParagraphInOrder() async throws {
        let engine = try engineWithArticle()
        let server = FakeSpeechServer()
        let player = RecordingPlayer()
        let speech = try SpeechClient(voice: "bf_emma", transport: server)
        var spoken: [String] = []
        let result = try await engine.read("decoding", speech: speech, player: player) { _, _, text in spoken.append(text) }
        XCTAssertEqual(result.title, "Speculative decoding explained")
        XCTAssertEqual(spoken.first, "Speculative decoding explained")
        XCTAssertEqual(spoken.suffix(2), ["First paragraph about decoding.", "Second paragraph about drafts."])
        XCTAssertEqual(server.inputs, spoken, "every piece is synthesized once, in order")
        XCTAssertEqual(Set(server.voices), ["bf_emma"])
        XCTAssertEqual(player.played.count, spoken.count)
    }

    func testEmptyQueryReadsTheNewestArticleAndSavesOneWAV() async throws {
        let engine = try engineWithArticle()
        let server = FakeSpeechServer()
        let result = try await engine.read("", speech: try SpeechClient(transport: server), player: nil, keepAudio: true)
        let audio = try XCTUnwrap(result.audio)
        XCTAssertTrue(WAV.isWAV(audio))
        let frames = server.inputs.reduce(0) { $0 + $1.count }
        XCTAssertEqual(audio.count, 44 + frames * 2, "one header, every piece's samples")
    }

    func testNothingFoundAndEmptyLibraryAreExplained() async throws {
        let engine = try engineWithArticle()
        let speech = try SpeechClient(transport: FakeSpeechServer())
        do {
            _ = try await engine.read("zzzz-not-here", speech: speech, player: nil)
            XCTFail("expected an error")
        } catch { XCTAssertTrue(error.localizedDescription.contains("zzzz-not-here")) }

        let empty = try SmartWardEngine(inMemory: true)
        do {
            _ = try await empty.read("", speech: speech, player: nil)
            XCTFail("expected an error")
        } catch { XCTAssertTrue(error.localizedDescription.contains("no articles")) }
    }

    func testSpeechServerMustBeOnThisMachine() {
        XCTAssertThrowsError(try SpeechClient(baseURL: URL(string: "https://api.example.com")!))
        XCTAssertThrowsError(try SpeechClient(baseURL: URL(string: "http://192.168.1.5:8880")!))
        XCTAssertNoThrow(try SpeechClient(baseURL: URL(string: "http://localhost:8880")!))
    }

    func testJoiningWAVsHandlesStreamingPlaceholderSizes() throws {
        let joined = try XCTUnwrap(WAV.concatenate([wav(frames: 10), wav(frames: 5, placeholderSizes: true)]))
        XCTAssertEqual(joined.count, 44 + 15 * 2)
        XCTAssertNil(WAV.concatenate([]))
        XCTAssertNil(WAV.concatenate([Data("not audio".utf8)]))
    }

    func testPlayerIsFoundOnThePath() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("players-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertNil(CommandAudioPlayer.detect(searchPath: directory.path))
        let fake = directory.appendingPathComponent("paplay")
        FileManager.default.createFile(atPath: fake.path, contents: Data("#!/bin/sh\n".utf8),
                                       attributes: [.posixPermissions: 0o755])
        XCTAssertEqual(CommandAudioPlayer.detect(searchPath: directory.path)?.name, "paplay")
    }
}
