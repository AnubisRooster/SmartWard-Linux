import XCTest
@testable import BYOKLLMKit

final class JSONValueTests: XCTestCase {

    func testRoundTripsEveryKind() throws {
        let value: JSONValue = [
            "null": nil,
            "bool": true,
            "int": 42,
            "double": 1.5,
            "string": "hi",
            "array": [1, "two", false],
            "object": ["nested": ["deep": 7]],
        ]
        let decoded = try JSONDecoder().decode(JSONValue.self, from: value.encodedData())
        XCTAssertEqual(decoded, value)
    }

    func testIntegersEncodeWithoutFraction() {
        let value: JSONValue = ["max_tokens": 4096]
        XCTAssertEqual(value.jsonString, #"{"max_tokens":4096}"#)
    }

    func testEncodingIsKeySorted() {
        let value: JSONValue = ["b": 1, "a": 2, "c": 3]
        XCTAssertEqual(value.jsonString, #"{"a":2,"b":1,"c":3}"#)
    }

    func testParseDistinguishesIntDoubleAndBool() throws {
        let value = try JSONValue.parse(#"{"i":3,"d":3.25,"b":true}"#)
        XCTAssertEqual(value["i"], .int(3))
        XCTAssertEqual(value["d"], .double(3.25))
        XCTAssertEqual(value["b"], .bool(true))
    }

    func testAccessors() {
        let value: JSONValue = ["s": "x", "i": 2, "a": [1], "o": ["k": "v"]]
        XCTAssertEqual(value["s"]?.stringValue, "x")
        XCTAssertEqual(value["i"]?.intValue, 2)
        XCTAssertEqual(value["i"]?.doubleValue, 2.0)
        XCTAssertEqual(value["a"]?.arrayValue, [1])
        XCTAssertEqual(value["o"]?["k"]?.stringValue, "v")
        XCTAssertNil(value["missing"])
        XCTAssertNil(JSONValue.string("not an object")["k"])
    }

    func testDecodeIntoConcreteType() throws {
        struct Args: Decodable, Equatable { let query: String; let limit: Int }
        let value: JSONValue = ["query": "vllm", "limit": 5]
        XCTAssertEqual(try value.decode(as: Args.self), Args(query: "vllm", limit: 5))
    }

    func testFromEncodable() throws {
        struct Point: Encodable { let x: Int; let y: Int }
        XCTAssertEqual(try JSONValue.from(Point(x: 1, y: 2)), ["x": 1, "y": 2])
    }
}
