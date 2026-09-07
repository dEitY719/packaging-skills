#!/usr/bin/env bash
# test_refactor_apply.sh — smoke test for refactor_apply.sh. Not a bats
# suite; the single runnable self-check for the ported apply logic, per
# repo convention (mirrors structure-check/lib/test_structure_check.sh).
#
# Usage: bash test_refactor_apply.sh
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ra="$here/refactor_apply.sh"
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
assert_no_line() {
    # $1=output $2=unwanted-substring $3=case-name
    if grep -qF "$2" <<<"$1"; then
        echo "FAIL: $3 — unexpected '$2'"
        echo "--- full output ---"
        echo "$1"
        fail=1
    fi
}
assert_exit() {
    [ "$1" -eq "$2" ] || {
        echo "FAIL: $3 — expected exit $2, got $1"
        fail=1
    }
}
assert_file() {
    [ -e "$1" ] || {
        echo "FAIL: $2 — expected $1 to exist"
        fail=1
    }
}

# ---- case 1: bad usage / missing dir ---------------------------------------
bash "$ra" >/dev/null 2>&1
assert_exit "$?" 64 "usage exit (no args)"
bash "$ra" "$tmp" --mode bogus --scope mp >/dev/null 2>&1
assert_exit "$?" 64 "usage exit (bad mode)"
bash "$ra" "$tmp/does-not-exist" --mode single --scope mp >/dev/null 2>&1
assert_exit "$?" 66 "missing-dir exit"

# ---- case 2: empty single-mode repo, dry-run -> full mandatory plan -------
r="$tmp/single-empty"
mkdir -p "$r"
git -C "$r" init -q
out="$(bash "$ra" "$r" --mode single --scope mp)"
code=$?
assert_exit "$code" 0 "single-empty dry-run exit"
assert_line "$out" "MODE single" "single-empty MODE"
assert_line "$out" "[M1] create  .claude-plugin/marketplace.json (skeleton)" "single-empty M1 plan"
assert_line "$out" "[M3] create  ./.claude-plugin/plugin.json (skeleton)" "single-empty M3 plan"
assert_line "$out" "[M6] create  README.md (stub)" "single-empty M6 plan"
[ -e "$r/README.md" ] && {
    echo "FAIL: single-empty dry-run wrote README.md"
    fail=1
}

# ---- case 3: same repo, --apply -> files actually created, idempotent -----
out="$(bash "$ra" "$r" --mode single --scope mp --apply)"
code=$?
assert_exit "$code" 0 "single-empty apply exit"
assert_file "$r/.claude-plugin/marketplace.json" "single-empty apply M1"
assert_file "$r/.claude-plugin/plugin.json" "single-empty apply M3"
assert_file "$r/README.md" "single-empty apply M6"
assert_file "$r/docs/skill-guides" "single-empty apply M5"
assert_file "$r/docs/skill-output" "single-empty apply M5"
jq empty "$r/.claude-plugin/marketplace.json" || {
    echo "FAIL: marketplace.json is not valid JSON"
    fail=1
}
jq empty "$r/.claude-plugin/plugin.json" || {
    echo "FAIL: plugin.json is not valid JSON"
    fail=1
}

# re-run: idempotent -> empty plan, applied=0
out2="$(bash "$ra" "$r" --mode single --scope mp --apply)"
assert_line "$out2" "SUMMARY applied=0 created=0 sourced=0 pruned=0 stubbed=0 renamed=0 linked=0 pages=n/a" "single-empty idempotent re-run"

# ---- case 4: M7 source injection on an existing marketplace.json ----------
r="$tmp/m7-fix"
mkdir -p "$r/.claude-plugin" "$r/plugins/bar/.claude-plugin" "$r/plugins/bar/skills/baz" \
    "$r/docs/skill-guides" "$r/docs/skill-output"
git -C "$r" init -q
printf '{"plugins":[{"name":"bar"}]}' >"$r/.claude-plugin/marketplace.json"
printf '{"name":"bar-plugin","version":"0.0.0"}' >"$r/plugins/bar/.claude-plugin/plugin.json"
printf -- '---\nname: baz\ndescription: test\n---\n' >"$r/plugins/bar/skills/baz/SKILL.md"
printf '# repo\n' >"$r/README.md"
out="$(bash "$ra" "$r" --mode mono --scope mp --apply)"
assert_line "$out" "SUMMARY applied=1 created=0 sourced=1 pruned=0 stubbed=0 renamed=0 linked=0 pages=n/a" "m7-fix summary"
src="$(jq -r '.plugins[0].source' "$r/.claude-plugin/marketplace.json")"
[ "$src" = "./plugins/bar" ] || {
    echo "FAIL: m7-fix — expected source ./plugins/bar, got $src"
    fail=1
}

# ---- case 4b: M7 on an object element with no name/homepage/repository --
# must NOT inject a bogus "./plugins/" source (codex review, PR #20) and must
# not count it toward `sourced` since nothing was actually fixed.
r="$tmp/m7-nameless"
mkdir -p "$r/.claude-plugin" "$r/plugins/bar/.claude-plugin" "$r/plugins/bar/skills/baz" \
    "$r/docs/skill-guides" "$r/docs/skill-output"
