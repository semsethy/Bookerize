# CLAUDE.md

Context for Claude Code. Read this first, then `progress.md` → "Resume here".

## ⚡ Run this before writing any code

```bash
./tool/preflight.sh
```

**At the start of every session on a machine you have not verified, run it before touching
code.** It checks the Flutter version, Swift Package Manager state, Xcode and simulators,
disk space, that no Podfile has appeared, that no banned packages are in `pubspec.yaml`, and
that a sample book exists. Exit 0 = safe to build; exit 1 = blockers, printed with the exact
fix command for each.

Do not skip it and do not "fix" a failure by working around it — a blocker means the build
will fail later in a more confusing way.

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

0. **⛔ Never install or use CocoaPods.** Hard constraint from the project owner. Every
   dependency is verified to build via Swift Package Manager or native-asset build hooks
   (`hook/build.dart`). If a package requires CocoaPods, **replace the package** — do not
   install CocoaPods, do not add a Podfile, do not suggest it as a fallback.
1. **Never commit an API key.** The Gemini key lives in the Cloudflare Worker proxy, set via
   `wrangler secret`. If you find a key in the repo, stop and remove it. This holds whatever
   the provider is — a key inside a Flutter app can be pulled straight out of the IPA.
2. **Never break `pdfrx`'s native text selection.** Phases 4–5 depend on it. See PLAN.md §5
   before touching the page-turn implementation.
3. **Long-press on a page with no text must fail silently.** 46 of 137 pages in the sample
   book are illustrations. An error toast there would feel broken.
4. **Never re-enable pdfrx's built-in "Select All".** It paints a selection across every page
   at once, and on a page with no text it asks an empty fragment list for its last element and
   brings down the painter. `lib/reader/reader_screen.dart` strips it from the context menu.
   Same root cause as #3: this book is a third pictures.

## Architecture at a glance

```
Flutter app ──HTTPS──> Cloudflare Worker (holds API key) ──> Gemini API
     │
     ├── pdfrx        (render + text coordinates + selection)
     ├── Drift        (SQLite: books, progress, notes, explanation cache)
     └── WordNet SQLite (bundled, offline definitions)
```

Model: `gemini-3.6-flash`, streaming responses (`streamGenerateContent`, `?alt=sse`).

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
  Solved in `lib/reader/word_finder.dart`; the two thresholds there were measured off this
  book with `tool/probe/measure_word_gaps.dart`, not guessed.
- **All pages are 612×792 pt.** One constant coordinate transform works for this book — do
  not assume it for imported books.
- Illustrations are low-res (457×375) and will look soft. That's the source file, not a bug.

## Commands

**iOS builds use Swift Package Manager, never CocoaPods.** See non-negotiable #0.
Verified CocoaPods-free as of 2026-08-20: `pdfium_flutter` (SPM), `file_picker_darwin` (SPM),
`path_provider_foundation` (SPM), `url_launcher_ios` (SPM), `sqlite3` (build hook).

Do **not** add `sqlite3_flutter_libs` — it is an EOL no-op stub.
Do **not** add `drift_flutter` — it pulls `sqlite3_flutter_libs` *and* `sqlcipher_flutter_libs`
(both `+eol` stubs) in transitively. Use `drift` + `sqlite3` and open the database with
`NativeDatabase` directly; that is what `lib/data/app_database.dart` does.

```bash
flutter run -d iphone        # run on iOS Simulator
flutter analyze              # static analysis — run before committing
flutter test                 # unit tests
flutter test integration_test -d <device-id>   # on-device tests (real gestures)
dart format .                # format
dart run build_runner build  # regenerate Drift code after changing a table
python3 tool/build_wordnet.py # rebuild the offline dictionary (rarely needed)
cd proxy && npm test          # proxy tests — no key or network needed
cd proxy && npx wrangler dev  # run the proxy locally (needs proxy/.dev.vars)

# Run the app against a deployed proxy (see proxy/README.md):
flutter run --dart-define=BOOKERIZE_PROXY_URL=... --dart-define=BOOKERIZE_TOKEN=...
```

## Conventions

- State management: `riverpod`
- Format with `dart format`; keep `flutter analyze` clean
- Feature-first folder layout under `lib/` (`lib/library/`, `lib/reader/`, `lib/dictionary/`,
  `lib/ai/`), with shared data access in `lib/data/`
- Generated `*.g.dart` files **are committed** so a fresh clone compiles without extra steps
- Book and cover paths are stored in the database **relative** to the documents directory —
  iOS renames the app container, so absolute paths go stale
- Dictionary lookups rank senses by WordNet's **tagged frequency**, never by trying one part
  of speech first — otherwise "are" resolves to a unit of area rather than the verb "be"
- **Prompts and the model name live in the Worker, never in the app.** Wording is the main
  lever on answer quality; keeping it server-side makes it a redeploy, not a release
- Every answer is cached in Drift against the exact question. Never cache an empty or failed
  answer — that would make one bad moment permanent
- Commit at the end of each phase with a message naming the phase
