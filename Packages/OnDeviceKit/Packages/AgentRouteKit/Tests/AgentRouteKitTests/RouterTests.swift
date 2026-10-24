import XCTest
@testable import AgentRouteKit

private struct EchoHandler: Handler {
    let name: String
    let score: Float
    func confidence(for context: String) -> Float { score }
    func handle(_ context: String) async -> String { "\(name):\(context)" }
}

final class RouterTests: XCTestCase {

    func testRoutesToHighestConfidenceHandler() async {
        let router = Router<String, String>(handlers: [
            EchoHandler(name: "low", score: 0.2),
            EchoHandler(name: "high", score: 0.9),
            EchoHandler(name: "mid", score: 0.5),
        ])
        let result = await router.route("hello", fallback: EchoHandler(name: "fallback", score: 0))
        XCTAssertEqual(result, "high:hello")
    }

    func testFallsBackWhenNoHandlerClaimsIt() async {
        let router = Router<String, String>(handlers: [
            EchoHandler(name: "a", score: 0),
            EchoHandler(name: "b", score: 0),
        ])
        let result = await router.route("hello", fallback: EchoHandler(name: "fallback", score: 1))
        XCTAssertEqual(result, "fallback:hello")
    }

    func testRouteAllReturnsEveryClaimingHandlerInOrder() async {
        let router = Router<String, String>(handlers: [
            EchoHandler(name: "a", score: 0.5),
            EchoHandler(name: "b", score: 0),
            EchoHandler(name: "c", score: 0.1),
        ])
        let results = await router.routeAll("x")
        XCTAssertEqual(results, ["a:x", "c:x"])
    }

    func testRegisterAddsHandlerDynamically() async {
        let router = Router<String, String>()
        XCTAssertTrue(router.handlerNames.isEmpty)
        router.register(EchoHandler(name: "late", score: 1))
        XCTAssertEqual(router.handlerNames, ["late"])
        let result = await router.route("y", fallback: EchoHandler(name: "fallback", score: 0))
        XCTAssertEqual(result, "late:y")
    }

    func testHandlerNamesReflectsRegistrationOrder() {
        let router = Router<String, String>(handlers: [
            EchoHandler(name: "first", score: 0),
            EchoHandler(name: "second", score: 0),
        ])
        XCTAssertEqual(router.handlerNames, ["first", "second"])
    }
}
