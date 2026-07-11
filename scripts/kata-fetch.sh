#!/usr/bin/env bash
# scripts/kata-fetch.sh — GCTP-side URL→cache fetch orchestrator (KA-2 G-6 / TICKET-125.a).
#
# Populates a fetch-cache directory from a technology's canonical source URLs so
# CTP's `commands/acquire-technology-live.sh --technology <t> --project <id> --cache <dir>`
# can acquire rules against real content instead of hand-written stubs. The plugin
# ships the tech-canonical URLs at `standards/technology-source-registry.yaml`
# (§31.9 / P-18); this orchestrator downloads each URL, strips HTML to prose, and
# writes to `<cache>/<source_id>.txt` — the shape the live wrapper expects.
#
# Boundary: the network download IS the harness's job per CTP's §31.8 clarification
# ("the plugin makes no live network calls"). This script owns exactly that seam.
# It does not touch rule content extraction — that's CTP's acquire pipeline.
#
# Usage:
#   scripts/kata-fetch.sh --tech <name> --cache <dir> [--registry <yaml>] [--offline]
#
# Env overrides (testability):
#   KATA_FETCH_CURL_OPTS   default "--fail --silent --show-error --location --max-time 30"
#   KATA_FETCH_MIN_PROSE   default 500 — WARN if fewer than N chars of extracted prose
#                          per source (a hint that the site is JS-SPA and needs a
#                          markdown-source fallback URL — e.g., raw.githubusercontent.com)
#   KATA_FETCH_REGISTRY    default "$PLUGIN_CACHE/standards/technology-source-registry.yaml"
#
# Exit codes:
#   0  every registered source for the tech fetched cleanly to cache
#   1  one or more sources failed to fetch (network error, 404, empty response) OR
#      returned thin prose (below KATA_FETCH_MIN_PROSE); the operator can retry with
#      an alternate URL or supply --source-file directly to acquire-technology-live.sh
#   2  usage error (missing arg, unknown tech, registry not present)
#
# Portability: bash 3.2 + BSD coreutils + curl + python3 (for HTML-to-prose extraction).

set -u

TECH=""; CACHE_DIR=""; REGISTRY=""; OFFLINE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --tech) TECH="${2-}"; shift 2 ;;
        --cache) CACHE_DIR="${2-}"; shift 2 ;;
        --registry) REGISTRY="${2-}"; shift 2 ;;
        --offline) OFFLINE=1; shift ;;
        -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
        *) printf 'kata-fetch.sh: unknown arg: %s\n' "$1" >&2; exit 2 ;;
    esac
done

[ -n "$TECH" ]      || { printf 'kata-fetch.sh: --tech required\n' >&2; exit 2; }
[ -n "$CACHE_DIR" ] || { printf 'kata-fetch.sh: --cache <dir> required\n' >&2; exit 2; }

PLUGIN_CACHE=".harness/plugin-cache/claude-tdd-pro"
[ -n "$REGISTRY" ] || REGISTRY="$PLUGIN_CACHE/standards/technology-source-registry.yaml"
[ -f "$REGISTRY" ] || { printf 'kata-fetch.sh: registry missing at %s (run sync-plugin.sh --ensure)\n' "$REGISTRY" >&2; exit 2; }

CURL_OPTS="${KATA_FETCH_CURL_OPTS:---fail --silent --show-error --location --max-time 30}"
MIN_PROSE="${KATA_FETCH_MIN_PROSE:-500}"

mkdir -p "$CACHE_DIR" || { printf 'kata-fetch.sh: cannot create cache dir %s\n' "$CACHE_DIR" >&2; exit 2; }

# Extract the tech's canonical sources from the registry via python3 (yaml is
# a plugin dependency but this script stays python-only to avoid pulling the
# `yaml` module — we parse the shipped registry with a targeted regex-per-entry).
ENTRIES=$(TECH="$TECH" REGISTRY="$REGISTRY" python3 -c '
import os, re, sys
tech = os.environ["TECH"]
try:
    src = open(os.environ["REGISTRY"]).read()
except OSError as e:
    print("REGISTRY_READ_FAIL:" + str(e), file=sys.stderr); sys.exit(2)
# Find the tech section — matches:  <tech>:  followed by indented `-` list items
m = re.search(r"^\s{2,4}" + re.escape(tech) + r":\s*\n((?:\s{4,}-.*\n)+)", src, re.M)
if not m:
    print("UNKNOWN_TECH", file=sys.stderr); sys.exit(2)
# For each list-item line, extract source_id + url
for line in m.group(1).splitlines():
    sid_m = re.search(r"source_id:\s*([A-Za-z0-9_-]+)", line)
    url_m = re.search(r"url:\s*[\"\x27]([^\"\x27]+)[\"\x27]", line)
    if sid_m and url_m:
        print(sid_m.group(1) + "\t" + url_m.group(1))
' 2>&1)
_ec=$?
if [ "$_ec" -ne 0 ]; then
    case "$ENTRIES" in
        UNKNOWN_TECH*) printf 'kata-fetch.sh: tech %s not in registry %s (add via §31.4 PR)\n' "$TECH" "$REGISTRY" >&2 ;;
        *) printf 'kata-fetch.sh: registry parse failed: %s\n' "$ENTRIES" >&2 ;;
    esac
    exit 2
fi
if [ -z "$ENTRIES" ]; then
    printf 'kata-fetch.sh: tech %s in registry but has no canonical sources\n' "$TECH" >&2
    exit 2
fi

