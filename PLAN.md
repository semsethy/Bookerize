# Bookerize — Build Plan

A PDF book reader for English books, with AI-assisted comprehension: tap a word for its
meaning in context, select a sentence to have it explained simply.

**Status:** Planning complete. No code written yet.
**Owner:** Sethy · **Started:** 2026-08-20

---

## 1. What we're building

A mobile reading app where:

- You import a PDF; the app stores it and remembers where you stopped
- Pages fill the screen and turn with a realistic page-curl on swipe
- **Long-press a word** → popup with its general meaning + its meaning *in this sentence*
- **Select a sentence** → AI explains it in simple language
- You can take notes and change the reading background (color, texture, subtle animation)

Target audience: you and a small group of friends. English-language books.

---

## 2. Decisions already made

| Decision | Choice | Why |
|---|---|---|
| Distribution | **Me + a few friends** (TestFlight) | Not a public app-store product |
| First platform | **iOS** | You read on iPhone |
| API key location | **Proxy server, never in the app** | The app ships to other people; an embedded key would be extracted |
| PDF engine | **`pdfrx`** (PDFium) | Only option giving both rendering *and* per-character text coordinates |
| Page curl | **Hybrid (Option C)** — deferred to last phase | See §5 |
| Model | **`claude-opus-5`**, streaming | Best explanation quality; streaming makes it feel instant |
| Offline dictionary | **Bundled WordNet SQLite** | Instant word meanings with no network, no cost |

### ⚠️ Two things that cost money

1. **Apple Developer Program — $99/year.** Required for TestFlight *and* for running on a
   physical iPhone. The iOS Simulator is free, so Phases 1–6 can be built without paying.
   You only need this when you want the app on a real phone or shared with friends.
2. **Claude API usage.** Rough estimate at `claude-opus-5` rates ($5/M input, $25/M output):
   a sentence explanation is ~500 input + ~300 output tokens ≈ **$0.01 per explanation**,
   so roughly **100 explanations per dollar**. Word-in-context lookups are cheaper (~$0.004).
   Offline dictionary lookups are free. If costs get uncomfortable, switching to
   `claude-haiku-4-5` cuts it ~5×, at some quality cost — your call, not an automatic change.

---

## 3. Architecture

```
┌─────────────────────────────────────────────┐
│  Flutter app (iOS first, Android later)     │
│                                             │
│  ┌───────────┐  ┌──────────────────────┐    │
│  │  Library  │  │  Reader              │    │
│  │  screen   │  │  ┌────────────────┐  │    │
│  └───────────┘  │  │ pdfrx viewer   │  │    │
│        │        │  │  + text layer  │  │    │
│        │        │  └────────────────┘  │    │
│        │        │   long-press → word  │    │
│        │        │   drag-select → sent.│    │
│        │        └──────────┬───────────┘    │
│        │                   │                │
│  ┌─────▼───────────────────▼─────────────┐  │
│  │  Local storage (Drift + SQLite)         │  │
│  │  books · progress · notes · cache     │  │
│  └───────────────────────────────────────┘  │
│  ┌───────────────────────────────────────┐  │
│  │  WordNet SQLite (bundled, offline)    │  │
│  └───────────────────────────────────────┘  │
└──────────────────┬──────────────────────────┘
                   │ HTTPS
        ┌──────────▼───────────────┐
        │  Cloudflare Worker proxy │
        │  holds ANTHROPIC_API_KEY │
        │  rate-limits per device  │
        └──────────┬───────────────┘
                   │
             Claude API
```

### Why a proxy

Flutter apps are decompilable. An `ANTHROPIC_API_KEY` compiled into the binary can be
extracted from the IPA in minutes and used to bill your account. The proxy holds the key
server-side; the app authenticates with a per-device token that you can revoke.

**Cloudflare Workers** is the recommended host: free tier covers this workload comfortably,
no server to maintain, and Node is already installed for local development.

### Tech stack

All versions verified against pub.dev on 2026-08-20 and confirmed CocoaPods-free.

| Layer | Package | Version | iOS native | Purpose |
|---|---|---|---|---|
| PDF render + text | `pdfrx` | 2.4.7 | SPM + build hook | Page bitmaps, character coordinates, native selection |
| Storage | `drift` + `drift_flutter` | 2.34.3 | via `sqlite3` build hook | Books, progress, notes, explanation cache |
| File import | `file_picker` | 12.0.0 | SPM | Pick PDFs from Files / iCloud |
| Dictionary | `drift` + custom WordNet DB | — | (same as storage) | Bundled offline definitions |
| HTTP | `dio` | 5.11.0 | pure Dart | Talks to the proxy, handles streaming |
| State | `flutter_riverpod` | 3.4.2 | pure Dart | App state; well documented |
| Page curl | TBD | — | — | Phase 7 only |

### ⛔ CocoaPods is prohibited on this project

Not a preference — a constraint. Every dependency above is verified to build without it via
Swift Package Manager or native-asset build hooks. **If a future package requires CocoaPods,
replace the package — do not install CocoaPods.**

Enforced by `flutter config --enable-swift-package-manager true` (set 2026-08-20).

### Two packages ruled out during the audit

- **`isar`** — last published **2023-04-25**, over three years stale. Replaced with `drift`,
  which is actively maintained (2026-07-27) and SQLite-backed, so the app's data and the
  WordNet dictionary share one storage engine instead of two.
- **`sqlite3_flutter_libs`** — now an empty stub (`0.6.0+eol`), described upstream as
  *"Not used anymore, update to version 3.x of package:sqlite3"*. Do **not** add it;
  `sqlite3` 3.5.2 compiles its own native library via `hook/build.dart`.

