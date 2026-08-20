# Progress

Living status file. **Update this at the end of every working session** so the project can be
picked up on any machine.

---

## 🔖 Resume here

> **Current phase:** Phase 0 — Environment setup
> **Next action:** Install CocoaPods, then run `flutter doctor` and fix any iOS blockers.
> **Blocked on:** Nothing.

### How to resume on a new laptop

```bash
git clone https://github.com/semsethy/Bookerize.git
cd Bookerize
# Copy any TEXT-BASED pdf into assets/books/ — sample books are gitignored (see below)
claude
```

Then say: **"Read progress.md and continue from the Resume here section."**

> ⚠️ **The sample book is not in the repo.** `assets/books/*.pdf` is gitignored because the
> test file is copyrighted and this repo is public. Drop your own text-based PDF in there
> before running the app. Scanned PDFs will not work — the app needs an embedded text layer.

Claude Code reads `CLAUDE.md` automatically, which points at `PLAN.md` and this file.

---

## Phase checklist

| # | Phase | Status | Notes |
|---|---|---|---|
| 0 | Environment setup | ⬜ Not started | CocoaPods missing |
| 1 | A PDF on screen | ⬜ Not started | |
| 2 | Library and persistence | ⬜ Not started | |
| 3 | Full-screen paging | ⬜ Not started | |
| 4 | Text interaction layer | ⬜ Not started | The hard one |
| 5 | AI layer (+ proxy) | ⬜ Not started | Needs Cloudflare account |
| 6 | Notes and backgrounds | ⬜ Not started | |
| 7 | Page curl | ⬜ Not started | Hybrid approach — see PLAN.md §5 |
| 8 | TestFlight | ⬜ Not started | Needs Apple Developer Program ($99/yr) |

Legend: ⬜ not started · 🟡 in progress · ✅ done · 🔴 blocked

---

## Environment status

Checked on Sethy's Mac, 2026-08-20:

| Tool | Status | Notes |
|---|---|---|
| Flutter | ✅ 3.41.9 | Homebrew Caskroom |
| Xcode | ✅ 26.3 | Build 17C519 |
| Node | ✅ v26.0.0 | For the Cloudflare Worker proxy |
| Git | ✅ 2.50.1 | |
| **CocoaPods** | ❌ **Missing** | `sudo gem install cocoapods` — required for Flutter iOS |
| Apple Developer Program | ❌ Not enrolled | Only needed at Phase 8 (and for physical-device testing) |
| Cloudflare account | ❌ Not set up | Only needed at Phase 5 |

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
| 2026-08-20 | `claude-opus-5` with streaming | Explanation quality; streaming hides latency |
| 2026-08-20 | Hybrid dictionary: offline WordNet + AI for context | Instant and free for the common case; AI only for genuine ambiguity |

---

## Session log

Newest first. One entry per working session.

### 2026-08-20 — Planning
- Analyzed the sample PDF (137 pages; 91 with text, 46 illustration-only) — findings in PLAN.md §6
- Confirmed toolchain; found CocoaPods missing
- Settled distribution model and platform priority
- Wrote `PLAN.md`, `progress.md`, `CLAUDE.md`; initialized git
- **No application code written yet**

---

## Open questions

- [ ] App name — `bookerize` is a working title, easy to change before Phase 8
- [ ] Which WordNet build to bundle (size vs. coverage trade-off) — decide at Phase 4
- [ ] Background "animation" — what did you have in mind? Subtle gradient drift, paper
      texture, page-turn particles? Decide at Phase 6.
