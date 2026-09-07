#!/usr/bin/env bash
# skills/rename-repo/lib/test_parse_remote.sh — one runnable smoke test for
# parse_remote.sh. Not a framework: asserts, plain bash. Run directly:
#   bash skills/rename-repo/lib/test_parse_remote.sh

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/parse_remote.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

cd "$TMP"
git init -q .

check() {
  local url="$1" want_host="$2" want_owner="$3" want_repo="$4"
  git remote remove origin 2>/dev/null || true
  git remote add origin "$url"
  local out
  out="$("$SCRIPT" origin)" || fail "parse failed for $url"
  eval "$out"
  [ "$HOST" = "$want_host" ] || fail "$url: HOST=$HOST want $want_host"
  [ "$OWNER" = "$want_owner" ] || fail "$url: OWNER=$OWNER want $want_owner"
  [ "$REPO" = "$want_repo" ] || fail "$url: REPO=$REPO want $want_repo"
}

# https, with and without .git, github.com
check "https://github.com/dEitY719/claude-plugin-visuals.git" \
  github.com dEitY719 claude-plugin-visuals
check "https://github.com/dEitY719/claude-plugin-visuals" \
  github.com dEitY719 claude-plugin-visuals

# git@ (SSH, scp-like) form
check "git@github.com:dEitY719/claude-plugin-visuals.git" \
  github.com dEitY719 claude-plugin-visuals

# ssh:// URL form
check "ssh://git@github.com/dEitY719/claude-plugin-visuals.git" \
  github.com dEitY719 claude-plugin-visuals

# ssh:// URL form with an explicit port — HOST must drop the :port
check "ssh://git@github.our-company.com:2222/team/company-skills.git" \
  github.our-company.com team company-skills

# trailing slash, no .git
check "https://github.com/dEitY719/claude-plugin-visuals/" \
  github.com dEitY719 claude-plugin-visuals

# GHES host, https
check "https://github.our-company.com/team/company-skills.git" \
  github.our-company.com team company-skills

# eval-safety: a crafted remote URL must never execute during eval
# (cwd is $TMP; the injected owner segment has no "/" so it stays a single
# path component and the payload only runs if `eval` is unsafe)
git remote remove origin 2>/dev/null || true
# shellcheck disable=SC2016  # deliberately literal — must NOT expand here
git remote add origin 'https://evil.example.com/$(touch PWNED)/repo.git'
out="$("$SCRIPT" origin)"
eval "$out"
[ -f "$TMP/PWNED" ] && fail "eval of parse_remote output executed injected command"
[ "$REPO" = "repo" ] || fail "eval-safety case: REPO=$REPO want repo"

# missing remote -> non-zero exit, no stdout
git remote remove origin
if "$SCRIPT" origin >/dev/null 2>&1; then
  fail "expected non-zero exit for a missing remote"
fi

# unparseable URL -> non-zero exit
git remote add origin "not-a-url"
if "$SCRIPT" origin >/dev/null 2>&1; then
  fail "expected non-zero exit for an unparseable URL"
fi

# more than two path segments (e.g. a GitLab subgroup) -> rejected, not
# silently mis-parsed
git remote remove origin
git remote add origin "https://gitlab.example.com/group/subgroup/repo.git"
if "$SCRIPT" origin >/dev/null 2>&1; then
  fail "expected non-zero exit for a 3-segment (subgroup) path"
fi

echo "OK: parse_remote.sh"
