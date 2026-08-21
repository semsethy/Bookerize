# Progress

Living status file. **Update this at the end of every working session** so the project can be
picked up on any machine.

---

## 🔖 Resume here

> **Current phase:** Phase 5 🟡 all but confirmed → **Phase 6 (notes and backgrounds)** next
>
> **Two small things to check first — both need a human, neither needs code:**
> 1. **Does a real finger select text?** Run the app, drag across a sentence, and look for
>    selection handles and a toolbar with Copy · Highlight · Note · Explain. No automated test
>    can reach pdfrx's selection (proven: a bare viewer with no config of ours selects nothing
>    under the harness either). Phase 6's highlighting and Phase 5's "Explain" both sit on it.
> 2. **Does an answer appear in the card?** Long-press a word → "What does it mean here?".
>    The proxy is live and has produced real answers via curl, but the Gemini free tier is
>    **20 requests a day** and 2026-08-21's were spent testing. Should work on any later day.
>
> **Then start Phase 6:** highlights anchored to text ranges, a notes list per book, and the
> paper/sepia/night reading grounds. The first half needs no decisions. The second half needs
> one answer from Sethy: what "a subtle animation" in the background should actually be —
> still paper grain, a gradient drifting over minutes, or something that reacts to a page turn.
>
> **Running the app with the AI features on:**
> ```
> flutter run -d iphone \
>   --dart-define=BOOKERIZE_PROXY_URL=$(cat proxy/.local-url) \
>   --dart-define=BOOKERIZE_TOKEN=$(cat proxy/.local-token)
> ```
> Both files are gitignored and exist only on Sethy's Mac. Without them the app still runs;
> the dictionary works and the AI features say so quietly.
>
> **Blocked on:** nothing.

### Where the work is

Pushed to **https://github.com/semsethy/Bookerize** (public) through Phase 5.
The Worker address, the device token and the sample book are all gitignored, so a fresh clone
needs: a PDF in `assets/books/`, and the two `--dart-define`s for the AI features.

`design/product-design.html` is the product design walkthrough — every screen and the
behaviour rules behind them. Committed by Sethy in `cbf7a62`. Open it in a browser, or
publish it as an artifact to scroll through it.

### How to resume on a new laptop

```bash
git clone https://github.com/semsethy/Bookerize.git
cd Bookerize

# 1. Copy any TEXT-BASED pdf into assets/books/ — sample books are gitignored (see below)
# 2. Verify the machine can actually build this project:
./tool/preflight.sh

# 3. Only once preflight exits 0:
claude
```

Then say: **"Read progress.md and continue from the Resume here section."**

`tool/preflight.sh` checks Flutter version, Swift Package Manager, Xcode, simulators, disk,
banned packages, and stray Podfiles — printing the exact fix command for anything that fails.
Claude Code is also instructed (in `CLAUDE.md`) to run it before writing code, so you get the
check even if you forget.

> ⚠️ **The sample book is not in the repo.** `assets/books/*.pdf` is gitignored because the
> test file is copyrighted and this repo is public. Drop your own text-based PDF in there
> before running the app. Scanned PDFs will not work — the app needs an embedded text layer.

Claude Code reads `CLAUDE.md` automatically, which points at `PLAN.md` and this file.

---

## Phase checklist

| # | Phase | Status | Notes |
|---|---|---|---|
| 0 | Environment setup | ✅ Done | Flutter 3.47.1, SPM on, full dep audit passed |
| 1 | A PDF on screen | ✅ Done | pdfrx renders the sample book in the Simulator |
| 2 | Library and persistence | ✅ Done | Drift + import + covers; resumes your page |
| 3 | Full-screen paging | ✅ Done | Horizontal snap paging, built on pdfrx's own hooks |
| 4 | Text interaction layer | ✅ Done | Word lookup works offline; thresholds measured, not guessed |
| 5 | AI layer (+ proxy) | 🟡 In progress | Proxy deployed and answering; awaiting quota reset to see it in the card |
| 6 | Notes and backgrounds | ⬜ Not started | |
| 7 | Page curl | ⬜ Not started | Hybrid approach — see PLAN.md §5 |
| 8 | TestFlight | ⬜ Not started | Needs Apple Developer Program ($99/yr) |

