import Foundation

/// Something that can handle a `Context` and knows how confident it is about
/// doing so. `Router` picks the highest-confidence handler for a given
/// context — a lightweight alternative to a hardcoded if/else or switch
/// chain when the set of handlers is open-ended or registered dynamically.
public protocol Handler<Context, Output>: Sendable {
    associatedtype Context
    associatedtype Output

    var name: String { get }

    /// How confident this handler is that it should handle `context`,
    /// from 0 (not applicable) to 1 (definitely this one).
    func confidence(for context: Context) -> Float
    func handle(_ context: Context) async -> Output
}

/// Routes a context to whichever registered handler reports the highest
/// `confidence(for:)`, falling back to a designated handler when nothing
/// claims the context (all confidences are 0).
public final class Router<Context, Output> {
    private var handlers: [any Handler<Context, Output>]

    public init(handlers: [any Handler<Context, Output>] = []) {
        self.handlers = handlers
    }

    public func register(_ handler: any Handler<Context, Output>) {
        handlers.append(handler)
    }

    /// Routes to the single best-scoring handler, or `fallback` if every
    /// registered handler reports 0 confidence.
    public func route(_ context: Context, fallback: any Handler<Context, Output>) async -> Output {
        let scored = handlers.map { ($0, $0.confidence(for: context)) }
            .sorted { $0.1 > $1.1 }

        guard let best = scored.first, best.1 > 0 else {
            return await fallback.handle(context)
        }
        return await best.0.handle(context)
    }

    /// Runs every handler that claims non-zero confidence for `context` and
    /// returns all of their outputs, in registration order.
    public func routeAll(_ context: Context) async -> [Output] {
        var results: [Output] = []
        for handler in handlers where handler.confidence(for: context) > 0 {
            results.append(await handler.handle(context))
        }
        return results
    }

    public var handlerNames: [String] { handlers.map(\.name) }
}
