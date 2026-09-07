#!/usr/bin/env bash
# structure_check.sh — deterministic M1-M10 / R1,R2,R4-R8 evaluator for a
# claude-plugin marketplace repo.
#
# Ported from the SSOT bats fixture at
#   dEitY719/dotfiles:tests/bats/skills/_fixtures/claude_plugin_structure.sh
# Keep the check logic in sync with that fixture and with
#   ../references/structure-spec.md (the full behavioral spec).
#
# R3 ("README is Simple") is intentionally NOT evaluated here — its heuristic
# needs model judgment (length + semantic "mentions", see structure-spec.md
# -> "R3 README Simple heuristic"); SKILL.md Step 3 evaluates it directly and
# folds it into the final verdict.
#
# Usage:
#   structure_check.sh <repo-path> [--single|--mono]
#
# Output (stdout): one context/result line per token, in this order —
#   MODE <single|mono> <signal>
#   PLUGINS <name> [<name> ...]        (or "." for single-mode root, or empty)
#   SKILLS <plugin>:<skill> [...]      (space-separated, empty if none)
#   GIT <yes|no>
#   M1 <PASS|FAIL>
#   M2 <PASS|FAIL>
#   M3 <PASS|FAIL|N/A> [detail]
#   M4 <PASS|FAIL|N/A> [detail]
#   M5 <PASS|FAIL>
#   M6 <PASS|FAIL>
#   M7 <PASS|FAIL|N/A> [detail]
#   M8 <PASS|FAIL|N/A> [detail]
#   M9 <PASS|FAIL|N/A> [detail]
#   M10 <PASS|FAIL|N/A> [detail]
#   R1 <PASS|WARN|N/A> [detail]
#   R2 <PASS|WARN|N/A> [detail]
#   R4 <PASS|WARN|N/A> [detail]
#   R5 <PASS|WARN|N/A> [detail]
#   R6 <PASS|WARN|N/A>
#   R7 <PASS|WARN|N/A>
#   R8 <PASS|WARN|N/A>
#   SUMMARY <FAIL|WARN|PASS> fail=<n> warn=<n> na=<n>
#
# `detail` (when present) names the failing/warning path or subject so
# SKILL.md's Step 4 can render the report-template.md prose without
# re-deriving it. SUMMARY covers only the checks this script runs (R3 is
# excluded) — the caller combines it with its own R3 judgment.
#
# Requires jq (all M1/M3/M7-M10/R6-R7 JSON checks go through it) — a clear
# error and exit 127 if it's missing, never a silent false FAIL.
#
# Exit: 0 all PASS/N/A, 1 any WARN (no FAIL), 2 any FAIL — over the checks
# this script runs. 64 on bad usage, 66 if <repo-path> is not a directory,
# 127 if jq is missing.
# shellcheck disable=SC2317 # check_* functions are invoked indirectly via `check_"$id"`
set -u

repo="${1:-}"
forced_flag="${2:-}"

usage() {
    echo "usage: structure_check.sh <repo-path> [--single|--mono]" >&2
}

if [ -z "$repo" ]; then
    usage
    exit 64
fi

forced=""
case "$forced_flag" in
--single) forced=single ;;
--mono) forced=mono ;;
"") ;;
*)
    usage
    exit 64
    ;;
esac

if [ ! -d "$repo" ]; then
    echo "error: no such directory: $repo" >&2
    exit 66
fi

# jq drives every JSON check below (M1, M3, M7-M10, R6-R7). Without this
# guard a missing jq makes `jq empty` fail like a parse error, so every JSON
# check would silently report FAIL instead of naming the real problem
# (codex review, PR #19).
if ! command -v jq >/dev/null 2>&1; then
    echo "error: jq is required but was not found in PATH" >&2
    exit 127
fi

# ---- JSON validity ---------------------------------------------------------
_json_ok() { [ -f "$1" ] && jq empty "$1" >/dev/null 2>&1; }

# ---- frontmatter extraction -------------------------------------------------
_frontmatter() {
    # $1=file -> echoes the lines strictly between the first `---` line and
    # the next `---` line (the YAML frontmatter block); nothing if the file
    # doesn't open with `---`. A bare `grep '^name:'` over the whole file
    # would also match `name:` in the body (e.g. a code-block example) —
    # M4/R4 must only ever see this block (agy+codex review, PR #19).
    awk '
        NR==1 { if ($0=="---") { infm=1; next } else { exit } }
        infm && $0=="---" { exit }
        infm { print }
    ' "$1"
}

