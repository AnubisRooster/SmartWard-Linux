<img src="images/app-icon.png" alt="SmartWard icon" width="96" height="96">

# SmartWard for iPhone

> This is the original iOS app README, kept for the app in `SmartWard/`. For the Linux tool, see the [top-level README](../README.md).

A local-first iPhone research strategist. SmartWard reads the AI and software-development world for you, keeps an on-device knowledge graph that links what you read with what you've discussed, and brainstorms your projects with the LLMs you bring your own keys for.

- **Plan & design:** [docs/PLAN.md](PLAN.md) covers requirements, the architecture and the data model.
- **Shared components:** [OnDeviceKit](https://github.com/AnubisRooster/OnDeviceKit), including BYOK LLM access, retrieval, the graph, and app lock.

## Screenshots

_Coming with the first on-device pass (see [docs/DEVICE_TESTING.md](DEVICE_TESTING.md)) — CI only runs on the Simulator, so there are no real screens to show yet. Once captured, they'll go in `docs/images/` and get linked here._

## Features

### Sources and reading

RSS/Atom feeds (with feed discovery from a blog's home page), arXiv categories or searches, Hugging Face daily papers, Hacker News searches, GitHub releases, and watched web pages. Every request is rate-limited per host, backs off on 429/503, uses conditional GET, and checks robots.txt for web pages. Articles are deduped across sources and cleaned of hidden text. The Reading tab has a reader view, sorts newest by actual publish date so several blogs interleave correctly, and dependency-radar suggestions can be followed with one tap. "Add to SmartWard" works from any app's share sheet, optionally tagged to a project.

Background polling (roughly hourly by default) and backlog processing while charging keep the library current without opening the app; Settings → Background refresh lets you nudge how soon the next check is allowed to run (iOS still decides the actual time from its own budget) or trigger one immediately. A manual Refresh from the Reading tab does the same on demand, and keeps going with system progress if you leave the app. If iOS ends a run early, Settings → Background refresh says how far it got and how many articles are still waiting to be indexed (the Reading tab shows that count too); the rest carries on at the next run.

New items go through a resumable stage machine that triages them on-device against your interests, projects, dependencies and reading history (Apple Foundation Models decides borderline items), fetches full text for relevant teasers, then chunks and embeds them on-device. Off-topic items stay searchable but are hidden from Unread. Each article opens with a five-question summary (what it's about, what it says, what supports it, why it matters, what to remember), one or two short bullets each. It's written as each new article is indexed, so it's ready when you open it: on-device with Apple Intelligence, or by your provider only when Apple Intelligence is off and the daily budget allows (private items never leave the device). Off-topic items, articles older than a week and linked-repo docs are summarized the first time you open them, and the summary is redone when an article's text changes. On-device summaries run with Apple's permissive content-transformation guardrails (the level meant for summarizing text you were given), because the default level turns down plenty of harmless articles as "likely to be unsafe"; the model answers in plain text that SmartWard reads back into bullets. If the on-device model still declines or comes back empty, your provider gets a turn where the routing allows it, and private items never do. Each card shows its relevance as a percentage at the bottom right once triage has scored it (scores from on-device embeddings run modest, so around 30% is already a match; the filter's thresholds are 22% balanced and 32% strict), and "Most relevant" sorts by it. While sources refresh or articles index, a bar under the Unread / Starred / All picker shows the percentage complete of the current step. When a source can't be refreshed, the Reading tab names it and opens Sources, where each failure says what went wrong and what to try (a moved feed, a slow site, a redirect to somewhere SmartWard won't follow). Any article can be read aloud, top to bottom in the order the screen shows it (title, source and date, the summary, themes, relevance, then the text a paragraph at a time), or just its summary: tap the speaker in the reader, or press and hold it for the choice. There's pause and keep going, skip and back, the screen scrolls to follow along, and headphone buttons work too. It uses the system voice only, so article text never leaves the device, and it stops when you leave the article, the app goes to the background or it locks. Turn on Settings → Voice navigation and you can drive the app by voice: say "SmartWard" and then what you want ("SmartWard, open Reading", "SmartWard, show starred", "SmartWard, open the second one", "SmartWard, open the article about agents", "SmartWard, open project inference stack", "SmartWard, read this article", "SmartWard, star this", "SmartWard, refresh", "SmartWard, go back", "SmartWard, what can I say?"). For when you can't look at the screen, "SmartWard, brief me" (or "read my news", "catch me up"; Siri's "Brief me with SmartWard" opens the app and does the same) reads your top unread articles most-relevant first: each one's number, title and source, then a two-line gist (from its summary, or the start of its teaser), and it keeps the screen awake while it does. It also works with the phone locked or in the car: "Hey Siri, brief me with SmartWard" (a Siri and Shortcuts action, also usable from CarPlay's Siri) starts one in the background, and next, previous and pause then come from Siri ("next"), headphones, the steering wheel and the lock screen's Now Playing controls. That's the one thing SmartWard reads out loud in the background (the system voice only; the microphone still listens only while the app is open), and Settings → Briefings → From the lock screen turns it off. With SmartWard's own lock on it only starts while SmartWard is unlocked and stops when the lock-after time is up. (A CarPlay app screen would need Apple's CarPlay audio entitlement, which SmartWard doesn't have.) An article heard to its end is marked read; one you skip stays unread. "SmartWard, read today's digest" reads the digest a theme at a time. During a briefing "next", "previous", "repeat", "tell me more" (the whole article instead of the gist), "star it", "dismiss" (mark read and move on), "mark as unread", "load the full article", "faster", "slower" and "normal speed" work with no wake word, as do "pause", "keep going" and "stop reading" while anything is being read. To find things: "SmartWard, search for speculative decoding" runs the Reading tab's search, says how many it found and the top three titles, and "open the first one" opens a result. "SmartWard, ask the strategist what changed in inference this week" asks your provider (it uses tokens, counts against the daily budget, and is saved as a chat) and reads the answer aloud, shortened for the ear, with pause, keep going and stop working on it. Quick questions get spoken answers: "how many unread articles do I have?", "did the refresh finish?", "which sources are failing?", "how much have I spent today?", "what are my top themes?" and "tell me about vLLM" (what the graph knows: its type, how many articles, which projects pin it, the latest article). With a project's card open: "read the brief", "what are my open items?" (numbered), "brief me on this project" (a briefing of its related reading), and "read the suggested update" (why, and how many lines it adds and removes). Anything that changes a project needs a spoken yes first: "mark item two done", "accept the suggested update" and "reject the suggested update" each read back what they'd do and end "Say yes or no"; "yes" (or "no") needs no wake word for the next 20 seconds, anything else drops the question, and nothing changes without the yes. Hands-free (on by default) drops the wake word while SmartWard is open: just say "read the first article", "show starred", "brief me". While something is being read aloud only the reading controls work on their own, since the app's own voice is in the room; start with "SmartWard" for anything else then. With smart understanding on (Settings → Voice navigation), words the phrase list doesn't know ("skip this one and read the next", "what's in the second one", "go to my projects and open the home lab one") are worked out by your provider, the model you last chatted with: what you said, the titles in the list on screen and your project names are sent to it, it costs a little (counted in Usage), and if it can't answer Apple Intelligence on the device does instead. It can only choose actions SmartWard already has, at most three at a time; it can't say yes for you, it asks the strategist a question only when you asked for one, and a project change still waits for your spoken yes. When neither understands, SmartWard says "Sorry, I didn't get that." Settings → Voice navigation → Speech engine offers Apple's newer on-device speech engine (SpeechAnalyzer, iOS 26) as a beta: it may recognize names and technical words better, runs the same way (a phrase ends at a pause, on-device, foreground only), downloads the English speech model from Apple the first time, and falls back to the standard engine if it can't start. It listens only while the app is open and unlocked, never in the background, and speech is turned into words on the device with no server fallback; it says back what it did unless you turn that off. Headphones work best, so it doesn't hear its own voice.

### Reading voice and profiles

Settings → Voice conversation picks the system voice and speaking rate (Premium and Enhanced voices are listed first and labelled; download them in the iOS Settings app under Accessibility → Spoken Content → Voices for a much more natural sound). Settings → Read aloud adds reading profiles: a named voice, rate and whether the speaker button reads the whole article or only the summary, with a Listen button to hear one. One profile can be in use; with none, the Voice conversation settings apply. Voices are the system's only.

### Search

Keyword (BM25, with compound tokens like "SWE-bench" kept whole) and semantic search fused per article, on-device, from the Reading tab's search field. Off-topic items are included. Semantic search is one matrix-vector product over unit-length vectors, and BM25 keeps a running document-length total rather than re-summing it; both keep their top results in a bounded heap instead of sorting every candidate. The index updates in place as articles are added or removed, rebuilding from scratch only when too much has changed at once.

### Knowledge graph

Entities and relations are extracted from articles, conversation turns and public repo docs by your provider (one call per article, counted in Usage and kept within the daily budget, several at a time), with Apple Intelligence on the device as the fallback when the provider fails or the budget is spent; private content and off-the-record chats stay on-device. On-device extraction answers in plain text under Apple's relaxed guardrails, since the default ones decline plenty of harmless articles. An article whose extraction fails in two runs is left out of the graph (it stays readable and searchable) instead of being retried forever, and while the app is open indexing keeps going in short runs (Settings → Background refresh shows what's not yet searchable, what's waiting for the graph and what was left out). Names resolve to one node through aliases and embedding similarity, with uncertain merges queued for review. Mentions and edges cite the chunk they came from, and the reader shows each article's themes.

The Graph tab shows the strongest themes by scope — all, the last two weeks, a project, or a source — with dormant themes hidden unless you ask; it switches to a list automatically with VoiceOver. Theme detail shows strength, names, connections and where each theme came up, with rename, merge and split (your corrections always win). Theme strengths are cached between visits and rescaled for decay rather than recomputed.

GraphRAG gives each chat turn passages from your library, found by words, by meaning, or by one hop through the graph, fenced as untrusted and cited as [R1]. The strategist can also search the library, explore a theme's connections, and open an item; each reply lists its sources and why each was retrieved.

### Strategist chat and projects

Streaming BYOK chat with four modes — brainstorm, critique, research plan, and weekly review — scoped to a project, where the strategist can read project state and record decisions and open questions. Onboarding runs the same chat as a guided interview: a key and Apple Intelligence preflight, pasted links, and a structured setup proposal you edit before anything is created.

The strategist can propose a revised project brief mid-chat, and "Suggest an update" drafts one from what's been decided since the last revision. Each suggestion is a line diff you accept or reject, your own edits apply at once, and every accepted change is kept in a history you can restore from. Open decisions, questions and action items are listed on the project, and you can swipe to close them. A "Related reading" section lists the Reading articles that pertain to the project, each with the reason it's there (shared to the project, covers themes tied to it, or names one of its pinned tools) and opening in the reader. It's worked out from the graph each time the card opens, so nothing extra is stored and it follows merges and new pins.

A project can link to plain URLs and GitHub repos (each editable after the fact — tap a link to fix a typo or repoint it), pulled in through one-tap GitHub device-flow sign-in or a token as the advanced option. Repo links sync their docs and manifests read-only, and their dependencies feed the dependency radar.

Tap the mic in any chat to talk instead of type. Your turn ends on a natural pause (or say "send"), the reply is read back in a few spoken sentences — citations, links, code and tables stay on screen, long replies stop with "the rest is on screen", and Skip cuts one short — then the mic re-opens for the next turn. Speech is transcribed on-device where possible and always in off-the-record chats, where voice mode won't start if it can't be. Since nobody can tap an approval card hands-free, voice mode needs "Approve fetches and new sources automatically" (the prompt to turn it on says it applies to every chat), and saving decisions or open items is left for typed chats. A failed turn is announced and stops listening, and voice stops when the app leaves the foreground, locks, or is interrupted by a call. Voice, speaking rate and pause length are in Settings → Voice conversation.

### Actions and approval

The strategist can read a public web page (`fetch_url`) or follow a new source (`add_source`), but each one pauses on a card showing exactly what it will do, and runs only if you tap Approve. Each mode gets its own tools: critique can read pages but not add sources, weekly review sticks to your library and projects, and onboarding uses none. Settings → "Approve fetches and new sources automatically" lets those two tools run without a card every time, still logged as auto-approved — saving a decision or open item to a project always asks regardless, since that changes what a project remembers rather than just what gets read. A page the strategist reads with your approval is saved as a real article too, under its own "Read in chat" source, so it's chunked, embedded and linked into the graph like anything else you read, not just used for that one reply.

Untrusted text (article content, titles, theme names, fetched pages) only ever reaches a prompt inside a fence it can't close. A red-team suite of poisoned articles checks this against a model that obeys every injected instruction: direct orders, fence breaks in any case or spacing, fake system turns, exfiltration through URLs, requests to cloud metadata and local hosts, credentials in URLs, planted decisions, brief rewrites, guessed private document ids, poisoned titles and theme names, and floods of tool calls. None of them adds, fetches or records anything without your approval, changes the brief, or gets private content to the provider.

### Cost controls

Settings → Usage & budget shows what your provider cost today and over 7 or 30 days, by feature and by model. When a provider doesn't report cost, it's estimated from OpenRouter catalog prices, or high on purpose for unknown models. A daily budget ($1 by default) switches background work to on-device once it's spent. When a model is rate-limited or down, requests retry on your fallback models, then on OpenRouter catalog models that support the same features and cost no more.

### Daily digest

The Today tab gathers articles linked since the last digest into theme clusters. Themes that show up in most new articles don't glue everything together. Clusters are ranked by how much they touch your active projects, how new their themes are, and how many articles they cover. The top three are summarized by your provider while the budget allows and without private content; the rest on-device. An optional notification says when a digest is ready.

### Privacy and security

Private-repo content never leaves the device, whichever provider you've pointed the strategist at, and SmartWard never writes back to GitHub — repo links are read-only. A chat you start off the record still talks to your provider, but its turns are added to the knowledge graph on-device only and are never quoted into other chats. App lock covers the whole app, including any sheet left open, with Face ID/Touch ID and a PIN fallback, locking on launch and after a background grace period, with a privacy cover in the app switcher.

### Export and backup

Settings → Export shares your library as versioned JSON (every table, relationships as ids, deterministic), the knowledge graph as GraphML (through OnDeviceKit's GraphKit) for Gephi or yEd, and projects as Markdown (goal, brief, decisions, open questions, action items and the brief's history). Private-repo content, links to private repos and themes found only there are left out unless you include them.

Settings → Backup & restore writes the whole library, including private-repo content and embeddings, as one file. It's compressed and encrypted with AES-GCM, using a key derived from your passphrase with PBKDF2-SHA256 (600,000 rounds). Restoring erases the library and recreates every row, field and relationship exactly. A wrong passphrase or a damaged file never restores anything. API keys, your GitHub sign-in and settings stay out of the file.

### Siri and Shortcuts

"Ask SmartWard" answers from your library and saves the chat. Actions that would need your approval are declined, and with the app lock on, Siri says where the answer is instead of reading it out. "Open my SmartWard digest" opens Today, and "Add a source to SmartWard" follows a feed, arXiv search, Hacker News search, GitHub releases or a web page, validated like the strategist's `add_source`.

### Accessibility

The graph can be shown as a list, and switches to it automatically with VoiceOver. An empty scope explains itself and offers to show every theme. Chat messages are announced by speaker; a new chat says what its mode is for, and warns before you type if the provider has no key. The reading list announces unread and starred items, and strategy items announce their kind. The budget bar reads as an amount of the cap, the lock screen icons scale with text size, and the reader explains when only a headline was saved.

### Performance

GraphRAG, `graph_neighbors` and the graph view fetch only the themes and edges they need, through stored theme keys, instead of the whole graph. Building the search index fetches chunks with their articles in one go. A 100,000-chunk search test and a 3,000-theme, 30,000-edge graph test print their timings to CI.

A developer screen (Settings → Developer, Debug builds or a Release build with a launch flag) can load a marked, removable 100,000-chunk sample library and run a GraphRAG latency check against a 500 ms target, with timings visible as signposts in Instruments — see [docs/DEVICE_TESTING.md](DEVICE_TESTING.md).

## Requirements

- Xcode 26+ and iOS 26+, on an iPhone 15 Pro or newer (Apple Intelligence-capable)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Build

```sh
brew install xcodegen
xcodegen generate          # SmartWard.xcodeproj is generated, not committed
open SmartWard.xcodeproj
```

Package tests run without the app, on the iOS Simulator:

```sh
cd Packages/SmartWardKit
xcodebuild test -scheme SmartWardKit-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
