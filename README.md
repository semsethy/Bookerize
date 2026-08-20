# Bookerize

A Flutter PDF reader for English books, built around understanding what you're reading.

Long-press a word to see what it means **in that sentence**. Select a passage you don't
follow and have it explained in plain language. Pages fill the screen and turn like a real
book.

> **Status:** Planning complete, implementation not started.
> See [`progress.md`](progress.md) for current state and [`PLAN.md`](PLAN.md) for the full build plan.

---

## Features

| | |
|---|---|
| 📚 **Your library** | Import PDFs, see covers, resume exactly where you stopped |
| 📖 **Real page turns** | Full-screen pages with a page-curl animation on swipe |
| 🔍 **Word in context** | Long-press any word — offline dictionary instantly, AI for its meaning in *this* sentence |
| 💡 **Explain simply** | Select a confusing sentence and get it rewritten in plain language |
| ✍️ **Notes & highlights** | Mark passages, write notes, find them later |
| 🎨 **Reading themes** | Background colors, sepia, night mode |

## Tech stack

- **Flutter** — iOS first, Android to follow
- **[pdfrx](https://pub.dev/packages/pdfrx)** — PDFium rendering with per-character text coordinates
- **Isar** — local storage for books, progress, notes, and cached explanations
- **WordNet (SQLite)** — bundled offline dictionary
- **Claude API** via a Cloudflare Worker proxy — contextual meanings and explanations

## Getting started

```bash
git clone https://github.com/semsethy/Bookerize.git
cd Bookerize
flutter pub get
flutter run -d iphone
```

**You need to supply your own book.** `assets/books/*.pdf` is gitignored, so drop any
**text-based** PDF into `assets/books/` before running. Scanned PDFs won't work — the app
needs an embedded text layer to do word lookup.

### Requirements

- **Flutter 3.44+** — needed for Swift Package Manager to be the default on iOS
- Xcode 26+
- A Cloudflare account (Phase 5+, for the API proxy)
- Apple Developer Program (Phase 8 only, for TestFlight)

> **CocoaPods is not required.** This project builds on Swift Package Manager. `pdfrx` pulls
> its native code from `pdfium_flutter`, which ships a `Package.swift`. Flutter falls back to
> CocoaPods only for individual plugins that haven't migrated yet — install it *only* if a
> build actually asks for it. The
> [CocoaPods registry becomes read-only on 2026-12-02](https://flutter.dev/blog/saying-goodbye-to-cocoapods-swift-package-manager-is-soon-the-default-in-flutter),
> so SPM is the forward path.

## Security

The Anthropic API key **never ships in the app**. Flutter binaries are decompilable, so the
key lives in a Cloudflare Worker proxy and the app authenticates with a revocable per-device
token.

## Project docs

| File | What it's for |
|---|---|
| [`PLAN.md`](PLAN.md) | Architecture, 8-phase build plan, risks |
| [`progress.md`](progress.md) | Current status, decisions log, session history |
| [`CLAUDE.md`](CLAUDE.md) | Context for Claude Code |
