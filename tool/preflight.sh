#!/usr/bin/env bash
#
# Bookerize preflight — verify every prerequisite before building.
#
#   ./tool/preflight.sh
#
# Exit 0 = ready to build. Exit 1 = at least one blocker.
#
# Written for macOS bash 3.2 (the system default) — no associative arrays,
# no `mapfile`, nothing from bash 4+.

set -u

RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YEL=$'\033[0;33m'; BLU=$'\033[0;34m'
DIM=$'\033[2m'; BLD=$'\033[1m'; RST=$'\033[0m'

BLOCKERS=0
WARNINGS=0

pass() { printf "  ${GRN}✓${RST} %-34s ${DIM}%s${RST}\n" "$1" "${2:-}"; }
warn() { printf "  ${YEL}!${RST} %-34s ${YEL}%s${RST}\n" "$1" "${2:-}"; WARNINGS=$((WARNINGS+1)); }
fail() { printf "  ${RED}✗${RST} %-34s ${RED}%s${RST}\n" "$1" "${2:-}"; BLOCKERS=$((BLOCKERS+1)); }
fixit() { printf "      ${DIM}→ %s${RST}\n" "$1"; }
section() { printf "\n${BLD}${BLU}%s${RST}\n" "$1"; }

# Compare dotted versions: ver_gte 3.47.1 3.44.0 -> 0 (true)
ver_gte() {
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)" = "$2" ]
}

printf "\n${BLD}Bookerize preflight${RST}\n"
printf "${DIM}%s${RST}\n" "$(date '+%Y-%m-%d %H:%M')"

# ─────────────────────────────────────────────────────────────
section "Required"

if command -v flutter >/dev/null 2>&1; then
  FV=$(flutter --version 2>/dev/null | head -1 | sed -n 's/.*Flutter \([0-9.]*\).*/\1/p')
  if [ -z "$FV" ]; then
    warn "Flutter" "installed, version unreadable"
    fixit "run 'flutter --version' manually and check it is >= 3.44"
  elif ver_gte "$FV" "3.44.0"; then
    pass "Flutter" "$FV"
  else
    fail "Flutter" "$FV — need >= 3.44"
    fixit "flutter upgrade      (3.44+ makes Swift Package Manager the iOS default)"
  fi
else
  fail "Flutter" "not installed"
  fixit "brew install --cask flutter"
fi

if command -v git >/dev/null 2>&1; then
  pass "Git" "$(git --version | awk '{print $3}')"
else
  fail "Git" "not installed"
  fixit "xcode-select --install"
fi

FREE=$(df -g . 2>/dev/null | tail -1 | awk '{print $4}')
if [ -n "${FREE:-}" ] && [ "$FREE" -ge 15 ] 2>/dev/null; then
  pass "Disk space" "${FREE}GB free"
elif [ -n "${FREE:-}" ]; then
  fail "Disk space" "${FREE}GB free — need ~15GB"
  fixit "Xcode + Flutter artifacts + simulators are large"
else
  warn "Disk space" "could not determine"
fi

# ─────────────────────────────────────────────────────────────
section "iOS build chain"

OS=$(uname -s)
if [ "$OS" != "Darwin" ]; then
  warn "Platform" "$OS — iOS builds require macOS"
  fixit "Android still works here; use a Mac for the iOS target"
else
  if command -v xcodebuild >/dev/null 2>&1; then
    XV=$(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}')
    if [ -n "$XV" ] && ver_gte "$XV" "26.0"; then
      pass "Xcode" "$XV"
    else
      warn "Xcode" "${XV:-unknown} — 26+ recommended"
    fi

    if xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
      pass "Xcode first-launch" "complete"
    else
      fail "Xcode first-launch" "not complete"
      fixit "sudo xcodebuild -runFirstLaunch"
    fi

    SIMS=$(xcrun simctl list devices available 2>/dev/null | grep -c "iPhone")
    if [ "${SIMS:-0}" -gt 0 ]; then
      pass "iOS Simulators" "$SIMS iPhone device(s)"
    else
      fail "iOS Simulators" "none available"
      fixit "Xcode → Settings → Components → install an iOS runtime"
    fi
  else
    fail "Xcode" "not installed"
    fixit "install Xcode from the App Store, then: sudo xcodebuild -runFirstLaunch"
  fi