# echo N/A + return 1 unless $1 is valid JSON — the bare guard shared by
# check_M9/R6/R7.
_require_json_or_na() { _json_ok "$1" || { echo "N/A"; return 1; }; }

# echo N/A + return 1 unless $1 is valid JSON with >=1 .plugins[] entry — the
# guard shared by check_M7/M8 before they diverge into different jq filters.
_plugins_or_na() {
    local n
    _require_json_or_na "$1" || return 1
    n="$(jq '(.plugins // []) | length' "$1" 2>/dev/null || echo 0)"
    [ "${n:-0}" -ge 1 ] || { echo "N/A"; return 1; }
}

# ---- dynamic discovery ------------------------------------------------------
_plugins() {
    [ -d "$1/plugins" ] || return 0
    for p in "$1"/plugins/*/; do
        [ -d "$p" ] || continue
        basename "$p"
    done
}

_skills_in_root() {
    # $1=repo $2=root(relative) -> skill basenames under <root>/skills/.
    local sd="$1/$2/skills"
    [ -d "$sd" ] || return 0
    for s in "$sd"/*/; do
        [ -d "$s" ] || continue
        basename "$s"
    done
}

# ---- mode detection + plugin-root abstraction ------------------------------
detect_mode() {
    local mf src
    case "$forced" in
    single | mono)
        echo "$forced"
        return
        ;;
    esac
    mf="$repo/.claude-plugin/marketplace.json"
    if _json_ok "$mf"; then
        src="$(jq -r '.plugins[]? | if type=="object" then .source else . end' "$mf" 2>/dev/null | head -n1)"
        case "$src" in
        ./ | .)
            echo single
            return
            ;;
        plugins/* | ./plugins/*)
            echo mono
            return
            ;;
        esac
    fi
    if [ -d "$repo/plugins" ] && [ -n "$(_plugins "$repo")" ]; then
        echo mono
        return
    fi
    [ -f "$repo/.claude-plugin/plugin.json" ] && {
        echo single
        return
    }
    echo mono # still ambiguous -> default (report notes "추정")
}

plugin_roots() {
    # $1=mode -> plugin-root paths relative to $repo, one per line.
    local mode="$1" p
    if [ "$mode" = single ]; then
        [ -f "$repo/.claude-plugin/plugin.json" ] && echo "."
        return
    fi
    [ -d "$repo/plugins" ] || return 0
    for p in "$repo"/plugins/*/; do
        [ -d "$p" ] || continue
        echo "plugins/$(basename "$p")"
    done
}

MODE="$(detect_mode)"
mapfile -t ROOTS < <(plugin_roots "$MODE")

# Every (plugin-root, skill) pair, computed once and reused by every check
# and the SKILLS context line below — avoids re-globbing skills/ per check.
mapfile -t SKILL_PAIRS < <(
    for root in "${ROOTS[@]}"; do
        [ -n "$root" ] || continue
        while IFS= read -r s; do
            [ -n "$s" ] || continue
            echo "$root $s"
        done <<EOF
$(_skills_in_root "$repo" "$root")
EOF
    done
)

# ---- mandatory checks (M1-M10) ---------------------------------------------
check_M1() { _json_ok "$repo/.claude-plugin/marketplace.json" && echo PASS || echo FAIL; }

check_M2() { [ "${#ROOTS[@]}" -ge 1 ] && echo PASS || echo FAIL; }

check_M3() {
    local root any=0
    for root in "${ROOTS[@]}"; do
        [ -n "$root" ] || continue
        any=1
        _json_ok "$repo/$root/.claude-plugin/plugin.json" || {
            echo "FAIL $root/.claude-plugin/plugin.json"
            return
        }
    done
    [ "$any" -eq 1 ] && echo PASS || echo "N/A"
}

check_M4() {
    local pair root s sm fm
    for pair in "${SKILL_PAIRS[@]}"; do
        [ -n "$pair" ] || continue
        root="${pair%% *}"
        s="${pair#* }"
        sm="$repo/$root/skills/$s/SKILL.md"
        [ -f "$sm" ] || {
            echo "FAIL $root/skills/$s/SKILL.md"
            return
        }
        fm="$(_frontmatter "$sm")"
        if ! grep -q '^name:' <<<"$fm" || ! grep -q '^description:' <<<"$fm"; then
            echo "FAIL $root/skills/$s/SKILL.md"
            return
        fi
    done
    [ "${#SKILL_PAIRS[@]}" -ge 1 ] && echo PASS || echo "N/A"
}

check_M5() { [ -d "$repo/docs/skill-guides" ] && [ -d "$repo/docs/skill-output" ] && echo PASS || echo FAIL; }

