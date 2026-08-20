# Progress

Living status file. **Update this at the end of every working session** so the project can be
picked up on any machine.

---

## 🔖 Resume here

> **Current phase:** Phase 0 ✅ complete → starting **Phase 1 (A PDF on screen)**
> **Next action:** run `./tool/preflight.sh`, then `flutter doctor`, boot the Simulator, `flutter create`
> the real app and get the sample book rendering.
> **Blocked on:** Nothing.

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
| Cloudflare account + `wrangler` | Phase 5 | ❌ Not set up |
| WordNet dictionary data | Phase 4 | ⚠️ No maintained Flutter package exists. Princeton raw data is reachable (HTTP 200) — we'll build our own SQLite from it as a one-time preprocessing step. |
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
| 2026-08-20 | `claude-opus-5` with streaming | Explanation quality; streaming hides latency |
| 2026-08-20 | Hybrid dictionary: offline WordNet + AI for context | Instant and free for the common case; AI only for genuine ambiguity |
| 2026-08-20 | **Swift Package Manager, not CocoaPods** | Verified `pdfium_flutter` (pdfrx's native layer) ships `darwin/pdfium_flutter/Package.swift`. SPM is default from Flutter 3.44. The CocoaPods registry goes read-only 2026-12-02, so building on it now would start on a sunset dependency. *(Superseded same day by the outright prohibition below.)* |
| 2026-08-20 | Upgrade Flutter 3.41.9 → 3.47.1 | Gets SPM-by-default; no code written yet so the upgrade carries no regression risk |
| 2026-08-20 | **CocoaPods prohibited outright** | Owner constraint. If a package needs CocoaPods, replace the package — never install it as a fallback. Verified the whole stack builds without it. |
| 2026-08-20 | **Isar → Drift** for local storage | Isar's last publish was 2023-04-25 (3+ years stale, effectively abandoned). Drift is active (2026-07-27), SQLite-backed, so app data and the WordNet dictionary share one engine instead of two. |
| 2026-08-20 | Do not add `sqlite3_flutter_libs` | It is now an EOL no-op stub. `sqlite3` 3.5.2 builds its own native lib via `hook/build.dart`. |
| 2026-08-20 | Build our own WordNet SQLite | No maintained Flutter WordNet package exists (`dictionaryx` last published 2022). Princeton raw data is available; one-time preprocessing gives us control over bundle size. |

---

## Session log

Newest first. One entry per working session.

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
- [ ] Which WordNet build to bundle (size vs. coverage trade-off) — decide at Phase 4
- [ ] Background "animation" — what did you have in mind? Subtle gradient drift, paper
      texture, page-turn particles? Decide at Phase 6.
