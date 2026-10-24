import XCTest
@testable import VoiceLoopKit

final class SpeakableTextTests: XCTestCase {

    func testLinksKeepTheirTextNotTheirURL() {
        XCTAssertEqual(SpeechService.speakableText("See [the post](https://example.com/a/b) now"),
                       "See the post now")
        XCTAssertEqual(SpeechService.speakableText("![diagram](https://example.com/d.png) above"),
                       "diagram above")
    }

    func testBareAndAutoLinkedURLsAreNotReadOut() {
        XCTAssertEqual(SpeechService.speakableText("Read https://example.com/very/long?x=1 today"),
                       "Read a link today")
        XCTAssertEqual(SpeechService.speakableText("Source: <https://example.com/y>"),
                       "Source: a link")
    }

    func testCodeBlocksAreDropped() {
        let spoken = SpeechService.speakableText("Try this:\n```swift\nlet x = 1\n```\nDone.")
        XCTAssertFalse(spoken.contains("let x"))
        XCTAssertFalse(spoken.contains("`"))
        XCTAssertTrue(spoken.hasPrefix("Try this:"))
        XCTAssertTrue(spoken.hasSuffix("Done."))
    }

    func testTablesAreDropped() {
        let spoken = SpeechService.speakableText("Options:\n| A | B |\n|---|---|\n| 1 | 2 |\nPick one.")
        XCTAssertFalse(spoken.contains("|"))
        XCTAssertTrue(spoken.hasPrefix("Options:"))
        XCTAssertTrue(spoken.hasSuffix("Pick one."))
    }

    func testEmphasisAndInlineCodeKeepTheirText() {
        XCTAssertEqual(SpeechService.speakableText("**Use** `vLLM` here"), "Use vLLM here")
    }
}