---

## 4. Build phases

Each phase ends with something that **runs**. Nothing is built on a foundation you can't see
working.

### Phase 0 — Environment setup ✅ **DONE (2026-08-20)**
- Flutter upgraded 3.41.9 → **3.47.1**
- `enable-swift-package-manager` set to `true` explicitly
- Full dependency set resolved together in a scratch project (73 packages, no conflicts)
- Every native plugin verified CocoaPods-free — see §3
- Scratch project deleted

Remaining: `flutter doctor` review and first Simulator boot, done at the start of Phase 1.

### Phase 1 — A PDF on screen
`flutter create`, add `pdfrx`, display the bundled sample book. No paging, no styling.
**Done when:** the book renders in the iOS Simulator and you can scroll it.

### Phase 2 — Library and persistence
Import PDFs via `file_picker`, copy into app storage, save metadata to Drift, render a home
grid with cover thumbnails (page 1). Tap a book to open. Save and restore last-read page.
**Done when:** you can close the app, reopen it, tap a book, and land on the page you left.

### Phase 3 — Full-screen paging
One page per screen, horizontal swipe with a plain `PageView`. Deliberately not the curl yet.
**Done when:** the app is genuinely usable as a reader end to end.

### Phase 4 — Text interaction layer ⭐
The technical heart of the project.
- Coordinate transform: screen point → PDF page space
- Long-press → hit-test character rects → expand to word boundaries
- Extract the containing sentence for context
- Drag-select → capture selected range via `pdfrx` selection
- Offline WordNet lookup → popup with general meaning
- "Explain" button placeholder on the selection toolbar
**Done when:** long-pressing a word shows its dictionary definition, and selecting a
sentence shows a toolbar with a (non-functional) Explain button.

### Phase 5 — AI layer ⭐
- Cloudflare Worker proxy: holds the key, per-device tokens, rate limiting
- "Meaning in this sentence" → streams into the word popup
- "Explain simply" → streams into a bottom sheet
- Cache every result in Drift so the same lookup is never billed twice
- Graceful offline behavior: dictionary still works, AI features show a clear message
**Done when:** both AI features work on a real book, and airplane mode degrades cleanly.

### Phase 6 — Notes and reading backgrounds
Highlights anchored to text ranges, notes list per book, background themes (color, sepia,
night mode via blend filters, optional subtle animation).
**Done when:** you can highlight a passage, write a note, and find it again later.

### Phase 7 — Page curl
Hybrid approach (§5). Live `pdfrx` page at rest; bitmap curl during the swipe.
**Done when:** page turns look like a real book and text selection still works.

### Phase 8 — TestFlight
Apple Developer Program enrollment, app icons, build signing, upload, invite friends.
**Done when:** a friend is reading on their own phone.

---

## 5. The page-curl conflict (important)

`pdfrx`'s built-in text selection works **inside its own viewer widget**. Page-curl packages
animate **bitmaps**. Replacing the viewer with a curl widget would mean rebuilding drag
selection, selection handles, and the toolbar by hand — roughly a week of fiddly work, and
it would break the features from Phases 4–5.

**Resolution — hybrid:**

- **At rest:** show the live `pdfrx` page. Selection and long-press work normally.
- **During swipe:** snapshot the page to a bitmap, run the curl over bitmaps, then hand
  back to the live widget when the animation lands.

The user can't select text mid-swipe anyway, so the swap is invisible. This is why the curl
is Phase 7 and not Phase 3 — everything before it must be built on the real `pdfrx` viewer
to keep this option open.

---

## 6. What the sample book taught us

`assets/books/the_communication_book_*.pdf` — 137 pages, analyzed 2026-08-20:

| Finding | Consequence for the app |
|---|---|
| 91 pages have real embedded text, median ~1,491 chars | Word lookup will work. No OCR needed for this book. |
| **46 pages have zero text** (full-page JPEG illustrations) | Long-press must **fail silently**. An error toast on a third of the book would feel broken. |
| Uniform 612×792 pt page size | Coordinate transform is one constant matrix, not per-page math. Don't assume this holds for other books. |
| Headings are letter-spaced (`T H E   B O O K`) | Word-boundary logic must group by **proximity**, not whitespace, or long-pressing a heading returns one letter. |
| Illustrations are 457×375 JPEGs on a 612×792 page | They will look soft on a high-DPI screen. Source-file limitation, not a rendering bug. |
| Fonts are Type0/CID subsets with working ToUnicode | Text extracts cleanly. Other books may not — see risks. |

---

## 7. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| A user imports a scanned PDF with no text layer | High | Detect empty text on import; warn clearly. On-device OCR (ML Kit) is a possible v2 addition. |
| Curl animation stutters on older iPhones | Medium | Pre-render neighboring pages to cached bitmaps; curl images, never live-render mid-animation. |
| Broken ToUnicode maps in some PDFs → garbled words | Medium | Sanity-check extracted text on import; fall back to dictionary-only mode. |
| API costs creep up | Low | Aggressive caching; per-device rate limits in the proxy; usage counter in-app. |
| Flutter learning curve stalls progress | Medium | Phases ordered so something runs at every step; the curl (hardest, most cosmetic) is last. |

---

## 8. Out of scope for v1

- Android (structure supports it; just not tested until v1 ships)
- EPUB / MOBI formats
- Cross-device sync
- Languages other than English
- Text-to-speech
- OCR for scanned PDFs
