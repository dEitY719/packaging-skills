#!/usr/bin/env bash
# skills/structure-refactor/lib/refactor_apply.sh — deterministic apply engine
# for the M1,M3,M5-M7,M10 / R1,R2,R4,R5 fixes over a claude-plugin marketplace
# repo (packaging-skills#8).
#
# Reuses ../../structure-check/lib/structure_check.sh for mode-aware plugin/
# skill discovery (its MODE/PLUGINS/SKILLS/GIT context lines) instead of
# re-deriving that logic here — one implementation scores and fixes a repo,
# not two prose specs (packaging-skills#8's Check-12 FAIL). It also reuses
# ../../rename-repo/lib/parse_remote.sh for host/owner/repo parsing (Pages
# activation + R5 link URLs), the same helper packaging:rename-repo uses.
#
# R1's real guide content comes from delegating to /visuals:visualize, an AI
# skill invocation that cannot live in a shell script. SKILL.md Step 4 must
# call that FIRST, for every skill missing docs/skill-guides/<s>.html, before
# invoking this script — this script only ever writes the documented TODO
# fallback stub for whatever guide is still missing afterward (delegation
# unavailable or failed). It never calls /visuals:visualize itself.
#
# ponytail: M2/M4/M8/M9 FAILs have no auto-fix defined in
# references/plan-and-report-templates.md (a missing plugin root, a stray
# SKILL.md outside skills/<s>/, or a malformed plugins[].source shape all
# need a human decision, not a guess) — this script reports nothing for them
# and leaves the WARN/FAIL standing; re-run `structure-check` to see it.
#
# Usage:
#   refactor_apply.sh <repo-path> --mode single|mono --scope mp|op [--apply]
#
# Output (stdout):
#   MODE <single|mono>
#   SCOPE <mp|op>
#   ROOTS <root ...>            (repo-relative, or "(none)")
#   [<ID>] <verb>  <detail>     one line per pending change, in apply order
#   ...
#   SUMMARY applied=<n> created=<n> sourced=<n> pruned=<n> stubbed=<n> renamed=<n> linked=<n> pages=<activated|active|skip|n/a>
#
# `applied` counts plan lines actually executed (0 on a dry run). An empty
# plan is success (idempotent: nothing left to fix), never a failure.
#
# Exit: 0 on a normal run (dry-run or apply, any plan size); 64 bad usage;
# 66 <repo-path> not a directory; 127 jq/git missing.
# shellcheck disable=SC2153,SC2154 # HOST/OWNER/REPO come from the %q-quoted
# eval of parse_remote.sh's stdout (see the two `eval "$remote_vars…"` call
# sites below), not a typo of the local `repo` variable.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/../../structure-check/lib/structure_check.sh"
PARSE_REMOTE="$HERE/../../rename-repo/lib/parse_remote.sh"

usage() {
    echo "usage: refactor_apply.sh <repo-path> --mode single|mono --scope mp|op [--apply]" >&2
}

repo=""
mode=""
scope=""
apply=0

while [ $# -gt 0 ]; do
    case "$1" in
    --mode)
        mode="${2:-}"
        shift 2
        ;;
    --scope)
        scope="${2:-}"
        shift 2
        ;;
    --apply)
        apply=1
        shift
        ;;
    -*)
        usage
        exit 64
        ;;
    *)
        [ -z "$repo" ] || {
            usage
            exit 64
        }
        repo="$1"
        shift
        ;;
    esac
done

[ -n "$repo" ] || {
    usage
    exit 64
}
case "$mode" in single | mono) ;; *)
    usage
    exit 64
    ;;
esac
case "$scope" in mp | op) ;; *)
    usage
    exit 64
    ;;
esac

if [ ! -d "$repo" ]; then
    echo "error: no such directory: $repo" >&2
    exit 66
fi

for bin in jq git; do
    command -v "$bin" >/dev/null 2>&1 || {
        echo "error: $bin is required but was not found in PATH" >&2
        exit 127
    }
done

repo="$(cd "$repo" && pwd)"
repo_base="$(basename "$repo")"

# ---- discovery: reuse structure_check.sh's context lines --------------------
eval_out="$(bash "$CHECK" "$repo" "--$mode" 2>/dev/null)"
plugins_line="$(grep -m1 '^PLUGINS ' <<<"$eval_out" | cut -d' ' -f2-)"
skills_line="$(grep -m1 '^SKILLS ' <<<"$eval_out" | cut -d' ' -f2-)"
git_line="$(grep -m1 '^GIT ' <<<"$eval_out" | cut -d' ' -f2-)"
git_repo=0
[ "$git_line" = "yes" ] && git_repo=1

