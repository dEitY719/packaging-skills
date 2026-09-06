#!/usr/bin/env bash
# skills/rename-repo/lib/parse_remote.sh — host-agnostic owner/repo parser.
# Parses `git remote get-url <remote>` (https:// or git@ form, any host —
# github.com or GHES) into HOST=/OWNER=/REPO= on stdout. Never hardcodes
# github.com. Exits non-zero (no stdout) if the remote is missing or the
# URL doesn't match either form.
#
# Usage: eval "$(bash skills/rename-repo/lib/parse_remote.sh [remote])"
#   remote defaults to "origin".

set -euo pipefail

REMOTE="${1:-origin}"

URL="$(git remote get-url "$REMOTE" 2>/dev/null)" || {
  echo "parse_remote: no such remote: $REMOTE" >&2
  exit 1
}

# https://<host>/<owner>/<repo>[.git][/]  or  git@<host>:<owner>/<repo>[.git]
# (POSIX ERE has no lazy quantifier, so the optional .git/trailing slash is
# stripped afterward rather than excluded from the repo group directly.)
if [[ "$URL" =~ ^https?://([^/]+)/([^/]+)/(.+)$ ]]; then
  HOST="${BASH_REMATCH[1]}"
  OWNER="${BASH_REMATCH[2]}"
  REPO="${BASH_REMATCH[3]}"
elif [[ "$URL" =~ ^[^@[:space:]]+@([^:]+):([^/]+)/(.+)$ ]]; then
  HOST="${BASH_REMATCH[1]}"
  OWNER="${BASH_REMATCH[2]}"
  REPO="${BASH_REMATCH[3]}"
else
  echo "parse_remote: unrecognized remote URL: $URL" >&2
  exit 1
fi
REPO="${REPO%/}"
REPO="${REPO%.git}"
if [ -z "$HOST" ] || [ -z "$OWNER" ] || [ -z "$REPO" ]; then
  echo "parse_remote: unrecognized remote URL: $URL" >&2
  exit 1
fi

echo "HOST=$HOST"
echo "OWNER=$OWNER"
echo "REPO=$REPO"
