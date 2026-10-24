import SwiftUI
import SwiftData
import KnowledgeStore
import Pipeline

/// Reader view: the article's cleaned text, with a fallback to fetch the full
/// page when the source only carried a teaser.
struct ArticleReaderView: View {
    let article: Article

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var ingest = IngestController.shared
    @State private var readout = ArticleReadoutController.shared
    @State private var navigation = AppNavigation.shared
    @State private var lock = AppLockController.shared
    @State private var isLoadingFullText = false
    @State private var fullTextError: String?
    @State private var recordedOpen = false

    private var paragraphs: [String] { ArticleReadout.paragraphs(of: article) }

    /// This article is being read aloud (or is paused mid-reading).
    private var isReading: Bool { readout.articleID == article.id && readout.isActive }

    private var originalURL: URL? { URL(string: article.canonicalURL) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(article.title)
                        .font(.title2.bold())
                        .id(ReadoutSegment.Anchor.title)
                    metadata
                        .id(ReadoutSegment.Anchor.details)

                    ArticleSummaryCard(article: article)
                        .id(ReadoutSegment.Anchor.summary)

                    ThemesRow(article: article)
                        .id(ReadoutSegment.Anchor.themes)

                    if !article.relevanceReason.isEmpty {
                        Label(article.relevanceReason, systemImage: "sparkle.magnifyingglass")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .id(ReadoutSegment.Anchor.relevance)
                    }

                    if article.stage == .fetched || (article.stage == .triagedOut && article.cleanedText.count < 1_000) {
                        fullTextBanner
                    }

                    if paragraphs.isEmpty && article.stage != .fetched {
                        Label("Only the headline was saved for this item. Open the original to read it.",
                              systemImage: "doc.text.magnifyingglass")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .id(ReadoutSegment.Anchor.note)
                    }

                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                        Text(paragraph)
                            .font(.body)
                            .lineSpacing(3)
                            .background(isReading && readout.currentAnchor == .paragraph(index)
                                        ? Color.accentColor.opacity(0.15) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 6))
                            .id(ReadoutSegment.Anchor.paragraph(index))
                    }
                    .textSelection(.enabled)

                    if let originalURL {
                        Link(destination: originalURL) {
                            Label("Open original", systemImage: "safari")
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // The screen follows the voice.
            .onChange(of: readout.currentAnchor) { _, anchor in
                guard isReading, let anchor else { return }
                withAnimation { proxy.scrollTo(anchor, anchor: .top) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isReading { readoutBar }
        }
        // Spoken commands ("read this article", "star this") act on the open article.
        .onAppear { navigation.readerArticle = article }
        // Reading aloud never outlives this screen, or the app being in
        // front and unlocked.
        .onDisappear {
            stopReading()
            if navigation.readerArticle?.id == article.id { navigation.readerArticle = nil }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { stopReading() }
        }
        .onChange(of: lock.isLocked) { _, locked in
            if locked { stopReading() }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if isReading {
                    Button("Stop reading", systemImage: "stop.fill") { readout.stop() }
                } else {
                    Menu {
                        Button("Read the article", systemImage: "text.book.closed") { startReading(.whole) }
                        Button("Read the summary", systemImage: "list.bullet.rectangle") { startReading(.summaryOnly) }
                    } label: {
                        Label("Read aloud", systemImage: "speaker.wave.2")
                    } primaryAction: {
                        // A reading profile can make the speaker button read just the summary.
                        startReading(VoiceSettings.readingScope)
                    }
                }
                Button(article.isStarred ? "Unstar" : "Star",
                       systemImage: article.isStarred ? "star.fill" : "star") {
                    article.isStarred.toggle()
                    if article.isStarred {
                        context.insert(ReadingSignal(articleID: article.id, kind: "star"))
                    }
                }
                if let originalURL {
                    ShareLink(item: originalURL)
                }
            }
        }
        .task { recordOpen() }
        // On first open, and again when the text changes (the full page was loaded).
        .task(id: article.cleanedText.count) {
            await ArticleSummaryController.shared.ensure(article, context: context)
        }
    }

    private func startReading(_ scope: ReadoutScope) {
        readout.start(article, scope: scope, sourceName: article.sourceLabel)
    }

    private func stopReading() {
        if readout.articleID == article.id { readout.stop() }
    }

    /// Previous, pause or keep going, next, and stop, while it reads.
    private var readoutBar: some View {
        HStack(spacing: 28) {
            Button { readout.previous() } label: { Image(systemName: "backward.fill") }
                .accessibilityLabel("Previous section")
            Button {
                if readout.isPaused { readout.resume() } else { readout.pause() }
            } label: {
                Image(systemName: readout.isPaused ? "play.fill" : "pause.fill")
            }
            .accessibilityLabel(readout.isPaused ? "Keep reading" : "Pause reading")
            Button { readout.next() } label: { Image(systemName: "forward.fill") }
                .accessibilityLabel("Next section")
            Spacer(minLength: 0)
            let position = readout.playback.position
            Text("\(position.number) of \(position.count)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button { readout.stop() } label: { Image(systemName: "stop.fill") }
                .accessibilityLabel("Stop reading")
        }
        .font(.title3)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let source = article.source {
                Label(source.title.isEmpty ? source.sourceKind.displayName : source.title,
                      systemImage: source.sourceKind.systemImage)
            }
            HStack(spacing: 4) {
                if let byline = article.byline, !byline.isEmpty {
                    Text(byline).lineLimit(1)
                    Text("·")
                }
                Text(article.publishedAt ?? article.ingestedAt, format: .dateTime.day().month().year())
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private var fullTextBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This source only includes a preview.")
                .font(.subheadline)
            if isLoadingFullText {
                ProgressView("Fetching the article…")
            } else {
                Button("Load full article", systemImage: "arrow.down.doc") {
                    Task { await loadFullText() }
                }
                .buttonStyle(.bordered)
            }
            if let fullTextError {
                Text(fullTextError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func loadFullText() async {
        isLoadingFullText = true
        defer { isLoadingFullText = false }
        do {
            try await ingest.loadFullText(of: article, context: context)
            fullTextError = nil
        } catch {
            fullTextError = error.localizedDescription
        }
    }

    /// Marks the article read and logs one `open` signal per visit; triage
    /// learns from these (PLAN FR-4).
    private func recordOpen() {
        guard !recordedOpen else { return }
        recordedOpen = true
        article.isRead = true
        context.insert(ReadingSignal(articleID: article.id, kind: "open"))
    }
}
