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
assert_line "$out" "SUMMARY PASS fail=0 warn=0 na=3" "single-pass summary"
assert_line "$out" "R9 PASS" "single-pass R9"
assert_line "$out" "R10 PASS" "single-pass R10"
assert_line "$out" "R11 N/A" "single-pass R11"
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

# ---- case 5: M7 FAIL — object plugin element with no source key -----------
r="$tmp/m7-fail"
mkdir -p "$r/.claude-plugin" "$r/plugins/bar/.claude-plugin" "$r/plugins/bar/skills/baz" \
    "$r/docs/skill-guides" "$r/docs/skill-output"
printf '{"plugins":[{"name":"bar"}]}' >"$r/.claude-plugin/marketplace.json"
printf '{"name":"bar-plugin","version":"0.0.0"}' >"$r/plugins/bar/.claude-plugin/plugin.json"
printf -- '---\nname: baz\ndescription: test\n---\n' >"$r/plugins/bar/skills/baz/SKILL.md"
printf '# repo\n' >"$r/README.md"
out="$(bash "$sc" "$r")"
code=$?
assert_line "$out" "M7 FAIL marketplace.json" "m7-fail detail"
assert_exit "$code" 2 "m7-fail exit"

# ---- case 6: M10 FAIL — plugin.json has an unknown top-level field ---------
r="$tmp/m10-fail"
mkdir -p "$r/.claude-plugin" "$r/skills/foo" "$r/docs/skill-guides" "$r/docs/skill-output"
printf '{"plugins":["./"]}' >"$r/.claude-plugin/marketplace.json"
printf '{"name":"foo-plugin","version":"0.0.0","skills":["foo"]}' >"$r/.claude-plugin/plugin.json"
printf -- '---\nname: foo\ndescription: test\n---\n' >"$r/skills/foo/SKILL.md"
printf '# repo\n' >"$r/README.md"
out="$(bash "$sc" "$r")"
code=$?
assert_line "$out" "M10 FAIL ./.claude-plugin/plugin.json" "m10-fail detail"
assert_exit "$code" 2 "m10-fail exit"

# ---- case 7: SKILL.md has no real frontmatter, only name:/description: in
# the body (e.g. a code-block example) -> M4 FAIL, R4 must not false-PASS by
# matching the body text (agy+codex review, PR #19) -----------------------
r="$tmp/fm-bug"
mkdir -p "$r/.claude-plugin" "$r/skills/foo" "$r/docs/skill-guides" "$r/docs/skill-output"
printf '{"plugins":["./"]}' >"$r/.claude-plugin/marketplace.json"
printf '{"name":"foo-plugin","version":"0.0.0"}' >"$r/.claude-plugin/plugin.json"
printf 'No real frontmatter here.\n\nExample:\nname: foo\ndescription: fake\n' >"$r/skills/foo/SKILL.md"
printf '# repo\n' >"$r/README.md"
out="$(bash "$sc" "$r")"
code=$?
assert_line "$out" "M4 FAIL ./skills/foo/SKILL.md" "fm-bug M4"
assert_exit "$code" 2 "fm-bug exit"

# ---- case 8: mono with 1 plugin -> R9 WARN (convertible to single) --------
mono1() {
    # $1=repo -> mono repo with one plugin "confluence" holding skill "a"
    mkdir -p "$1/.claude-plugin" "$1/plugins/confluence/.claude-plugin" "$1/plugins/confluence/skills/a"
    printf '{"plugins":[{"name":"confluence","source":"./plugins/confluence"}]}' >"$1/.claude-plugin/marketplace.json"
    printf '{"name":"confluence","version":"0.0.0"}' >"$1/plugins/confluence/.claude-plugin/plugin.json"
    printf -- '---\nname: a\ndescription: test\n---\n' >"$1/plugins/confluence/skills/a/SKILL.md"
}
r="$tmp/mono1"
mono1 "$r"
out="$(bash "$sc" "$r")"
grep -q '^R9 WARN convert to single' <<<"$out" || {
    echo "FAIL: mono1 R9 — expected 'R9 WARN convert to single ...'"
    echo "$out"
    fail=1
}
assert_line "$out" "R10 PASS" "mono1 R10"

# ---- case 9: mono 1 plugin + root skills/ symlink workaround -> R10 WARN ---
r="$tmp/mono1-link"
mono1 "$r"
mkdir -p "$r/skills"
ln -s ../plugins/confluence/skills/a "$r/skills/a"
out="$(bash "$sc" "$r")"
grep -q '^R9 WARN' <<<"$out" || {
    echo "FAIL: mono1-link R9 — expected WARN"
    fail=1
}
assert_line "$out" "R10 WARN skills/a" "mono1-link R10"

# ---- case 10: mono 2 plugins sharing a skill name -> R9 N/A, R11 WARN -------
r="$tmp/mono2-dup"
mkdir -p "$r/.claude-plugin"
printf '{"plugins":["./plugins/p1","./plugins/p2"]}' >"$r/.claude-plugin/marketplace.json"
for p in p1 p2; do
    mkdir -p "$r/plugins/$p/.claude-plugin" "$r/plugins/$p/skills/dup"
    printf '{"name":"%s","version":"0.0.0"}' "$p" >"$r/plugins/$p/.claude-plugin/plugin.json"
    printf -- '---\nname: dup\ndescription: test\n---\n' >"$r/plugins/$p/skills/dup/SKILL.md"
done
out="$(bash "$sc" "$r")"
grep -q '^R9 N/A multi-plugin mono' <<<"$out" || {
    echo "FAIL: mono2-dup R9 — expected 'R9 N/A multi-plugin mono ...'"
    echo "$out"
    fail=1
}
assert_line "$out" "R11 WARN dup (plugins/p1 plugins/p2)" "mono2-dup R11"

# ---- case 11: symlink only outside skill trees (AGENTS.md) -> R10 PASS -----
r="$tmp/agents-link"
mkdir -p "$r/.claude-plugin" "$r/skills/foo"
printf '{"plugins":["./"]}' >"$r/.claude-plugin/marketplace.json"
printf '{"name":"foo-plugin","version":"0.0.0"}' >"$r/.claude-plugin/plugin.json"
printf -- '---\nname: foo\ndescription: test\n---\n' >"$r/skills/foo/SKILL.md"
printf '# ctx\n' >"$r/CLAUDE.md"
ln -s CLAUDE.md "$r/AGENTS.md"
out="$(bash "$sc" "$r")"
assert_line "$out" "R10 PASS" "agents-link R10"

if [ "$fail" -eq 0 ]; then
    echo "PASS: all structure_check.sh smoke cases"
    exit 0
else
    exit 1
fi