check_M6() { [ -f "$repo/README.md" ] && echo PASS || echo FAIL; }

check_M7() {
    local mf="$repo/.claude-plugin/marketplace.json" bad
    _plugins_or_na "$mf" || return
    bad="$(jq -r '[(.plugins // [])[] | select(type=="object") | select(has("source")|not)] | length' "$mf" 2>/dev/null || echo 1)"
    [ "${bad:-1}" -eq 0 ] && echo PASS || echo "FAIL marketplace.json"
}

check_M8() {
    local mf="$repo/.claude-plugin/marketplace.json" bad
    _plugins_or_na "$mf" || return
    bad="$(jq '
      [ (.plugins // [])[]
        | ( if type=="object" then . else { "source": . } end ) as $e
        | ($e.source) as $s
        | select( if type=="object" then has("source") else true end )
        | select(
            ( ($s|type=="string") and
              ( $s=="." or $s=="./" or ($s|test("^(\\./)?plugins/[^/]+/?$")) ) )
            or
            ( $s=="url" and (($e.url // "")|type=="string") and (($e.url // "")|length>0) )
          | not )
      ] | length' "$mf" 2>/dev/null || echo 1)"
    [ "${bad:-1}" -eq 0 ] && echo PASS || echo "FAIL marketplace.json"
}

check_M9() {
    local mf="$repo/.claude-plugin/marketplace.json" paths p any=0
    [ "$MODE" = mono ] || {
        echo "N/A"
        return
    }
    _require_json_or_na "$mf" || return
    paths="$(jq -r '(.plugins // [])[]
        | ( if type=="object" then .source else . end )
        | select(type=="string")
        | select(test("^(\\./)?plugins/[^/]+/?$"))' "$mf" 2>/dev/null)"
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        any=1
        p="${p#./}"
        p="${p%/}"
        [ -d "$repo/$p" ] || {
            echo "FAIL $p"
            return
        }
    done <<EOF
$paths
EOF
    [ "$any" -eq 1 ] && echo PASS || echo "N/A"
}

# Known top-level plugin.json fields (Claude Code manifest schema). Last
# verified 2026-09 against Claude Code 2.1.263 — SSOT mirror of
# ../references/structure-spec.md -> "plugin.json known fields (M10)" and
# dotfiles:tests/bats/skills/_fixtures/claude_plugin_structure.sh
# (_CPS_PLUGIN_JSON_KNOWN_FIELDS). `skills` is intentionally NOT here — the
# runtime auto-scans skills/, and a skills field fails manifest validation.
KNOWN_PLUGIN_JSON_FIELDS='["name","version","description","author","homepage","repository","license","keywords"]'

check_M10() {
    local root pj unknown any=0
    for root in "${ROOTS[@]}"; do
        [ -n "$root" ] || continue
        pj="$repo/$root/.claude-plugin/plugin.json"
        _json_ok "$pj" || continue
        any=1
        unknown="$(jq --argjson k "$KNOWN_PLUGIN_JSON_FIELDS" \
            '[keys[] | select(. as $x | $k | index($x) | not)] | length' \
            "$pj" 2>/dev/null || echo 1)"
        [ "${unknown:-1}" -eq 0 ] || {
            echo "FAIL $root/.claude-plugin/plugin.json"
            return
        }
    done
    [ "$any" -eq 1 ] && echo PASS || echo "N/A"
}

# ---- recommended checks (R1,R2,R4-R8; R3 is a model judgment call) ---------
check_R1() {
    local pair s
    for pair in "${SKILL_PAIRS[@]}"; do
        [ -n "$pair" ] || continue
        s="${pair#* }"
        [ -f "$repo/docs/skill-guides/$s.html" ] || {
            echo "WARN $s"
            return
        }
    done
    [ "${#SKILL_PAIRS[@]}" -ge 1 ] && echo PASS || echo "N/A"
}

check_R2() {
    local pair s
    for pair in "${SKILL_PAIRS[@]}"; do
        [ -n "$pair" ] || continue
        s="${pair#* }"
        { [ -f "$repo/docs/skill-output/$s-usage.html" ] ||
            [ -f "$repo/docs/skill-output/$s-usage.md" ]; } || {
            echo "WARN $s"
            return
        }
    done
    [ "${#SKILL_PAIRS[@]}" -ge 1 ] && echo PASS || echo "N/A"
}

check_R4() {
    # naming: SKILL.md name: must be bare and == the skill directory basename.
    local pair root s any=0 sm name fm
    for pair in "${SKILL_PAIRS[@]}"; do
        [ -n "$pair" ] || continue
        root="${pair%% *}"
        s="${pair#* }"
        sm="$repo/$root/skills/$s/SKILL.md"
        [ -f "$sm" ] || continue
        any=1
        fm="$(_frontmatter "$sm")"
        name="$(grep -m1 '^name:' <<<"$fm" | sed 's/^name:[[:space:]'\''" ]*//;s/[[:space:]'\''" ]*$//')"
        [ "$name" = "$s" ] || {
            echo "WARN $s ($name)"
            return
        }
    done
    [ "$any" -eq 1 ] && echo PASS || echo "N/A"
}

check_R5() {
    local pair s
    [ -f "$repo/README.md" ] || {
        echo "N/A"
        return
    }
    for pair in "${SKILL_PAIRS[@]}"; do
        [ -n "$pair" ] || continue
        s="${pair#* }"
        grep -qF "skill-guides/$s.html" "$repo/README.md" || {
            echo "WARN $s"
            return
        }
        { grep -qF "skill-output/$s-usage.html" "$repo/README.md" ||
            grep -qF "skill-output/$s-usage.md" "$repo/README.md"; } || {
            echo "WARN $s"
            return
        }
    done
    [ "${#SKILL_PAIRS[@]}" -ge 1 ] && echo PASS || echo "N/A"
}

check_R6() {
    local mf="$repo/.claude-plugin/marketplace.json"
    _require_json_or_na "$mf" || return
    [ "$(jq -r 'has("$schema")' "$mf" 2>/dev/null)" = "true" ] && echo PASS || echo WARN
}

check_R7() {
    local mf="$repo/.claude-plugin/marketplace.json" missing
    _require_json_or_na "$mf" || return
    [ "$(jq -r '(has("description") and (.description|type=="string") and (.description|length>0))' "$mf" 2>/dev/null)" = "true" ] || {
        echo WARN
        return
    }
    missing="$(jq '[(.plugins // [])[] | select(type=="object") | select((has("homepage")|not) or (.homepage|type!="string") or (.homepage|length==0))] | length' "$mf" 2>/dev/null || echo 0)"
    [ "${missing:-0}" -eq 0 ] && echo PASS || echo WARN
}

check_R8() {
    local rm="$repo/README.md" line
    [ -f "$rm" ] || {
        echo "N/A"
        return
    }
    grep -q 'plugin marketplace add' "$rm" || {
        echo "N/A"
        return
    }
    line="$(grep -m1 'plugin marketplace add' "$rm")"
    case "$line" in
    *marketplace.json*) echo PASS ;;
    *.git*) echo WARN ;;
    *) echo PASS ;;
    esac
}

