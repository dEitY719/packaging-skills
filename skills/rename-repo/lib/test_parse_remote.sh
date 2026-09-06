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

# git@ (SSH) form
check "git@github.com:dEitY719/claude-plugin-visuals.git" \
  github.com dEitY719 claude-plugin-visuals

# GHES host, https
check "https://github.our-company.com/team/company-skills.git" \
  github.our-company.com team company-skills

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

echo "OK: parse_remote.sh"
