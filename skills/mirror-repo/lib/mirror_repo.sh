#!/usr/bin/env bash
# skills/mirror-repo/lib/mirror_repo.sh — packaging:mirror-repo, Steps 0-7.
#
# Mirrors an existing external `*-skills` repo onto a GHES host: clone from
# the upstream host over HTTPS, create the GHES repo, point origin at GHES
# (SSH) and upstream at the source (HTTPS), push. New mirrors only.
#
# Usage:
#   mirror_repo.sh <repo-name> [--owner <o>] [--ghes-owner <o>] [--dest <path>]
#                  [--host <h>] [--ghes-host <h>] [--dry-run] [--yes]
#
# Safety contract:
#   - --dry-run stops after the [PLAN] block: no clone, no create, no push.
#   - GHES repo create and push each ask "[y/N]" on stdin; anything but y/yes
#     aborts. --yes answers both — pass it only after the user confirmed both
#     in chat. No stdin (EOF) is a "no".
#   - Never `git push --force`. Aborts if <dest>/<repo-name> or the GHES repo
#     already exists (refreshing a mirror is git-pull-skills.sh's job).
#   - Host-agnostic: the GHES host comes from --ghes-host or the dotfiles SSOT
#     `_gh_resolve_host` (shell-common/functions/gh_host.sh); none is
#     hardcoded here.

set -euo pipefail

die() { printf '[ABORT] packaging:mirror-repo: %s\n' "$*" >&2; exit 1; }
valid_id() { [[ "$2" =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid $1 '$2'"; }
repo_exists() { GH_HOST="$1" gh repo view "$2" --json name >/dev/null 2>&1; }

mirror_repo_help() {
  echo "Usage: $0 <repo-name> [--owner <o>] [--ghes-owner <o>] [--dest <path>]" >&2
  echo "          [--host <h>] [--ghes-host <h>] [--dry-run] [--yes]" >&2
  exit 1
}

NAME="" OWNER="dEitY719" GHES_OWNER="" DEST="$HOME/para/project/skills"
HOST="github.com" GHES_HOST="" DRY_RUN=0 YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --owner|--ghes-owner|--dest|--host|--ghes-host)
      [ $# -ge 2 ] || die "$1 needs a value"
      case "$1" in
        --owner) OWNER="$2" ;; --ghes-owner) GHES_OWNER="$2" ;;
        --dest) DEST="$2" ;; --host) HOST="$2" ;; --ghes-host) GHES_HOST="$2" ;;
      esac
      shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes) YES=1; shift ;;
    -h|--help) mirror_repo_help ;;
    -*) echo "unknown flag: $1" >&2; mirror_repo_help ;;
    *) [ -z "$NAME" ] || die "only one <repo-name> is accepted (got '$NAME' and '$1')"
       NAME="$1"; shift ;;
  esac
done
[ -n "$NAME" ] || mirror_repo_help

# --- Step 1 (offline half): name validation --------------------------------
case "$NAME" in
  claude-plugin-*)
    die "'$NAME' uses the pre-#1410 claude-plugin- prefix; the convention is <domain>-skills (try '${NAME#claude-plugin-}-skills')" ;;
esac
[[ "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] \
  || die "invalid <repo-name> '$NAME': lowercase letters, digits and single hyphens only"
case "$NAME" in
  *-skills) ;;
  *) NAME="$NAME-skills"; printf '[INFO] -skills suffix auto-appended: %s\n' "$NAME" ;;
esac
valid_id owner "$OWNER"
valid_id host "$HOST"
DEST="${DEST%/}"
TARGET="$DEST/$NAME"
[ ! -e "$TARGET" ] || die "$TARGET already exists — this skill creates new mirrors only; refresh with git-pull-skills.sh"

# --- Step 0: host resolution + auth ----------------------------------------
if [ -z "$GHES_HOST" ]; then
  helper="${SHELL_COMMON:-$HOME/dotfiles/shell-common}/functions/gh_host.sh"
  [ -r "$helper" ] || die "cannot resolve the GHES host: $helper not found — pass --ghes-host <host>"
  # Subshell + timeout: the helper is pure definitions, but never let a
  # sourced dotfile hang this run.
  # shellcheck disable=SC2016  # $1 expands in the inner bash, by design
  GHES_HOST=$(timeout 20 bash -c '. "$1" >/dev/null 2>&1; _gh_resolve_host' _ "$helper" 2>/dev/null) \
    || die "_gh_resolve_host failed — pass --ghes-host <host>"
