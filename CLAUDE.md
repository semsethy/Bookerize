# CLAUDE.md

Context for Claude Code. Read this first, then `progress.md` → "Resume here".

## What this is

**Bookerize** — a Flutter PDF book reader with AI comprehension aids. Long-press a word for
its meaning in context; select a sentence to have it explained simply.

- **Full plan:** `PLAN.md`
- **Current state:** `progress.md` ← always start here
- **Platform:** iOS first, Android later
- **Distribution:** TestFlight, small private group

## Working agreement

**The user does not write code.** They are new to Flutter and are learning by watching the
project get built. This means:

- Explain *why*, not just *what*, when introducing a Flutter concept for the first time
- Prefer boring, well-documented approaches over clever ones
- Never leave the app in a non-running state at the end of a session
- Update `progress.md` before finishing — it's the only handoff between machines

## Non-negotiables

1. **Never commit an API key.** The Anthropic key lives in the Cloudflare Worker proxy, set
   via `wrangler secret`. If you find a key in the repo, stop and remove it.
2. **Never break `pdfrx`'s native text selection.** Phases 4–5 depend on it. See PLAN.md §5
   before touching the page-turn implementation.
3. **Long-press on a page with no text must fail silently.** 46 of 137 pages in the sample
   book are illustrations. An error toast there would feel broken.

## Architecture at a glance

```
Flutter app ──HTTPS──> Cloudflare Worker (holds API key) ──> Claude API
     │
     ├── pdfrx        (render + text coordinates + selection)
     ├── Isar         (books, progress, notes, explanation cache)
     └── WordNet SQLite (bundled, offline definitions)
```

Model: `claude-opus-5`, streaming responses.

## Sample books are NOT in the repo

`assets/books/*.pdf` is gitignored — the test book is copyrighted and this repo is public.
On a fresh clone the folder is empty. Copy any **text-based** PDF (not a scan) into
`assets/books/` before running the app.

## Gotchas discovered in the sample book

Analyzed `the_communication_book_44_ideas_for_better_conversations_every_day.pdf`
(137 pages), the reference file these findings come from:

- **46 pages have zero text** — full-page JPEG illustrations. Handle gracefully.
- **Headings are letter-spaced** (`T H E   B O O K`). Group characters into words by
  *proximity*, not whitespace, or long-pressing a heading returns a single letter.
- **All pages are 612×792 pt.** One constant coordinate transform works for this book — do
  not assume it for imported books.
- Illustrations are low-res (457×375) and will look soft. That's the source file, not a bug.

## Commands

```bash
flutter run -d iphone        # run on iOS Simulator
flutter analyze              # static analysis — run before committing
flutter test                 # unit tests
dart format .                # format
cd proxy && npx wrangler dev  # run the proxy locally (Phase 5+)
```

## Conventions

- State management: `riverpod`
- Format with `dart format`; keep `flutter analyze` clean
- Feature-first folder layout under `lib/` (`lib/library/`, `lib/reader/`, `lib/dictionary/`,
  `lib/ai/`)
- Commit at the end of each phase with a message naming the phase