# ---- emit context lines -----------------------------------------------------
if [ "$MODE" = single ]; then
    plugins_list="."
else
    plugins_list="$(_plugins "$repo" | tr '\n' ' ')"
    plugins_list="${plugins_list% }"
fi
[ -n "$plugins_list" ] || plugins_list="(none)"

skills_list=""
for pair in "${SKILL_PAIRS[@]}"; do
    [ -n "$pair" ] || continue
    root="${pair%% *}"
    s="${pair#* }"
    skills_list="$skills_list ${root##*/}:$s"
done
skills_list="${skills_list# }"
[ -n "$skills_list" ] || skills_list="(none)"

git_present="no"
[ -e "$repo/.git" ] && git_present="yes" # dir (repo) or file (worktree)

echo "MODE $MODE"
echo "PLUGINS $plugins_list"
echo "SKILLS $skills_list"
echo "GIT $git_present"

# ---- run + tally -------------------------------------------------------------
fail=0
warn=0
na=0

for id in M1 M2 M3 M4 M5 M6 M7 M8 M9 M10; do
    result="$(check_"$id")"
    echo "$id $result"
    case "$result" in
    FAIL*) fail=$((fail + 1)) ;;
    "N/A") na=$((na + 1)) ;;
    esac
done

for id in R1 R2 R4 R5 R6 R7 R8; do
    result="$(check_"$id")"
    echo "$id $result"
    case "$result" in
    WARN*) warn=$((warn + 1)) ;;
    "N/A") na=$((na + 1)) ;;
    esac
done

if [ "$fail" -gt 0 ]; then
    verdict=FAIL
    code=2
elif [ "$warn" -gt 0 ]; then
    verdict=WARN
    code=1
else
    verdict=PASS
    code=0
fi

echo "SUMMARY $verdict fail=$fail warn=$warn na=$na"
exit "$code"
