import Foundation
#if canImport(os)
import os
#endif

#if !canImport(os)
/// Stand-in for `OSAllocatedUnfairLock` where `os` doesn't exist.
final class SampleLock<State>: @unchecked Sendable {
    private let lock = NSLock()
    private var state: State
    init(initialState: State) { state = initialState }
    func withLock<R>(_ body: (inout State) throws -> R) rethrows -> R {
        lock.lock(); defer { lock.unlock() }
        return try body(&state)
    }
}
#endif

/// Timing for the paths with latency targets (NFR-4): each measurement is a
/// signpost interval (Instruments → Points of Interest) and is kept in a
/// short in-memory log for the developer readout. Nothing leaves the device.
public enum PerfTrace {
    public struct Sample: Sendable, Identifiable {
        public let id = UUID()
        public let name: String
        public let milliseconds: Double
        public let at: Date
    }

    public struct Summary: Sendable, Equatable {
        public let count: Int
        public let p50: Double
        public let p95: Double
        public let max: Double
    }

    #if canImport(os)
    static let signposter = OSSignposter(subsystem: "com.intelligentdesignsllc.smartward", category: .pointsOfInterest)
    private static let log = OSAllocatedUnfairLock(initialState: [Sample]())
    #else
    private static let log = SampleLock(initialState: [Sample]())
    #endif
    static let capacity = 500

    public static func measure<T>(_ name: StaticString, _ work: () throws -> T) rethrows -> T {
        #if canImport(os)
        let state = signposter.beginInterval(name)
        #endif
        let start = DispatchTime.now()
        defer {
            #if canImport(os)
            signposter.endInterval(name, state)
            #endif
            record("\(name)", since: start)
        }
        return try work()
    }

    public static func measureAsync<T>(_ name: StaticString, _ work: () async throws -> T) async rethrows -> T {
        #if canImport(os)
        let state = signposter.beginInterval(name)
        #endif
        let start = DispatchTime.now()
        defer {
            #if canImport(os)
            signposter.endInterval(name, state)
            #endif
            record("\(name)", since: start)
        }
        return try await work()
    }

    static func record(_ name: String, since start: DispatchTime) {
        let milliseconds = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        record(name, milliseconds: milliseconds)
    }

    public static func record(_ name: String, milliseconds: Double) {
        let sample = Sample(name: name, milliseconds: milliseconds, at: Date())
        log.withLock { samples in
            samples.append(sample)
            if samples.count > capacity { samples.removeFirst(samples.count - capacity) }
        }
    }

    public static var samples: [Sample] { log.withLock { $0 } }

    public static var names: [String] {
        Array(Set(samples.map(\.name))).sorted()
    }

    /// Percentiles over the kept samples named `name`.
    public static func summary(_ name: String) -> Summary? {
        let times = samples.filter { $0.name == name }.map(\.milliseconds).sorted()
        guard !times.isEmpty else { return nil }
        func percentile(_ p: Double) -> Double {
            times[min(times.count - 1, Int((Double(times.count - 1) * p).rounded()))]
        }
        return Summary(count: times.count, p50: percentile(0.5), p95: percentile(0.95), max: times[times.count - 1])
    }

    public static func reset() {
        log.withLock { $0.removeAll() }
    }
}