ROOTS=()
if [ "$mode" = single ]; then
    # single mode has exactly one possible root: the repo itself. Unlike the
    # read-only evaluator (which only counts "." once plugin.json exists — a
    # bootstrap chicken/egg it can live with), the fixer's whole job is to
    # create what's missing, so "." is always a candidate root here.
    ROOTS=(".")
elif [ "$plugins_line" != "(none)" ]; then
    read -r -a _plugin_names <<<"$plugins_line"
    for p in "${_plugin_names[@]}"; do ROOTS+=("plugins/$p"); done
fi

SKILL_PAIRS=()
if [ "$skills_line" != "(none)" ]; then
    read -r -a _pairs <<<"$skills_line"
    for pr in "${_pairs[@]}"; do
        s="${pr#*:}"
        if [ "$mode" = single ]; then
            SKILL_PAIRS+=(". $s")
        else
            SKILL_PAIRS+=("plugins/${pr%%:*} $s")
        fi
    done
fi

# ---- plan + counters --------------------------------------------------------
plan=()
created=0
sourced=0
pruned=0
stubbed=0
renamed=0
linked=0
pages_status="n/a"

add_plan() { plan+=("$1"); }

# ---- M5 (+ per-root scaffolding dirs from Apply rule 1) ---------------------
mkdir_needed=()
[ -d "$repo/docs/skill-guides" ] || mkdir_needed+=("docs/skill-guides")
[ -d "$repo/docs/skill-output" ] || mkdir_needed+=("docs/skill-output")
[ -d "$repo/.claude-plugin" ] || mkdir_needed+=(".claude-plugin")
for root in "${ROOTS[@]}"; do
    [ -d "$repo/$root/.claude-plugin" ] || mkdir_needed+=("$root/.claude-plugin")
    [ -d "$repo/$root/skills" ] || mkdir_needed+=("$root/skills")
done
for d in "${mkdir_needed[@]}"; do
    add_plan "[M5] mkdir   $d/"
    if [ "$apply" -eq 1 ]; then
        mkdir -p "$repo/$d"
        created=$((created + 1))
    fi
done

# ---- M1: marketplace.json skeleton ------------------------------------------
mf="$repo/.claude-plugin/marketplace.json"
if [ ! -e "$mf" ]; then
    if [ "$mode" = single ]; then
        plugins_json='[{"source":"./"}]'
    else
        names=()
        for root in "${ROOTS[@]}"; do names+=("$(basename "$root")"); done
        [ "${#names[@]}" -gt 0 ] || names=("$repo_base")
        plugins_json="$(jq -n --args '$ARGS.positional | map("./plugins/" + .)' "${names[@]}")"
    fi
    add_plan "[M1] create  .claude-plugin/marketplace.json (skeleton)"
    if [ "$apply" -eq 1 ]; then
        mkdir -p "$repo/.claude-plugin"
        jq -n --arg name "$repo_base" --argjson plugins "$plugins_json" \
            '{name: $name, plugins: $plugins}' >"$mf"
        created=$((created + 1))
    fi
fi

# ---- M3: per-root plugin.json skeleton --------------------------------------
for root in "${ROOTS[@]}"; do
    pj="$repo/$root/.claude-plugin/plugin.json"
    if [ ! -e "$pj" ]; then
        pname="$(basename "$root")"
        [ "$root" = "." ] && pname="$repo_base"
        add_plan "[M3] create  $root/.claude-plugin/plugin.json (skeleton)"
        if [ "$apply" -eq 1 ]; then
            mkdir -p "$(dirname "$pj")"
            jq -n --arg name "$pname" '{name: $name, version: "0.0.0"}' >"$pj"
            created=$((created + 1))
        fi
    fi
done

# ---- M6: README.md stub ------------------------------------------------------
if [ ! -e "$repo/README.md" ]; then
    add_plan "[M6] create  README.md (stub)"
    if [ "$apply" -eq 1 ]; then
        printf '# %s\n' "$repo_base" >"$repo/README.md"
        created=$((created + 1))
    fi
fi

