# Graph Report - SmartWard-Linux  (2026-10-24)

## Corpus Check
- Large corpus: 364 files · ~798,963 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder.

## Summary
- 5765 nodes · 15803 edges · 257 communities (240 shown, 17 thin omitted)
- Extraction: 87% EXTRACTED · 13% INFERRED · 0% AMBIGUOUS · INFERRED: 2051 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- View
- cytoscape.min.js
- LLMResponse
- JSONValue
- AnalyzerCommandRecognizer
- RetrievedPassage
- ThemeNode
- KnowledgeStore
- .save()
- GraphIndexer
- ArticleSummary
- Project
- Conversation
- DigestBuilder
- .outcome()
- ModelContext
- SharedInbox
- ArticleReadoutController
- String
- Plugin.swift
- VoiceCommandParser
- VoiceCommand
- Foundation
- Retriever
- .makeContainer()
- LLMRequest
- .run()
- OllamaClient
- PipelineController
- VoiceAnswersTests
- BYOKLLMKit
- IngestError
- LocalizedError
- .refresh()
- BiometricService
- LLMCompleting
- .record()
- Sendable
- XCTest
- LLMProvider
- Article
- PINService
- StrategistRunner
- AppLockCoordinator
- Identifiable
- FallbackLLM
- ShimObjectState
- ReadoutPlayback
- LLMService
- ScoredChunk
- VectorIndex
- ActionRequest
- OnboardingProposal
- server.py
- HybridRetriever
- VoiceConversationController
- ExtractedGraph
- LibraryFixture
- StrategyItemKind
- BackupView
- XCTestCase
- EmbeddingModel
- CaseIterable
- SQLiteDatabase
- RawItem
- SourceKind
- .extract()
- GitHubDeviceFlow
- PerfTrace
- LocalLLMEngine
- BiometricUnavailable
- EchoHandler
- Library
- ExtractedArticle
- ShimRelationship
- InterestModel
- VoiceIntentTests
- SmartWardEngine
- BiometricEvaluation
- WireModels.swift
- EntityChunkIndex
- Phase 5: Hardening
- Pipeline module (ingestion, graph, searc
- GitHubDeviceCode
- FileCache
- SelectionPolicy
- CappedFetch
- GitHubClient
- Choice
- AskStrategistIntent
- OpenAITTSEngine
- Invariant D5: Private content never goes
- .segments()
- .analyze()
- PINAttemptResult
- ElevenLabsTTSEngine
- SourceFetcher
- makeContext()
- .outcome()
- VoiceCommandTests
- AVFoundation
- GraphRAG
- .items()
- LLMCompletionError
- ConversationView
- Dependency
- IngestController
- .fromPastedURL()
- LocalAIError
- .matches()
- Parent
- CodingKeys
- .energies()
- VoiceTranscriptTests
- HTTPTransport
- DigestCluster
- HybridSearchIndex
- .load()
- VoiceConfirmationGate
- Ingestion pipeline: fetch, clean, triage
- BYOKLLMKit
- RetrievalKit
- GraphRetriever
- ConversationMode
- .synthesize()
- .check()
- .fetch()
- VoiceSpeaker
- .body
- PackageDescription
- .consume()
- ContextAssembler
- LexicalIndex
- SearchDocument
- ProjectArticlesTests
- SmartWardKit.KnowledgeStore (SwiftData m
- Article (SwiftData model)
- ThemeNode (SwiftData model)
- AppNavigation
- StreamDelegate
- Coordinator
- GitHubAccount
- ReadoutSegment
- Approval Before Actions
- Strategist Layer
- SpeechService
- .check()
- ModelContainer
- BriefingTests
- ThemeStrengthCache
- .read()
- .check()
- SmartWard (iOS Application Target)
- SearchHit
- LLMKeychainStore
- ShareSheet
- .score()
- .plan()
- ModelFallback
- .makeFixture()
- .makeStore()
- OnboardingView
- SmartWardShare (Share Extension Target)
- Prompt-injection defense
- PersistentModel
- .check()
- OpenAITTSEngineTests
- VoiceLoopConfig
- AppLockPolicy
- FakeTransport
- AppLockController
- .score()
- SmartWard XcodeGen Project Spec
- GitHubRepo
- .fallbackLLM()
- SourcesView
- Accessibility Verification Pass
- GraphRAG Latency Budget (NFR-4: p95 unde
- PINLockoutTests
- RobotsRules
- .projects()
- Refusal
- LocalModelConfig
- .text()
- StepProgress
- .messages()
- SeededRandom
- .check()
- .start()
- ProjectEntity
- .canonicalize()
- What the Simulator Can't Show
- Inference Layer
- ContextAssembler token budget and fencin
- CatalogEntry
- ShimKey
- BYOKFileSecretStore
- .parseSSELine()
- KeychainLockoutStore
- TTSError
- GitHubError
- .apply()
- Anchor
- DeveloperView
- ModelCatalogController
- AppLockTests.swift
- .service()
- TopK
- TopKTests
- ArticleStage
- TopK
- .check()
- FakeEmbedder
- .check()
- StrategistCore (tool loop, prompts, brie
- Packages/SmartWardKit (local SPM package
- SmartWardKit (Local Swift Package)
- NLEmbeddingProvider
- BiometryType
- .allowsRedirect()
- .seededEngine()
- SourceKindOption
- NSObject
- CatalogCacheTests
- ElevenLabsTTSEngineTests
- ArchiveError
- FetchDescriptor
- Why
- Graph View
- UntrustedText (body/attribute inside its
- KeychainDomainStateStore
- .audioPlayerDidFinishPlaying()
- FileCacheTests
- .speakableText()
- .graphML()
- .documents()
- ActivitySheet
- Living Project Brief
- RepoSync.swift
- BundledResourcesTests
- TTSError
- Chunk (SwiftData model)
- DecisionProviding protocol seam
- LLMProviderTests
- Status
- VoiceSpeedChange
- Apple Intelligence Preflight
- Phase
- VoiceReadingFilter
- LocalBackendsLiveTests
- .send()
- TriageScore
- VoiceReadingOrder
- LexicalIndexTests
- graphify_refresh.sh
- shim.h
- .init()

## God Nodes (most connected - your core abstractions)
1. `ModelContext` - 154 edges
2. `Article` - 121 edges
3. `KnowledgeStore` - 118 edges
4. `SwiftData` - 102 edges
5. `XCTest` - 95 edges
6. `JSONValue` - 95 edges
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
- `.body` --calls--> `Section`  [INFERRED]
  SmartWard/Graph/GraphExtraction.swift → Packages/SmartWardKit/Sources/Pipeline/Extraction.swift
- `.parameterSummary` --calls--> `Summary`  [INFERRED]
  SmartWard/Intents/SmartWardIntents.swift → Packages/SmartWardKit/Sources/Pipeline/PerfTrace.swift

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

## Communities (257 total, 17 thin omitted)

### Community 0 - "View"
Cohesion: 0.03
Nodes (88): Section, entities, relations, BriefDiff, Line, added, removed, same (+80 more)

### Community 1 - "cytoscape.min.js"
Cohesion: 0.05
Nodes (58): a(), Ao(), b(), Ba(), cs(), d(), dc(), ds() (+50 more)

### Community 2 - "LLMResponse"
Cohesion: 0.05
Nodes (48): AnthropicStreamAccumulator, AnthropicWire, Block, text, toolUse, Data, Int, LLMChatMessage (+40 more)

### Community 3 - "JSONValue"
Cohesion: 0.04
Nodes (43): ExpressibleByArrayLiteral, ExpressibleByBooleanLiteral, ExpressibleByDictionaryLiteral, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, ExpressibleByNilLiteral, ExpressibleByStringLiteral, error (+35 more)

### Community 4 - "AnalyzerCommandRecognizer"
Cohesion: 0.05
Nodes (38): AnalyzerInput, AsyncStream, AVAudioConverter, AVAudioFormat, AnalyzerCommandRecognizer, AnalyzerFeed, Session, AVAudioNodeTapBlock (+30 more)

### Community 5 - "RetrievedPassage"
Cohesion: 0.06
Nodes (38): Decodable, Arguments, FetchURLTool, .asksForApproval, .definition, URL, GraphRetriever, ReferenceContext (+30 more)

### Community 6 - "ThemeNode"
Cohesion: 0.06
Nodes (51): CGFloat, Color, Data, ThemeNode, Edge, ForceLayout, GraphSnapshot, Node (+43 more)

### Community 7 - "KnowledgeStore"
Cohesion: 0.07
Nodes (12): BackgroundTasks, FoundationModels, KnowledgeStore, Observation, ShareInbox, Triage.Strength, .label, SwiftData (+4 more)

### Community 8 - ".save()"
Cohesion: 0.10
Nodes (23): ExtractionTiers, Backlog, .total, PipelineRunner, Report, Bool, Date, Double (+15 more)

### Community 9 - "GraphIndexer"
Cohesion: 0.07
Nodes (33): Error, EntityExtracting, ExtractionOutput, ExtractionTier, byok, onDevice, ExtractionAttempt, ExtractionJob (+25 more)

### Community 10 - "ArticleSummary"
Cohesion: 0.06
Nodes (26): NSRegularExpression, DailyBudget, ArticleSummarizer, ArticleSummarizing, ArticleSummaryOutput, ArticleSummaryPrompt, .schema, BYOKArticleSummarizer (+18 more)

### Community 11 - "Project"
Cohesion: 0.07
Nodes (25): Project, BriefEditing, tooLong, BriefReviser, Suggestion, Date, ProjectStateTool, .asksForApproval (+17 more)

### Community 12 - "Conversation"
Cohesion: 0.09
Nodes (29): Set, BriefRevision, Chunk, Conversation, EntityAlias, InterestProfile, Mention, MergeSuggestion (+21 more)

### Community 13 - "DigestBuilder"
Cohesion: 0.06
Nodes (29): BYOKDigestSummarizer, DigestBuilder, DigestPrompt, DigestSummarizing, DigestSummary, DigestSummaryRequest, Excerpt, Group (+21 more)

### Community 14 - ".outcome()"
Cohesion: 0.07
Nodes (21): AVAudioSession, CommandRecognizing, VoiceEngine, .current, .id, newer, standard, Outcome (+13 more)

### Community 15 - "ModelContext"
Cohesion: 0.07
Nodes (26): Encodable, LibraryArchive, Bool, Int, T, DecodeBox, ModelContext, .hasChanges (+18 more)

### Community 16 - "SharedInbox"
Cohesion: 0.06
Nodes (29): NSExtensionContext, Result, SharedImport, Date, Int, Source, SharedInbox, .itemsDirectory (+21 more)

### Community 17 - "ArticleReadoutController"
Cohesion: 0.07
Nodes (28): AVSpeechSynthesizerDelegate, MPRemoteCommand, .readoutBar, ArticleReadoutController, .currentAnchor, .currentArticle, .currentText, .isActive (+20 more)

### Community 18 - "String"
Cohesion: 0.08
Nodes (29): CatalogFetcher, JSONDecoder, Int, String, .sentenceList, VoiceContext, Action, Answer (+21 more)

### Community 19 - "Plugin.swift"
Cohesion: 0.08
Nodes (42): AccessorDeclSyntax, AccessorMacro, AttributeSyntax, CompilerPlugin, DeclGroupSyntax, DeclSyntax, DeclSyntaxProtocol, ExtensionDeclSyntax (+34 more)

### Community 20 - "VoiceCommandParser"
Cohesion: 0.09
Nodes (24): EchoGuard, Bool, Int, Set, VoiceCommandParser, VoiceItemMatcher, VoiceParse, command (+16 more)

### Community 21 - "VoiceCommand"
Cohesion: 0.04
Nodes (47): VoiceCommand, aboutTheme, acceptBriefUpdate, ask, back, clearSearch, .confirmation, decline (+39 more)

### Community 22 - "Foundation"
Cohesion: 0.08
Nodes (8): ArgumentParser, Foundation, FoundationNetworking, IngestKit, NaturalLanguage, Security, GitHubConfig, SmartWardCore

### Community 23 - "Retriever"
Cohesion: 0.09
Nodes (16): Chunker, Chunk, Document, Int, Document, EmbeddingProviding, Float, Retriever (+8 more)

### Community 24 - ".makeContainer()"
Cohesion: 0.13
Nodes (15): Bool, URL, ArticleSummaryTests, IngestionSummaryTests, Refused, device, provider, StubSummarizer (+7 more)

### Community 25 - "LLMRequest"
Cohesion: 0.09
Nodes (18): Bool, LLMRequest, LLMToolChoice, auto, none, required, tool, groq (+10 more)

### Community 26 - ".run()"
Cohesion: 0.08
Nodes (23): ActionTools, ApprovalDecision, approve, ask, decline, Bool, Set, Set (+15 more)

### Community 27 - "OllamaClient"
Cohesion: 0.11
Nodes (20): ExtractionBusy, .errorDescription, LocalArticleSummarizer, LocalBackends, LocalDigestSummarizer, LocalEntityExtractor, LocalRelevanceJudge, reachable() (+12 more)

### Community 28 - "PipelineController"
Cohesion: 0.07
Nodes (29): GraphRunStats, .isEmpty, .onDeviceSecondsPerCall, .providerSecondsPerCall, Double, .body, IndexingDetailsView, .body (+21 more)

### Community 29 - "VoiceAnswersTests"
Cohesion: 0.09
Nodes (8): LibraryVoiceQueries, Bool, Double, Int, ThemeDescription, VoiceAnswers, VoiceAnswersTests, World

### Community 30 - "BYOKLLMKit"
Cohesion: 0.07
Nodes (5): AppIntents, BYOKLLMKit, LocalLLMKit, ModelCatalogKit, StrategistCore

### Community 31 - "IngestError"
Cohesion: 0.09
Nodes (26): IngestError, backingOff, disallowedByRobots, .errorDescription, http, invalidResponse, invalidURL, notAFeed (+18 more)

### Community 32 - "LocalizedError"
Cohesion: 0.05
Nodes (38): LocalizedError, LocalLLMError, busy, .errorDescription, loadFailed, notLoaded, timeout, CatalogError (+30 more)

### Community 33 - ".refresh()"
Cohesion: 0.08
Nodes (26): App, BGContinuedProcessingTask, Scene, SmartWardApp, .body, BackgroundRefreshSettingsSection, .eagerness, .isRefreshing (+18 more)

### Community 34 - "BiometricService"
Cohesion: 0.12
Nodes (13): BiometricEvaluating, DomainStateStoring, Data, BiometricService, .hasBaseline, Bool, Data, DomainStateTests (+5 more)

### Community 35 - "LLMCompleting"
Cohesion: 0.08
Nodes (15): LLMCompleting, invalidStructuredOutput, AsyncThrowingStream, Error, BYOKExtractor, ExtractionPrompt, .schema, FallbackLLM (+7 more)

### Community 36 - ".record()"
Cohesion: 0.12
Nodes (19): Line, .id, Price, PriceBook, Bool, Calendar, Date, Double (+11 more)

### Community 37 - "Sendable"
Cohesion: 0.24
Nodes (32): Codable, Equatable, GitHubUser, AliasRecord, ArticleRecord, BriefRecord, BriefRevisionRecord, ChunkRecord (+24 more)

### Community 38 - "XCTest"
Cohesion: 0.10
Nodes (3): ContentSafetyKit, Pipeline, XCTest

### Community 39 - "LLMProvider"
Cohesion: 0.10
Nodes (25): LLMProvider, anthropic, .baseURL, deepseek, .displayName, .exampleModelID, .id, .isOpenAICompatible (+17 more)

### Community 40 - "Article"
Cohesion: 0.08
Nodes (29): Article, Chunk, Int, .sourceLabel, ArticleReaderView, .body, .fullTextBanner, .metadata (+21 more)

### Community 41 - "PINService"
Cohesion: 0.10
Nodes (17): AppLockCoordinator, Outcome, denied, unlocked, Bool, PINFileSecretStore, .directory, Bool (+9 more)

### Community 42 - "StrategistRunner"
Cohesion: 0.13
Nodes (17): StrategistRunner, Int, EchoTool, .asksForApproval, .definition, FailingTool, .asksForApproval, .definition (+9 more)

### Community 43 - "AppLockCoordinator"
Cohesion: 0.10
Nodes (20): AnyObject, AppLockCoordinator, .biometryName, .isPINLockedOut, .pinLockoutRemaining, BiometricStep, needsPIN, unlocked (+12 more)

### Community 44 - "Identifiable"
Cohesion: 0.15
Nodes (9): Identifiable, AggregatedEdge, AggregatedGraph, AggregatedNode, GraphExporter, Int, URL, GraphExporterTests (+1 more)

### Community 45 - "FallbackLLM"
Cohesion: 0.15
Nodes (15): FallbackLLM, Alternatives, AsyncThrowingStream, Bool, Error, Int, CallRecorder, FallbackLLMTests (+7 more)

### Community 46 - "ShimObjectState"
Cohesion: 0.15
Nodes (12): M, BlobSlot, LinkSlot, pending, resolved, ShimObjectState, AnyModel, AnyObject (+4 more)

### Community 47 - "ReadoutPlayback"
Cohesion: 0.16
Nodes (8): ReadoutPlayback, .currentGroup, .groupPosition, .isActive, .position, Bool, ReadoutPlaybackTests, Int

### Community 48 - "LLMService"
Cohesion: 0.13
Nodes (15): LLMError, apiError, .errorDescription, noAPIKey, streamingNotSupported, unsupportedProvider, LLMSending, LLMService (+7 more)

### Community 49 - "ScoredChunk"
Cohesion: 0.15
Nodes (17): Edge, Node, SessionGraph, Float, GraphExpander, Float, GraphExpanderTests, Chunk (+9 more)

### Community 50 - "VectorIndex"
Cohesion: 0.17
Nodes (12): entries, CodableEntry, Entry, Bool, Chunk, Data, Float, Int (+4 more)

### Community 51 - "ActionRequest"
Cohesion: 0.11
Nodes (20): confirm, ProposeBriefUpdateTool, .asksForApproval, .definition, ActionRequest, StrategistEvent, awaitingConfirmation, confirmationResolved (+12 more)

### Community 52 - "OnboardingProposal"
Cohesion: 0.09
Nodes (21): ApplyResult, OnboardingProposal, .schema, ProjectProposal, .id, SourceProposal, .id, OnboardingApplyTests (+13 more)

### Community 53 - "server.py"
Cohesion: 0.08
Nodes (27): argparse, datetime, glob, http_server, io, json, Kokoro, kokoro_onnx (+19 more)

### Community 54 - "HybridRetriever"
Cohesion: 0.15
Nodes (13): HybridRetriever, .underlyingRetriever, Bool, Chunk, Document, Int, Sendable, FakeEmbeddingProvider (+5 more)

### Community 55 - "VoiceConversationController"
Cohesion: 0.13
Nodes (15): Phase, idle, listening, speaking, thinking, Bool, Never, SFSpeechAudioBufferRecognitionRequest (+7 more)

### Community 56 - "ExtractedGraph"
Cohesion: 0.11
Nodes (11): LanguageModelSession, Entity, ExtractedGraph, ExtractionText, Relation, Bool, .name, ExtractionTextTests (+3 more)

### Community 57 - "LibraryFixture"
Cohesion: 0.11
Nodes (18): BackupError, .errorDescription, newerVersion, notABackup, passphraseTooShort, unsupportedCompression, wrongPassphraseOrDamaged, EncryptedBackup (+10 more)

### Community 58 - "StrategyItemKind"
Cohesion: 0.10
Nodes (16): .kind, StrategyItemKind, actionItem, assumption, decision, openQuestion, risk, .definition (+8 more)

### Community 59 - "BackupView"
Cohesion: 0.09
Nodes (24): BackupView, .body, .canCreate, Bool, Data, Error, LibraryArchive, Result (+16 more)

### Community 60 - "XCTestCase"
Cohesion: 0.09
Nodes (12): T, ChatMessageTests, CompletionServiceTests, Entity, FakeCompleter, StructuredOutputTests, AsyncThrowingStream, Error (+4 more)

### Community 61 - "EmbeddingModel"
Cohesion: 0.14
Nodes (12): EmbeddingModel, Data, Float, VectorCoding, EntityResolver, Resolution, Bool, Float (+4 more)

### Community 62 - "CaseIterable"
Cohesion: 0.07
Nodes (28): CaseIterable, .status, BriefRevisionStatus, accepted, pending, rejected, superseded, .status (+20 more)

### Community 63 - "SQLiteDatabase"
Cohesion: 0.10
Nodes (18): CSQLite, CustomStringConvertible, Int32, OpaquePointer, Bool, Void, SQLiteDatabase, SQLiteError (+10 more)

### Community 64 - "RawItem"
Cohesion: 0.15
Nodes (12): FeedIngest, Result, Bool, Date, Error, Int, Source, TimeInterval (+4 more)

### Community 65 - "SourceKind"
Cohesion: 0.12
Nodes (17): SourceEndpoint, URL, .sourceKind, SourceKind, arxiv, githubReleases, githubRepo, hfPapers (+9 more)

### Community 66 - ".extract()"
Cohesion: 0.14
Nodes (8): ArticleExtractor, Bool, Document, Element, URL, ArticleExtractorTests, SwiftSoup, Unicode

### Community 67 - "GitHubDeviceFlow"
Cohesion: 0.11
Nodes (16): GitHubDeviceFlow, failed, GitHubTokenPoll, pending, slowDown, token, async, Data (+8 more)

### Community 68 - "PerfTrace"
Cohesion: 0.14
Nodes (16): DispatchTime, os, PerfTrace, .names, .samples, Sample, SampleLock, Summary (+8 more)

### Community 69 - "LocalLLMEngine"
Cohesion: 0.14
Nodes (10): LLM, LocalLLMEngine, Bool, Int, Never, Task, URL, Void (+2 more)

### Community 70 - "BiometricUnavailable"
Cohesion: 0.10
Nodes (19): Result, Void, BiometricResult, biometryChanged, canceled, failed, fallback, lockout (+11 more)

### Community 71 - "EchoHandler"
Cohesion: 0.17
Nodes (10): AgentRouteKit, Output, Handler, Router, .handlerNames, Context, Float, EchoHandler (+2 more)

### Community 72 - "Library"
Cohesion: 0.18
Nodes (14): AsyncParsableCommand, Add, Ask, Digest, Ingest, Library, note(), Read (+6 more)

### Community 73 - "ExtractedArticle"
Cohesion: 0.13
Nodes (11): ExtractedArticle, Date, FetchedPageImport, Bool, Date, URL, FullTextFetching, URL (+3 more)

### Community 74 - "ShimRelationship"
Cohesion: 0.11
Nodes (19): CloudKitDatabase, automatic, none, `private`, DeleteRule, cascade, deny, noAction (+11 more)

### Community 75 - "InterestModel"
Cohesion: 0.14
Nodes (12): Interest, InterestModel, .isEmpty, RelevanceJudging, Bool, Float, Set, UUID (+4 more)

### Community 76 - "VoiceIntentTests"
Cohesion: 0.11
Nodes (12): CodingKeys, action, change, filter, kind, number, on, order (+4 more)

### Community 77 - "SmartWardEngine"
Cohesion: 0.13
Nodes (15): Answer, EngineError, .errorDescription, noEmbeddings, noModels, SearchResult, SmartWardEngine, .context (+7 more)

### Community 78 - "BiometricEvaluation"
Cohesion: 0.10
Nodes (15): LAPolicy, LocalAuthentication, BiometricEvaluation, canceled, failed, fallback, lockout, success (+7 more)

### Community 79 - "WireModels.swift"
Cohesion: 0.14
Nodes (22): Data, AnthropicContentBlock, AnthropicMessage, AnthropicRequest, AnthropicResponse, AnthropicUsage, CodingKeys, completionTokens (+14 more)

### Community 80 - "EntityChunkIndex"
Cohesion: 0.20
Nodes (7): EntityChunkIndex, Chunk, Set, Int, Set, EntityChunkIndexTests, Chunk

### Community 81 - "Phase 5: Hardening"
Cohesion: 0.14
Nodes (24): Empty States and Accessibility, App Lock (Face ID/Touch ID with PIN fallback), BM25 Lexical Search (compound tokens kept whole), Bounded-heap Top-K Rankings, Device Measurement (Instruments signposts), docs/DEVICE_TESTING.md, Export (Settings to Export), GraphML Export (Gephi or yEd) (+16 more)

### Community 82 - "Pipeline module (ingestion, graph, searc"
Cohesion: 0.14
Nodes (23): ArticleIndexer (search index built and updated in place), DigestBuilder (clustering, ranking, tiered summaries), EmbeddingModel (vectors never compared across models), EntityResolver (names resolve to one node), GraphEditing (merge and split, writes user aliases), GraphExport (GraphML via GraphKit), GraphIndexer (extraction routing tiers, D2/D5), OnDeviceKit GraphKit (+15 more)

### Community 83 - "GitHubDeviceCode"
Cohesion: 0.09
Nodes (23): CodingKey, CodingKeys, defaultBranch, description, fullName, htmlURL, isPrivate, pushedAt (+15 more)

### Community 84 - "FileCache"
Cohesion: 0.13
Nodes (8): CatalogCache, Bool, TimeInterval, FileCache, .cacheDir, Bool, Data, URL

### Community 85 - "SelectionPolicy"
Cohesion: 0.17
Nodes (8): ModelRole, chat, extract, image, SelectionPolicy, Bool, Double, SelectionPolicyTests

### Community 86 - "CappedFetch"
Cohesion: 0.19
Nodes (15): CappedFetch, Router, Bool, CheckedContinuation, Data, Error, HTTPURLResponse, Int (+7 more)

### Community 87 - "GitHubClient"
Cohesion: 0.20
Nodes (8): GitHubClient, .isAuthenticated, Data, HTTPURLResponse, Set, T, URLRequest, URLQueryItem

### Community 88 - "Choice"
Cohesion: 0.10
Nodes (20): AddSourceView, .body, .defaultName, .storedURL, .trimmedInput, Choice, arxiv, feed (+12 more)

### Community 89 - "AskStrategistIntent"
Cohesion: 0.14
Nodes (18): AppIntent, AppShortcut, AppShortcutsProvider, AudioPlaybackIntent, IntentAuthenticationPolicy, IntentResult, LocalizedStringResource, ParameterSummary (+10 more)

### Community 90 - "OpenAITTSEngine"
Cohesion: 0.22
Nodes (11): AVAudioPlayerDelegate, OpenAITTSEngine, PrefetchedClip, Error, Float, NSRange, TimeInterval, Timer (+3 more)

### Community 91 - "Invariant D5: Private content never goes"
Cohesion: 0.12
Nodes (22): ArticleExtractor (SwiftSoup HTML to clean text), ContextPolicy (provider-context filter), Invariant D5: Private content never goes to a BYOK provider, Plan Decision IDs D1-D6 (referenced in code), Invariant: extraction routing lives in GraphIndexer.tiers(for:), GitHubClient (GET-only), GitHubTokenStore (device-only Keychain), IngestKit (source ingestion and GitHub) (+14 more)

### Community 92 - ".segments()"
Cohesion: 0.14
Nodes (9): Locale, Array, ArticleReadout, Builder, .current, ReadoutScope, summaryOnly, whole (+1 more)

### Community 93 - ".analyze()"
Cohesion: 0.15
Nodes (6): EdgeSpec, Extraction, GraphDisplay, KnowledgeGraphExtractor, NodeSpec, KnowledgeGraphExtractorTests

### Community 94 - "PINAttemptResult"
Cohesion: 0.18
Nodes (12): PINAttemptResult, incorrect, lockedOut, success, PINLockout, .isLockedOut, PINLockoutStore, Bool (+4 more)

### Community 95 - "ElevenLabsTTSEngine"
Cohesion: 0.23
Nodes (11): ElevenLabsTTSEngine, PrefetchedClip, Double, Error, Float, NSRange, TimeInterval, Timer (+3 more)

### Community 96 - "SourceFetcher"
Cohesion: 0.21
Nodes (8): SourceDescriptor, SourceFetcher, Bool, Data, HTTPURLResponse, Source, UUID, SourceFetcherTests

### Community 97 - "makeContext()"
Cohesion: 0.15
Nodes (7): ContextPolicy, Bool, Chunk, ContextPolicyTests, makeContext(), NormalizedKeyTests, SchemaTests

### Community 98 - ".outcome()"
Cohesion: 0.14
Nodes (10): Outcome, fail, listen, speak, StartBlocker, missingKey, needsAutoApprove, Bool (+2 more)

### Community 99 - "VoiceCommandTests"
Cohesion: 0.16
Nodes (3): StaticString, UInt, VoiceCommandTests

### Community 100 - "AVFoundation"
Cohesion: 0.12
Nodes (4): AVFoundation, MediaPlayer, Speech, VoiceLoopKit

### Community 101 - "GraphRAG"
Cohesion: 0.16
Nodes (21): B1 GraphRAG over the SwiftData graph, B4 Graph view drawn natively in SwiftUI, C3 GraphRetrievalKit needs an injectable entity index, FR-11 GraphRAG every turn with why-retrieved, FR-14 Full-text, semantic and graph-expanded search, FR-15 Interactive offline graph view, FR-18 Encrypted export and import, FR-20 App Intents and Shortcuts (+13 more)

### Community 102 - ".items()"
Cohesion: 0.16
Nodes (9): FoundationXML, Entry, .url, FeedParser, FeedXMLDelegate, ParsedFeed, Data, XMLParser (+1 more)

### Community 103 - "LLMCompletionError"
Cohesion: 0.13
Nodes (15): LLMCompletionError, .errorDescription, http, .isRetryable, malformedResponse, missingResponseFormat, provider, Behavior (+7 more)

### Community 104 - "ConversationView"
Cohesion: 0.13
Nodes (13): ActionConfirmationCard, .body, ConversationView, .body, .messages, .missingKeyWarning, .voiceStatusText, MessageRow (+5 more)

### Community 105 - "Dependency"
Cohesion: 0.23
Nodes (3): Dependency, ManifestParser, ManifestParserTests

### Community 106 - "IngestController"
Cohesion: 0.13
Nodes (11): SourceHealth, Error, SourceHealthTests, FullTextError, .errorDescription, nothingMore, IngestController, Set (+3 more)

### Community 107 - ".fromPastedURL()"
Cohesion: 0.14
Nodes (11): LinkParsingTests, syncGitHubLinks(), GitHubProjectSection, .body, .dependencies, .repoLinks, EditLinkView, .body (+3 more)

### Community 108 - "LocalAIError"
Cohesion: 0.12
Nodes (14): ChatReply, LocalAIError, badResponse, .errorDescription, http, modelMissing, notLoopback, unreachable (+6 more)

### Community 109 - ".matches()"
Cohesion: 0.14
Nodes (18): Candidate, Match, .id, ProjectArticles, Date, Double, Int, TimeInterval (+10 more)

### Community 110 - "Parent"
Cohesion: 0.20
Nodes (9): Child, LinuxSwiftDataTests, Parent, Bool, Data, Date, URL, UUID (+1 more)

### Community 111 - "CodingKeys"
Cohesion: 0.13
Nodes (18): CodingKeys, architecture, completion, contextLength, id, image, inputModalities, lastRefreshed (+10 more)

### Community 112 - ".energies()"
Cohesion: 0.18
Nodes (8): PCMEnergyAnalyzer, AVAudioPCMBuffer, Float, Int, PCMEnergyAnalyzerTests, AVAudioPCMBuffer, Double, Float

### Community 114 - "HTTPTransport"
Cohesion: 0.17
Nodes (10): HTTPTransport, Bool, LocalAddress, Bool, URL, SpeechClient, Double, URL (+2 more)

### Community 115 - "DigestCluster"
Cohesion: 0.20
Nodes (13): ArticleRef, Digest, .clusters, DigestCluster, ProjectRef, Bool, Date, Double (+5 more)

### Community 116 - "HybridSearchIndex"
Cohesion: 0.20
Nodes (10): HybridSearchIndex, .documentCount, .documentIDs, .needsRebuild, LexicalIndex, .count, RankedDocument, Double (+2 more)

### Community 117 - ".load()"
Cohesion: 0.18
Nodes (12): SampleLibrary, Size, SplitMix, Bool, Date, Double, Float, Int (+4 more)

### Community 118 - "VoiceConfirmationGate"
Cohesion: 0.22
Nodes (10): Pending, Resolution, cancelled, nothingToConfirm, run, Bool, Date, TimeInterval (+2 more)

### Community 119 - "Ingestion pipeline: fetch, clean, triage"
Cohesion: 0.22
Nodes (19): ArticleExtractor, BGTaskScheduler background tasks, FR-1 Add, edit, disable and remove sources, FR-22 GitHub integration and repo sync, FR-2 Fetch new items manually and in background, FR-3 Share extension ingestion, GitHub option A: paste repo links only, GitHubClient (+11 more)

### Community 120 - "BYOKLLMKit"
Cohesion: 0.16
Nodes (19): BiometricLockKit, BYOKLLMKit, C1 Anthropic SSE streaming is missing from BYOKLLMKit, CloudKit-compatible schema rules, Evaluation harness, FR-16 BYOK key management and model picker, FR-19 PIN and biometric app lock, Inference tiers T0-T3 (+11 more)

### Community 121 - "RetrievalKit"
Cohesion: 0.14
Nodes (3): GraphKit, GraphRetrievalKit, RetrievalKit

### Community 122 - "GraphRetriever"
Cohesion: 0.14
Nodes (9): GraphRetriever, Chunk, Document, Int, FakeEmbeddingProvider, Float, Int, Substring (+1 more)

### Community 123 - "ConversationMode"
Cohesion: 0.12
Nodes (16): .mode, ConversationMode, brainstorm, critique, onboarding, researchPlan, weeklyReview, ChatListView (+8 more)

### Community 124 - ".synthesize()"
Cohesion: 0.15
Nodes (11): Bool, Data, UInt32, WAV, RecordingPlayer, Bool, Data, HTTPURLResponse (+3 more)

### Community 125 - ".check()"
Cohesion: 0.15
Nodes (4): VoiceCommandHelp, StaticString, UInt, VoiceProjectCommandTests

### Community 126 - ".fetch()"
Cohesion: 0.15
Nodes (10): FetchError, .errorDescription, http, invalidKey, unreadable, ProviderModelFetcher, Data, Int (+2 more)

### Community 127 - "VoiceSpeaker"
Cohesion: 0.13
Nodes (10): AVSpeechSynthesisVoice, VoiceSettings, .current, VoiceSettingsSection, .body, AppAudio, Bool, Bool (+2 more)

### Community 128 - ".body"
Cohesion: 0.12
Nodes (14): LockWindow, Bool, .state, ArticleSummaryController, State, failed, generating, tooShort (+6 more)

### Community 129 - "PackageDescription"
Cohesion: 0.11
Nodes (3): CompilerPluginSupport, PackageDescription, Package

### Community 130 - ".consume()"
Cohesion: 0.22
Nodes (7): AsyncThrowingStream, Error, OpenAIStreamAccumulator, PartialToolCall, SSE, Int, OpenAIStreamAccumulatorTests

### Community 131 - "ContextAssembler"
Cohesion: 0.20
Nodes (6): ContextAssembler, Int, HeuristicTokenEstimator, TokenEstimating, ContextAssemblerTests, Float

### Community 132 - "LexicalIndex"
Cohesion: 0.16
Nodes (5): LexicalIndex, .count, Double, Int, LexicalIndexTests

### Community 133 - "SearchDocument"
Cohesion: 0.21
Nodes (8): SearchCorpus, SearchDocument, Bool, Set, UUID, Update, .isEmpty, Sequence

### Community 134 - "ProjectArticlesTests"
Cohesion: 0.30
Nodes (6): ProjectArticlesTests, Date, Double, Int, Source, World

### Community 135 - "SmartWardKit.KnowledgeStore (SwiftData m"
Cohesion: 0.18
Nodes (17): Invariant: new models and properties go into LibraryArchive in the same change, Invariant: schema stays CloudKit-compatible (PLAN section 4), DailyBudget (background provider spend cap), Invariant: strength and weight are derived, not stored counters, EncryptedBackup (single-file library backup), Invariant: enum-backed fields store raw String with typed fallback property, KnowledgeSchema.models (schema registry), SmartWardKit.KnowledgeStore (SwiftData models and services) (+9 more)

### Community 136 - "Article (SwiftData model)"
Cohesion: 0.15
Nodes (17): Article (SwiftData model), D1 Day-one onboarding interview, FeedFetcher, FR-0 Onboarding interview, FR-23 Dependency radar, FR-4 Triage by relevance to profile and projects, FR-9 Projects with a living Project Brief, GitHubReleases adapter (+9 more)

### Community 137 - "ThemeNode (SwiftData model)"
Cohesion: 0.19
Nodes (17): B2 Never auto-merge differing version tokens, C2 BYOKLLMKit lacks tool calling and structured output, C7 Explicit Mention join entity replaces many-to-many, Conversation indexing pipeline, Digest pipeline, Entity-resolution eval: false-merge rate under 2%, EntityAlias (SwiftData model), EntityResolver (+9 more)

### Community 138 - "AppNavigation"
Cohesion: 0.15
Nodes (11): NavigationPath, AppNavigation, AppTab, chat, graph, projects, reading, today (+3 more)

### Community 139 - "StreamDelegate"
Cohesion: 0.22
Nodes (12): LinuxStreamedBytes, StreamDelegate, AsyncThrowingStream, CheckedContinuation, Data, Error, URLRequest, URLResponse (+4 more)

### Community 140 - "Coordinator"
Cohesion: 0.18
Nodes (10): Coordinator, GraphVisualizationView, Void, UIViewRepresentable, WKNavigation, WKNavigationDelegate, WKScriptMessage, WKScriptMessageHandler (+2 more)

### Community 141 - "GitHubAccount"
Cohesion: 0.16
Nodes (10): GitHubTokenStore, .fileURL, Bool, URL, GitHubAccount, .client, .hasToken, Bool (+2 more)

### Community 142 - "ReadoutSegment"
Cohesion: 0.24
Nodes (6): ReadoutSegment, ArticleBriefing, SegmentBuilder, Digest, Int, SpokenAnswer

### Community 143 - "Approval Before Actions"
Cohesion: 0.18
Nodes (17): add_source Tool, Add to SmartWard (Share Sheet), App Shell (Tabs, Projects, Settings), Approval Before Actions, Background Refresh (hourly polling, charging, system progress), BYOK Key Settings (bring your own keys), Four Strategist Chat Modes, Daily Budget (switches background work to on-device when spent) (+9 more)

### Community 144 - "Strategist Layer"
Cohesion: 0.20
Nodes (16): BriefService living document watermark, C6 One Strategist with a tool-use loop and modes, Conversation (SwiftData model), ConversationCompactor rolling summary, FR-10 Project-scoped conversations with modes, FR-12 Strategist tool set, Message (SwiftData model), ModeSelector (+8 more)

### Community 145 - "SpeechService"
Cohesion: 0.17
Nodes (8): ObservableObject, SpeechService, AVSpeechSynthesisVoice, AVSpeechSynthesizer, AVSpeechUtterance, Bool, Float, Void

### Community 146 - ".check()"
Cohesion: 0.19
Nodes (6): BoundaryContext, spiritualGuidance, standard, BoundaryDetector, Bool, BoundaryDetectorTests

### Community 147 - "ModelContainer"
Cohesion: 0.18
Nodes (9): ModelContainer, .mainContext, .version, Data, Int, UUID, AppStore, Error (+1 more)

### Community 148 - "BriefingTests"
Cohesion: 0.23
Nodes (6): DigestReadout, BriefingTests, Fixture, Bool, Double, Source

### Community 149 - "ThemeStrengthCache"
Cohesion: 0.26
Nodes (10): Entry, Fingerprint, Date, Double, Int, TimeInterval, UUID, ThemeStrengthCache (+2 more)

### Community 150 - ".read()"
Cohesion: 0.17
Nodes (12): AudioPlaying, CommandAudioPlayer, ReadError, .errorDescription, noArticle, nothingToRead, ReadResult, Bool (+4 more)

### Community 151 - ".check()"
Cohesion: 0.22
Nodes (3): StaticString, UInt, VoiceBriefingCommandTests

### Community 152 - "SmartWard (iOS Application Target)"
Cohesion: 0.23
Nodes (15): App Lock: Face ID with Grace Period, App Lock PIN Fallback, App Switcher Privacy Cover, SmartWard App Icon (product icon image), AppIcon Asset Catalog Name, AppLock (SmartWardKit Library Product), BiometricLockKit (OnDeviceKit Library Product), BYOKLLMKit (OnDeviceKit Library Product) (+7 more)

### Community 153 - "SearchHit"
Cohesion: 0.17
Nodes (11): OptionSet, MatchKind, SearchHit, .id, MatchBadge, .body, SearchController, SearchResultsView (+3 more)

### Community 154 - "LLMKeychainStore"
Cohesion: 0.41
Nodes (3): LLMKeychainStore, Bool, LLMKeychainStoreTests

### Community 155 - "ShareSheet"
Cohesion: 0.16
Nodes (9): GraphViewKitResources, .cytoscapeJSURL, .graphHTMLURL, URL, ShareSheet, Any, Context, UIActivityViewController (+1 more)

### Community 156 - ".score()"
Cohesion: 0.18
Nodes (7): Date, Double, TimeInterval, ThemeStrength, TimeInterval, ThemeStrengthTests, ThemeStrengthCacheTests

### Community 157 - ".plan()"
Cohesion: 0.22
Nodes (10): Plan, Refusal, alreadyFollowed, .errorDescription, invalidAddress, unsafeAddress, unsupportedKind, SourceIntake (+2 more)

### Community 158 - "ModelFallback"
Cohesion: 0.22
Nodes (8): ModelFallback, Bool, Int, ModelFallbackTests, .catalog, Bool, Double, Int

### Community 159 - ".makeFixture()"
Cohesion: 0.30
Nodes (4): ArticleReadoutTests, Fixture, Bool, Int

### Community 160 - ".makeStore()"
Cohesion: 0.28
Nodes (4): FixedJudge, PipelineRunnerTests, Bool, Source

### Community 161 - "OnboardingView"
Cohesion: 0.15
Nodes (12): OnboardingView, .appleIntelligenceStatus, .body, .canStart, .hasUserInput, .links, .providersWithKeys, .welcome (+4 more)

### Community 162 - "SmartWardShare (Share Extension Target)"
Cohesion: 0.22
Nodes (14): App Group Registration (group.com.intelligentdesignsllc.smartward), Share Extension Safari Capture Path, SmartWard/SmartWard.entitlements, App Group Entitlement (shared container app ↔ extension), com.intelligentdesignsllc.smartward Bundle Identifier, Bundle ID Prefix com.intelligentdesignsllc, PLAN FR-3 (Share Extension Requirement), ShareExtension/SmartWardShare.entitlements (+6 more)

### Community 163 - "Prompt-injection defense"
Cohesion: 0.22
Nodes (14): Confirmation chips for side-effecting tools, D4 One-tap GitHub sign-in, PAT advanced, FR-17 Usage and cost ledger with daily cap, GitHub App rejected: needs a token-exchange backend, GitHub option B: fine-grained PAT, GitHub option C: OAuth device flow, Prompt-injection defense, Keychain storage (+6 more)

### Community 164 - "PersistentModel"
Cohesion: 0.23
Nodes (9): Hasher, KnowledgeSchema, .schema, PersistentModel, .shimEntity, Attribute, Entity, Schema (+1 more)

### Community 165 - ".check()"
Cohesion: 0.25
Nodes (4): CrisisDetector, CrisisPattern, Bool, CrisisDetectorTests

### Community 166 - "OpenAITTSEngineTests"
Cohesion: 0.20
Nodes (4): Data, Double, http, OpenAITTSEngineTests

### Community 167 - "VoiceLoopConfig"
Cohesion: 0.23
Nodes (6): Int, Bool, Float, TimeInterval, VoiceLoopConfig, VoiceLoopConfigTests

### Community 168 - "AppLockPolicy"
Cohesion: 0.21
Nodes (6): AppLockPolicy, PINRules, Bool, Date, TimeInterval, AppLockPolicyTests

### Community 169 - "FakeTransport"
Cohesion: 0.23
Nodes (6): FakeTransport, GitHubClientTests, Data, HTTPURLResponse, URLRequest, Reply

### Community 170 - "AppLockController"
Cohesion: 0.18
Nodes (9): ScenePhase, AppLockController, .handsFreeWindow, .isEnabled, .policy, Bool, Date, TimeInterval (+1 more)

### Community 171 - ".score()"
Cohesion: 0.22
Nodes (4): Accelerate, CosineSimilarity, Float, CosineSimilarityTests

### Community 172 - "SmartWard XcodeGen Project Spec"
Cohesion: 0.22
Nodes (13): DEVELOPMENT_TEAM Signing Setup, GitHub OAuth Device Flow Sign-In, iPhone 15 Pro / iOS 26 / Apple Intelligence Device Requirement, One-Time Device Setup, OpenRouter API Key During Onboarding, Apple Intelligence-Capable Device Floor (iPhone 15 Pro+), Automatic Code Sign Style, iOS 26.0 Deployment Target (+5 more)

### Community 173 - "GitHubRepo"
Cohesion: 0.23
Nodes (7): GitHubRepo, .id, Bool, Document, RepoSnapshot, RepoSyncTests, Bool

### Community 174 - ".fallbackLLM()"
Cohesion: 0.21
Nodes (3): project, OnboardingSynthesizer, OnboardingSynthesizerTests

### Community 175 - "SourcesView"
Cohesion: 0.23
Nodes (11): .body, SourceDetailView, SourceRow, SourcesView, .body, .following, .listed, .paused (+3 more)

### Community 176 - "Accessibility Verification Pass"
Cohesion: 0.24
Nodes (12): Accessibility Verification Pass, CI Simulator Test Pipeline, Daily Budget Set to $0.25 Exhaustion Test, Device Testing Strategy, Largest Text Sizes / Dynamic Type Clipping Check, Onboarding Under 5 Minutes (Phase 1 Exit Criterion), Phase 5 Exit Criteria, A Real-Use Pass (+4 more)

### Community 177 - "GraphRAG Latency Budget (NFR-4: p95 unde"
Cohesion: 0.29
Nodes (12): -SmartWardDeveloper YES Launch Argument, Developer Sample Library (100,000 chunks / 3,000 themes / 30,000 connections, ~250 MB), Graph Snapshot Signpost Interval, GraphRAG Latency Budget (NFR-4: p95 under 500 ms at 100k chunks), GraphRAG Signpost Interval, Instruments Points of Interest Profiling, Latency Check (20 chat-style questions, p50/p95 report), Release Build Requirement for Latency Measurement (+4 more)

### Community 179 - "RobotsRules"
Cohesion: 0.26
Nodes (5): RobotsRules, Rule, Bool, RobotsRulesTests, PublicHostTests

### Community 180 - ".projects()"
Cohesion: 0.29
Nodes (5): MarkdownExport, Bool, Date, Int, MarkdownExportTests

### Community 181 - "Refusal"
Cohesion: 0.23
Nodes (9): BriefingGate, Conditions, Refusal, appLocked, lockScreenOff, .message, needsUnlock, Bool (+1 more)

### Community 182 - "LocalModelConfig"
Cohesion: 0.21
Nodes (7): LocalModelConfig, OllamaEmbeddingProvider, Float, Int, URL, Bool, URL

### Community 183 - ".text()"
Cohesion: 0.24
Nodes (5): RunSummary, Bool, Int, TimeInterval, RunSummaryTests

### Community 184 - "StepProgress"
Cohesion: 0.21
Nodes (8): StepProgress, .isDeterminate, .percent, Bool, Int, StepProgressTests, ActivityBar, .body

### Community 185 - ".messages()"
Cohesion: 0.29
Nodes (6): ConversationHistory, Entry, Date, Int, ConversationHistoryTests, TimeInterval

### Community 186 - "SeededRandom"
Cohesion: 0.21
Nodes (7): PerformanceTests, SeededRandom, TimeInterval, UInt64, Void, TopKTests, RandomNumberGenerator

### Community 187 - ".check()"
Cohesion: 0.27
Nodes (3): StaticString, UInt, VoiceHandsFreeCommandTests

### Community 188 - ".start()"
Cohesion: 0.20
Nodes (10): BriefingLauncher, .lockScreenAllowed, Refusal, .errorDescription, gate, libraryUnavailable, nothingUnread, Bool (+2 more)

### Community 189 - "ProjectEntity"
Cohesion: 0.29
Nodes (8): AppEntity, DisplayRepresentation, EntityQuery, ProjectEntity, .displayRepresentation, ProjectQuery, UUID, TypeDisplayRepresentation

### Community 190 - ".canonicalize()"
Cohesion: 0.20
Nodes (7): DateFormatter, ISO8601DateFormatter, CanonicalURL, FeedDate, Set, URL, CanonicalURLTests

### Community 191 - "What the Simulator Can't Show"
Cohesion: 0.31
Nodes (11): Apple Intelligence On-Device Item Triage, Background Work via BGTaskScheduler, On-Device Theme Extraction in Reader, Overnight Processing Digest Notification, com.intelligentdesignsllc.smartward.processing Task Identifier, Shortcuts App Intents (Open digest / Add a source), What the Simulator Can't Show, Siri "Ask SmartWard" Voice Answer (+3 more)

### Community 192 - "Inference Layer"
Cohesion: 0.25
Nodes (11): AppleFMKit, C4 ODK core packages are iOS-only, D3 iPhone 15 Pro minimum device, FR-21 Mac companion with CloudKit sync, Inference Layer, LocalLLMKit dropped from scope, NFR-11 Platform targets and device floor, NFR-1 Offline operation (+3 more)

### Community 193 - "ContextAssembler token budget and fencin"
Cohesion: 0.27
Nodes (11): B3 Extraction routing by content class, BYOKExtractor, ContextAssembler token budget and fencing, D2 Conversations may be extracted by BYOK, D5 Private repos extracted on-device only, EntityExtracting protocol, FoundationModelsExtractor, KnowledgeGraphExtractor not used (therapy vocabulary) (+3 more)

### Community 194 - "CatalogEntry"
Cohesion: 0.33
Nodes (7): Hashable, Architecture, CatalogCacheData, CatalogEntry, CatalogResponse, Date, Int

### Community 195 - "ShimKey"
Cohesion: 0.20
Nodes (6): KeyedEncodingContainer, Encoder, ShimKey, .intValue, Int, T

### Community 196 - "BYOKFileSecretStore"
Cohesion: 0.33
Nodes (5): BYOKFileSecretStore, .directory, Bool, Data, URL

### Community 197 - ".parseSSELine()"
Cohesion: 0.27
Nodes (4): SSEEvent, delta, ignore, SSEParsingTests

### Community 198 - "KeychainLockoutStore"
Cohesion: 0.40
Nodes (4): KeychainLockoutStore, State, Double, Int

### Community 199 - "TTSError"
Cohesion: 0.18
Nodes (9): Data, Int, TTSError, decodeFailed, emptyAudio, .errorDescription, http, missingKey (+1 more)

### Community 200 - "GitHubError"
Cohesion: 0.20
Nodes (10): GitHubError, .errorDescription, http, invalidResponse, notFound, rateLimited, unauthorized, Date (+2 more)

### Community 201 - ".apply()"
Cohesion: 0.31
Nodes (5): ApplyResult, RepoSync, Date, Int, Source

### Community 202 - "Anchor"
Cohesion: 0.18
Nodes (10): Anchor, details, note, paragraph, relevance, summary, themes, title (+2 more)

### Community 203 - "DeveloperView"
Cohesion: 0.31
Nodes (6): DeveloperSettings, .isEnabled, DeveloperView, .body, Bool, Double

### Community 204 - "ModelCatalogController"
Cohesion: 0.24
Nodes (6): FallbackModelsRow, .body, ModelCatalogController, .fallback, Bool, Date

### Community 205 - "AppLockTests.swift"
Cohesion: 0.27
Nodes (4): AppLock, BiometricLockKit, PINRulesTests, PINLockKit

### Community 207 - "TopK"
Cohesion: 0.40
Nodes (4): Bool, Element, Int, TopK

### Community 208 - "TopKTests"
Cohesion: 0.20
Nodes (3): Bool, Int, TopKTests

### Community 209 - "ArticleStage"
Cohesion: 0.20
Nodes (10): .stage, ArticleStage, cleaned, embedded, extracted, failed, fetched, linked (+2 more)

### Community 210 - "TopK"
Cohesion: 0.40
Nodes (4): Bool, Element, Int, TopK

### Community 211 - ".check()"
Cohesion: 0.31
Nodes (3): BriefingGateTests, Bool, TimeInterval

### Community 212 - "FakeEmbedder"
Cohesion: 0.33
Nodes (4): FakeEmbedder, .dimension, Int, HybridSearchTests

### Community 213 - ".check()"
Cohesion: 0.33
Nodes (3): StaticString, UInt, VoiceFindCommandTests

### Community 214 - "StrategistCore (tool loop, prompts, brie"
Cohesion: 0.31
Nodes (9): Invariant: network or durable-state tools must return an ActionRequest, ActionRequest (confirmation(for:) contract), OnDeviceKit BYOKLLMKit, ModelFallback (FallbackLLM over ModelCatalogKit), StrategistCore (tool loop, prompts, brief, fallback), StrategistRunner (tool-calling loop), Invariant: every strategist turn must end (toolChoice none, errors as results), Cost Controls (Settings to Usage and budget) (+1 more)

### Community 215 - "Packages/SmartWardKit (local SPM package"
Cohesion: 0.25
Nodes (9): AppLock module (AppLockPolicy, AppLockCoordinator, PINRules), OnDeviceKit BiometricLockKit, GitNexus code intelligence (impact before edit, detect-changes before commit), Logic-in-Package Convention (swift test without a simulator), OnDeviceKit PINLockKit, ShareExtension/ (never opens the SwiftData store), ShareInbox (App Group JSON inbox, dependency-free), SmartWard/ (SwiftUI iOS app) (+1 more)

### Community 216 - "SmartWardKit (Local Swift Package)"
Cohesion: 0.31
Nodes (9): Background Extraction Stays On-Device Until Midnight, JSON / GraphML / Markdown Export Formats, Private Local Address Rejection (192.168.1.1), Wipe to Restore Backup Test, IngestKit (SmartWardKit Library Product), KnowledgeStore (SmartWardKit Library Product), Pipeline (SmartWardKit Library Product), SmartWardKit (Local Swift Package) (+1 more)

### Community 217 - "NLEmbeddingProvider"
Cohesion: 0.22
Nodes (6): NLEmbedding, NLLanguage, NLEmbeddingProvider, .dimension, Float, Int

### Community 218 - "BiometryType"
Cohesion: 0.22
Nodes (6): BiometryType, .displayName, faceID, none, opticID, touchID

### Community 219 - ".allowsRedirect()"
Cohesion: 0.28
Nodes (6): PublicHost, Bool, HTTPURLResponse, URL, URLRequest, URLSessionTask

### Community 221 - "SourceKindOption"
Cohesion: 0.25
Nodes (8): AppEnum, SourceKindOption, arxiv, feed, githubReleases, hackerNews, .kind, webPage

### Community 222 - "NSObject"
Cohesion: 0.29
Nodes (7): NSObject, Error, XMLParser, XMLParserRecorder, RedirectPolicy, URLSessionTaskDelegate, XMLParserDelegate

### Community 225 - "ArchiveError"
Cohesion: 0.25
Nodes (6): ArchiveError, .errorDescription, newerVersion, notAnArchive, Data, Int

### Community 226 - "FetchDescriptor"
Cohesion: 0.36
Nodes (6): FetchDescriptor, Int, Predicate, T, PartialKeyPath, SortDescriptor

### Community 227 - "Why"
Cohesion: 0.25
Nodes (8): Bool, Why, connected, .description, direct, fetched, .isGraphHop, named

### Community 228 - "Graph View"
Cohesion: 0.25
Nodes (8): Alias + Embedding Similarity Name Resolution, Chunk-level Citations for Mentions and Edges, Entity and Relation Extraction, Extraction and Entity Resolution, Graph View, Theme Rename/Merge/Split (user corrections win), Theme Scopes (all, two weeks, project, source), Uncertain Merge Review Queue

### Community 229 - "UntrustedText (body/attribute inside its"
Cohesion: 0.43
Nodes (7): RedTeamTests (zero unapproved side effects), Invariant: untrusted text only through UntrustedText inside its fence, UntrustedText (body/attribute inside its fence), Poisoned Article Corpus, Private-Content Policy (private repos stay on-device), Uniform Prompt Fence Escaping, Red-team Suite

### Community 231 - ".audioPlayerDidFinishPlaying()"
Cohesion: 0.29
Nodes (5): done, AVAudioPlayer, Bool, AVAudioPlayer, Bool

### Community 234 - ".graphML()"
Cohesion: 0.48
Nodes (4): GraphExport, Date, LibraryArchive, GraphExportTests

### Community 235 - ".documents()"
Cohesion: 0.43
Nodes (3): IncrementalIndexTests, Int, Range

### Community 236 - "ActivitySheet"
Cohesion: 0.38
Nodes (5): ActivitySheet, Any, Context, UIActivityViewController, UIViewControllerRepresentable

### Community 237 - "Living Project Brief"
Cohesion: 0.53
Nodes (6): Invariant: brief text changes only through BriefEditing, BriefDiff (line diff of brief changes), BriefEditing (only path that changes brief text), Brief Line Diff (accept or reject), Living Project Brief, Suggest an Update

### Community 238 - "RepoSync.swift"
Cohesion: 0.47
Nodes (3): CommonCrypto, Crypto, CryptoKit

### Community 240 - "TTSError"
Cohesion: 0.33
Nodes (6): Int, TTSError, decodeFailed, emptyAudio, .errorDescription, missingKey

### Community 241 - "Chunk (SwiftData model)"
Cohesion: 0.80
Nodes (5): C5 Store vectors as binary Data, not JSON snapshots, Chunk (SwiftData model), Phase 0 embedding bake-off, FR-5 Chunk and embed on-device with model version, RetrievalKit

### Community 242 - "DecisionProviding protocol seam"
Cohesion: 0.50
Nodes (5): DecisionKit proposed ODK module, DecisionProviding protocol seam, Jev typed decision models, LangChain - What Is Jev?, T0 heuristics and embeddings

### Community 244 - "Status"
Cohesion: 0.40
Nodes (5): Status, finished, idle, paused, playing

### Community 245 - "VoiceSpeedChange"
Cohesion: 0.40
Nodes (4): VoiceSpeedChange, faster, normal, slower

### Community 246 - "Apple Intelligence Preflight"
Cohesion: 0.40
Nodes (5): Apple Intelligence Preflight, Build and Package Test Commands, Onboarding Interview, Requirements (Xcode 26+, iOS 26+, iPhone 15 Pro+), XcodeGen (project.yml, generated xcodeproj)

### Community 247 - "Phase"
Cohesion: 0.40
Nodes (5): Phase, listening, off, starting, unavailable

### Community 248 - "VoiceReadingFilter"
Cohesion: 0.50
Nodes (4): VoiceReadingFilter, all, starred, unread

### Community 250 - ".send()"
Cohesion: 0.50
Nodes (3): Data, HTTPURLResponse, URLRequest

### Community 252 - "VoiceReadingOrder"
Cohesion: 0.67
Nodes (3): VoiceReadingOrder, mostRelevant, newest

## Ambiguous Edges - Review These
- `Scale Performance Tests (100k chunks, 3k themes)` → `Device Measurement (Instruments signposts)`  [AMBIGUOUS]
  README.md · relation: conceptually_related_to

## Knowledge Gaps
- **685 isolated node(s):** `unlocked`, `denied`, `AgentRouteKit`, `toolUse`, `auto` (+680 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1289 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Scale Performance Tests (100k chunks, 3k themes)` and `Device Measurement (Instruments signposts)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `String` connect `String` to `View`, `LLMResponse`, `JSONValue`, `AnalyzerCommandRecognizer`, `RetrievedPassage`, `ThemeNode`, `KnowledgeStore`, `.save()`, `GraphIndexer`, `ArticleSummary`, `Project`, `Conversation`, `DigestBuilder`, `.outcome()`, `ModelContext`, `SharedInbox`, `ArticleReadoutController`, `Plugin.swift`, `VoiceCommandParser`, `VoiceCommand`, `Retriever`, `.makeContainer()`, `LLMRequest`, `.run()`, `OllamaClient`, `PipelineController`, `VoiceAnswersTests`, `IngestError`, `LocalizedError`, `.refresh()`, `BiometricService`, `LLMCompleting`, `.record()`, `Sendable`, `LLMProvider`, `Article`, `PINService`, `StrategistRunner`, `AppLockCoordinator`, `Identifiable`, `FallbackLLM`, `ShimObjectState`, `LLMService`, `ScoredChunk`, `VectorIndex`, `ActionRequest`, `OnboardingProposal`, `HybridRetriever`, `VoiceConversationController`, `ExtractedGraph`, `LibraryFixture`, `StrategyItemKind`, `BackupView`, `XCTestCase`, `EmbeddingModel`, `CaseIterable`, `SQLiteDatabase`, `RawItem`, `SourceKind`, `.extract()`, `GitHubDeviceFlow`, `PerfTrace`, `LocalLLMEngine`, `BiometricUnavailable`, `EchoHandler`, `Library`, `ExtractedArticle`, `ShimRelationship`, `InterestModel`, `VoiceIntentTests`, `SmartWardEngine`, `BiometricEvaluation`, `WireModels.swift`, `EntityChunkIndex`, `GitHubDeviceCode`, `FileCache`, `SelectionPolicy`, `GitHubClient`, `Choice`, `AskStrategistIntent`, `OpenAITTSEngine`, `.segments()`, `.analyze()`, `PINAttemptResult`, `ElevenLabsTTSEngine`, `SourceFetcher`, `.outcome()`, `VoiceCommandTests`, `.items()`, `LLMCompletionError`, `ConversationView`, `Dependency`, `IngestController`, `.fromPastedURL()`, `LocalAIError`, `.matches()`, `Parent`, `CodingKeys`, `VoiceTranscriptTests`, `HTTPTransport`, `DigestCluster`, `HybridSearchIndex`, `.load()`, `VoiceConfirmationGate`, `GraphRetriever`, `ConversationMode`, `.synthesize()`, `.check()`, `.fetch()`, `VoiceSpeaker`, `.body`, `.consume()`, `ContextAssembler`, `LexicalIndex`, `SearchDocument`, `ProjectArticlesTests`, `StreamDelegate`, `Coordinator`, `GitHubAccount`, `ReadoutSegment`, `SpeechService`, `.check()`, `ModelContainer`, `BriefingTests`, `ThemeStrengthCache`, `.read()`, `.check()`, `SearchHit`, `LLMKeychainStore`, `.plan()`, `ModelFallback`, `.makeFixture()`, `.makeStore()`, `OnboardingView`, `PersistentModel`, `.check()`, `OpenAITTSEngineTests`, `VoiceLoopConfig`, `AppLockPolicy`, `AppLockController`, `GitHubRepo`, `.fallbackLLM()`, `PINLockoutTests`, `RobotsRules`, `.projects()`, `Refusal`, `LocalModelConfig`, `.text()`, `StepProgress`, `.messages()`, `SeededRandom`, `.check()`, `.start()`, `ProjectEntity`, `.canonicalize()`, `CatalogEntry`, `ShimKey`, `BYOKFileSecretStore`, `.parseSSELine()`, `KeychainLockoutStore`, `TTSError`, `GitHubError`, `.apply()`, `DeveloperView`, `ModelCatalogController`, `ArticleStage`, `.check()`, `NLEmbeddingProvider`, `BiometryType`, `.allowsRedirect()`, `.seededEngine()`, `SourceKindOption`, `ElevenLabsTTSEngineTests`, `ArchiveError`, `Why`, `KeychainDomainStateStore`, `.speakableText()`, `.graphML()`, `TTSError`, `Phase`, `TriageScore`, `.init()`?**
  _High betweenness centrality (0.515) - this node is a cross-community bridge._
- **Why does `ModelContext` connect `ModelContext` to `View`, `JSONValue`, `RetrievedPassage`, `ThemeNode`, `SearchDocument`, `.save()`, `GraphIndexer`, `ArticleSummary`, `ProjectArticlesTests`, `Conversation`, `DigestBuilder`, `.outcome()`, `SharedInbox`, `String`, `ModelContainer`, `BriefingTests`, `ThemeStrengthCache`, `.makeContainer()`, `SearchHit`, `.run()`, `.score()`, `.plan()`, `VoiceAnswersTests`, `PipelineController`, `.makeStore()`, `.refresh()`, `.record()`, `Sendable`, `ShimObjectState`, `ActionRequest`, `.projects()`, `OnboardingProposal`, `LibraryFixture`, `EmbeddingModel`, `RawItem`, `.apply()`, `ExtractedArticle`, `InterestModel`, `SmartWardEngine`, `AskStrategistIntent`, `makeContext()`, `.fromPastedURL()`, `LocalAIError`, `.matches()`, `Parent`, `.load()`?**
  _High betweenness centrality (0.034) - this node is a cross-community bridge._
- **Why does `Foundation` connect `Foundation` to `LLMResponse`, `JSONValue`, `.consume()`, `ContextAssembler`, `LexicalIndex`, `KnowledgeStore`, `SearchDocument`, `ArticleSummary`, `StreamDelegate`, `Conversation`, `GitHubAccount`, `DigestBuilder`, `ModelContext`, `SharedInbox`, `.outcome()`, `.check()`, `ModelContainer`, `String`, `VoiceCommandParser`, `Plugin.swift`, `Retriever`, `ShareSheet`, `.score()`, `OllamaClient`, `BYOKLLMKit`, `BiometricService`, `PersistentModel`, `.check()`, `XCTest`, `LLMProvider`, `VoiceLoopConfig`, `PINService`, `.score()`, `Identifiable`, `FallbackLLM`, `AppLockCoordinator`, `ShimObjectState`, `ScoredChunk`, `VectorIndex`, `Refusal`, `HybridRetriever`, `.text()`, `StepProgress`, `.canonicalize()`, `SQLiteDatabase`, `CatalogEntry`, `.extract()`, `BYOKFileSecretStore`, `PerfTrace`, `BiometricUnavailable`, `EchoHandler`, `ShimRelationship`, `AppLockTests.swift`, `BiometricEvaluation`, `WireModels.swift`, `EntityChunkIndex`, `TopK`, `TopK`, `FileCache`, `SelectionPolicy`, `BiometryType`, `.segments()`, `.analyze()`, `PINAttemptResult`, `makeContext()`, `FetchDescriptor`, `.outcome()`, `AVFoundation`, `KeychainDomainStateStore`, `.items()`, `Dependency`, `IngestController`, `RepoSync.swift`, `Parent`, `RetrievalKit`, `GraphRetriever`?**
  _High betweenness centrality (0.025) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `ModelContext` (e.g. with `.external()` and `.testSecondContextSeesSavedChangesAndEdits()`) actually correct?**
  _`ModelContext` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `unlocked`, `denied`, `AgentRouteKit` to the rest of the system?**
  _685 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `View` be split into smaller, more focused modules?**
  _Cohesion score 0.033516483516483515 - nodes in this community are weakly interconnected._