Legend: ⬜ not started · 🟡 in progress · ✅ done · 🔴 blocked

---

## Environment status

Full prerequisite audit run on Sethy's Mac, 2026-08-20. Everything needed through Phase 4 is
present. **On any other machine, run `./tool/preflight.sh` instead of trusting this table.**

### Toolchain

| Tool | Status | Notes |
|---|---|---|
| Flutter | ✅ **3.47.1** | Upgraded from 3.41.9. Now at `/opt/homebrew/share/flutter` |
| Swift Package Manager | ✅ **Enabled explicitly** | `flutter config --enable-swift-package-manager true` |
| Xcode | ✅ 26.3 (17C519) | iOS 26.2 SDK; first-launch complete |
| iOS Simulator runtimes | ✅ 16.0, 18.4, 18.5, 18.6, 26.1 | iPhone 14 / 14 Pro / SE 3rd gen available |
| Node | ✅ v26.0.0 | For the Cloudflare Worker proxy |
| npm | ✅ 11.12.1 | |
| Git | ✅ 2.50.1 | |
| GitHub CLI | ✅ 2.92.0 | Authed as `semsethy` |
| Disk | ✅ 329 GB free | |
| **CocoaPods** | ⛔ **Prohibited** | Hard constraint. Not installed and must stay that way. |
| Ruby | ⚠️ 2.6.10 (system) | Ancient — another reason CocoaPods was the wrong path |

### Dependencies — all verified CocoaPods-free

| Package | Version | Published | iOS native strategy |
|---|---|---|---|
| `pdfrx` | 2.4.7 | 2026-07-09 | `pdfium_flutter` → SPM + `hook/link.dart` |
| `drift` | 2.34.3 | 2026-07-27 | via `sqlite3` |
| `sqlite3` | 3.5.2 | — | `hook/build.dart` native assets, no podspec |
| `file_picker` | 12.0.0 | 2026-08-14 | `file_picker_darwin` → SPM ✓ |
| `path_provider` | 2.1.6 | 2026-06-15 | `path_provider_foundation` → SPM ✓ |
| `url_launcher` | 6.3.2 | 2025-07-10 | `url_launcher_ios` → SPM ✓ (transitive via pdfrx) |
| `dio` | 5.11.0 | 2026-07-25 | pure Dart |
| `flutter_riverpod` | 3.4.2 | 2026-07-28 | pure Dart |

Verified empirically: all 73 packages resolved together in a scratch project with no version
conflicts. Scratch project deleted afterward.

### Deferred prerequisites

| Item | Needed at | Status |
|---|---|---|
| Cloudflare account + `wrangler` | Phase 5 | ✅ **Done 2026-08-21.** Account created, `wrangler` 4.125.0 logged in, Worker deployed with both secrets set. Address in `proxy/.local-url`. |
| Gemini API key | Phase 5 | ✅ **Done 2026-08-21.** Entered through the Cloudflare dashboard, so it never touched a terminal or this repo. ⚠️ Free tier is **20 requests/day**; testing exhausted 2026-08-21's allowance. |
| WordNet dictionary data | Phase 4 | ✅ **Done.** `tool/build_wordnet.py` builds `assets/dictionary/wordnet.sqlite` from Princeton WordNet 3.1: 132,826 senses, 12.3 MB, committed. Licence in `assets/dictionary/WORDNET_LICENSE.txt`. |
| Apple Developer Program ($99/yr) | Phase 8 | ❌ Not enrolled. Simulator work needs nothing. |

---

## Decisions log

Append here whenever a choice is made, so the reasoning survives context resets.

