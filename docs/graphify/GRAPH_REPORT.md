# Graph Report - SmartWard-Linux  (2026-10-24)

## Corpus Check
- Large corpus: 358 files · ~796,273 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder.

## Summary
- 5685 nodes · 15613 edges · 257 communities (242 shown, 15 thin omitted)
- Extraction: 87% EXTRACTED · 13% INFERRED · 0% AMBIGUOUS · INFERRED: 2032 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- ThemeNode
- .fetch()
- cytoscape.min.js
- KnowledgeStore
- AnalyzerCommandRecognizer
- GraphIndexer
- JSONValue
- Article
- Retriever
- PipelineController
- String
- Foundation
- ArticleReadoutController
- .makeContainer()
- Plugin.swift
- VoiceCommandParser
- FetchURLTool
- View
- VoiceCommand
- .outcome()
- Choice
- LLMUsage
- Project
- SmartWardIntents.swift
- ModelContext
- Sendable
- LocalizedError
- DailyBudget
- BYOKLLMKit
- .extract()
- LLMProvider
- VoiceAnswersTests
- BiometricService
- XCTest
- BackupView
- OpenAITTSEngine
- Identifiable
- BiometricEvaluation
- LLMChatMessage
- HybridSearchIndex
- FallbackLLM
- GitHubClient
- IngestError
- RetrievedPassage
- AppLockCoordinator
- LLMService
- .aggregate()
- VoiceContext
- ShimObjectState
- LLMCompleting
- ScoredChunk
- VectorIndex
- ArticleSummary
- FileCache
- CatalogEntry
- RawItem
- GitHubDeviceFlow
- LibraryFixture
- ReadoutPlayback
- PerfTrace
- ExtractedGraph
- LLMRequest
- ProjectArticlesTests
- .body()
- OllamaClient
- StrategistRunner
- Codable
- SQLiteDatabase
- SourceKind
- .dismiss()
- LocalLLMEngine
- Library
- .body
- VoiceConversationController
- GitHubRepo
- EchoHandler
- LLMStreamEvent
- ConversationView
- VoiceIntentTests
- OnboardingProposal
- .decodeResponse()
- EntityChunkIndex
- ExtractedArticle
- ConversationMode
- .start()
- GraphSnapshot
- Phase 5: Hardening
- Pipeline module (ingestion, graph, searc
- .outcome()
- VoiceCommandTests
- Invariant D5: Private content never goes
- XCTestCase
- PINService
- StreamDelegate
- .analyze()
- PINAttemptResult
- ContextAssembler
- ElevenLabsTTSEngine
- CappedFetch
- SourceFetcher
- StrategyItemKind
- .chat()
- AVFoundation
- CodingKeys
- GraphRAG
- Dependency
- BriefError
- .suggest()
- LLMCompletionError
- LLMKeychainStore
- .energies()
- VoiceTranscriptTests
- ReadoutSegment
- .load()
- .check()
- VoiceConfirmationGate
- Parent
- Ingestion pipeline: fetch, clean, triage
- BYOKLLMKit
- GraphRetriever
- ThemeStrengthCache
- .fetch()
- ArticleSummaryController
- ModelCatalogController
- PackageDescription
- .segments()
- CodingKeys
- LexicalIndex
- BriefingTests
- LocalModelConfig
- SmartWardKit.KnowledgeStore (SwiftData m
- Article (SwiftData model)
- ThemeNode (SwiftData model)
- AppNavigation
- BiometricResult
- LLMResponse
- Coordinator
- GitHubError
- GitHubAccount
- .fetchURL()
- ApprovalDecision
- InterestModel
- ActionRequest
- Approval Before Actions
- .run()
- ArticleReaderView
- IngestController
- Strategist Layer
- SpeechService
- .check()
- ShareSheet
- Chunker
- .apply()
- ShimRelationship
- SmartWardEngine
- .check()
- RootView
- GraphCanvas
- SmartWard (iOS Application Target)
- PersistentModel
- DigestCluster
- .makeFixture()
- SmartWardShare (Share Extension Target)
- Prompt-injection defense
- ShareModel
- FakeCompleter
- .check()
- VoiceLoopConfig
- AppLockPolicy
- ModelContainer
- ModelFallback
- AppLockController
- DeveloperView
- SmartWard XcodeGen Project Spec
- ParsedFeed
- StepProgress
- Scenario
- .body
- Accessibility Verification Pass
- GraphRAG Latency Budget (NFR-4: p95 unde
- ShimKey
- LLMTool
- PINLockoutTests
- .projects()
- AddSourceTool
- Anchor
- LexicalIndex
- .text()
- .messages()
- FakeClock
- SeededRandom
- VoiceSpeaker
- GraphView
- What the Simulator Can't Show
- Inference Layer
- ContextAssembler token budget and fencin
- BYOKFileSecretStore
- .parseSSELine()
- .importItems()
- .score()
- .data()
- .decode()
- ThemeDetailView
- .check()
- OnboardingView
- graphify_pipeline.py
- BiometryType
- .service()
- .score()
- TopK
- TopKTests
- TTSError
- TopK
- FallbackLLM
- .check()
- FakeOllama
- FakeEmbedder
- .check()
- StrategistCore (tool loop, prompts, brie
- Packages/SmartWardKit (local SPM package
- SmartWardKit (Local Swift Package)
- .items()
- ModelConfiguration
- .seededEngine()
- NLEmbeddingProvider
- ElevenLabsTTSEngineTests
- .allowsRedirect()
- ArchiveError
- FetchDescriptor
- Graph View
- BiometricLockKit
- UntrustedText (body/attribute inside its
- NSObject
- SearchHit
- .audioPlayerDidFinishPlaying()
- FileCacheTests
- TTSError
- .speakableText()
- DigestController
- Living Project Brief
- RepoSync.swift
- BriefRevisionStatus
- StrategyItemStatus
- VoiceSettings
- Chunk (SwiftData model)
- DecisionProviding protocol seam
- LLMProviderTests
- Phase
- Status
- Apple Intelligence Preflight
- VoiceReadingFilter
- VoiceSpeedChange
- .send()
- Answer
- TriageScore
- graphify_refresh.sh
- shim.h

## God Nodes (most connected - your core abstractions)
1. `ModelContext` - 154 edges
2. `Article` - 120 edges
3. `KnowledgeStore` - 116 edges
4. `SwiftData` - 100 edges
5. `JSONValue` - 95 edges
6. `XCTest` - 94 edges
7. `LLMProvider` - 81 edges
8. `Project` - 80 edges
9. `VoiceCommand` - 79 edges
10. `LLMRequest` - 70 edges

## Surprising Connections (you probably didn't know these)
- `.missingKeyWarning` --calls--> `LLMProvider`  [INFERRED]
  SmartWard/Chat/ConversationView.swift → Packages/OnDeviceKit/Packages/BYOKLLMKit/Sources/BYOKLLMKit/LLMProvider.swift
- `.canStart` --references--> `LLMProvider`  [INFERRED]
  SmartWard/Chat/NewConversationView.swift → Packages/OnDeviceKit/Packages/BYOKLLMKit/Sources/BYOKLLMKit/LLMProvider.swift
- `.canStart` --references--> `LLMProvider`  [INFERRED]
  SmartWard/Onboarding/OnboardingView.swift → Packages/OnDeviceKit/Packages/BYOKLLMKit/Sources/BYOKLLMKit/LLMProvider.swift
- `.matches` --references--> `ThemeNode`  [INFERRED]
  SmartWard/Graph/GraphView.swift → Packages/SmartWardKit/Sources/KnowledgeStore/Models.swift
- `.body` --calls--> `Section`  [INFERRED]
  SmartWard/Graph/GraphExtraction.swift → Packages/SmartWardKit/Sources/Pipeline/Extraction.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Build Targets and the Package Products They Link** — project_smartward, project_smartwardshare, project_smartwardkit, project_ondevicekit, project_shareinbox, project_knowledgestore, project_strategistcore, project_ingestkit, project_applock, project_pipeline, project_byokllmkit, project_modelcatalogkit, project_pinlockkit, project_biometriclockkit [EXTRACTED 1.00]
- **Device-Only Capabilities the Simulator Cannot Verify** — docs_device_testing_apple_intelligence_on_device_triage, docs_device_testing_on_device_theme_extraction, docs_device_testing_summarized_on_device_digest, docs_device_testing_background_processing_bgtaskscheduler, docs_device_testing_share_extension_safari_capture, docs_device_testing_app_lock_face_id, docs_device_testing_siri_ask_smartward, docs_device_testing_shortcuts_app_intents [EXTRACTED 1.00]
- **Ingestion pipeline and politeness subsystem** — claude_ingestkit, claude_politenessgate, claude_articleextractor, claude_reposync, claude_pipelinerunner, claude_articleindexer, claude_embeddingmodel, claude_politeness_invariant, claude_idempotent_stages [EXTRACTED 1.00]
- **Phase 1 Foundation feature set** — readme_phase1_foundation, readme_knowledgestore, readme_app_shell, readme_strategist_chat, readme_onboarding_interview, readme_github_signin, readme_repo_sync, readme_app_lock [EXTRACTED 1.00]
- **Inference tier stack T0-T3** — docs_plan_inference_tiers, docs_plan_t0_heuristics, docs_plan_t1_foundation_models, docs_plan_t2_cheap_byok, docs_plan_t3_frontier_byok, docs_plan_applefmkit, docs_plan_byokllmkit, docs_plan_modelcatalogkit, docs_plan_usageledger [EXTRACTED 1.00]
- **Knowledge Layer subsystem** — docs_plan_knowledge_layer, docs_plan_retrievalkit, docs_plan_graphkit, docs_plan_graphretrievalkit, docs_plan_entityresolver, docs_plan_contextassembler, docs_plan_graphrag [EXTRACTED 1.00]
- **SwiftData theme-graph entity set** — docs_plan_themenode, docs_plan_entityalias, docs_plan_mention, docs_plan_themeedge, docs_plan_chunk, docs_plan_article, docs_plan_message, docs_plan_conversation, docs_plan_project, docs_plan_projectlink, docs_plan_projectbrief, docs_plan_strategyitem, docs_plan_interestprofile, docs_plan_readingsignal, docs_plan_source, docs_plan_usagerecord [EXTRACTED 1.00]
- **App Group Shared-Container Mechanism (extension writes, app imports)** — project_app_group_entitlement, project_shareinbox, project_smartward, project_smartwardshare, docs_device_testing_app_group_registration [INFERRED 0.85]
- **Prompt isolation and approval boundary** — readme_approval_before_actions, readme_reference_fencing, readme_prompt_fence_escaping, readme_red_team_suite, readme_poisoned_corpus, readme_private_content_policy, claude_untrustedtext, claude_contextpolicy, claude_action_confirmation, claude_untrusted_text_rule [INFERRED 0.85]

## Communities (257 total, 15 thin omitted)

### Community 0 - "ThemeNode"
Cohesion: 0.05
Nodes (47): ContextPolicy, Bool, Chunk, Set, Chunk, Conversation, EntityAlias, InterestProfile (+39 more)

### Community 1 - ".fetch()"
Cohesion: 0.07
Nodes (33): T, EmbeddingModel, ExtractionTiers, ArticleIndexer, Backlog, .total, FullTextFetching, PipelineRunner (+25 more)

### Community 2 - "cytoscape.min.js"
Cohesion: 0.05
Nodes (58): a(), Ao(), b(), Ba(), cs(), d(), dc(), ds() (+50 more)

### Community 3 - "KnowledgeStore"
Cohesion: 0.06
Nodes (14): BackgroundTasks, FoundationModels, IngestKit, KnowledgeStore, Observation, ShareInbox, GitHubConfig, Triage.Strength (+6 more)

### Community 4 - "AnalyzerCommandRecognizer"
Cohesion: 0.05
Nodes (38): AnalyzerInput, AsyncStream, AVAudioConverter, AVAudioFormat, AnalyzerCommandRecognizer, AnalyzerFeed, Session, AVAudioNodeTapBlock (+30 more)

### Community 5 - "GraphIndexer"
Cohesion: 0.06
Nodes (35): Error, EntityExtracting, ExtractionOutput, ExtractionTier, byok, onDevice, ExtractionAttempt, ExtractionJob (+27 more)

### Community 6 - "JSONValue"
Cohesion: 0.05
Nodes (35): ExpressibleByArrayLiteral, ExpressibleByBooleanLiteral, ExpressibleByDictionaryLiteral, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, ExpressibleByNilLiteral, ExpressibleByStringLiteral, error (+27 more)

### Community 7 - "Article"
Cohesion: 0.05
Nodes (48): Article, .stage, ArticleStage, cleaned, embedded, extracted, failed, fetched (+40 more)

### Community 8 - "Retriever"
Cohesion: 0.09
Nodes (24): Document, EmbeddingProviding, Float, HybridRetriever, .underlyingRetriever, Bool, Chunk, Document (+16 more)

### Community 9 - "PipelineController"
Cohesion: 0.05
Nodes (36): App, BGContinuedProcessingTask, Scene, SmartWardApp, .body, .body, BackgroundWork, Date (+28 more)

### Community 10 - "String"
Cohesion: 0.07
Nodes (25): CatalogFetcher, JSONDecoder, PINFileSecretStore, .directory, Bool, Data, URL, KeychainLockoutStore (+17 more)

### Community 11 - "Foundation"
Cohesion: 0.06
Nodes (11): Accelerate, Foundation, FoundationNetworking, GraphKit, GraphRetrievalKit, NaturalLanguage, KeychainDomainStateStore, Data (+3 more)

### Community 12 - "ArticleReadoutController"
Cohesion: 0.08
Nodes (24): AVSpeechSynthesizerDelegate, MPRemoteCommand, .readoutBar, ArticleReadoutController, .currentAnchor, .currentText, .isActive, .isBriefing (+16 more)

### Community 13 - ".makeContainer()"
Cohesion: 0.10
Nodes (16): Bool, URL, ArticleSummaryTests, IngestionSummaryTests, Refused, device, provider, StubSummarizer (+8 more)

### Community 14 - "Plugin.swift"
Cohesion: 0.08
Nodes (42): AccessorDeclSyntax, AccessorMacro, AttributeSyntax, CompilerPlugin, DeclGroupSyntax, DeclSyntax, DeclSyntaxProtocol, ExtensionDeclSyntax (+34 more)

### Community 15 - "VoiceCommandParser"
Cohesion: 0.09
Nodes (24): EchoGuard, Bool, Int, Set, VoiceCommandParser, VoiceItemMatcher, VoiceParse, command (+16 more)

### Community 16 - "FetchURLTool"
Cohesion: 0.08
Nodes (26): Decodable, Arguments, FetchURLTool, .asksForApproval, .definition, Bool, URL, ReferenceContext (+18 more)

### Community 17 - "View"
Cohesion: 0.07
Nodes (40): Section, entities, relations, ActionApprovalSettingsSection, .body, LockScreen, PrivacyCover, .body (+32 more)

### Community 18 - "VoiceCommand"
Cohesion: 0.04
Nodes (47): VoiceCommand, aboutTheme, acceptBriefUpdate, ask, back, clearSearch, .confirmation, decline (+39 more)

### Community 19 - ".outcome()"
Cohesion: 0.08
Nodes (19): ProjectVoiceQueries, Outcome, Phase, listening, off, starting, unavailable, Digest (+11 more)

### Community 20 - "Choice"
Cohesion: 0.05
Nodes (44): CaseIterable, Strength, balanced, off, strict, .threshold, ReadingFilter, all (+36 more)

### Community 21 - "LLMUsage"
Cohesion: 0.11
Nodes (20): LLMUsage, BYOKDigestSummarizer, DigestBuilder, DigestSummarizing, DigestSummary, DigestSummaryRequest, Group, Bool (+12 more)

### Community 22 - "Project"
Cohesion: 0.12
Nodes (18): BriefRevision, Project, ProjectBrief, BriefEditing, tooLong, BriefReviser, Suggestion, Date (+10 more)

### Community 23 - "SmartWardIntents.swift"
Cohesion: 0.08
Nodes (33): AppEntity, AppEnum, AppIntent, AppIntents, AppShortcut, AppShortcutsProvider, AudioPlaybackIntent, DisplayRepresentation (+25 more)

### Community 24 - "ModelContext"
Cohesion: 0.09
Nodes (18): Encodable, LibraryArchive, Bool, Int, T, DecodeBox, ModelContext, .hasChanges (+10 more)

### Community 25 - "Sendable"
Cohesion: 0.18
Nodes (36): Equatable, AliasRecord, ArticleRecord, BriefRecord, BriefRevisionRecord, ChunkRecord, ConversationRecord, DigestRecord (+28 more)

### Community 26 - "LocalizedError"
Cohesion: 0.05
Nodes (39): LocalizedError, LocalLLMError, busy, .errorDescription, loadFailed, notLoaded, timeout, CatalogError (+31 more)

### Community 27 - "DailyBudget"
Cohesion: 0.10
Nodes (17): DailyBudget, Line, .id, Bool, Calendar, Date, Double, Int (+9 more)

### Community 28 - "BYOKLLMKit"
Cohesion: 0.07
Nodes (4): BYOKLLMKit, LocalLLMKit, ModelCatalogKit, StrategistCore

### Community 29 - ".extract()"
Cohesion: 0.09
Nodes (15): DateFormatter, ISO8601DateFormatter, ArticleExtractor, Bool, Document, Element, URL, CanonicalURL (+7 more)

### Community 30 - "LLMProvider"
Cohesion: 0.09
Nodes (27): LLMProvider, anthropic, .baseURL, deepseek, .displayName, .exampleModelID, groq, .id (+19 more)

### Community 31 - "VoiceAnswersTests"
Cohesion: 0.09
Nodes (8): LibraryVoiceQueries, Bool, Double, Int, ThemeDescription, VoiceAnswers, VoiceAnswersTests, World

### Community 32 - "BiometricService"
Cohesion: 0.12
Nodes (13): BiometricEvaluating, DomainStateStoring, Data, BiometricService, .hasBaseline, Bool, Data, DomainStateTests (+5 more)

### Community 33 - "XCTest"
Cohesion: 0.10
Nodes (3): ContentSafetyKit, Pipeline, XCTest

### Community 34 - "BackupView"
Cohesion: 0.08
Nodes (28): BackupView, .body, .canCreate, Bool, Data, Error, LibraryArchive, Result (+20 more)

### Community 35 - "OpenAITTSEngine"
Cohesion: 0.14
Nodes (14): AVAudioPlayerDelegate, OpenAITTSEngine, PrefetchedClip, Data, Double, Error, Float, NSRange (+6 more)

### Community 36 - "Identifiable"
Cohesion: 0.10
Nodes (18): Hashable, Identifiable, Architecture, Voice, SharedInbox, .itemsDirectory, .projectsFile, SharedItem (+10 more)

### Community 37 - "BiometricEvaluation"
Cohesion: 0.07
Nodes (23): LAPolicy, LocalAuthentication, Result, Void, BiometricEvaluation, canceled, failed, fallback (+15 more)

### Community 38 - "LLMChatMessage"
Cohesion: 0.09
Nodes (23): LLMChatMessage, .text, .toolCalls, .toolResults, .isRetryable, LLMContentBlock, text, toolCall (+15 more)

### Community 39 - "HybridSearchIndex"
Cohesion: 0.13
Nodes (18): HybridSearchIndex, .documentCount, .documentIDs, .needsRebuild, RankedDocument, SearchCorpus, SearchDocument, Bool (+10 more)

### Community 40 - "FallbackLLM"
Cohesion: 0.15
Nodes (15): FallbackLLM, Alternatives, AsyncThrowingStream, Bool, Error, Int, CallRecorder, FallbackLLMTests (+7 more)

### Community 41 - "GitHubClient"
Cohesion: 0.12
Nodes (13): GitHubClient, .isAuthenticated, GitHubUser, HTTPTransport, Set, T, FakeTransport, GitHubClientTests (+5 more)

### Community 42 - "IngestError"
Cohesion: 0.09
Nodes (25): IngestError, backingOff, disallowedByRobots, .errorDescription, http, invalidResponse, invalidURL, notAFeed (+17 more)

### Community 43 - "RetrievedPassage"
Cohesion: 0.11
Nodes (17): GraphRetriever, RetrievedPassage, Bool, Float, UUID, Why, connected, .description (+9 more)

### Community 44 - "AppLockCoordinator"
Cohesion: 0.11
Nodes (19): AnyObject, AppLock, AppLockCoordinator, .biometryName, .isPINLockedOut, .pinLockoutRemaining, BiometricUnlocking, PINOutcome (+11 more)

### Community 45 - "LLMService"
Cohesion: 0.12
Nodes (15): LLMError, apiError, .errorDescription, noAPIKey, streamingNotSupported, unsupportedProvider, LLMSending, LLMService (+7 more)

### Community 46 - ".aggregate()"
Cohesion: 0.16
Nodes (8): AggregatedEdge, AggregatedGraph, AggregatedNode, GraphExporter, Int, URL, GraphExporterTests, Int

### Community 47 - "VoiceContext"
Cohesion: 0.12
Nodes (19): VoiceContext, Action, Answer, Outcome, actions, notUnderstood, Bool, Int (+11 more)

### Community 48 - "ShimObjectState"
Cohesion: 0.16
Nodes (12): M, BlobSlot, LinkSlot, pending, resolved, ShimObjectState, AnyModel, AnyObject (+4 more)

### Community 49 - "LLMCompleting"
Cohesion: 0.09
Nodes (11): LLMCompleting, invalidStructuredOutput, AsyncThrowingStream, Error, T, BYOKArticleSummarizer, BYOKExtractor, ExtractionTests (+3 more)

### Community 50 - "ScoredChunk"
Cohesion: 0.15
Nodes (17): Edge, Node, SessionGraph, Float, GraphExpander, Float, GraphExpanderTests, Chunk (+9 more)

### Community 51 - "VectorIndex"
Cohesion: 0.17
Nodes (12): entries, CodableEntry, Entry, Bool, Chunk, Data, Float, Int (+4 more)

### Community 52 - "ArticleSummary"
Cohesion: 0.10
Nodes (14): NSRegularExpression, ArticleSummary, .isEmpty, Question, about, evidence, matters, remember (+6 more)

### Community 53 - "FileCache"
Cohesion: 0.10
Nodes (10): CatalogCache, Bool, TimeInterval, FileCache, .cacheDir, Bool, Data, URL (+2 more)

### Community 54 - "CatalogEntry"
Cohesion: 0.14
Nodes (13): CatalogCacheData, CatalogEntry, CatalogResponse, ModelRole, chat, extract, image, Date (+5 more)

### Community 55 - "RawItem"
Cohesion: 0.13
Nodes (14): FeedIngest, Result, Bool, Date, Error, Int, Source, TimeInterval (+6 more)

### Community 56 - "GitHubDeviceFlow"
Cohesion: 0.10
Nodes (19): GitHubDeviceCode, GitHubDeviceFlow, failed, GitHubTokenPoll, pending, slowDown, token, async (+11 more)

### Community 57 - "LibraryFixture"
Cohesion: 0.11
Nodes (19): BackupError, .errorDescription, newerVersion, notABackup, passphraseTooShort, unsupportedCompression, wrongPassphraseOrDamaged, EncryptedBackup (+11 more)

### Community 58 - "ReadoutPlayback"
Cohesion: 0.17
Nodes (7): ReadoutPlayback, .currentGroup, .groupPosition, .isActive, .position, Bool, ReadoutPlaybackTests

### Community 59 - "PerfTrace"
Cohesion: 0.12
Nodes (19): DispatchTime, os, PerfTrace, .names, .samples, Sample, SampleLock, Summary (+11 more)

### Community 60 - "ExtractedGraph"
Cohesion: 0.11
Nodes (11): LanguageModelSession, name, Entity, ExtractedGraph, ExtractionText, Relation, Bool, ExtractionTextTests (+3 more)

### Community 61 - "LLMRequest"
Cohesion: 0.11
Nodes (15): LLMRequest, LLMToolChoice, auto, none, required, tool, Double, Int (+7 more)

### Community 62 - "ProjectArticlesTests"
Cohesion: 0.15
Nodes (9): SourceHealth, Error, SourceHealthTests, ProjectArticlesTests, Date, Double, Int, Source (+1 more)

### Community 63 - ".body()"
Cohesion: 0.11
Nodes (10): AnthropicWire, Bool, messages, AnthropicWireRequestTests, ArticleSummaryPrompt, .schema, DigestPrompt, ExtractionPrompt (+2 more)

### Community 64 - "OllamaClient"
Cohesion: 0.15
Nodes (12): ExtractionBusy, .errorDescription, LocalArticleSummarizer, LocalDigestSummarizer, LocalEntityExtractor, LocalRelevanceJudge, reachable(), Bool (+4 more)

### Community 65 - "StrategistRunner"
Cohesion: 0.18
Nodes (15): StrategistRunner, Int, EchoTool, .asksForApproval, .definition, FailingTool, .asksForApproval, .definition (+7 more)

### Community 66 - "Codable"
Cohesion: 0.14
Nodes (25): Codable, Data, AnthropicContentBlock, AnthropicMessage, AnthropicRequest, AnthropicResponse, AnthropicUsage, CodingKeys (+17 more)

### Community 67 - "SQLiteDatabase"
Cohesion: 0.10
Nodes (18): CSQLite, CustomStringConvertible, Int32, OpaquePointer, Bool, Void, SQLiteDatabase, SQLiteError (+10 more)

### Community 68 - "SourceKind"
Cohesion: 0.10
Nodes (23): .sourceKind, SourceKind, arxiv, githubReleases, githubRepo, hfPapers, hn, .isPolled (+15 more)

### Community 69 - ".dismiss()"
Cohesion: 0.10
Nodes (20): ChatListView, .body, modeLabel(), NewConversationView, .body, .canStart, .providersWithKeys, Bool (+12 more)

### Community 70 - "LocalLLMEngine"
Cohesion: 0.13
Nodes (10): LLM, LocalLLMEngine, Bool, Int, Never, Task, URL, Void (+2 more)

### Community 71 - "Library"
Cohesion: 0.17
Nodes (17): ArgumentParser, AsyncParsableCommand, Add, Ask, Digest, Ingest, Library, note() (+9 more)

### Community 72 - ".body"
Cohesion: 0.11
Nodes (12): AVAudioSession, LockWindow, Bool, .body, CommandRecognizing, VoiceEngine, .current, .id (+4 more)

### Community 73 - "VoiceConversationController"
Cohesion: 0.16
Nodes (11): completion, Bool, Never, SFSpeechAudioBufferRecognitionRequest, SFSpeechRecognitionTask, Task, Timer, Void (+3 more)

### Community 74 - "GitHubRepo"
Cohesion: 0.15
Nodes (12): GitHubRepo, .id, Bool, ApplyResult, Document, RepoSnapshot, RepoSync, Date (+4 more)

### Community 75 - "EchoHandler"
Cohesion: 0.17
Nodes (10): AgentRouteKit, Output, Handler, Router, .handlerNames, Context, Float, EchoHandler (+2 more)

### Community 76 - "LLMStreamEvent"
Cohesion: 0.15
Nodes (12): LLMStreamEvent, completed, textDelta, AsyncThrowingStream, Error, OpenAIStreamAccumulator, PartialToolCall, SSE (+4 more)

### Community 77 - "ConversationView"
Cohesion: 0.11
Nodes (17): ActionConfirmationCard, .body, ConversationView, .body, .composer, .messages, .missingKeyWarning, .voiceStatusText (+9 more)

### Community 78 - "VoiceIntentTests"
Cohesion: 0.11
Nodes (12): CodingKeys, action, change, filter, kind, number, on, order (+4 more)

### Community 79 - "OnboardingProposal"
Cohesion: 0.11
Nodes (19): OnboardingProposal, .schema, ProjectProposal, .id, SourceProposal, .id, OnboardingReviewView, .body (+11 more)

### Community 80 - ".decodeResponse()"
Cohesion: 0.14
Nodes (8): AnthropicStreamAccumulator, Block, text, toolUse, Data, Int, AnthropicStreamAccumulatorTests, AnthropicWireResponseTests

### Community 81 - "EntityChunkIndex"
Cohesion: 0.20
Nodes (7): EntityChunkIndex, Chunk, Set, Int, Set, EntityChunkIndexTests, Chunk

### Community 82 - "ExtractedArticle"
Cohesion: 0.14
Nodes (11): ExtractedArticle, Date, FetchedPageImport, Bool, Date, Source, URL, FetchedPageImportTests (+3 more)

### Community 83 - "ConversationMode"
Cohesion: 0.13
Nodes (12): .mode, ConversationMode, brainstorm, critique, onboarding, researchPlan, weeklyReview, ProjectSnapshot (+4 more)

### Community 84 - ".start()"
Cohesion: 0.11
Nodes (19): BriefingGate, Conditions, Refusal, appLocked, lockScreenOff, .message, needsUnlock, Bool (+11 more)

### Community 85 - "GraphSnapshot"
Cohesion: 0.19
Nodes (15): Edge, ForceLayout, GraphSnapshot, Node, Point, Scope, all, recent (+7 more)

### Community 86 - "Phase 5: Hardening"
Cohesion: 0.14
Nodes (24): Empty States and Accessibility, App Lock (Face ID/Touch ID with PIN fallback), BM25 Lexical Search (compound tokens kept whole), Bounded-heap Top-K Rankings, Device Measurement (Instruments signposts), docs/DEVICE_TESTING.md, Export (Settings to Export), GraphML Export (Gephi or yEd) (+16 more)

### Community 87 - "Pipeline module (ingestion, graph, searc"
Cohesion: 0.14
Nodes (23): ArticleIndexer (search index built and updated in place), DigestBuilder (clustering, ranking, tiered summaries), EmbeddingModel (vectors never compared across models), EntityResolver (names resolve to one node), GraphEditing (merge and split, writes user aliases), GraphExport (GraphML via GraphKit), GraphIndexer (extraction routing tiers, D2/D5), OnDeviceKit GraphKit (+15 more)

### Community 88 - ".outcome()"
Cohesion: 0.13
Nodes (10): Outcome, fail, listen, speak, StartBlocker, missingKey, needsAutoApprove, Bool (+2 more)

### Community 89 - "VoiceCommandTests"
Cohesion: 0.15
Nodes (3): StaticString, UInt, VoiceCommandTests

### Community 90 - "Invariant D5: Private content never goes"
Cohesion: 0.12
Nodes (22): ArticleExtractor (SwiftSoup HTML to clean text), ContextPolicy (provider-context filter), Invariant D5: Private content never goes to a BYOK provider, Plan Decision IDs D1-D6 (referenced in code), Invariant: extraction routing lives in GraphIndexer.tiers(for:), GitHubClient (GET-only), GitHubTokenStore (device-only Keychain), IngestKit (source ingestion and GitHub) (+14 more)

### Community 91 - "XCTestCase"
Cohesion: 0.11
Nodes (10): GraphViewKit, BundledResourcesTests, CatalogTypesTests, GraphExport, Date, LibraryArchive, NormalizedKeyTests, GraphExportTests (+2 more)

### Community 92 - "PINService"
Cohesion: 0.15
Nodes (11): AppLockCoordinator, Outcome, denied, unlocked, Bool, PINService, .isLockedOut, .lockoutRemaining (+3 more)

### Community 93 - "StreamDelegate"
Cohesion: 0.15
Nodes (16): LinuxStreamedBytes, StreamDelegate, AsyncThrowingStream, CheckedContinuation, Data, Error, URLRequest, URLResponse (+8 more)

### Community 94 - ".analyze()"
Cohesion: 0.15
Nodes (6): EdgeSpec, Extraction, GraphDisplay, KnowledgeGraphExtractor, NodeSpec, KnowledgeGraphExtractorTests

### Community 95 - "PINAttemptResult"
Cohesion: 0.18
Nodes (12): PINAttemptResult, incorrect, lockedOut, success, PINLockout, .isLockedOut, PINLockoutStore, Bool (+4 more)

### Community 96 - "ContextAssembler"
Cohesion: 0.16
Nodes (7): ContextAssembler, Int, HeuristicTokenEstimator, Int, TokenEstimating, ContextAssemblerTests, Float

### Community 97 - "ElevenLabsTTSEngine"
Cohesion: 0.23
Nodes (11): ElevenLabsTTSEngine, PrefetchedClip, Double, Error, Float, NSRange, TimeInterval, Timer (+3 more)

### Community 98 - "CappedFetch"
Cohesion: 0.20
Nodes (14): CappedFetch, Router, Bool, CheckedContinuation, Data, Error, HTTPURLResponse, Int (+6 more)

### Community 99 - "SourceFetcher"
Cohesion: 0.21
Nodes (8): SourceDescriptor, SourceFetcher, Bool, Data, HTTPURLResponse, Source, UUID, SourceFetcherTests

### Community 100 - "StrategyItemKind"
Cohesion: 0.14
Nodes (12): .kind, StrategyItemKind, actionItem, assumption, decision, openQuestion, risk, RecordStrategyItemTool (+4 more)

### Community 101 - ".chat()"
Cohesion: 0.12
Nodes (15): ChatReply, LocalAIError, badResponse, .errorDescription, http, modelMissing, notLoopback, unreachable (+7 more)

### Community 102 - "AVFoundation"
Cohesion: 0.12
Nodes (4): AVFoundation, MediaPlayer, Speech, VoiceLoopKit

### Community 103 - "CodingKeys"
Cohesion: 0.10
Nodes (21): CodingKey, CodingKeys, defaultBranch, description, fullName, htmlURL, isPrivate, pushedAt (+13 more)

### Community 104 - "GraphRAG"
Cohesion: 0.16
Nodes (21): B1 GraphRAG over the SwiftData graph, B4 Graph view drawn natively in SwiftUI, C3 GraphRetrievalKit needs an injectable entity index, FR-11 GraphRAG every turn with why-retrieved, FR-14 Full-text, semantic and graph-expanded search, FR-15 Interactive offline graph view, FR-18 Encrypted export and import, FR-20 App Intents and Shortcuts (+13 more)

### Community 105 - "Dependency"
Cohesion: 0.23
Nodes (3): Dependency, ManifestParser, ManifestParserTests

### Community 106 - "BriefError"
Cohesion: 0.13
Nodes (16): BriefDiff, BriefError, empty, .errorDescription, notPending, outdated, unchanged, Line (+8 more)

### Community 107 - ".suggest()"
Cohesion: 0.11
Nodes (18): BriefController, BriefEditorView, .body, BriefSection, .body, ProjectRoute, briefHistory, briefReview (+10 more)

### Community 108 - "LLMCompletionError"
Cohesion: 0.14
Nodes (14): LLMCompletionError, .errorDescription, http, malformedResponse, missingResponseFormat, provider, Behavior, fail (+6 more)

### Community 109 - "LLMKeychainStore"
Cohesion: 0.26
Nodes (6): LLMKeychainStore, Bool, LLMKeychainStoreTests, ProviderKeyRow, .body, Void

### Community 110 - ".energies()"
Cohesion: 0.18
Nodes (8): PCMEnergyAnalyzer, AVAudioPCMBuffer, Float, Int, PCMEnergyAnalyzerTests, AVAudioPCMBuffer, Double, Float

### Community 112 - "ReadoutSegment"
Cohesion: 0.18
Nodes (6): ReadoutSegment, ArticleBriefing, SegmentBuilder, Digest, Int, SpokenAnswer

### Community 113 - ".load()"
Cohesion: 0.18
Nodes (12): SampleLibrary, Size, SplitMix, Bool, Date, Double, Float, Int (+4 more)

### Community 114 - ".check()"
Cohesion: 0.15
Nodes (4): VoiceCommandHelp, StaticString, UInt, VoiceHandsFreeCommandTests

### Community 115 - "VoiceConfirmationGate"
Cohesion: 0.22
Nodes (10): Pending, Resolution, cancelled, nothingToConfirm, run, Bool, Date, TimeInterval (+2 more)

### Community 116 - "Parent"
Cohesion: 0.21
Nodes (9): Child, LinuxSwiftDataTests, Parent, Bool, Data, Date, URL, UUID (+1 more)

### Community 117 - "Ingestion pipeline: fetch, clean, triage"
Cohesion: 0.22
Nodes (19): ArticleExtractor, BGTaskScheduler background tasks, FR-1 Add, edit, disable and remove sources, FR-22 GitHub integration and repo sync, FR-2 Fetch new items manually and in background, FR-3 Share extension ingestion, GitHub option A: paste repo links only, GitHubClient (+11 more)

### Community 118 - "BYOKLLMKit"
Cohesion: 0.16
Nodes (19): BiometricLockKit, BYOKLLMKit, C1 Anthropic SSE streaming is missing from BYOKLLMKit, CloudKit-compatible schema rules, Evaluation harness, FR-16 BYOK key management and model picker, FR-19 PIN and biometric app lock, Inference tiers T0-T3 (+11 more)

### Community 119 - "GraphRetriever"
Cohesion: 0.14
Nodes (9): GraphRetriever, Chunk, Document, Int, FakeEmbeddingProvider, Float, Int, Substring (+1 more)

### Community 120 - "ThemeStrengthCache"
Cohesion: 0.22
Nodes (11): Entry, Fingerprint, Date, Double, Int, TimeInterval, UUID, ThemeStrengthCache (+3 more)

### Community 121 - ".fetch()"
Cohesion: 0.15
Nodes (10): FetchError, .errorDescription, http, invalidKey, unreadable, ProviderModelFetcher, Data, Int (+2 more)

### Community 122 - "ArticleSummaryController"
Cohesion: 0.11
Nodes (17): syncGitHubLinks(), GitHubProjectSection, .body, .dependencies, .repoLinks, .state, ArticleSummaryController, State (+9 more)

### Community 123 - "ModelCatalogController"
Cohesion: 0.17
Nodes (12): BudgetSettings, .current, FallbackModelsRow, .body, ModelCatalogController, .fallback, Bool, Date (+4 more)

### Community 124 - "PackageDescription"
Cohesion: 0.11
Nodes (3): CompilerPluginSupport, PackageDescription, Package

### Community 125 - ".segments()"
Cohesion: 0.17
Nodes (8): Locale, ArticleReadout, Builder, .current, ReadoutScope, summaryOnly, whole, TimeZone

### Community 126 - "CodingKeys"
Cohesion: 0.14
Nodes (16): CodingKeys, architecture, contextLength, id, image, inputModalities, lastRefreshed, outputModalities (+8 more)

### Community 127 - "LexicalIndex"
Cohesion: 0.16
Nodes (5): LexicalIndex, .count, Double, Int, LexicalIndexTests

### Community 128 - "BriefingTests"
Cohesion: 0.22
Nodes (7): DigestReadout, BriefingTests, Fixture, Bool, Double, Int, Source

### Community 129 - "LocalModelConfig"
Cohesion: 0.16
Nodes (8): LocalModelConfig, OllamaEmbeddingProvider, Float, Int, URL, Bool, URL, LocalBackendsLiveTests

### Community 130 - "SmartWardKit.KnowledgeStore (SwiftData m"
Cohesion: 0.18
Nodes (17): Invariant: new models and properties go into LibraryArchive in the same change, Invariant: schema stays CloudKit-compatible (PLAN section 4), DailyBudget (background provider spend cap), Invariant: strength and weight are derived, not stored counters, EncryptedBackup (single-file library backup), Invariant: enum-backed fields store raw String with typed fallback property, KnowledgeSchema.models (schema registry), SmartWardKit.KnowledgeStore (SwiftData models and services) (+9 more)

### Community 131 - "Article (SwiftData model)"
Cohesion: 0.15
Nodes (17): Article (SwiftData model), D1 Day-one onboarding interview, FeedFetcher, FR-0 Onboarding interview, FR-23 Dependency radar, FR-4 Triage by relevance to profile and projects, FR-9 Projects with a living Project Brief, GitHubReleases adapter (+9 more)

### Community 132 - "ThemeNode (SwiftData model)"
Cohesion: 0.19
Nodes (17): B2 Never auto-merge differing version tokens, C2 BYOKLLMKit lacks tool calling and structured output, C7 Explicit Mention join entity replaces many-to-many, Conversation indexing pipeline, Digest pipeline, Entity-resolution eval: false-merge rate under 2%, EntityAlias (SwiftData model), EntityResolver (+9 more)

### Community 133 - "AppNavigation"
Cohesion: 0.15
Nodes (11): NavigationPath, AppNavigation, AppTab, chat, graph, projects, reading, today (+3 more)

### Community 134 - "BiometricResult"
Cohesion: 0.12
Nodes (13): BiometricResult, biometryChanged, canceled, failed, fallback, lockout, success, unavailable (+5 more)

### Community 135 - "LLMResponse"
Cohesion: 0.15
Nodes (12): LLMResponse, .toolCalls, LLMStopReason, contentFilter, endTurn, maxTokens, other, stopSequence (+4 more)

### Community 136 - "Coordinator"
Cohesion: 0.18
Nodes (10): Coordinator, GraphVisualizationView, Void, UIViewRepresentable, WKNavigation, WKNavigationDelegate, WKScriptMessage, WKScriptMessageHandler (+2 more)

### Community 137 - "GitHubError"
Cohesion: 0.16
Nodes (13): GitHubError, .errorDescription, http, invalidResponse, notFound, rateLimited, unauthorized, Data (+5 more)

### Community 138 - "GitHubAccount"
Cohesion: 0.16
Nodes (10): GitHubTokenStore, .fileURL, Bool, URL, GitHubAccount, .client, .hasToken, Bool (+2 more)

### Community 139 - ".fetchURL()"
Cohesion: 0.24
Nodes (5): SourceEndpoint, URL, SourceEndpointTests, URL, AddSourceToolTests

### Community 140 - "ApprovalDecision"
Cohesion: 0.14
Nodes (10): ActionTools, ApprovalDecision, approve, ask, decline, Set, ApprovalPolicyTests, StubTool (+2 more)

### Community 141 - "InterestModel"
Cohesion: 0.23
Nodes (8): Interest, InterestModel, .isEmpty, Bool, Float, Triage, TriageTests, .strength

### Community 142 - "ActionRequest"
Cohesion: 0.18
Nodes (12): confirm, ActionRequest, StrategistEvent, awaitingConfirmation, confirmationResolved, roundFinished, textDelta, toolCall (+4 more)

### Community 143 - "Approval Before Actions"
Cohesion: 0.18
Nodes (17): add_source Tool, Add to SmartWard (Share Sheet), App Shell (Tabs, Projects, Settings), Approval Before Actions, Background Refresh (hourly polling, charging, system progress), BYOK Key Settings (bring your own keys), Four Strategist Chat Modes, Daily Budget (switches background work to on-device when spent) (+9 more)

### Community 144 - ".run()"
Cohesion: 0.23
Nodes (9): ChatController, .autoApproveEnabled, Bool, CheckedContinuation, Never, Turn, .isHandsFree, spoken (+1 more)

### Community 145 - "ArticleReaderView"
Cohesion: 0.12
Nodes (14): ProjectRouteView, ArticleReaderView, .fullTextBanner, .isReading, .metadata, .originalURL, .paragraphs, Bool (+6 more)

### Community 146 - "IngestController"
Cohesion: 0.17
Nodes (15): IngestController, Set, UUID, SourceDetailView, .body, SourceRow, .body, SourcesView (+7 more)

### Community 147 - "Strategist Layer"
Cohesion: 0.20
Nodes (16): BriefService living document watermark, C6 One Strategist with a tool-use loop and modes, Conversation (SwiftData model), ConversationCompactor rolling summary, FR-10 Project-scoped conversations with modes, FR-12 Strategist tool set, Message (SwiftData model), ModeSelector (+8 more)

### Community 148 - "SpeechService"
Cohesion: 0.17
Nodes (8): ObservableObject, SpeechService, AVSpeechSynthesisVoice, AVSpeechSynthesizer, AVSpeechUtterance, Bool, Float, Void

### Community 149 - ".check()"
Cohesion: 0.19
Nodes (6): BoundaryContext, spiritualGuidance, standard, BoundaryDetector, Bool, BoundaryDetectorTests

### Community 150 - "ShareSheet"
Cohesion: 0.15
Nodes (10): GraphViewKitResources, .cytoscapeJSURL, .graphHTMLURL, URL, ShareSheet, Any, Context, UIActivityViewController (+2 more)

### Community 151 - "Chunker"
Cohesion: 0.19
Nodes (5): Chunker, Chunk, Document, Int, ChunkerTests

### Community 153 - "ShimRelationship"
Cohesion: 0.17
Nodes (11): DeleteRule, cascade, deny, noAction, nullify, Relationship, ShimEntity, ShimRegistry (+3 more)

### Community 154 - "SmartWardEngine"
Cohesion: 0.24
Nodes (8): LocalBackends, Answer, SearchResult, SmartWardEngine, .context, Status, Double, Source

### Community 155 - ".check()"
Cohesion: 0.22
Nodes (3): StaticString, UInt, VoiceBriefingCommandTests

### Community 156 - "RootView"
Cohesion: 0.12
Nodes (13): ProjectsView, IndexSet, ComingSoonView, .body, RootView, .shouldListenByVoice, .tabs, .tabView (+5 more)

### Community 157 - "GraphCanvas"
Cohesion: 0.19
Nodes (12): CGFloat, Color, .body, ThemeStyle, GraphCanvas, .body, UUID, Void (+4 more)

### Community 158 - "SmartWard (iOS Application Target)"
Cohesion: 0.23
Nodes (15): App Lock: Face ID with Grace Period, App Lock PIN Fallback, App Switcher Privacy Cover, SmartWard App Icon (product icon image), AppIcon Asset Catalog Name, AppLock (SmartWardKit Library Product), BiometricLockKit (OnDeviceKit Library Product), BYOKLLMKit (OnDeviceKit Library Product) (+7 more)

### Community 159 - "PersistentModel"
Cohesion: 0.21
Nodes (9): Hasher, KnowledgeSchema, .schema, PersistentModel, .shimEntity, Attribute, Entity, Schema (+1 more)

### Community 160 - "DigestCluster"
Cohesion: 0.28
Nodes (10): ArticleRef, Digest, .clusters, DigestCluster, ProjectRef, Bool, Date, Double (+2 more)

### Community 161 - ".makeFixture()"
Cohesion: 0.30
Nodes (4): ArticleReadoutTests, Fixture, Bool, Int

### Community 162 - "SmartWardShare (Share Extension Target)"
Cohesion: 0.22
Nodes (14): App Group Registration (group.com.intelligentdesignsllc.smartward), Share Extension Safari Capture Path, SmartWard/SmartWard.entitlements, App Group Entitlement (shared container app ↔ extension), com.intelligentdesignsllc.smartward Bundle Identifier, Bundle ID Prefix com.intelligentdesignsllc, PLAN FR-3 (Share Extension Requirement), ShareExtension/SmartWardShare.entitlements (+6 more)

### Community 163 - "Prompt-injection defense"
Cohesion: 0.22
Nodes (14): Confirmation chips for side-effecting tools, D4 One-tap GitHub sign-in, PAT advanced, FR-17 Usage and cost ledger with daily cap, GitHub App rejected: needs a token-exchange backend, GitHub option B: fine-grained PAT, GitHub option C: OAuth device flow, Prompt-injection defense, Keychain storage (+6 more)

### Community 164 - "ShareModel"
Cohesion: 0.20
Nodes (9): NSExtensionContext, ShareModel, .canSave, ShareView, .body, ShareViewController, Bool, UUID (+1 more)

### Community 165 - "FakeCompleter"
Cohesion: 0.19
Nodes (6): CompletionServiceTests, Entity, FakeCompleter, StructuredOutputTests, AsyncThrowingStream, Error

### Community 166 - ".check()"
Cohesion: 0.25
Nodes (4): CrisisDetector, CrisisPattern, Bool, CrisisDetectorTests

### Community 167 - "VoiceLoopConfig"
Cohesion: 0.23
Nodes (6): Int, Bool, Float, TimeInterval, VoiceLoopConfig, VoiceLoopConfigTests

### Community 168 - "AppLockPolicy"
Cohesion: 0.21
Nodes (7): AppLockPolicy, PINRules, Bool, Date, TimeInterval, AppLockPolicyTests, PINRulesTests

### Community 169 - "ModelContainer"
Cohesion: 0.22
Nodes (9): ModelContainer, .mainContext, .version, Data, Int, UUID, AppStore, Error (+1 more)

### Community 170 - "ModelFallback"
Cohesion: 0.23
Nodes (7): ModelFallback, Bool, ModelFallbackTests, .catalog, Bool, Double, Int

### Community 171 - "AppLockController"
Cohesion: 0.18
Nodes (9): ScenePhase, AppLockController, .handsFreeWindow, .isEnabled, .policy, Bool, Date, TimeInterval (+1 more)

### Community 172 - "DeveloperView"
Cohesion: 0.22
Nodes (8): SearchController, Int, DeveloperSettings, .isEnabled, DeveloperView, .body, Bool, Double

### Community 173 - "SmartWard XcodeGen Project Spec"
Cohesion: 0.22
Nodes (13): DEVELOPMENT_TEAM Signing Setup, GitHub OAuth Device Flow Sign-In, iPhone 15 Pro / iOS 26 / Apple Intelligence Device Requirement, One-Time Device Setup, OpenRouter API Key During Onboarding, Apple Intelligence-Capable Device Floor (iPhone 15 Pro+), Automatic Code Sign Style, iOS 26.0 Deployment Target (+5 more)

### Community 174 - "ParsedFeed"
Cohesion: 0.21
Nodes (9): FoundationXML, Entry, .url, FeedParser, FeedXMLDelegate, ParsedFeed, Data, XMLParser (+1 more)

### Community 175 - "StepProgress"
Cohesion: 0.19
Nodes (8): StepProgress, .isDeterminate, .percent, Bool, Int, StepProgressTests, ActivityBar, .body

### Community 176 - "Scenario"
Cohesion: 0.29
Nodes (7): Attack, RecordingFetcher, RedTeamTests, Scenario, .system, Bool, URL

### Community 177 - ".body"
Cohesion: 0.22
Nodes (10): DigestClusterSection, .body, DigestRow, .body, DigestSections, .body, Digest, UUID (+2 more)

### Community 178 - "Accessibility Verification Pass"
Cohesion: 0.24
Nodes (12): Accessibility Verification Pass, CI Simulator Test Pipeline, Daily Budget Set to $0.25 Exhaustion Test, Device Testing Strategy, Largest Text Sizes / Dynamic Type Clipping Check, Onboarding Under 5 Minutes (Phase 1 Exit Criterion), Phase 5 Exit Criteria, A Real-Use Pass (+4 more)

### Community 179 - "GraphRAG Latency Budget (NFR-4: p95 unde"
Cohesion: 0.29
Nodes (12): -SmartWardDeveloper YES Launch Argument, Developer Sample Library (100,000 chunks / 3,000 themes / 30,000 connections, ~250 MB), Graph Snapshot Signpost Interval, GraphRAG Latency Budget (NFR-4: p95 under 500 ms at 100k chunks), GraphRAG Signpost Interval, Instruments Points of Interest Profiling, Latency Check (20 chat-style questions, p50/p95 report), Release Build Requirement for Latency Measurement (+4 more)

### Community 180 - "ShimKey"
Cohesion: 0.18
Nodes (7): KeyedEncodingContainer, RowDecoder, Decoder, ShimKey, .intValue, Int, T

### Community 181 - "LLMTool"
Cohesion: 0.18
Nodes (9): LLMTool, ProjectStateTool, .asksForApproval, .definition, ProposeBriefUpdateTool, .asksForApproval, .definition, Bool (+1 more)

### Community 183 - ".projects()"
Cohesion: 0.29
Nodes (5): MarkdownExport, Bool, Date, Int, MarkdownExportTests

### Community 184 - "AddSourceTool"
Cohesion: 0.23
Nodes (6): AddSourceTool, .asksForApproval, .definition, .kinds, answer(), InjectedActionTests

### Community 185 - "Anchor"
Cohesion: 0.17
Nodes (11): Anchor, details, note, paragraph, relevance, summary, themes, title (+3 more)

### Community 186 - "LexicalIndex"
Cohesion: 0.20
Nodes (4): LexicalIndex, .count, Double, LexicalIndexTests

### Community 187 - ".text()"
Cohesion: 0.24
Nodes (5): RunSummary, Bool, Int, TimeInterval, RunSummaryTests

### Community 188 - ".messages()"
Cohesion: 0.29
Nodes (6): ConversationHistory, Entry, Date, Int, ConversationHistoryTests, TimeInterval

### Community 189 - "FakeClock"
Cohesion: 0.36
Nodes (4): FakeClock, PolitenessGateTests, Date, TimeInterval

### Community 190 - "SeededRandom"
Cohesion: 0.21
Nodes (7): PerformanceTests, SeededRandom, TimeInterval, UInt64, Void, TopKTests, RandomNumberGenerator

### Community 191 - "VoiceSpeaker"
Cohesion: 0.20
Nodes (5): AppAudio, Bool, Bool, VoiceSpeaker, .isBusy

### Community 192 - "GraphView"
Cohesion: 0.24
Nodes (12): GraphView, .asList, .body, .graphScope, RefreshKey, ScopeChoice, all, project (+4 more)

### Community 193 - "What the Simulator Can't Show"
Cohesion: 0.31
Nodes (11): Apple Intelligence On-Device Item Triage, Background Work via BGTaskScheduler, On-Device Theme Extraction in Reader, Overnight Processing Digest Notification, com.intelligentdesignsllc.smartward.processing Task Identifier, Shortcuts App Intents (Open digest / Add a source), What the Simulator Can't Show, Siri "Ask SmartWard" Voice Answer (+3 more)

### Community 194 - "Inference Layer"
Cohesion: 0.25
Nodes (11): AppleFMKit, C4 ODK core packages are iOS-only, D3 iPhone 15 Pro minimum device, FR-21 Mac companion with CloudKit sync, Inference Layer, LocalLLMKit dropped from scope, NFR-11 Platform targets and device floor, NFR-1 Offline operation (+3 more)

### Community 195 - "ContextAssembler token budget and fencin"
Cohesion: 0.27
Nodes (11): B3 Extraction routing by content class, BYOKExtractor, ContextAssembler token budget and fencing, D2 Conversations may be extracted by BYOK, D5 Private repos extracted on-device only, EntityExtracting protocol, FoundationModelsExtractor, KnowledgeGraphExtractor not used (therapy vocabulary) (+3 more)

### Community 196 - "BYOKFileSecretStore"
Cohesion: 0.33
Nodes (5): BYOKFileSecretStore, .directory, Bool, Data, URL

### Community 197 - ".parseSSELine()"
Cohesion: 0.27
Nodes (4): SSEEvent, delta, ignore, SSEParsingTests

### Community 198 - ".importItems()"
Cohesion: 0.27
Nodes (6): Result, SharedImport, Date, Int, Source, SharedImportTests

### Community 199 - ".score()"
Cohesion: 0.24
Nodes (6): Date, Double, TimeInterval, ThemeStrength, TimeInterval, ThemeStrengthTests

### Community 200 - ".data()"
Cohesion: 0.29
Nodes (6): Data, Float, VectorCoding, Set, UUID, VectorCodingTests

### Community 201 - ".decode()"
Cohesion: 0.24
Nodes (3): project, OnboardingSynthesizer, OnboardingSynthesizerTests

### Community 202 - "ThemeDetailView"
Cohesion: 0.24
Nodes (8): Connection, .id, Int, ThemeDetailView, .body, .connections, .recentMentions, .body

### Community 203 - ".check()"
Cohesion: 0.29
Nodes (3): StaticString, UInt, VoiceProjectCommandTests

### Community 204 - "OnboardingView"
Cohesion: 0.22
Nodes (9): OnboardingView, .appleIntelligenceStatus, .body, .canStart, .hasUserInput, .links, .providersWithKeys, .welcome (+1 more)

### Community 205 - "graphify_pipeline.py"
Cohesion: 0.22
Nodes (8): datetime, json, pathlib, re, keep(), main(), Self-contained graphify pipeline for CI and for headless local runs. Builds a…, sys

### Community 206 - "BiometryType"
Cohesion: 0.20
Nodes (6): BiometryType, .displayName, faceID, none, opticID, touchID

### Community 209 - "TopK"
Cohesion: 0.40
Nodes (4): Bool, Element, Int, TopK

### Community 210 - "TopKTests"
Cohesion: 0.20
Nodes (3): Bool, Int, TopKTests

### Community 211 - "TTSError"
Cohesion: 0.20
Nodes (8): Data, Int, TTSError, decodeFailed, emptyAudio, .errorDescription, http, missingKey

### Community 212 - "TopK"
Cohesion: 0.40
Nodes (4): Bool, Element, Int, TopK

### Community 213 - "FallbackLLM"
Cohesion: 0.36
Nodes (5): FallbackLLM, Alternatives, AsyncThrowingStream, Error, Int

### Community 214 - ".check()"
Cohesion: 0.31
Nodes (3): BriefingGateTests, Bool, TimeInterval

### Community 215 - "FakeOllama"
Cohesion: 0.24
Nodes (7): FakeOllama, Any, Data, HTTPURLResponse, Int, URLRequest, throws

### Community 216 - "FakeEmbedder"
Cohesion: 0.33
Nodes (5): FakeEmbedder, .dimension, Float, Int, HybridSearchTests

### Community 217 - ".check()"
Cohesion: 0.33
Nodes (3): StaticString, UInt, VoiceFindCommandTests

### Community 218 - "StrategistCore (tool loop, prompts, brie"
Cohesion: 0.31
Nodes (9): Invariant: network or durable-state tools must return an ActionRequest, ActionRequest (confirmation(for:) contract), OnDeviceKit BYOKLLMKit, ModelFallback (FallbackLLM over ModelCatalogKit), StrategistCore (tool loop, prompts, brief, fallback), StrategistRunner (tool-calling loop), Invariant: every strategist turn must end (toolChoice none, errors as results), Cost Controls (Settings to Usage and budget) (+1 more)

### Community 219 - "Packages/SmartWardKit (local SPM package"
Cohesion: 0.25
Nodes (9): AppLock module (AppLockPolicy, AppLockCoordinator, PINRules), OnDeviceKit BiometricLockKit, GitNexus code intelligence (impact before edit, detect-changes before commit), Logic-in-Package Convention (swift test without a simulator), OnDeviceKit PINLockKit, ShareExtension/ (never opens the SwiftData store), ShareInbox (App Group JSON inbox, dependency-free), SmartWard/ (SwiftUI iOS app) (+1 more)

### Community 220 - "SmartWardKit (Local Swift Package)"
Cohesion: 0.31
Nodes (9): Background Extraction Stays On-Device Until Midnight, JSON / GraphML / Markdown Export Formats, Private Local Address Rejection (192.168.1.1), Wipe to Restore Backup Test, IngestKit (SmartWardKit Library Product), KnowledgeStore (SmartWardKit Library Product), Pipeline (SmartWardKit Library Product), SmartWardKit (Local Swift Package) (+1 more)

### Community 222 - "ModelConfiguration"
Cohesion: 0.31
Nodes (8): CloudKitDatabase, automatic, none, `private`, ModelConfiguration, .defaultStoreURL, Bool, URL

### Community 224 - "NLEmbeddingProvider"
Cohesion: 0.25
Nodes (6): NLEmbedding, NLLanguage, NLEmbeddingProvider, .dimension, Float, Int

### Community 226 - ".allowsRedirect()"
Cohesion: 0.32
Nodes (4): PublicHost, Bool, URL, PublicHostTests

### Community 227 - "ArchiveError"
Cohesion: 0.25
Nodes (6): ArchiveError, .errorDescription, newerVersion, notAnArchive, Data, Int

### Community 228 - "FetchDescriptor"
Cohesion: 0.36
Nodes (6): FetchDescriptor, Int, Predicate, T, PartialKeyPath, SortDescriptor

### Community 229 - "Graph View"
Cohesion: 0.25
Nodes (8): Alias + Embedding Similarity Name Resolution, Chunk-level Citations for Mentions and Edges, Entity and Relation Extraction, Extraction and Entity Resolution, Graph View, Theme Rename/Merge/Split (user corrections win), Theme Scopes (all, two weeks, project, source), Uncertain Merge Review Queue

### Community 231 - "UntrustedText (body/attribute inside its"
Cohesion: 0.43
Nodes (7): RedTeamTests (zero unapproved side effects), Invariant: untrusted text only through UntrustedText inside its fence, UntrustedText (body/attribute inside its fence), Poisoned Article Corpus, Private-Content Policy (private repos stay on-device), Uniform Prompt Fence Escaping, Red-team Suite

### Community 232 - "NSObject"
Cohesion: 0.33
Nodes (6): NSObject, Error, XMLParser, XMLParserRecorder, RedirectPolicy, URLSessionTaskDelegate

### Community 233 - "SearchHit"
Cohesion: 0.33
Nodes (6): OptionSet, MatchKind, SearchHit, .id, MatchBadge, .body

### Community 234 - ".audioPlayerDidFinishPlaying()"
Cohesion: 0.29
Nodes (5): done, AVAudioPlayer, Bool, AVAudioPlayer, Bool

### Community 236 - "TTSError"
Cohesion: 0.29
Nodes (7): Int, TTSError, decodeFailed, emptyAudio, .errorDescription, http, missingKey

### Community 238 - "DigestController"
Cohesion: 0.33
Nodes (5): DigestController, .notificationsEnabled, Bool, Digest, TimeInterval

### Community 239 - "Living Project Brief"
Cohesion: 0.53
Nodes (6): Invariant: brief text changes only through BriefEditing, BriefDiff (line diff of brief changes), BriefEditing (only path that changes brief text), Brief Line Diff (accept or reject), Living Project Brief, Suggest an Update

### Community 240 - "RepoSync.swift"
Cohesion: 0.47
Nodes (3): CommonCrypto, Crypto, CryptoKit

### Community 241 - "BriefRevisionStatus"
Cohesion: 0.33
Nodes (6): .status, BriefRevisionStatus, accepted, pending, rejected, superseded

### Community 242 - "StrategyItemStatus"
Cohesion: 0.33
Nodes (6): .status, StrategyItemStatus, done, invalidated, open, superseded

### Community 243 - "VoiceSettings"
Cohesion: 0.40
Nodes (5): AVSpeechSynthesisVoice, VoiceSettings, .current, VoiceSettingsSection, .body

### Community 244 - "Chunk (SwiftData model)"
Cohesion: 0.80
Nodes (5): C5 Store vectors as binary Data, not JSON snapshots, Chunk (SwiftData model), Phase 0 embedding bake-off, FR-5 Chunk and embed on-device with model version, RetrievalKit

### Community 245 - "DecisionProviding protocol seam"
Cohesion: 0.50
Nodes (5): DecisionKit proposed ODK module, DecisionProviding protocol seam, Jev typed decision models, LangChain - What Is Jev?, T0 heuristics and embeddings

### Community 247 - "Phase"
Cohesion: 0.40
Nodes (5): Phase, idle, listening, speaking, thinking

### Community 248 - "Status"
Cohesion: 0.40
Nodes (5): Status, finished, idle, paused, playing

### Community 249 - "Apple Intelligence Preflight"
Cohesion: 0.40
Nodes (5): Apple Intelligence Preflight, Build and Package Test Commands, Onboarding Interview, Requirements (Xcode 26+, iOS 26+, iPhone 15 Pro+), XcodeGen (project.yml, generated xcodeproj)

### Community 250 - "VoiceReadingFilter"
Cohesion: 0.50
Nodes (4): VoiceReadingFilter, all, starred, unread

### Community 251 - "VoiceSpeedChange"
Cohesion: 0.50
Nodes (4): VoiceSpeedChange, faster, normal, slower

### Community 252 - ".send()"
Cohesion: 0.50
Nodes (3): Data, HTTPURLResponse, URLRequest

### Community 253 - "Answer"
Cohesion: 0.50
Nodes (4): Answer, failed, spoken, VoiceAsk

## Ambiguous Edges - Review These
- `Scale Performance Tests (100k chunks, 3k themes)` → `Device Measurement (Instruments signposts)`  [AMBIGUOUS]
  README.md · relation: conceptually_related_to

## Knowledge Gaps
- **682 isolated node(s):** `unlocked`, `denied`, `AgentRouteKit`, `toolUse`, `auto` (+677 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1267 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **15 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Scale Performance Tests (100k chunks, 3k themes)` and `Device Measurement (Instruments signposts)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `String` connect `String` to `ThemeNode`, `.fetch()`, `KnowledgeStore`, `AnalyzerCommandRecognizer`, `GraphIndexer`, `JSONValue`, `Article`, `Retriever`, `PipelineController`, `Foundation`, `ArticleReadoutController`, `.makeContainer()`, `Plugin.swift`, `VoiceCommandParser`, `FetchURLTool`, `View`, `VoiceCommand`, `.outcome()`, `Choice`, `LLMUsage`, `Project`, `SmartWardIntents.swift`, `ModelContext`, `Sendable`, `LocalizedError`, `DailyBudget`, `.extract()`, `LLMProvider`, `VoiceAnswersTests`, `BiometricService`, `BackupView`, `OpenAITTSEngine`, `Identifiable`, `BiometricEvaluation`, `LLMChatMessage`, `HybridSearchIndex`, `FallbackLLM`, `GitHubClient`, `IngestError`, `RetrievedPassage`, `AppLockCoordinator`, `LLMService`, `.aggregate()`, `VoiceContext`, `ShimObjectState`, `LLMCompleting`, `ScoredChunk`, `VectorIndex`, `ArticleSummary`, `FileCache`, `CatalogEntry`, `RawItem`, `GitHubDeviceFlow`, `LibraryFixture`, `PerfTrace`, `ExtractedGraph`, `LLMRequest`, `ProjectArticlesTests`, `.body()`, `OllamaClient`, `StrategistRunner`, `Codable`, `SQLiteDatabase`, `SourceKind`, `.dismiss()`, `LocalLLMEngine`, `Library`, `.body`, `VoiceConversationController`, `GitHubRepo`, `EchoHandler`, `LLMStreamEvent`, `ConversationView`, `VoiceIntentTests`, `OnboardingProposal`, `.decodeResponse()`, `EntityChunkIndex`, `ExtractedArticle`, `ConversationMode`, `.start()`, `GraphSnapshot`, `.outcome()`, `VoiceCommandTests`, `XCTestCase`, `PINService`, `StreamDelegate`, `.analyze()`, `PINAttemptResult`, `ContextAssembler`, `ElevenLabsTTSEngine`, `SourceFetcher`, `StrategyItemKind`, `.chat()`, `CodingKeys`, `Dependency`, `BriefError`, `.suggest()`, `LLMCompletionError`, `LLMKeychainStore`, `VoiceTranscriptTests`, `ReadoutSegment`, `.load()`, `.check()`, `VoiceConfirmationGate`, `Parent`, `GraphRetriever`, `ThemeStrengthCache`, `.fetch()`, `ArticleSummaryController`, `ModelCatalogController`, `.segments()`, `CodingKeys`, `LexicalIndex`, `BriefingTests`, `LocalModelConfig`, `BiometricResult`, `LLMResponse`, `Coordinator`, `GitHubError`, `GitHubAccount`, `.fetchURL()`, `ApprovalDecision`, `InterestModel`, `ActionRequest`, `.run()`, `ArticleReaderView`, `IngestController`, `SpeechService`, `.check()`, `Chunker`, `.apply()`, `ShimRelationship`, `SmartWardEngine`, `.check()`, `RootView`, `GraphCanvas`, `PersistentModel`, `DigestCluster`, `.makeFixture()`, `ShareModel`, `FakeCompleter`, `.check()`, `VoiceLoopConfig`, `AppLockPolicy`, `ModelContainer`, `ModelFallback`, `AppLockController`, `DeveloperView`, `ParsedFeed`, `StepProgress`, `Scenario`, `.body`, `ShimKey`, `LLMTool`, `PINLockoutTests`, `.projects()`, `AddSourceTool`, `LexicalIndex`, `.text()`, `.messages()`, `SeededRandom`, `VoiceSpeaker`, `GraphView`, `BYOKFileSecretStore`, `.parseSSELine()`, `.decode()`, `ThemeDetailView`, `.check()`, `OnboardingView`, `BiometryType`, `TTSError`, `FallbackLLM`, `FakeOllama`, `FakeEmbedder`, `.check()`, `ModelConfiguration`, `.seededEngine()`, `NLEmbeddingProvider`, `ElevenLabsTTSEngineTests`, `.allowsRedirect()`, `ArchiveError`, `SearchHit`, `TTSError`, `.speakableText()`, `DigestController`, `BriefRevisionStatus`, `StrategyItemStatus`, `Answer`, `TriageScore`?**
  _High betweenness centrality (0.544) - this node is a cross-community bridge._
- **Why does `ModelContext` connect `ModelContext` to `ThemeNode`, `.fetch()`, `BriefingTests`, `GraphIndexer`, `Article`, `PipelineController`, `String`, `.makeContainer()`, `FetchURLTool`, `.run()`, `.outcome()`, `LLMUsage`, `SmartWardIntents.swift`, `.apply()`, `Sendable`, `SmartWardEngine`, `DailyBudget`, `VoiceAnswersTests`, `Identifiable`, `HybridSearchIndex`, `ModelContainer`, `RetrievedPassage`, `VoiceContext`, `ShimObjectState`, `Scenario`, `RawItem`, `AddSourceTool`, `.projects()`, `LibraryFixture`, `PerfTrace`, `ProjectArticlesTests`, `SourceKind`, `.importItems()`, `.data()`, `GitHubRepo`, `ExtractedArticle`, `GraphSnapshot`, `.chat()`, `.suggest()`, `.load()`, `ThemeStrengthCache`, `ArticleSummaryController`?**
  _High betweenness centrality (0.035) - this node is a cross-community bridge._
- **Why does `Foundation` connect `Foundation` to `ThemeNode`, `KnowledgeStore`, `GraphIndexer`, `JSONValue`, `Retriever`, `String`, `GitHubAccount`, `Plugin.swift`, `VoiceCommandParser`, `.check()`, `ShareSheet`, `LLMUsage`, `ModelContext`, `ShimRelationship`, `SmartWardIntents.swift`, `BYOKLLMKit`, `.extract()`, `LLMProvider`, `PersistentModel`, `BiometricService`, `XCTest`, `Identifiable`, `BiometricEvaluation`, `LLMChatMessage`, `.check()`, `FallbackLLM`, `VoiceLoopConfig`, `GitHubClient`, `ModelContainer`, `AppLockCoordinator`, `LLMService`, `.aggregate()`, `ParsedFeed`, `ShimObjectState`, `StepProgress`, `ScoredChunk`, `VectorIndex`, `ArticleSummary`, `FileCache`, `CatalogEntry`, `PerfTrace`, `.text()`, `ProjectArticlesTests`, `.body()`, `OllamaClient`, `Codable`, `SQLiteDatabase`, `BYOKFileSecretStore`, `LocalLLMEngine`, `.score()`, `Library`, `.body`, `EchoHandler`, `LLMStreamEvent`, `BiometryType`, `.decodeResponse()`, `EntityChunkIndex`, `TopK`, `.start()`, `TopK`, `.outcome()`, `StreamDelegate`, `.analyze()`, `PINAttemptResult`, `ContextAssembler`, `FetchDescriptor`, `BiometricLockKit`, `AVFoundation`, `Dependency`, `RepoSync.swift`, `Parent`, `GraphRetriever`, `.segments()`, `LexicalIndex`?**
  _High betweenness centrality (0.027) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `ModelContext` (e.g. with `.external()` and `.testSecondContextSeesSavedChangesAndEdits()`) actually correct?**
  _`ModelContext` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `unlocked`, `denied`, `AgentRouteKit` to the rest of the system?**
  _682 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `ThemeNode` be split into smaller, more focused modules?**
  _Cohesion score 0.05193171608265948 - nodes in this community are weakly interconnected._