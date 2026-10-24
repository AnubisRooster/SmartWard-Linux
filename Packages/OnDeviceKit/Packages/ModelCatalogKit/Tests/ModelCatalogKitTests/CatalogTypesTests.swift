import XCTest
@testable import ModelCatalogKit

final class CatalogTypesTests: XCTestCase {

    func testPricingDecodesNumericStrings() throws {
        let json = #"{"prompt":"0.0001","completion":"0.0002","image":"0.05"}"#
        let decoded = try JSONDecoder().decode(Pricing.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.prompt, 0.0001, accuracy: 1e-9)
        XCTAssertEqual(decoded.completion, 0.0002, accuracy: 1e-9)
        XCTAssertEqual(decoded.image, 0.05)
    }

    func testPricingDecodesNumericDoubles() throws {
        let json = #"{"prompt":0.0001,"completion":0.0002}"#
        let decoded = try JSONDecoder().decode(Pricing.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.prompt, 0.0001, accuracy: 1e-9)
        XCTAssertNil(decoded.image)
    }

    func testPricingMissingFieldsDefaultToZero() throws {
        let decoded = try JSONDecoder().decode(Pricing.self, from: Data("{}".utf8))
        XCTAssertEqual(decoded.prompt, 0)
        XCTAssertEqual(decoded.completion, 0)
    }

    func testCatalogErrorHasDescription() {
        XCTAssertNotNil(CatalogError.fetchFailed.errorDescription)
    }
}
