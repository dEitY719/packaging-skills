#!/usr/bin/env bash
# skills/rename-repo/lib/parse_remote.sh — host-agnostic owner/repo parser.
# Parses `git remote get-url <remote>` (any URI scheme — https://, ssh://,
# git://, or the git@host: scp-like form — any host, github.com or GHES)
# into HOST=/OWNER=/REPO= on stdout. Never hardcodes github.com. Exits
# non-zero (no stdout) if the remote is missing or the URL doesn't parse.
#
# Output is %q-quoted so `eval` cannot execute anything even if the local
# git config's remote URL were crafted with shell metacharacters — HOST/
# OWNER/REPO always end up as inert strings in the caller's shell, never as
# commands.
#
# Usage: eval "$(bash skills/rename-repo/lib/parse_remote.sh [remote])"
#   remote defaults to "origin".

set -euo pipefail

REMOTE="${1:-origin}"

URL="$(git remote get-url "$REMOTE" 2>/dev/null)" || {
  echo "parse_remote: no such remote: $REMOTE" >&2
  exit 1
}

# <scheme>://<host>/<owner>/<repo>[.git][/]  or  git@<host>:<owner>/<repo>[.git]
# The repo group is [^/]+ (no embedded slash) with one optional trailing
# slash — exactly two path segments (owner, repo), matching how GitHub and
# GHES repo URLs are shaped. A URL with more path segments (e.g. a GitLab
# subgroup) fails to match at all and is reported as unrecognized, rather
# than being silently mis-parsed by a greedy capture.
if [[ "$URL" =~ ^[A-Za-z][A-Za-z0-9+.-]*://([^/]+)/([^/]+)/([^/]+)/?$ ]] ||
   [[ "$URL" =~ ^[^@[:space:]]+@([^:]+):([^/]+)/([^/]+)/?$ ]]; then
  HOST="${BASH_REMATCH[1]}"
  OWNER="${BASH_REMATCH[2]}"
  REPO="${BASH_REMATCH[3]}"
else
  echo "parse_remote: unrecognized remote URL: $URL" >&2
  exit 1
fi
REPO="${REPO%.git}"
HOST="${HOST##*@}"  # strip optional userinfo (ssh://user@host/... form)
HOST="${HOST%%:*}"  # strip optional :port (ssh://host:2222/... form) —
                     # `gh auth status --hostname` / `gh repo rename --repo`
                     # both want a bare hostname, never host:port
if [ -z "$HOST" ] || [ -z "$OWNER" ] || [ -z "$REPO" ]; then
  echo "parse_remote: unrecognized remote URL: $URL" >&2
  exit 1
fi

printf 'HOST=%q\n' "$HOST"
printf 'OWNER=%q\n' "$OWNER"
printf 'REPO=%q\n' "$REPO"