fi
valid_id "GHES host" "$GHES_HOST"
[ "$GHES_HOST" != "$HOST" ] \
  || die "GHES host resolved to the upstream host ($HOST) — pass --ghes-host <host>"

for h in "$HOST" "$GHES_HOST"; do
  gh auth status --hostname "$h" >/dev/null 2>&1 \
    || die "not logged in to $h — run: gh auth login --hostname $h"
done
if [ -z "$GHES_OWNER" ]; then
  GHES_OWNER=$(gh api --hostname "$GHES_HOST" user --jq .login 2>/dev/null) \
    || die "cannot detect the active $GHES_HOST login — pass --ghes-owner <owner>"
fi
valid_id "GHES owner" "$GHES_OWNER"

# --- Step 1 (online half): upstream must exist, GHES repo must not --------
repo_exists "$HOST" "$OWNER/$NAME" || die "upstream repo $HOST/$OWNER/$NAME not found"
if repo_exists "$GHES_HOST" "$GHES_OWNER/$NAME"; then
  die "$GHES_HOST/$GHES_OWNER/$NAME already exists — refresh it with git-pull-skills.sh instead"
fi

SRC_URL="https://$HOST/$OWNER/$NAME.git"
ORIGIN_URL="git@$GHES_HOST:$GHES_OWNER/$NAME.git"

# --- Step 2: plan (always) -------------------------------------------------
cat <<EOF
[PLAN] packaging:mirror-repo
  Source repo  : $HOST/$OWNER/$NAME
  GHES repo    : $GHES_HOST/$GHES_OWNER/$NAME
  Destination  : $TARGET/
  Remotes:
    origin    -> $ORIGIN_URL
    upstream  -> $SRC_URL
  Dry-run     : $([ "$DRY_RUN" -eq 1 ] && echo on || echo off)
EOF
[ "$DRY_RUN" -eq 0 ] || exit 0

confirm() {
  [ "$YES" -eq 0 ] || return 0
  local ans=""
  printf '%s [y/N] ' "$1" >&2
  read -r ans || true
  case "$ans" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# --- Step 3: clone from upstream (HTTPS) -----------------------------------
mkdir -p "$DEST"
git clone "$SRC_URL" "$TARGET" || die "git clone $SRC_URL failed"
BRANCH=$(git -C "$TARGET" symbolic-ref --short HEAD) || die "cannot read the cloned default branch"

# --- Step 4: create the GHES repo (confirm first) --------------------------
confirm "Create private repo $GHES_HOST/$GHES_OWNER/$NAME?" \
  || die "GHES repo create declined — nothing created; the clone at $TARGET is local only (delete it to retry)"
GH_HOST="$GHES_HOST" gh repo create "$GHES_OWNER/$NAME" --private \
  || die "gh repo create $GHES_OWNER/$NAME on $GHES_HOST failed"

# --- Step 5: remotes -------------------------------------------------------
git -C "$TARGET" remote set-url origin "$ORIGIN_URL"
git -C "$TARGET" remote add upstream "$SRC_URL"

# --- Step 6: push (confirm first; never --force) ---------------------------
confirm "Push $BRANCH to $ORIGIN_URL?" \
  || die "push declined — GHES repo exists but is empty; push later with: git -C $TARGET push -u origin $BRANCH"
# push -u also sets $BRANCH's tracking to origin/$BRANCH (a separate
# --set-upstream-to cannot run before origin/$BRANCH exists).
git -C "$TARGET" push -u origin "$BRANCH" || die "push to $ORIGIN_URL rejected"

# --- Step 7: verify + report -----------------------------------------------
REMOTES=$(git -C "$TARGET" remote -v)
grep -qF "$ORIGIN_URL" <<<"$REMOTES" || die "origin is not $ORIGIN_URL after setup"
grep -qF "$SRC_URL" <<<"$REMOTES" || die "upstream is not $SRC_URL after setup"
repo_exists "$GHES_HOST" "$GHES_OWNER/$NAME" \
  || die "GHES repo $GHES_OWNER/$NAME not visible after create"

cat <<EOF
[OK] packaging:mirror-repo
  Source    : https://$HOST/$OWNER/$NAME
  GHES repo : https://$GHES_HOST/$GHES_OWNER/$NAME
  Dest      : $TARGET/
  Remotes   : origin=GHES, upstream=$HOST
  Next      : Run skills-sync to verify (should show "already present (skipped)")
EOF