fi

# ─────────────────────────────────────────────────────────────
section "Swift Package Manager  (CocoaPods is prohibited)"

if command -v flutter >/dev/null 2>&1; then
  SPM=$(flutter config --list 2>/dev/null | grep "enable-swift-package-manager" | sed 's/.*: //')
  case "$SPM" in
    true) pass "SPM enabled" "explicit" ;;
    "(Not set)")
      if [ -n "${FV:-}" ] && ver_gte "$FV" "3.44.0"; then
        warn "SPM enabled" "using default (on for 3.44+) — set it explicitly"
        fixit "flutter config --enable-swift-package-manager"
      else
        fail "SPM enabled" "not set, and Flutter < 3.44"
        fixit "flutter upgrade && flutter config --enable-swift-package-manager"
      fi ;;
    false)
      fail "SPM enabled" "explicitly disabled"
      fixit "flutter config --enable-swift-package-manager" ;;
    *) warn "SPM enabled" "unknown state: ${SPM:-empty}" ;;
  esac
fi

if command -v pod >/dev/null 2>&1; then
  warn "CocoaPods" "installed — this project must not use it"
  fixit "harmless if unused, but never add a Podfile (see CLAUDE.md non-negotiable #0)"
else
  pass "CocoaPods" "absent — correct"
fi

if [ -f "ios/Podfile" ]; then
  fail "ios/Podfile" "present — violates the no-CocoaPods rule"
  fixit "rm -rf ios/Podfile ios/Podfile.lock ios/Pods && flutter clean"
else
  pass "ios/Podfile" "absent — correct"
fi

# ─────────────────────────────────────────────────────────────
section "Project state"

if [ -f "pubspec.yaml" ]; then
  pass "Flutter project" "pubspec.yaml present"
  if grep -qE "^\s+isar:" pubspec.yaml 2>/dev/null; then
    fail "Storage package" "isar found — abandoned since 2023"
    fixit "use drift instead (see PLAN.md §3)"
  fi
  if grep -qE "^\s+sqlite3_flutter_libs:" pubspec.yaml 2>/dev/null; then
    warn "sqlite3_flutter_libs" "EOL no-op stub — remove it"
    fixit "sqlite3 3.x builds its own native lib via hook/build.dart"
  fi
else
  warn "Flutter project" "not created yet (expected before Phase 1)"
fi

BOOKS=$(ls assets/books/*.pdf 2>/dev/null | wc -l | tr -d ' ')
if [ "${BOOKS:-0}" -gt 0 ]; then
  pass "Sample book" "$BOOKS PDF(s) in assets/books/"
else
  warn "Sample book" "none — assets/books/*.pdf is gitignored"
  fixit "copy any TEXT-BASED pdf into assets/books/ (scanned PDFs will not work)"
fi

# ─────────────────────────────────────────────────────────────
section "Deferred  (not needed until later phases)"

if command -v node >/dev/null 2>&1; then
  pass "Node  (Phase 5 proxy)" "$(node --version)"
else
  warn "Node  (Phase 5 proxy)" "not installed"
  fixit "brew install node — only needed when the API proxy is built"
fi

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    pass "GitHub CLI" "authenticated"
  else
    warn "GitHub CLI" "installed, not authenticated"
    fixit "gh auth login"
  fi
else
  warn "GitHub CLI" "not installed (optional)"
fi

# ─────────────────────────────────────────────────────────────
printf "\n${BLD}────────────────────────────────────────────${RST}\n"
if [ "$BLOCKERS" -gt 0 ]; then
  printf "${RED}${BLD}  %d blocker(s), %d warning(s)${RST}\n" "$BLOCKERS" "$WARNINGS"
  printf "${DIM}  Fix the ✗ items above before building.${RST}\n\n"
  exit 1
elif [ "$WARNINGS" -gt 0 ]; then
  printf "${YEL}${BLD}  Ready to build${RST} ${DIM}— %d warning(s), none blocking${RST}\n\n" "$WARNINGS"
  exit 0
else
  printf "${GRN}${BLD}  All checks passed — ready to build${RST}\n\n"
  exit 0
fi
