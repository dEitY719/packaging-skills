#!/usr/bin/env bash
# test_structure_check.sh — smoke test for structure_check.sh. Not a bats
# suite (the SSOT bats fixture lives in dEitY719/dotfiles); this is the
# single runnable self-check for the ported logic, per repo convention.
#
# Usage: bash test_structure_check.sh
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sc="$here/structure_check.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0
assert_line() {
    # $1=output $2=expected-line $3=case-name
    if ! grep -qxF "$2" <<<"$1"; then
        echo "FAIL: $3 — expected line '$2'"
        echo "--- full output ---"
        echo "$1"
        fail=1
    fi
}

assert_exit() {
    # $1=actual $2=expected $3=case-name
    [ "$1" -eq "$2" ] || {
        echo "FAIL: $3 — expected exit $2, got $1"
        fail=1
    }
}

# ---- case 1: clean single-mode repo -> PASS ---------------------------------
r="$tmp/single-pass"
mkdir -p "$r/.claude-plugin" "$r/skills/foo" "$r/docs/skill-guides" "$r/docs/skill-output"
# shellcheck disable=SC2016 # literal "$schema" JSON key, not a shell expansion
printf '{"$schema":"https://example/schema.json","description":"a plugin","plugins":["./"]}' >"$r/.claude-plugin/marketplace.json"
printf '{"name":"foo-plugin","version":"0.0.0"}' >"$r/.claude-plugin/plugin.json"
printf -- '---\nname: foo\ndescription: test\n---\nbody\n' >"$r/skills/foo/SKILL.md"
printf '<!-- guide -->' >"$r/docs/skill-guides/foo.html"
printf '<!-- usage -->' >"$r/docs/skill-output/foo-usage.md"
printf '# repo\nsee [guide](docs/skill-guides/foo.html) and [usage](docs/skill-output/foo-usage.md)\n' >"$r/README.md"
out="$(bash "$sc" "$r")"
code=$?
assert_line "$out" "SUMMARY PASS fail=0 warn=0 na=2" "single-pass summary"
assert_exit "$code" 0 "single-pass exit"

# ---- case 2: missing plugin.json (mono) -> M3 FAIL, verdict FAIL, exit 2 ---
r="$tmp/mono-fail"
mkdir -p "$r/.claude-plugin" "$r/plugins/bar/skills/baz" "$r/docs/skill-guides" "$r/docs/skill-output"
printf '{"plugins":["./plugins/bar"]}' >"$r/.claude-plugin/marketplace.json"
printf -- '---\nname: baz\ndescription: test\n---\n' >"$r/plugins/bar/skills/baz/SKILL.md"
printf '# repo' >"$r/README.md"
out="$(bash "$sc" "$r")"
code=$?
assert_line "$out" "M3 FAIL plugins/bar/.claude-plugin/plugin.json" "mono-fail M3"
assert_line "$out" "MODE mono" "mono-fail mode"
assert_exit "$code" 2 "mono-fail exit"

# ---- case 3: R4 name mismatch -> WARN, exit 1 (no FAIL) --------------------
r="$tmp/r4-warn"
mkdir -p "$r/.claude-plugin" "$r/skills/foo" "$r/docs/skill-guides" "$r/docs/skill-output"
printf '{"plugins":["./"]}' >"$r/.claude-plugin/marketplace.json"
printf '{"name":"foo-plugin","version":"0.0.0"}' >"$r/.claude-plugin/plugin.json"
printf -- '---\nname: wrong-name\ndescription: test\n---\n' >"$r/skills/foo/SKILL.md"
printf '# repo\n' >"$r/README.md"
out="$(bash "$sc" "$r")"
code=$?
assert_line "$out" "R4 WARN foo (wrong-name)" "r4-warn detail"
assert_exit "$code" 1 "r4-warn exit"

# ---- case 4: bad usage / missing dir --------------------------------------
bash "$sc" >/dev/null 2>&1
assert_exit "$?" 64 "usage exit"
bash "$sc" "$tmp/does-not-exist" >/dev/null 2>&1
assert_exit "$?" 66 "missing-dir exit"

if [ "$fail" -eq 0 ]; then
    echo "PASS: all structure_check.sh smoke cases"
    exit 0
else
    exit 1
fi
