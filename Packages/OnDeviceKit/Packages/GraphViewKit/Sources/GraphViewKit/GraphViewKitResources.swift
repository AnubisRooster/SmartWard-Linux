import Foundation

/// Locations of the bundled, offline Cytoscape.js assets. Exposed publicly
/// (rather than relying on callers reaching for `Bundle.module`, which only
/// resolves correctly from within this target) so both `GraphVisualizationView`
/// and this package's own tests can verify the resources are present.
public enum GraphViewKitResources {
    // `.copy("Resources/graph.html")` in Package.swift places the file at the
    // bundle root (not under a "Resources/" subdirectory) — SPM's per-file
    // .copy() drops the source-relative directory prefix.
    public static var graphHTMLURL: URL? {
        Bundle.module.url(forResource: "graph", withExtension: "html")
    }

    public static var cytoscapeJSURL: URL? {
        Bundle.module.url(forResource: "cytoscape.min", withExtension: "js")
    }
}