git -C "$r" init -q
printf '{"plugins":[{}]}' >"$r/.claude-plugin/marketplace.json"
printf '{"name":"bar-plugin","version":"0.0.0"}' >"$r/plugins/bar/.claude-plugin/plugin.json"
printf -- '---\nname: baz\ndescription: test\n---\n' >"$r/plugins/bar/skills/baz/SKILL.md"
printf '# repo\n' >"$r/README.md"
out="$(bash "$ra" "$r" --mode mono --scope mp --apply 2>/dev/null)"
assert_line "$out" "SUMMARY applied=0 created=0 sourced=0 pruned=0 stubbed=0 renamed=0 linked=0 pages=n/a" "m7-nameless summary (no false credit)"
src="$(jq -r '.plugins[0].source // "MISSING"' "$r/.claude-plugin/marketplace.json")"
[ "$src" = "MISSING" ] || {
    echo "FAIL: m7-nameless — expected no source injected, got '$src'"
    fail=1
}

# ---- case 5: M10 prune with .bak backup ------------------------------------
r="$tmp/m10-fix"
mkdir -p "$r/.claude-plugin" "$r/skills/foo" "$r/docs/skill-guides" "$r/docs/skill-output"
git -C "$r" init -q
printf '{"plugins":["./"]}' >"$r/.claude-plugin/marketplace.json"
printf '{"name":"foo-plugin","version":"0.0.0","skills":["foo"]}' >"$r/.claude-plugin/plugin.json"
printf -- '---\nname: foo\ndescription: test\n---\n' >"$r/skills/foo/SKILL.md"
printf '# repo\n' >"$r/README.md"
out="$(bash "$ra" "$r" --mode single --scope mp --apply)"
assert_line "$out" "SUMMARY applied=1 created=0 sourced=0 pruned=1 stubbed=0 renamed=0 linked=0 pages=n/a" "m10-fix summary"
assert_file "$r/.claude-plugin/plugin.json.bak" "m10-fix .bak kept"
grep -q '"skills"' "$r/.claude-plugin/plugin.json" && {
    echo "FAIL: m10-fix — unknown field 'skills' survived the prune"
    fail=1
}
grep -q '"skills"' "$r/.claude-plugin/plugin.json.bak" || {
    echo "FAIL: m10-fix — .bak should retain the original unknown field"
    fail=1
}

# ---- case 6: --scope op — R2 stub + R4 rename, --scope mp must skip both --
r="$tmp/op-fix"
mkdir -p "$r/.claude-plugin" "$r/skills/foo" "$r/docs/skill-guides" "$r/docs/skill-output"
git -C "$r" init -q
printf '{"plugins":["./"]}' >"$r/.claude-plugin/marketplace.json"
printf '{"name":"foo-plugin","version":"0.0.0"}' >"$r/.claude-plugin/plugin.json"
printf -- '---\nname: wrong-name\ndescription: test\n---\n' >"$r/skills/foo/SKILL.md"
printf '# repo\n' >"$r/README.md"

out_mp="$(bash "$ra" "$r" --mode single --scope mp)"
assert_no_line "$out_mp" "[R4]" "op-fix --mp must not plan R4"
assert_no_line "$out_mp" "[R2]" "op-fix --mp must not plan R2"

bash "$ra" "$r" --mode single --scope op --apply >/dev/null
assert_file "$r/docs/skill-output/foo-usage.md" "op-fix R2 stub written"
name_after="$(grep '^name:' "$r/skills/foo/SKILL.md")"
[ "$name_after" = "name: foo" ] || {
    echo "FAIL: op-fix R4 rename — expected 'name: foo', got '$name_after'"
    fail=1
}
grep -q '^description: test$' "$r/skills/foo/SKILL.md" || {
    echo "FAIL: op-fix R4 rename clobbered another frontmatter line"
    fail=1
}
[ "$(grep -c '^description:' "$r/skills/foo/SKILL.md")" -eq 1 ] || {
    echo "FAIL: op-fix R4 rename duplicated a line"
    fail=1
}
grep -qF "skill-guides/foo.html" "$r/README.md" || {
    echo "FAIL: op-fix R5 — guide link not backfilled into README"
    fail=1
}
grep -qF "skill-output/foo-usage.md" "$r/README.md" || {
    echo "FAIL: op-fix R5 — usage link not backfilled into README"
    fail=1
}

# re-run op scope: idempotent
out_op2="$(bash "$ra" "$r" --mode single --scope op --apply)"
# no `origin` remote in this test repo -> Pages step's precondition never
# fires, so pages stays n/a (not skip/active/activated) -- that path is
# covered by parse_remote.sh's own test suite, not re-tested here.
assert_line "$out_op2" "SUMMARY applied=0 created=0 sourced=0 pruned=0 stubbed=0 renamed=0 linked=0 pages=n/a" "op-fix idempotent re-run"

