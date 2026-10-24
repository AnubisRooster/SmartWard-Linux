# OnDeviceKit

**OnDeviceKit** (ODK) — reusable Swift Package Manager components extracted from [therAIpist](https://github.com/AnubisRooster/therAIpist) (a private on-device iOS therapy companion app) and [CompyPal](https://github.com/AnubisRooster/CompyPal) (a sibling on-device AI companion app). These modules are domain-agnostic — nothing here is specific to therapy, journaling, or mental health — and are split out so other iOS/macOS projects can use them independently.

## Modules

### BYOKLLMKit

A "bring your own key" multi-provider LLM client. One `LLMService` actor routes to OpenRouter, OpenAI, Anthropic, xAI (Grok), DeepSeek, Groq, or Together AI, handling both the shared OpenAI-compatible chat-completions schema and Anthropic's distinct message schema. API keys are stored in the Keychain via `LLMKeychainStore`, never in `UserDefaults`.

Two API levels:
- **`LLMSending`** (`sendMessage` / `streamMessage`): plain text in, plain text out.
- **`LLMCompleting`** (`complete` / `stream` / `generateStructured`): tool calling, structured output, and token usage (plus billed cost on OpenRouter), identical across every provider.

```swift
import BYOKLLMKit

let keychain = LLMKeychainStore.shared
keychain.set("sk-...", for: .openai)

let llm = LLMService(keychain: keychain)
let reply = try await llm.sendMessage(
    provider: "openai",
    model: "gpt-4o-mini",
    messages: [LLMMessage(role: "user", content: "Hello!")]
)

// Or stream token-by-token (every provider, including Anthropic):
for try await delta in llm.streamMessage(provider: "openai", model: "gpt-4o-mini",
                                         messages: [LLMMessage(role: "user", content: "Hello!")]) {
    print(delta, terminator: "")
}
```

Tool calling: send tools, run the calls the model asks for, send the results back, repeat.

```swift
let search = LLMTool(name: "search_corpus",
                     description: "Search saved articles.",
                     inputSchema: ["type": "object",
                                   "properties": ["query": ["type": "string"]],
                                   "required": ["query"]])

var messages: [LLMChatMessage] = [.system("You are a research strategist."), .user("What's new in LoRA?")]
while true {
    let response = try await llm.complete(LLMRequest(provider: .anthropic, model: "claude-sonnet-5",
                                                     messages: messages, tools: [search]))
    messages.append(response.message)
    guard !response.toolCalls.isEmpty else { print(response.text); break }
    for call in response.toolCalls {
        let args = try call.decodeArguments(as: SearchArgs.self)
        messages.append(.toolResult(callID: call.id, content: runSearch(args.query)))
    }
}

// Streaming works the same way: `.textDelta`s as they arrive, `.toolCall` once a
// call's arguments are complete, and a final `.completed(LLMResponse)` with usage.
for try await event in llm.stream(request) { /* ... */ }
```

Structured output: JSON-schema output on OpenAI-compatible providers, and a forced tool call on Anthropic. Either way, the reply decodes straight into your type.

```swift
struct Entity: Decodable { let label: String; let type: String }
let entity = try await llm.generateStructured(
    LLMRequest(provider: .openrouter, model: "openai/gpt-4o-mini",
               messages: [.user("Extract the main entity: 'vLLM adds LoRA hot-swapping'")],
               responseFormat: .jsonSchema(name: "entity", schema: entitySchema)),
    as: Entity.self)
```

New-API failures throw `LLMCompletionError` (with `isRetryable` for 408/429/5xx and overload errors, for fallback rotation). Missing keys and unknown providers still throw `LLMError`, and `LLMError`'s cases are unchanged, so existing exhaustive `switch`es keep compiling.

`FallbackLLM` wraps any `LLMCompleting` and retries on another model when `isRetryable` says the failure is transient — the host supplies which models to try next (its own fallback list, a model catalog's cost/capability ranking, or both), so this stays a small, dependency-free wrapper:

```swift
let resilient = FallbackLLM(base: llm, maxAttempts: 3) { request in
    ["anthropic/claude-haiku-4-5", "openai/gpt-4o-mini"]   // tried in order, deduped against request.model
}
let reply = try await resilient.complete(request)   // rotates only before any output has reached the caller
```

### VoiceLoopKit

A hands-free, continuous voice-conversation loop: listen → (natural pause) → hand off → speak → resume listening. Wraps `SFSpeechRecognizer` + `AVAudioEngine` with silence-based endpointing, and stitches long monologues across `SFSpeechRecognizer`'s ~1-minute segment cap. `SpeechService` wraps `AVSpeechSynthesizer` for the speaking half.

```swift
import VoiceLoopKit

let controller = VoiceConversationController(
    config: VoiceLoopConfig(silenceInterval: 4, ttsRate: 0.5)
)
controller.start()

// Observe `controller.pendingUtterance`, run your own reply pipeline,
// then hand the reply back:
controller.deliverResponse("Here's my reply.")
```

Recognition runs on-device where the device supports it, but by default falls back to Apple's server recognition if on-device recognition keeps failing. Pass `VoiceLoopConfig(requiresOnDeviceRecognition: true)` when a conversation's audio must never leave the device: voice mode then refuses to start where on-device recognition isn't available, and never falls back. `SpeechService` drops code blocks and tables, reads links by their text and bare URLs as "a link", and strips markdown before speaking — `SpeechService.speakableText(_:)` exposes that cleanup on its own.

Also includes `ElevenLabsTTSEngine` and `OpenAITTSEngine`, two cloud-TTS alternatives to the on-device `SpeechService` (from [CompyPal](https://github.com/AnubisRooster/CompyPal)), and `PCMEnergyAnalyzer`, a pure utility that turns synthesized/recorded PCM audio into per-chunk amplitude "energies" for driving audio-reactive UI (waveform visualizers, lip-sync, speaking indicators) from any engine.

```swift
let tts = ElevenLabsTTSEngine()
tts.speak("Hello there!", voiceId: ElevenLabsTTSEngine.defaultVoiceId, modelId: "", apiKey: key,
          onStart: { energies, duration in /* drive a waveform/lip-sync view */ },
          onProgress: { range in /* highlight spoken text */ },
          completion: { },
          onError: { error in })

// Or OpenAI's TTS API — `speed` is applied server-side, unlike ElevenLabs's client-side `rate`:
let openaiTTS = OpenAITTSEngine()
openaiTTS.speak("Hello there!", voice: OpenAITTSEngine.defaultVoice, model: OpenAITTSEngine.defaultModel, apiKey: key,
                onStart: { energies, duration in /* drive a waveform/lip-sync view */ },
                onProgress: { range in /* highlight spoken text */ },
                completion: { },
                onError: { error in })
```

### PINLockKit

Keychain-backed PIN storage (`PINService`) plus a fully decoupled `PINLockout` state machine implementing escalating brute-force lockout (30s → 60s → 5m → 15m).

```swift
import PINLockKit

let pin = PINService()
pin.save("1234")

switch pin.attempt("0000") {
case .success: break
case .incorrect(let remaining): print("\(remaining) attempts left")
case .lockedOut(let seconds): print("locked for \(seconds)s")
}
```

### BiometricLockKit

A standalone Face ID / Touch ID / Optic ID unlock primitive over Apple's `LocalAuthentication`. It does **no** face matching itself — the camera, the neural match, and the biometric templates never leave the Secure Enclave; `BiometricService` only ever receives an opaque success/failure. Uses `.deviceOwnerAuthenticationWithBiometrics` (biometrics only, not the device passcode) so a failure routes to *your* fallback, plus a **domain-state anti-tamper check**: if someone enrolls a new face/finger in Settings, the next unlock returns `.biometryChanged` instead of `.success`.

The module owns no fallback UI and has **no dependency on `PINLockKit`** — any non-`.success` result is your cue to present a fallback (e.g. the `PINLockKit` screen).

> **Host requirement:** add an `NSFaceIDUsageDescription` string to your app's `Info.plist`, or Face ID evaluation crashes at runtime.

```swift
import BiometricLockKit

let biometrics = BiometricService()   // defaults: LAContext + Keychain baseline

switch await biometrics.unlock(reason: "Unlock your journal") {
case .success:
    openApp()

case .biometryChanged:
    // Enrolled biometrics changed since we last trusted this device.
    if presentPINScreenAndVerify() {          // your PINLockKit UI
        biometrics.acceptCurrentBiometry()    // re-baseline to the new set
        openApp()
    }

case .fallback, .lockout, .failed, .unavailable, .canceled:
    presentPINScreen()                        // your PINLockKit UI
}
```

Pairs with `PINLockKit`: treat biometrics as the fast path and the PIN as the always-present fallback (iOS *requires* a non-biometric path — it locks biometry after repeated failures). A ready-to-adapt composition of the two lives in [`Examples/AppLockCoordinator.swift`](Examples/AppLockCoordinator.swift) — kept out of the build so `BiometricLockKit` stays dependency-free. For the details behind `.biometryChanged` (and why an iOS upgrade can trigger it), see [`docs/biometric-domain-state.md`](docs/biometric-domain-state.md).

### ContentSafetyKit

Keyword-based crisis detection (`CrisisDetector`) and boundary-violation detection (`BoundaryDetector`) for assistant replies that must avoid diagnostic/prescriptive language. Both ship with sensible defaults and accept custom pattern lists.

```swift
import ContentSafetyKit

let crisis = CrisisDetector()
let result = crisis.check(userMessage)   // (isCrisis, level, pattern)

let boundary = BoundaryDetector()
let violation = boundary.check(replyText, context: .standard)
```

### GraphKit

Heuristic knowledge-graph extraction (`KnowledgeGraphExtractor`: emotions, people, and belief statements from free text, with edges wired between co-occurring entities) plus cross-session aggregation and export to Cytoscape/Neo4j JSON and GraphML (Gephi) via `GraphExporter`. Persistence-agnostic — pass your own node/edge value types via `SessionGraph`.

```swift
import GraphKit

let extraction = KnowledgeGraphExtractor().analyze("I feel anxious around my mother")
// extraction.nodes / extraction.edges — persist however you like

let graph = GraphExporter.aggregate(sessions: sessionGraphs)
let json = GraphExporter.cytoscapeJSON(graph: graph)
```

### AgentRouteKit

A generic confidence-scored routing primitive: register handlers that each report how confident they are about a context, and `Router` dispatches to the best match (with a fallback when nothing claims it).

```swift
import AgentRouteKit

let router = Router<String, String>(handlers: [myHandlerA, myHandlerB])
let output = await router.route(input, fallback: myDefaultHandler)
```

### GraphViewKit

An offline `WKWebView` wrapper (`GraphVisualizationView`) rendering a Cytoscape.js graph with no CDN/network dependency — a pinned Cytoscape.js build ships as a bundled SPM resource. Pairs naturally with `GraphKit`'s `GraphExporter.cytoscapeJSON(graph:)`. Also includes a thin `ShareSheet` wrapper for exporting the underlying GraphML/JSON files.

```swift
import GraphViewKit

GraphVisualizationView(cytoscapeJSON: json, onNodeTap: { tappedNodeID in
    // look up the tapped node in your own graph model
})
```

### LocalLLMKit

On-device GGUF inference via [LLM.swift](https://github.com/eastriverlee/LLM.swift) (a Swift wrapper around llama.cpp). `LocalLLMEngine` keeps a single model loaded, serializes concurrent load calls, races generation against a hard timeout, and picks the right chat template (Llama 3, Phi, Gemma, or a ChatML fallback) from the model ID. Depends on `BYOKLLMKit` for the shared `LLMMessage` type.

```swift
import LocalLLMKit
import BYOKLLMKit

let engine = LocalLLMEngine()
await engine.loadModel(id: "llama-3.2-1b", url: ggufFileURL)
let reply = try await engine.generate(
    modelID: "llama-3.2-1b",
    messages: [LLMMessage(role: "user", content: "Hello!")]
)
```

### ModelCatalogKit

Live model catalog fetching, TTL disk caching, and cost-first selection for OpenAI-compatible provider APIs — ported from [CompyPal](https://github.com/AnubisRooster/CompyPal). Instead of hardcoding a model ID, fetch the provider's live catalog and let `SelectionPolicy` rank it: free models first, then cheapest-paid, with an optional pinned override. Pairs naturally with `BYOKLLMKit` — pass the winning `CatalogEntry.id` as the `model:` argument.

```swift
import ModelCatalogKit

let fetcher = CatalogFetcher()          // defaults to OpenRouter's API
let cache = CatalogCache()
if await cache.isStale() {
    let entries = try await fetcher.fetch(apiKey: key)
    try await cache.save(entries: entries)
}
let catalog = (await cache.load())?.entries ?? []

let policy = SelectionPolicy(role: .chat, catalog: catalog, pinnedModelId: nil)
let candidates = policy.rank()   // walk this list for 429/5xx fallback rotation
```

### RetrievalKit

On-device retrieval-augmented generation: chunk documents (sentence-aligned via `NLTokenizer`, never mid-sentence), embed them with Apple's on-device `NLEmbedding` (no model to bundle, no network call — the whole indexed corpus never leaves the device), and retrieve the top-k most similar chunks by brute-force cosine similarity (`Accelerate`/vDSP). `ContextAssembler` then formats retrieved chunks into a token-budgeted context block ready to prepend to a `BYOKLLMKit`/`LocalLLMKit` prompt — sized to respect `LocalLLMKit`'s small on-device context windows.

Sized deliberately for a single user's personal corpus: a linear scan over vectors comfortably handles tens of thousands of chunks on-device with no ANN dependency. Beyond that scale you'd want an HNSW/usearch-backed index, which this module intentionally doesn't ship.

```swift
import RetrievalKit

let retriever = Retriever()   // NLEmbeddingProvider + in-memory VectorIndex by default
await retriever.index(Document(id: "entry-42", text: "I feel anxious around my mother."))

let hits = await retriever.retrieve("how do I feel about my mother?", topK: 5)
let context = ContextAssembler(tokenBudget: 1500).assemble(hits)
// Prepend `context` (a "reference material, not instructions" block) as a
// system message alongside the user's actual question.
```

`EmbeddingProviding` is a protocol seam — swap `NLEmbeddingProvider` for a GGUF embedding model (via `LocalLLMKit`) or a BYOK embeddings API. **A cloud-backed embedder sends the entire indexed corpus to that provider**, not just one chat turn — prefer the on-device default for personal data.

`LexicalIndex` adds BM25 keyword search alongside `Retriever`'s vector search — technical or proper-noun queries ("LoRA", "vLLM", "SWE-bench") are full of exact tokens that keyword matching finds and embeddings alone can miss, and compound tokens are indexed both whole and by their parts. `HybridRetriever` fuses the two by reciprocal rank fusion, so a query full of exact terms and a query that's purely conceptual both work well:

```swift
import RetrievalKit

let hybrid = HybridRetriever()   // Retriever + LexicalIndex
await hybrid.index(Document(id: "entry-42", text: "vLLM adds speculative decoding support."))

let hits = await hybrid.retrieve("vLLM speculative decoding", topK: 5)
// Each hit's `.provenance` is `.hybrid(keyword:vector:)`, so a host UI can
// show whether it matched on the words, the meaning, or both.
```

Both `LexicalIndex`'s BM25 ranking and `VectorIndex`'s cosine ranking narrow their candidates through `TopK`, a bounded min-heap — O(n log k) instead of sorting every candidate to find the top few.

### GraphRetrievalKit

GraphRAG: layers graph-hop expansion on top of `RetrievalKit`'s vector search, using `GraphKit`'s existing `KnowledgeGraphExtractor`/`AggregatedGraph` rather than duplicating entity extraction. A vector-search hit is expanded outward by `hops` graph edges (default 1, score-decayed) through the entities it mentions, surfacing related chunks that share no vocabulary with the query but are structurally connected — e.g. a chunk about "my mother" pulls in a chunk about "anxious" if the knowledge graph has a `Mother —TRIGGERS→ Anxious` edge, something cosine similarity alone would miss. Each result's `Provenance` (`.vector` vs. `.graphHop(distance:via:)`) is preserved, so a host UI can show *why* something was retrieved — worth surfacing given this sits on top of a personal/therapeutic corpus.

Depends on `RetrievalKit` + `GraphKit`; neither depends back on it, so a host that only wants plain vector RAG uses `RetrievalKit.Retriever` alone with no graph involved.

```swift
import GraphRetrievalKit
import GraphKit

let graphRetriever = GraphRetriever()
await graphRetriever.index(Document(id: "entry-42", text: "I feel anxious around my mother."))

// The host owns building/aggregating its own knowledge graph, same as GraphViewKit's usage.
let graph = GraphExporter.aggregate(sessions: sessionGraphs)

let hits = await graphRetriever.retrieve("my mother", topK: 5, hops: 1, graph: graph)
```

## Requirements

- iOS 17+ (all modules currently require iOS — `VoiceLoopKit` depends on `Speech`/`AVAudioSession`, which don't exist on macOS)
- Swift 5.9+

## Installation

Add via Swift Package Manager:

```swift
.package(url: "https://github.com/AnubisRooster/OnDeviceKit", from: "0.1.0")
```

Then depend on whichever product(s) you need — `BYOKLLMKit`, `VoiceLoopKit`, `PINLockKit`, `BiometricLockKit`, `ContentSafetyKit`, `GraphKit`, `AgentRouteKit`, `GraphViewKit`, `LocalLLMKit`, `ModelCatalogKit` — in your target.

### Repository structure

Each module also lives as its own standalone package under `Packages/<Name>/` — own `Package.swift`, own `Sources/`, own `Tests/`, declaring only *that module's* actual dependencies (e.g. `Packages/PINLockKit` has none; `Packages/LocalLLMKit` depends on `../BYOKLLMKit` locally plus `LLM.swift`). The root `Package.swift` is an umbrella manifest whose targets point at those same source directories, so remote consumers get the exact experience above — pick any product(s) from one `.package(url:)` — while local development, standalone testing, or lifting a single module into its own repo can all be done directly from its `Packages/<Name>/` folder without touching anything else.

## Status

Early extraction — API surface may still shift before `1.0`. All modules planned from the initial [therAIpist](https://github.com/AnubisRooster/therAIpist) review are present, plus `ModelCatalogKit`, streaming support in `BYOKLLMKit`, and `ElevenLabsTTSEngine`/`PCMEnergyAnalyzer` in `VoiceLoopKit`, ported from a comparison against [CompyPal](https://github.com/AnubisRooster/CompyPal), plus `OpenAITTSEngine` as a second cloud-TTS option, and `RetrievalKit`/`GraphRetrievalKit` (on-device RAG and GraphRAG, the latter built on `GraphKit`'s existing extraction).

## License

Apache License 2.0 — see [LICENSE](LICENSE).
