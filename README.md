# SmartWard for Linux

A local-first research strategist for your Linux laptop. SmartWard follows the feeds, papers and repos you care about, keeps a searchable library with an on-device knowledge graph, and answers questions from what you've read. Everything runs on your machine: models come from a local [Ollama](https://ollama.com) server, and nothing is sent to a cloud service.

This is a Linux fork of [SmartWard](https://github.com/AnubisRooster/SmartWard), originally an iPhone app built on Apple Intelligence. The shared logic lives in `Packages/SmartWardKit`; the Linux tool is a command-line program, `smartward`. The iPhone app is still in this tree ([docs/IOS_APP.md](docs/IOS_APP.md)).

> **Status: experimental.** The command-line tool works end to end, but there is no GUI yet and indexing is slow on a CPU-only machine (see [Performance](#performance)).

## What it does

| Command | |
|---|---|
| `smartward add <kind> <address>` | Follow a source: `rss`, `site`, `arxiv`, `hn`, `github-releases` or `hf-papers`. |
| `smartward sources` | List what you follow and when each source was last fetched. |
| `smartward ingest` | Fetch your sources, then index what's new: triage, full text, embeddings, knowledge-graph extraction and a five-question summary per article. `--minutes N` bounds the run (default 10); run it again to continue. `--skip-fetch` only indexes, `--fetch-only` only fetches. |
| `smartward search <words>` | Keyword and semantic search over everything you've ingested. Falls back to keywords if no embedding model is available. |
| `smartward ask <question>` | Answers from your library with numbered citations (`[R1]`), using passages found by words, meaning and one hop through the knowledge graph. |
| `smartward digest` | What's new since the last digest, grouped by theme. Needs articles that have been linked into the graph. |
| `smartward read [words]` | Read an article aloud with a local voice (the best match for your words, or the newest article). Uses your default profile or voice; `--profile NAME`, `--voice`, `--speed` and `--summary` override it, and `--out file.wav --no-play` saves it. Needs a local speech server, see [tools/kokoro-server](tools/kokoro-server/README.md). |
| `smartward settings` | Opens a Settings page in your browser (served on 127.0.0.1 only): pick the voice with a Listen button, set the speed, manage reading profiles, and choose the models. The same choices are available as `smartward voices`, `voice use`, `voice sample` and `profile list/set/remove/use`, and are stored in `~/.config/smartward/config.json`. |
| `smartward status` | Library counts, the indexing backlog, and which models are available. |

All commands accept `--store <file>`, `--config <file>`, `--chat-model`, `--embed-model` and `--ollama-url`; the model options override Settings.

## Requirements

- Linux with a Swift 6 toolchain (developed with 6.4.1 via [swiftly](https://www.swift.org/install/linux/)); run swiftly's suggested `apt-get` line for your distribution.
- `libsqlite3-dev` and `pkg-config`.
- [Ollama](https://ollama.com), running, with a chat model and an embedding model:

  ```bash
  ollama pull llama3.2:3b
  ollama pull nomic-embed-text
  ```

## Quick start

```bash
cd Packages/SmartWardKit
swift build --product smartward
export PATH="$PWD/.build/debug:$PATH"

smartward add rss https://huggingface.co/blog/feed.xml --title "Hugging Face blog"
smartward ingest --minutes 10
smartward search "speculative decoding"
smartward ask "What changed in open models this month?"
```

The library is stored in `~/.local/share/smartward/default.store` (under `$XDG_DATA_HOME` if set). API keys and the GitHub token, where used, are kept in 0600 files in the same directory tree, because Linux has no Keychain.

## Privacy

- The model server must be on this machine: SmartWard refuses any Ollama address that isn't loopback, so private content can't be sent elsewhere by a mis-set URL.
- Feeds are fetched politely: per-host rate limits, backoff, `robots.txt` for web pages, and redirects only to public hosts.
- Article text is treated as untrusted. It only reaches a prompt inside a fence it can't close, and a red-team test suite keeps that honest.
- The Linux tool doesn't use a cloud provider at all.

## Performance

Measured on an 8-core CPU-only machine with `llama3.2:3b` and `nomic-embed-text`:

- Search takes well under a second.
- Embedding runs at a few articles a minute, and graph extraction and summaries take tens of seconds per article, so a large first import can take hours. `smartward ingest` is resumable.
- A 3B model gets the shape of summaries and entity lists right, but the detail is thin and it sometimes invents an entity. A larger chat model (`--chat-model`) will do better if your hardware allows it.
- Library queries compare in memory, so very large libraries (around 100k chunks) will be slow until filters are pushed down into SQL.

## How it differs from the iPhone app

| | iPhone | Linux |
|---|---|---|
| Models | Apple Foundation Models, Apple sentence embeddings | Ollama (default `llama3.2:3b`, `nomic-embed-text`) |
| Storage | SwiftData | A Linux module also named `SwiftData`, backed by SQLite (`Sources/LinuxSwiftData`) |
| Interface | SwiftUI app, voice, Siri, CarPlay | Command line |
| Keys and tokens | Keychain | 0600 files under `$XDG_DATA_HOME` |
| Backups | LZFSE-compressed, AES-GCM encrypted | Same encryption, uncompressed (format 2); can't open Apple-made format 1 files yet |
| Cloud providers (BYOK) | Optional | Not used |

Not available on Linux yet: a graphical app, voice navigation and read-aloud, background refresh, the share extension, and the projects and strategist chat screens.

## Layout

- `Packages/SmartWardKit/`: the shared package.
  - `KnowledgeStore`, `IngestKit`, `Pipeline`, `StrategistCore`, `AppLock`, `ShareInbox`: shared with the iPhone app.
  - `Pipeline/Local`: the Ollama client, embeddings and the local relevance, summary, extraction and digest backends.
  - `SmartWardCore`: the engine behind the command-line tool, reusable by a future GUI.
  - `smartward`: the command-line program.
  - `LinuxSwiftData`, `SwiftDataMacros`, `CSQLite`: the Linux `SwiftData` replacement.
- `Packages/OnDeviceKit/`: a Linux-ready copy of [OnDeviceKit](https://github.com/AnubisRooster/OnDeviceKit) (LLM access, retrieval, graph, lock).
- `SmartWard/`, `ShareExtension/`, `project.yml`: the iPhone app.
- `docs/PLAN.md`: requirements, architecture and the data model. `CLAUDE.md` lists the invariants to keep when changing code.

## Development

```bash
cd Packages/SmartWardKit
swift test                      # about 450 tests, no network or Ollama needed
SMARTWARD_OLLAMA=1 swift test --filter LocalBackendsLiveTests   # against a real Ollama
```

While bringing up a target, `SMARTWARD_SKIP=Target,TargetTests` drops it from the manifest. `.github/workflows/linux.yml` is set up to run `swift test` on every push (it hasn't been run on GitHub yet).

## Licence

The upstream SmartWard repository has no licence file, and this fork doesn't add one. Check with the upstream author before reusing or redistributing the code.