| Date | Decision | Reasoning |
|---|---|---|
| 2026-08-20 | Flutter, iOS first | User reads on iPhone; Simulator is free for early phases |
| 2026-08-20 | Distribution: me + a few friends via TestFlight | Not a public product |
| 2026-08-20 | API key behind a Cloudflare Worker proxy, never in the app | App ships to other devices; an embedded key would be extracted from the IPA |
| 2026-08-20 | `pdfrx` as the PDF engine | Only package giving both rendering and per-character text coordinates |
| 2026-08-20 | Page curl deferred to Phase 7, hybrid approach | Native `pdfrx` selection lives in its viewer widget; a bitmap-based curl would break Phases 4–5 |
| 2026-08-20 | `claude-opus-5` with streaming | Explanation quality; streaming hides latency. *(Superseded 2026-08-21 — see below.)* |
| 2026-08-20 | Hybrid dictionary: offline WordNet + AI for context | Instant and free for the common case; AI only for genuine ambiguity |
| 2026-08-20 | **Swift Package Manager, not CocoaPods** | Verified `pdfium_flutter` (pdfrx's native layer) ships `darwin/pdfium_flutter/Package.swift`. SPM is default from Flutter 3.44. The CocoaPods registry goes read-only 2026-12-02, so building on it now would start on a sunset dependency. *(Superseded same day by the outright prohibition below.)* |
| 2026-08-20 | Upgrade Flutter 3.41.9 → 3.47.1 | Gets SPM-by-default; no code written yet so the upgrade carries no regression risk |
| 2026-08-20 | **CocoaPods prohibited outright** | Owner constraint. If a package needs CocoaPods, replace the package — never install it as a fallback. Verified the whole stack builds without it. |
| 2026-08-20 | **Isar → Drift** for local storage | Isar's last publish was 2023-04-25 (3+ years stale, effectively abandoned). Drift is active (2026-07-27), SQLite-backed, so app data and the WordNet dictionary share one engine instead of two. |
| 2026-08-20 | Do not add `sqlite3_flutter_libs` | It is now an EOL no-op stub. `sqlite3` 3.5.2 builds its own native lib via `hook/build.dart`. |
| 2026-08-20 | Build our own WordNet SQLite | No maintained Flutter WordNet package exists (`dictionaryx` last published 2022). Princeton raw data is available; one-time preprocessing gives us control over bundle size. |
| 2026-08-21 | Bundle id `com.semsethy.bookerize`, iOS-only scaffold | Matches the GitHub org; Android platform folder can be added later with `flutter create --platforms=android .` |
| 2026-08-21 | Find the book by scanning `AssetManifest` instead of hardcoding a filename | Sample PDFs are gitignored, so the filename differs per machine — a hardcoded path would break every fresh clone |
| 2026-08-21 | **Do not use `drift_flutter`** | It pulls `sqlite3_flutter_libs` *and* `sqlcipher_flutter_libs`, both `+eol` no-op stubs already ruled out in Phase 0. `drift` + `sqlite3` with `NativeDatabase` gives the same thing with nothing banned in the tree. |
| 2026-08-21 | Store book/cover paths **relative** to the documents directory | iOS hands the app a newly-named container on reinstall, so an absolute path saved today points nowhere tomorrow. Confirmed live: the container UUID changed between runs during testing. |
| 2026-08-21 | **Commit generated `*.g.dart`** (was gitignored) | This project is cloned onto a second machine and must build immediately. Ignoring generated Drift code means a fresh clone fails to compile until someone knows to run `build_runner`. |
| 2026-08-21 | Opening a book marks it as read, not just turning a page | pdfrx only reports page changes the reader makes, so without this the shelf still said "Not started" after a full session. |
| 2026-08-21 | Covers use `BoxFit.contain` on white, not `BoxFit.cover` | Page proportions vary book to book; cropping ate the title off the edges of the sample book. |
| 2026-08-21 | **Paging built from pdfrx's own hooks, not a `PageView`** | PLAN.md said "a plain PageView", but that means putting page *images* in a list, and pdfrx's text selection only lives inside its viewer — it would have broken non-negotiable #2 and with it Phases 4–5. Instead: horizontal `layoutPages`, `SizeDelegateSmart(maxPagesVisible: 1)` so one page fills the screen, and a snap on `onInteractionEnd`. No gesture detector wraps the viewer, so nothing competes for the drags selection needs. |
| 2026-08-21 | Snap on interaction-end, not via `ScrollPhysics` | pdfrx only runs scroll physics on a *fling*, so a snapping physics would leave a slow drag resting between two pages. |
| 2026-08-21 | Don't snap when the view never moved | Every gesture ends with an interaction-end, including a long-press. Animating back to the page you never left is pointless and risks cancelling a selection. |
| 2026-08-21 | **Strip pdfrx's "Select All" from the context menu** | It paints a selection across all 137 pages; the 46 with no text have zero text fragments, and pdfrx asks that empty list for its last element → `Bad state: No element`, thrown from `paint()`. Reachable from the default toolbar. Recorded as non-negotiable #4. |
| 2026-08-21 | Added `integration_test` (verified SPM, no CocoaPods) | Unit tests cannot reach a finger, and "turn a page and your place is kept" is made of gestures. |
| 2026-08-21 | Word-grouping thresholds **measured off the real book**, not guessed | `tool/probe/measure_word_gaps.dart` printed the numbers: a letter-spacing gap is 0.27 of a glyph width, a real word space is 0.65–0.97, and body text never exceeds a 0.17 gap. Both thresholds sit in wide empty margins. |
| 2026-08-21 | Rank dictionary senses by WordNet's **tagged frequency** | Trying parts of speech in a fixed order made "are" resolve to the noun — "a unit of surface area equal to 100 square meters". Caught by looking at the screen, not by a test. WordNet's `cntlist.rev` gives "be" a count of 10,742 against nothing for "are". |
| 2026-08-21 | Cap at 5 senses per lemma, skip multi-word entries | Multi-word entries can never be reached by long-pressing one word, and the first few senses are the ones a reader wants. Keeps the bundle at 12.3 MB. |
| 2026-08-21 | Commit the 12.3 MB dictionary | Same reason as the generated Drift code: a fresh clone has to build without first running a script that downloads 16 MB from Princeton. |
| 2026-08-21 | Word card rises from the bottom, not over the word | A popover covers the sentence you were reading and sits where your thumb isn't. Settled in the design review and now built. |
| 2026-08-21 | **Gemini instead of Claude** — `gemini-3.6-flash`, streaming | Owner's choice. Cost nothing to change: Phase 5 had not started, and no code referenced a provider. Also ~7x cheaper per explanation (~650 per dollar against ~100), and Gemini has a free tier that may cover a group this size outright. The proxy stays — that reasoning never depended on the provider. |
| 2026-08-21 | **Prompts and model name live in the Worker, not the app** | Wording is the main lever on answer quality. Server-side, changing it is a redeploy; in the app it is an App Store review. It also means the app has no idea which provider it is talking to — switching again would cost one file. |
| 2026-08-21 | Proxy flattens Gemini's SSE to `{"text":...}` / `[DONE]` | Gemini emits five event types per answer. The app should not have to know that, and would break if it changed. |
| 2026-08-21 | Errors are reported *inside* the stream | By the time an answer fails, the HTTP status has already gone out. A mid-stream `{"error":...}` is the only way to say so. |
| 2026-08-21 | Never cache an empty or failed answer | Otherwise one bad moment becomes permanent, and the reader can never ask again. |
| 2026-08-21 | Config via `--dart-define`, not a settings screen | Keeps every secret out of the repo and off disk. A proper token-entry screen is Phase 8 work, when friends actually need to enter one. |
| 2026-08-21 | Rate limit via Cloudflare's native binding, not KV | No namespace to create, no write quota to burn, and it keys on the device token rather than an IP. |
| 2026-08-21 | Ask the proxy for `accept-encoding: identity` | dio does **not** decompress when `ResponseType.stream` is used, so a gzipped stream parsed to nothing and the card sat blank. Compressing an event stream also buffers it, defeating streaming. |
| 2026-08-21 | Never set `content-encoding` on the Worker's response | Tried it to stop compression; declaring it tells the runtime the body is already encoded and every answer came back as nothing but `[DONE]`. A regression I introduced and caught with curl. |
| 2026-08-21 | Surface Gemini's `event: error` records | Gemini reports failures *inside* a 200 response. Discarding unknown events — right for the chatty ones — turned a quota error into a blank card. Now translated into something a reader can act on. |
| 2026-08-21 | An answer with no text is an error, not an empty card | Silence means something upstream changed shape; say so rather than leave the reader staring at nothing. |

---

## Session log

Newest first. One entry per working session.

### 2026-08-21 — Phase 5 (part 2): the proxy is live, and it works
- Deployed to Cloudflare Workers. The address is kept in `proxy/.local-url` rather than here,
  since this repo is public; a token is required either way. Secrets are set; the Gemini key was
  entered through the Cloudflare dashboard so it never touched a terminal or this repo. The
  device token lives in `proxy/.local-token` (gitignored) and was piped into the secret
  without ever being printed.
- **Real answers, verified:** "That pause is where mutual sharing begins. When the other
  person is given space, they share something they had not planned to." It also correctly
  spotted "raw" in "raw material" as figurative — which is exactly what the prompt asks for.
- **Rate limiting verified:** first 429 at request 22 against a limit of 20/60s. Two earlier
  attempts wrongly suggested it was broken — one was too slow to fill the window, the other
  too bursty for a best-effort counter.
- 72 unit + 39 proxy tests, analyze clean.

**Four real bugs, all found by running it rather than by testing it:**

1. **Answers arrived cut off mid-sentence.** Gemini 3.x thinks before answering, and thinking
   tokens are billed as output *and* spent from `max_output_tokens`. At 320 there was nothing
   left for the answer. Now `thinking_level: 'low'` with a 1024 ceiling.
2. **The card stayed blank.** dio does not decompress when `ResponseType.stream` is used, so
   a gzipped stream parsed to nothing. The app now asks for `identity`.
3. **A regression I caused:** setting `content-encoding: identity` on the Worker's *response*
   made every answer come back as nothing but `[DONE]`. Caught because curl had worked ten
   minutes earlier and suddenly didn't.
4. **Gemini reports failures inside a 200 response**, as `event: error`. Discarding unknown
   events meant a quota error became a blank card. Now translated to plain English.

**⚠️ Blocked on quota, not on code.** The free tier allows 20 requests a day for
`gemini-3.6-flash`, and testing used them up. The success path is proven through the proxy by
curl; what has not yet been *seen* is a real answer rendered in the card, because the quota
ran out before the gzip fix landed. Retry after reset, or after enabling billing.

### 2026-08-21 — Phase 5 (part 1): the AI layer, built but unproven ⭐
- `proxy/` — a Cloudflare Worker holding the Gemini key. Two endpoints, per-token auth with a
  constant-time check, native rate limiting, input caps, and a `max_output_tokens` ceiling so
  no single request can run away.
- `lib/ai/ai_client.dart` — streams the answer as it arrives; every failure has a message
  written for a reader rather than a developer.
- `lib/ai/explainer.dart` — asks once, ever. Answers are cached in Drift against the exact
  question, so a second look is instant, free, and works with no signal.
- Schema v1 → v2 for the cache, with a migration test proving a v1 library keeps its books
  **and its page**.
- Both placeholders are now real: "What does it mean here?" streams into the word card, and
  "Explain" opens a sheet with the author's sentence above the plainer version.
- 72 unit tests + 4 on-device tests + 32 proxy tests. Analyze clean, preflight green.

**Checked the wire format instead of trusting memory.** Gemini's `generateContent` is now
legacy; the Interactions API went GA in June 2026 and is what new projects should use. The
request and SSE event shapes came from the current docs, not from recall — getting this wrong
would have meant a Phase 5 that silently never worked.

**⚠️ Nothing here has spoken to the real Gemini API.** Everything is tested against a fake:
the proxy against a stub upstream, the client against a real local socket serving real SSE.
That covers parsing, auth, caching, failure messages and the offline path — but not whether
Google accepts our request body. **Phase 5 is not done until a real answer streams into the
card.** Verified for now: with no proxy configured, the reader sees one quiet line where the
button would be, and the dictionary carries on working.

### 2026-08-21 — Phase 4: text interaction layer ⭐
- **Built the offline dictionary.** `tool/build_wordnet.py` downloads Princeton WordNet 3.1
  and produces `assets/dictionary/wordnet.sqlite` — 132,826 senses in 12.3 MB, committed.
- `lib/reader/word_finder.dart` — the heart of the phase. Turns a page's characters into
  words you can hit-test with a fingertip, grouping by **proximity** so letter-spaced
  headings come back whole.
- `lib/dictionary/morphy.dart` — WordNet's exception lists and detachment rules, so
  `conversations` finds `conversation` and `ran` finds `run`.
- `lib/reader/page_words.dart` — loads and caches a page's text so a long-press is instant.
- `lib/dictionary/word_card.dart` — the card from the design review, rising from the bottom.
- "What does it mean here?" and "Explain" are on screen and visibly inert, waiting for Phase 5.
- 52 unit tests + 4 on-device tests, analyze clean, preflight green, still no Podfile.

**The thresholds were measured, not guessed.** `tool/probe/measure_word_gaps.dart` was written
to print real numbers off the sample book before any heuristic was chosen:

| signal | letter-spacing | real word break |
|---|---|---|
| whitespace glyph width | 0.27 | 0.65 – 0.97 |
| gap between glyphs | 0.03 – 0.11 | 0.84 – 0.90 |

Body text never produced a gap above 0.17, so both thresholds sit in wide empty margins.
`test/real_book_test.dart` then checks the finder against the actual PDF rather than synthetic
rectangles — synthetic tests only prove the code matches what the author imagined.

**A bug the tests could not have caught.** The first run on the Simulator long-pressed "are"
and the card said *"a unit of surface area equal to 100 square meters"*. Correct data, useless
answer: the lookup tried nouns first, arbitrarily. Fixed by ranking senses across all parts of
speech by WordNet's tagged frequency (`cntlist.rev`), where "be" scores 10,742 and the noun
"are" was never tagged at all. Worth remembering that this was found by *looking at the
screen*, after every unit test had passed.

**Silence on picture pages is tested, not assumed.** An on-device test long-presses an
illustration-only page and asserts no card, no snackbar, and no exception (non-negotiable #3).

### 2026-08-21 — Phase 3: full-screen paging
- One page per screen, turned by swiping sideways, **without replacing the pdfrx viewer**
  (see the decisions log — a literal `PageView` would have broken non-negotiable #2)
- `lib/reader/page_layout.dart` — horizontal layout with a uniform slot pitch, plus the
  arithmetic for "which page is nearest" and "are we already resting on one"
- `lib/reader/reader_chrome.dart` — hidden by default; tap the middle to reveal a back
  button, a page slider and "Page N of M". Tap the left/right edge to turn a page.
- Added `integration_test` — **confirmed it ships a `Package.swift`, so still no CocoaPods**
- 20 unit tests + 2 on-device tests, `flutter analyze` clean, preflight green

**Closed the gap left open in Phase 2:** an on-device test now taps a book, swipes to turn a
page, goes back, and asserts the shelf shows the page it reached. Turning a page with a real
gesture saves your place — verified, not assumed.

**Found a crash in pdfrx, reachable from the app.** Selecting a word and tapping "Select All"
paints a selection over every page; the 46 illustration-only pages have no text fragments, and
pdfrx asks that empty list for its last element — `Bad state: No element`, out of `paint()`.
Stripped the item from the context menu and recorded it as non-negotiable #4. Phase 4 replaces
this toolbar anyway.

**⚠️ Not verified: selection by an actual finger.** Synthesised long-presses don't reach pdfrx's
selection under the integration-test harness — confirmed by long-pressing a *bare* `PdfViewer`
with none of our configuration, which also selected nothing. So this is a harness limit, not a
regression. The on-device test proves selection is enabled and the text layer + per-character
rects are reachable through the paging config, which is the regression worth catching.
**Someone should long-press text in the Simulator by hand before Phase 4 leans on it.**

Also worth a look: on a tall phone a 612x792 page fits by width and leaves roughly 40% of the
screen as empty ground above and below. That is what "show the whole page" means on this
aspect ratio — but it is a design choice, and Phase 6's reading backgrounds will fill it.

### 2026-08-21 — Phase 2: library and persistence
- Added `drift`, `sqlite3`, `file_picker`, `path_provider`, `flutter_riverpod`, `path`
- **Caught `drift_flutter` dragging in two banned EOL stubs** — dropped it, wired
  `NativeDatabase` directly instead. Nothing prohibited is in the tree.
- `lib/data/app_database.dart` — Drift schema: title, file name, cover, page count, last page,
  text-layer flag, added/last-opened timestamps
- `lib/data/book_repository.dart` — copies PDFs into app storage, renders page 1 as a cover
  PNG, samples pages for a text layer, seeds any bundled book on first run
- `lib/library/library_screen.dart` — cover grid, import via Files/iCloud, long-press to remove
- `lib/reader/reader_screen.dart` — opens at your saved page, writes position on every turn
- 8 tests, `flutter analyze` clean
- **Verified on the Simulator across cold launches:** set a page in the on-device SQLite,
  relaunched, and the shelf read "p. 47 / 137"; the reader reopened at page 47 and later at 88
- Two real bugs found and fixed while verifying:
  1. `ReaderScreen` used repository file paths without guaranteeing storage was initialised —
     it only worked because the library screen happened to run first. Now it waits on
     `startupProvider`, and the repository throws a readable error instead of
     `LateInitializationError` if anyone gets the order wrong again.
  2. Opening a book left it showing "Not started" forever, because pdfrx only reports page
     changes the reader actually makes.
- ⚠️ **Not yet verified by hand:** saving on an actual swipe. The write path is proven on
  device (opening a book writes to SQLite) and `saveLastPage` is unit-tested, but no test
  drives a real page-turn gesture. Worth confirming in Phase 3 when paging is built.

### 2026-08-21 — Phase 1: a PDF on screen
- Ran `./tool/preflight.sh` — exit 0 (only warning was "no Flutter project yet"; now resolved)
- `flutter create` in place: project `bookerize`, org `com.semsethy`, **iOS platform only**
- Added `pdfrx` 2.4.7; **no Podfile was generated and none exists anywhere in the tree** ✓
- Registered `assets/books/` in pubspec; `lib/main.dart` finds the first bundled PDF via
  `AssetManifest` and shows a plain "copy a PDF into assets/books/" message when none is there
- Left `pdfrx` text selection at its default (enabled) — Phases 4–5 depend on it
- Replaced the template widget test; `flutter analyze` clean, `flutter test` passing
- **Verified running on the iPhone 16 Pro Simulator** — the sample book renders and scrolls
- ⏱️ First iOS build takes **~20 minutes**: `pdfium_flutter` compiles three pdfium SDK slices
  (ios / ios-profile / ios-release) from source via SPM. Cached afterwards; later builds ~50s.
  On a new machine, expect this once and don't assume the build has hung.

### 2026-08-20 — Phase 0: prerequisite audit
- Upgraded Flutter 3.41.9 → **3.47.1**; enabled SPM explicitly
- Audited the full toolchain (Xcode, simulators, Node, git, disk) — all clear
- Verified every native plugin builds without CocoaPods by inspecting the pub cache directly
- **Found `isar` abandoned** (last publish 2023-04-25) → switched storage to `drift`
- **Found `sqlite3_flutter_libs` is an EOL stub** → excluded; `sqlite3` self-builds via hook
- **Found no maintained WordNet package** → we'll generate our own SQLite at Phase 4
- Resolved all 73 deps together in a scratch project, no conflicts; deleted the scratch
- Recorded CocoaPods prohibition as non-negotiable #0 in CLAUDE.md
- Wrote `tool/preflight.sh` so any new machine verifies itself before building; wired it
  into CLAUDE.md, README and the resume instructions. Unit-tested the version comparison
  (incl. `3.9` vs `3.44`) and confirmed blockers exit non-zero.
- **Still no application code written**

### 2026-08-20 — Planning
- Analyzed the sample PDF (137 pages; 91 with text, 46 illustration-only) — findings in PLAN.md §6
- Confirmed toolchain; found CocoaPods missing
- Settled distribution model and platform priority
- Wrote `PLAN.md`, `progress.md`, `CLAUDE.md`; initialized git
- **No application code written yet**

---

## Open questions

- [ ] App name — `bookerize` is a working title, easy to change before Phase 8
- [x] Which WordNet build to bundle — WordNet 3.1, single words only, 5 senses each: 12.3 MB
- [ ] In-app WordNet attribution before TestFlight (Phase 8) — the licence asks for it
- [ ] Background "animation" — what did you have in mind? Subtle gradient drift, paper
      texture, page-turn particles? Decide at Phase 6.
