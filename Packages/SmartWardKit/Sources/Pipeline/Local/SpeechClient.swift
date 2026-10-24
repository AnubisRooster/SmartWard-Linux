import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import IngestKit

/// A client for a local text-to-speech server that speaks the OpenAI
/// `/v1/audio/speech` API (Kokoro-FastAPI, or `tools/kokoro-server`). Like
/// `OllamaClient` it only talks to this machine: article text, private items
/// included, is never sent to a cloud voice (D5).
public struct SpeechClient: Sendable {
    public static let defaultBaseURL = URL(string: "http://127.0.0.1:8880")!
    public static let defaultVoice = "af_heart"

    public let baseURL: URL
    public var voice: String
    public var speed: Double
    private let transport: any HTTPTransport

    public init(baseURL: URL = SpeechClient.defaultBaseURL, voice: String = SpeechClient.defaultVoice,
                speed: Double = 1.0, transport: any HTTPTransport = URLSessionTransport()) throws {
        guard LocalAddress.isLoopback(baseURL) else {
            throw LocalAIError.notLoopback(baseURL.host ?? baseURL.absoluteString)
        }
        self.baseURL = baseURL
        self.voice = voice
        self.speed = speed
        self.transport = transport
    }

    /// WAV audio for `text`.
    public func synthesize(_ text: String) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/audio/speech"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        let body: [String: Any] = ["model": "kokoro", "input": text, "voice": voice, "speed": speed,
                                   "response_format": "wav"]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data: Data, response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch {
            throw LocalAIError.unreachable(error.localizedDescription)
        }
        guard response.statusCode == 200 else {
            throw LocalAIError.http(status: response.statusCode, body: String(decoding: data, as: UTF8.self))
        }
        guard WAV.isWAV(data) else { throw LocalAIError.badResponse }
        return data
    }

    /// The voices the server offers (`GET /v1/voices` or `/v1/audio/voices`).
    public func voices() async throws -> [String] {
        for path in ["v1/voices", "v1/audio/voices"] {
            var request = URLRequest(url: baseURL.appendingPathComponent(path))
            request.timeoutInterval = 5
            guard let (data, response) = try? await transport.send(request), response.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let names = json["voices"] as? [String] else { continue }
            return names.sorted()
        }
        throw LocalAIError.unreachable("no voice list from \(baseURL.host ?? "the speech server")")
    }

    public func isReachable() async -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("health"))
        request.timeoutInterval = 3
        guard let (_, response) = try? await transport.send(request) else { return false }
        return response.statusCode == 200
    }
}

/// Just enough WAV handling to join the pieces of one reading into a file.
public enum WAV {
    public static func isWAV(_ data: Data) -> Bool {
        data.count > 44 && data.prefix(4) == Data("RIFF".utf8) && data[8..<12] == Data("WAVE".utf8)
    }

    /// Joins WAV files with the same format into one: the first file's format
    /// header and every file's samples. Streaming servers write placeholder
    /// sizes, so a data chunk that claims more than is there runs to the end.
    public static func concatenate(_ files: [Data]) -> Data? {
        guard let first = files.first, let format = chunks(of: first).format else { return nil }
        var samples = Data()
        for file in files {
            let parts = chunks(of: file)
            guard parts.format == format, let data = parts.data else { return nil }
            samples.append(data)
        }
        var out = Data("RIFF".utf8)
        out.append(le32(UInt32(4 + 8 + format.count + 8 + samples.count)))
        out.append(Data("WAVE".utf8))
        out.append(Data("fmt ".utf8))
        out.append(le32(UInt32(format.count)))
        out.append(format)
        out.append(Data("data".utf8))
        out.append(le32(UInt32(samples.count)))
        out.append(samples)
        return out
    }

    private static func chunks(of file: Data) -> (format: Data?, data: Data?) {
        guard isWAV(file) else { return (nil, nil) }
        var format: Data?
        var offset = 12
        while offset + 8 <= file.count {
            let id = String(decoding: file[offset..<offset + 4], as: UTF8.self)
            let declared = Int(file[offset + 4]) | Int(file[offset + 5]) << 8 | Int(file[offset + 6]) << 16
                | Int(file[offset + 7]) << 24
            let start = offset + 8
            if id == "data" {
                let end = (declared == 0xFFFF_FFFF || start + declared > file.count) ? file.count : start + declared
                return (format, Data(file[start..<end]))
            }
            let end = min(file.count, start + declared)
            if id == "fmt " { format = Data(file[start..<end]) }
            offset = end + (declared % 2)
        }
        return (format, nil)
    }

    private static func le32(_ value: UInt32) -> Data {
        Data([UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF)])
    }
}