fetched=0; failed=0; thin=0
while IFS=$'\t' read -r sid url; do
    [ -z "$sid" ] && continue
    dest="$CACHE_DIR/$sid.txt"
    if [ "$OFFLINE" -eq 1 ]; then
        if [ -f "$dest" ]; then
            printf '  ✓ %-30s (offline: cache already populated)\n' "$sid" >&2
            fetched=$((fetched+1))
        else
            printf '  ✗ %-30s (offline: no cache)\n' "$sid" >&2
            failed=$((failed+1))
        fi
        continue
    fi
    # Fetch to a temp file so a partial download does not corrupt the cache.
    tmpf=$(mktemp -t kata-fetch.XXXXXX) || { printf '  ✗ %s (mktemp failed)\n' "$sid" >&2; failed=$((failed+1)); continue; }
    # shellcheck disable=SC2086 disable=SC2015
    if ! curl $CURL_OPTS -o "$tmpf" "$url" 2>/dev/null; then
        printf '  ✗ %-30s (curl failed: %s)\n' "$sid" "$url" >&2
        rm -f "$tmpf"
        failed=$((failed+1))
        continue
    fi
    # Convert HTML → prose (one meaningful sentence per line). Python stdlib
    # handles this cleanly:
    #   • Skip content inside script/style/noscript/svg (never rules).
    #   • Skip content inside nav/header/footer/aside (navigation cruft).
    #   • PREFER content inside main/article/section — when the doc has one, we
    #     use ONLY its text; otherwise fall back to whole-body text.
    #   • Split on sentence boundaries; keep substantive lines (≥ 30 chars).
    #   • Drop lines with menu-list signals (many pipes, many uppercase words in a
    #     row, or dense caps-first tokens — classic nav-menu shapes).
    prose_chars=$(SRC_FILE="$tmpf" DEST_FILE="$dest" python3 -c '
import os, re, sys
from html.parser import HTMLParser
class Extract(HTMLParser):
    SKIP_TAGS = ("script","style","noscript","svg","nav","header","footer","aside","form","button")
    PREFER_TAGS = ("main","article","section")
    def __init__(self):
        super().__init__()
        self.out = []              # whole-document fallback
        self.pref_out = []         # accumulated preferred-tag content
        self.skip = 0              # nesting depth of a SKIP_TAG
        self.pref_depth = 0        # nesting depth of a PREFER_TAG
    def handle_starttag(self, tag, attrs):
        if tag in self.SKIP_TAGS: self.skip += 1
        elif tag in self.PREFER_TAGS: self.pref_depth += 1
    def handle_endtag(self, tag):
        if tag in self.SKIP_TAGS and self.skip > 0: self.skip -= 1
        elif tag in self.PREFER_TAGS and self.pref_depth > 0: self.pref_depth -= 1
    def handle_data(self, data):
        if self.skip: return
        t = data.strip()
        if not t: return
        if self.pref_depth > 0: self.pref_out.append(t)
        self.out.append(t)
src = open(os.environ["SRC_FILE"], "rb").read().decode("utf-8", errors="replace")
p = Extract(); p.feed(src)
# Use main/article/section content when we saw enough of it; else whole body.
chosen = " ".join(p.pref_out) if len(" ".join(p.pref_out)) > 500 else " ".join(p.out)
# Split on sentence boundaries.
sents = re.split(r"(?<=[.!?])\s+", chosen)
lines = []
for s in sents:
    s = re.sub(r"\s+", " ", s).strip()
    if len(s) < 30: continue                        # too short — likely label
    if "{" in s or "}" in s: continue               # leaked JSX/JSON braces
    if s.startswith("//") or s.startswith("/*"): continue
    if s.count("|") >= 3: continue                  # nav breadcrumbs "A | B | C | D"
    # Drop lines that are mostly Title-Case tokens (nav menus) — heuristic:
    # count tokens matching /^[A-Z][a-z]+$/ and require < 40 percent of tokens.
    toks = s.split()
    if len(toks) >= 6:
        title_like = sum(1 for t in toks if re.match(r"^[A-Z][a-z]+$", t))
        if title_like / len(toks) > 0.4: continue
    # Drop lines with too many capitalized ALL-CAP words (nav headers).
    all_cap = sum(1 for t in toks if t.isupper() and len(t) > 1)
    if all_cap >= 3: continue
    # Sentences generally end with punctuation.
    if not re.search(r"[.!?]$", s): continue
    lines.append(s)
open(os.environ["DEST_FILE"], "w").write("\n".join(lines))
print(sum(len(l) for l in lines))
' 2>/dev/null)
    rm -f "$tmpf"
    if [ -z "$prose_chars" ] || [ "$prose_chars" -lt "$MIN_PROSE" ]; then
        printf '  ⚠ %-30s (fetched but prose=%s < %s chars — likely JS-SPA; try raw.githubusercontent.com fallback)\n' "$sid" "${prose_chars:-0}" "$MIN_PROSE" >&2
        thin=$((thin+1))
    else
        printf '  ✓ %-30s (prose=%s chars)\n' "$sid" "$prose_chars" >&2
    fi
    fetched=$((fetched+1))
done <<EOF
$ENTRIES
EOF

printf 'kata-fetch: fetched=%d thin=%d failed=%d tech=%s cache=%s\n' "$fetched" "$thin" "$failed" "$TECH" "$CACHE_DIR" >&2

# Exit 1 if any source failed to fetch OR came back thin (the operator needs to
# know before running acquire-technology-live.sh against a mostly-empty cache).
# Fetched-but-thin is a soft warning — the cache is populated with SOMETHING and
# acquire will still run; it just probably won't hit the ≥30-rule sufficiency floor.
if [ "$failed" -gt 0 ]; then exit 1; fi
if [ "$thin" -gt 0 ]; then exit 1; fi
exit 0
