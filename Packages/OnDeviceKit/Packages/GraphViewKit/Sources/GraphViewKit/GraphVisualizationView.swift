import SwiftUI
import WebKit

/// A full-screen Cytoscape.js graph rendered in an offline `WKWebView` —
/// no CDN, no network access. Bundles a pinned Cytoscape.js build as an SPM
/// resource.
///
/// Pass a Cytoscape.js `elements` JSON string, e.g. the output of
/// `GraphExporter.cytoscapeJSON(graph:)` from `GraphKit`.
public struct GraphVisualizationView: UIViewRepresentable {
    let cytoscapeJSON: String
    /// Called with the tapped node's id.
    var onNodeTap: ((String) -> Void)?

    public init(cytoscapeJSON: String, onNodeTap: ((String) -> Void)? = nil) {
        self.cytoscapeJSON = cytoscapeJSON
        self.onNodeTap = onNodeTap
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // graph.html posts the tapped node id on this channel.
        config.userContentController.add(context.coordinator, name: "nodeTap")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.pendingJSON = cytoscapeJSON

        let htmlURL = GraphViewKitResources.graphHTMLURL
        if let htmlURL {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }
        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        // Keep the coordinator's callback and data current across re-renders.
        context.coordinator.onNodeTap = onNodeTap
        context.coordinator.pendingJSON = cytoscapeJSON
        if context.coordinator.isLoaded {
            context.coordinator.inject(into: webView)
        }
    }

    public func makeCoordinator() -> Coordinator {
        let c = Coordinator()
        c.onNodeTap = onNodeTap
        return c
    }

    public static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        // Avoid leaking the strong reference the userContentController holds.
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "nodeTap")
    }

    // MARK: - Coordinator

    public final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var pendingJSON: String = ""
        var isLoaded = false
        var onNodeTap: ((String) -> Void)?

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            inject(into: webView)
        }

        public func userContentController(_ controller: WKUserContentController,
                                          didReceive message: WKScriptMessage) {
            guard message.name == "nodeTap", let id = message.body as? String else { return }
            onNodeTap?(id)
        }

        func inject(into webView: WKWebView) {
            guard !pendingJSON.isEmpty else { return }
            // Escape backticks and backslashes so the JS template literal is safe.
            let safe = pendingJSON
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`",  with: "\\`")
            let js = "renderGraph(`\(safe)`);"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}

// MARK: - ShareSheet

/// Thin wrapper around `UIActivityViewController` for sharing exported graph
/// files (e.g. the GraphML/Cytoscape JSON produced by `GraphKit`).
public struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    public init(items: [Any]) {
        self.items = items
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    public func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