# ---- M7: plugins[].source injection (mandatory; runs under --mp and --op) --
# Apply rule 3b. The fix is naturally idempotent (only touches elements
# missing `source`), so it runs unconditionally on any valid marketplace.json
# rather than needing structure_check.sh's FAIL verdict first.
if [ -e "$mf" ] && jq empty "$mf" >/dev/null 2>&1; then
    missing_before="$(jq '[(.plugins // [])[] | select(type=="object") | select(has("source")|not)] | length' "$mf" 2>/dev/null || echo 0)"
    if [ "${missing_before:-0}" -gt 0 ]; then
        add_plan "[M7] source  marketplace.json ← plugins[].source 주입 ($missing_before)"
        if [ "$apply" -eq 1 ]; then
            tmp="$(mktemp)"
            jq --arg mode "$mode" '
              (.plugins // []) |= map(
                if (type == "object") and (has("source") | not) then
                  ((.homepage // .repository // "")) as $g
                  | if ($g | type == "string") and ($g | endswith(".git")) then
                      . + {source: "url", url: $g}
                    else
                      . + {source: (if $mode == "mono" then "./plugins/" + (.name // "") else "./" end)}
                    end
                else
                  .
                end
              )
            ' "$mf" >"$tmp" && mv "$tmp" "$mf"
            sourced=$((sourced + missing_before))
        fi
    fi
fi

# ---- M10: unknown plugin.json field prune (mandatory) -----------------------
# Apply rule 3c. SSOT for the whitelist: structure-check's
# lib/structure_check.sh KNOWN_PLUGIN_JSON_FIELDS — kept in step by hand
# (bump both on a manifest-schema change) since sourcing that script would
# re-run its whole top-level evaluation.
KNOWN_PLUGIN_JSON_FIELDS='["name","version","description","author","homepage","repository","license","keywords"]'
for root in "${ROOTS[@]}"; do
    pj="$repo/$root/.claude-plugin/plugin.json"
    [ -e "$pj" ] || continue
    jq empty "$pj" >/dev/null 2>&1 || continue
    unknown_n="$(jq --argjson k "$KNOWN_PLUGIN_JSON_FIELDS" \
        '[keys[] | select(. as $x | $k | index($x) | not)] | length' "$pj" 2>/dev/null || echo 0)"
    if [ "${unknown_n:-0}" -gt 0 ]; then
        add_plan "[M10] prune  $root/.claude-plugin/plugin.json ← 미지원 필드 제거 (.bak 백업, $unknown_n)"
        if [ "$apply" -eq 1 ]; then
            cp "$pj" "$pj.bak"
            tmp="$(mktemp)"
            jq --argjson k "$KNOWN_PLUGIN_JSON_FIELDS" \
                'with_entries(select(.key as $x | $k | index($x)))' "$pj" >"$tmp" && mv "$tmp" "$pj"
            pruned=$((pruned + unknown_n))
        fi
    fi
done

# ---- --op only: R1 fallback stub, R2 stub, Pages, R4 rename, R5 links ------
if [ "$scope" = op ]; then
    # R1 — fallback stub only (real guides are SKILL.md's job, before this
    # script runs; see the header note).
    for pair in "${SKILL_PAIRS[@]}"; do
        s="${pair#* }"
        g="$repo/docs/skill-guides/$s.html"
        if [ ! -e "$g" ]; then
            add_plan "[R1] visualize docs/skill-guides/$s.html (→ /visuals:visualize; TODO stub if unavailable)"
            if [ "$apply" -eq 1 ]; then
                mkdir -p "$(dirname "$g")"
                printf '<!-- TODO: claude-plugin guide for %s -->\n<!-- 이 가이드는 /visuals:visualize 로 채우세요 (placeholder stub). -->\n' "$s" >"$g"
                stubbed=$((stubbed + 1))
            fi
        fi
    done

    # R2 — usage placeholder stub.
    for pair in "${SKILL_PAIRS[@]}"; do
        s="${pair#* }"
        if [ ! -e "$repo/docs/skill-output/$s-usage.html" ] && [ ! -e "$repo/docs/skill-output/$s-usage.md" ]; then
            add_plan "[R2] stub    docs/skill-output/$s-usage.md"
            if [ "$apply" -eq 1 ]; then
                mkdir -p "$repo/docs/skill-output"
                printf '<!-- TODO: %s usage sample — fill with /visuals:visualize -->\n' "$s" >"$repo/docs/skill-output/$s-usage.md"
                stubbed=$((stubbed + 1))
            fi
        fi
    done

    # GitHub Pages activation — soft-fail: no remote, no `gh`, or a `gh`
    # error all warn (or stay n/a) and never abort the run.
    if [ "$git_repo" -eq 1 ] && git -C "$repo" remote get-url origin >/dev/null 2>&1 &&
        command -v gh >/dev/null 2>&1; then
        if remote_vars="$( (cd "$repo" && bash "$PARSE_REMOTE" origin) 2>/dev/null)"; then
            eval "$remote_vars"
            add_plan "[Pages] enable GitHub Pages (branch=main, path=/docs) if inactive"
            if [ "$apply" -eq 1 ]; then
                if gh api --hostname "$HOST" "repos/$OWNER/$REPO/pages" >/dev/null 2>&1; then
                    pages_status="active"
                elif echo '{"source":{"branch":"main","path":"/docs"}}' |
                    gh api --hostname "$HOST" "repos/$OWNER/$REPO/pages" -X POST --input - >/dev/null 2>&1; then
                    pages_status="activated"
                else
                    pages_status="warn"
                    echo "warn: GitHub Pages activation failed (missing token scope or unreachable host) — continuing" >&2
                fi
            else
                pages_status="skip"
            fi
        fi
    fi

    # R4 — naming correction: rewrite name: to the bare directory basename.
    # Never git mv the directory (public invocation path); skip entirely
    # when the basename itself carries a colon (Apply rule 7).
    for pair in "${SKILL_PAIRS[@]}"; do
        root="${pair%% *}"
        s="${pair#* }"
        case "$s" in *:*) continue ;; esac
        sm="$repo/$root/skills/$s/SKILL.md"
        [ -f "$sm" ] || continue
        fm="$(awk 'NR==1{if($0=="---"){f=1;next}else{exit}} f&&$0=="---"{exit} f{print}' "$sm")"
        name="$(grep -m1 '^name:' <<<"$fm" | sed -E "s/^name:[[:space:]'\"]*//; s/[[:space:]'\"]*\$//")"
        if [ -n "$name" ] && [ "$name" != "$s" ]; then
            add_plan "[R4] rename  $root/skills/$s/SKILL.md name: $name → $s"
            if [ "$apply" -eq 1 ]; then
                sed -i "0,/^name:.*/{s/^name:.*/name: $s/}" "$sm"
                renamed=$((renamed + 1))
            fi
        fi
    done

    # R5 — README link backfill (guide link uses the Pages URL when a
    # remote is resolvable; falls back to a relative path otherwise — there
    # is no Pages URL to build without one, same soft-fail spirit as Pages
    # activation above).
    if [ -f "$repo/README.md" ]; then
        pages_base=""
        if remote_vars2="$( (cd "$repo" && bash "$PARSE_REMOTE" origin) 2>/dev/null)"; then
            # shellcheck disable=SC2153,SC2154 # see the Pages block above
            eval "$remote_vars2"
            case "$HOST" in
            github.com) pages_base="https://$OWNER.github.io/$REPO" ;;
            *) pages_base="https://$HOST/pages/$OWNER/$REPO" ;;
            esac
        fi
        for pair in "${SKILL_PAIRS[@]}"; do
            s="${pair#* }"
            missing=()
            if ! grep -qF "skill-guides/$s.html" "$repo/README.md"; then
                if [ -n "$pages_base" ]; then
                    missing+=("- \`$s\` ([visual guide ↗]($pages_base/skill-guides/$s.html))")
                else
                    missing+=("- \`$s\` ([visual guide ↗](docs/skill-guides/$s.html))")
                fi
            fi
            if ! grep -qF "skill-output/$s-usage.html" "$repo/README.md" &&
                ! grep -qF "skill-output/$s-usage.md" "$repo/README.md"; then
                missing+=("- \`$s\` usage: [usage](docs/skill-output/$s-usage.md)")
            fi
            if [ "${#missing[@]}" -gt 0 ]; then
                add_plan "[R5] link    README.md ← $s guide/usage 링크 추가"
                if [ "$apply" -eq 1 ]; then
                    {
                        printf '\n'
                        printf '%s\n' "${missing[@]}"
                    } >>"$repo/README.md"
                    linked=$((linked + ${#missing[@]}))
                fi
            fi
        done
    fi
fi

# ---- emit ---------------------------------------------------------------
echo "MODE $mode"
echo "SCOPE $scope"
if [ "${#ROOTS[@]}" -gt 0 ]; then
    echo "ROOTS ${ROOTS[*]}"
else
    echo "ROOTS (none)"
fi

if [ "${#plan[@]}" -gt 0 ]; then
    printf '%s\n' "${plan[@]}"
fi

applied=0
[ "$apply" -eq 1 ] && applied="${#plan[@]}"
echo "SUMMARY applied=$applied created=$created sourced=$sourced pruned=$pruned stubbed=$stubbed renamed=$renamed linked=$linked pages=$pages_status"
exit 0