# ---- case 7: with an origin remote + a stubbed `gh` — Pages activation and
# the R5 guide link both use the derived Pages URL ---------------------------
r="$tmp/pages-fix"
mkdir -p "$r/.claude-plugin" "$r/skills/foo" "$r/docs/skill-guides" "$r/docs/skill-output"
git -C "$r" init -q
git -C "$r" remote add origin "https://github.com/acme/proj.git"
printf '{"plugins":["./"]}' >"$r/.claude-plugin/marketplace.json"
printf '{"name":"foo-plugin","version":"0.0.0"}' >"$r/.claude-plugin/plugin.json"
printf -- '---\nname: foo\ndescription: test\n---\n' >"$r/skills/foo/SKILL.md"
printf '# repo\n' >"$r/README.md"

fakebin="$tmp/fakebin"
mkdir -p "$fakebin"
cat >"$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
# fake gh: GET .../pages -> 404 (inactive) once, then succeeds after POST.
STATE="${GH_FAKE_STATE:?}"
if [ "$1" = "api" ] && [ "$5" != "-X" ]; then
    # GET (no -X) — report inactive until the POST has run
    [ -f "$STATE" ] && exit 0
    exit 1
fi
if [ "$1" = "api" ] && [ "$5" = "-X" ] && [ "$6" = "POST" ]; then
    touch "$STATE"
    exit 0
fi
exit 1
EOF
chmod +x "$fakebin/gh"
GH_FAKE_STATE="$tmp/pages-active-flag"
export GH_FAKE_STATE
out="$(PATH="$fakebin:$PATH" bash "$ra" "$r" --mode single --scope op --apply)"
assert_line "$out" "SUMMARY applied=5 created=0 sourced=0 pruned=0 stubbed=2 renamed=0 linked=2 pages=activated" "pages-fix summary"
grep -qF "https://acme.github.io/proj/skill-guides/foo.html" "$r/README.md" || {
    echo "FAIL: pages-fix — README guide link should use the derived Pages URL"
    fail=1
}
unset GH_FAKE_STATE

# ---- case 8: a write that actually fails must not inflate `created`/
# `applied` (codex review, PR #20 round 3 — reproduced with a read-only dir).
# A read-only .claude-plugin/ blocks M1's marketplace.json and M3's
# plugin.json (both write inside it) but not M6's README.md (repo root is
# still writable) — `created` must reflect exactly that one real success,
# not all three attempted plan lines.
r="$tmp/write-fail"
mkdir -p "$r/docs/skill-guides" "$r/docs/skill-output" "$r/.claude-plugin" "$r/skills"
git -C "$r" init -q
chmod 555 "$r/.claude-plugin"
out="$(bash "$ra" "$r" --mode single --scope mp --apply 2>/dev/null)"
chmod 755 "$r/.claude-plugin" # restore before the trap's rm -rf can run
assert_line "$out" "SUMMARY applied=1 created=1 sourced=0 pruned=0 stubbed=0 renamed=0 linked=0 pages=n/a" "write-fail: only the one real success (README) counts, not all 3 plan lines"
[ -e "$r/.claude-plugin/marketplace.json" ] && {
    echo "FAIL: write-fail — marketplace.json should not exist (write into a read-only dir can't have succeeded)"
    fail=1
}
[ -e "$r/README.md" ] || {
    echo "FAIL: write-fail — README.md should exist (repo root was still writable)"
    fail=1
}

# ---- case 9: M10 must never prune without a verified .bak (codex review,
# PR #20 round 4) — a read-only .claude-plugin/ blocks the `cp ... .bak`
# step, and plugin.json must come out byte-for-byte unchanged, not partially
# pruned.
r="$tmp/m10-backup-fail"
mkdir -p "$r/.claude-plugin" "$r/skills/foo" "$r/docs/skill-guides" "$r/docs/skill-output"
git -C "$r" init -q
printf '{"plugins":["./"]}' >"$r/.claude-plugin/marketplace.json"
printf '{"name":"foo-plugin","version":"0.0.0","skills":["foo"]}' >"$r/.claude-plugin/plugin.json"
printf -- '---\nname: foo\ndescription: test\n---\n' >"$r/skills/foo/SKILL.md"
printf '# repo\n' >"$r/README.md"
plugin_json_before="$(cat "$r/.claude-plugin/plugin.json")"
chmod 555 "$r/.claude-plugin"
out="$(bash "$ra" "$r" --mode single --scope mp --apply 2>/dev/null)"
chmod 755 "$r/.claude-plugin"
assert_line "$out" "SUMMARY applied=0 created=0 sourced=0 pruned=0 stubbed=0 renamed=0 linked=0 pages=n/a" "m10-backup-fail: no prune without a verified backup"
[ "$(cat "$r/.claude-plugin/plugin.json")" = "$plugin_json_before" ] || {
    echo "FAIL: m10-backup-fail — plugin.json changed despite the backup failing"
    fail=1
}
[ -e "$r/.claude-plugin/plugin.json.bak" ] && {
    echo "FAIL: m10-backup-fail — a .bak claiming success shouldn't exist when cp failed"
    fail=1
}

if [ "$fail" -eq 0 ]; then
    echo "PASS: all refactor_apply.sh smoke cases"
    exit 0
else
    exit 1
fi
