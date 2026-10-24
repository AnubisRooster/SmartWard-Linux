import XCTest
@testable import GraphViewKit

final class BundledResourcesTests: XCTestCase {

    func testGraphHTMLResourceIsBundled() {
        XCTAssertNotNil(GraphViewKitResources.graphHTMLURL,
                        "graph.html should be bundled as an SPM resource")
    }

    func testCytoscapeJSResourceIsBundled() {
        XCTAssertNotNil(GraphViewKitResources.cytoscapeJSURL,
                        "cytoscape.min.js should be bundled as an SPM resource")
    }

    func testGraphHTMLReferencesTheSiblingCytoscapeFile() throws {
        let htmlURL = try XCTUnwrap(GraphViewKitResources.graphHTMLURL)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        XCTAssertTrue(html.contains("cytoscape.min.js"),
                     "graph.html should load the bundled Cytoscape.js build")
    }
}
