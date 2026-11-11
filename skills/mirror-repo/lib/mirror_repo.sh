#!/usr/bin/env bash
# skills/mirror-repo/lib/mirror_repo.sh — packaging:mirror-repo, Steps 0-7.
#
# Mirrors an existing repo from one host onto another (typically github.com
# onto GHES): clone from the --upstream URL, create the --origin repo, point
# origin at the --origin URL and upstream at the --upstream URL, push. Works
# for any repo — no naming convention is enforced. New mirrors only.
#
# Usage:
#   mirror_repo.sh --upstream <url> --origin <url> [--dest <path>]
#                  [--visibility public|private] [--dry-run] [--yes]
#
# URL forms (both flags, `.git` optional, used verbatim for clone/remotes):
#   https://<host>/<owner>/<repo>.git   http://<host>/<owner>/<repo>.git
#   git@<host>:<owner>/<repo>.git       ssh://git@<host>/<owner>/<repo>.git
#
# Safety contract:
#   - --dry-run stops after the [PLAN] block: no clone, no create, no push.
#   - Mirror repo create and push each ask "[y/N]" on stdin; anything but y/yes
#     aborts. --yes answers both — pass it only after the user confirmed both
#     in chat. No stdin (EOF) is a "no".
#   - Never `git push --force`. Aborts if <dest>/<repo> or the mirror repo
#     already exists.
#   - Origin host must differ from the upstream host, and an internal PC
#     (~/.dotfiles-setup-mode = internal) never pushes to github.com.
#   - Host-agnostic: every host comes from the URLs; none is hardcoded here.

set -euo pipefail

die() { printf '[ABORT] packaging:mirror-repo: %s\n' "$*" >&2; exit 1; }
lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }  # bash 3.2 (macOS) has no ${var,,}
repo_exists() { GH_HOST="$1" gh repo view "$2" --json name >/dev/null 2>&1; }

mirror_repo_help() {
  cat <<'EOF'
Usage: mirror_repo.sh --upstream <url> --origin <url> [--dest <path>]
                      [--visibility public|private] [--dry-run] [--yes]

  --upstream <url>   Source repo to clone (required).
  --origin <url>     Mirror repo to create and push to (required). Its repo
                     name is used verbatim as the clone directory name.
  --dest <path>      Clone parent directory (default ~/para/project).
  --visibility <v>   Mirror repo visibility: public|private (default private).
  --dry-run          Print the plan only: no clone, no create, no push.
  --yes              Answer both confirmations (script use only).

URL forms (.git suffix optional):
  https://<host>/<owner>/<repo>.git   http://<host>/<owner>/<repo>.git
  git@<host>:<owner>/<repo>.git       ssh://git@<host>/<owner>/<repo>.git

Examples:
  # Check the plan first (nothing is cloned, created or pushed)
  mirror_repo.sh --upstream https://github.com/dEitY719/equinest.git \
                 --origin git@ghes.example.com:my-user/equinest.git --dry-run

  # SSH (scp-form) origin
  mirror_repo.sh --upstream https://github.com/dEitY719/video-skills.git \
                 --origin git@ghes.example.com:my-user/video-skills.git

  # HTTPS origin with a custom --dest
  mirror_repo.sh --upstream https://github.com/dEitY719/notes-skills.git \
                 --origin https://ghes.example.com/my-user/notes-skills.git \
                 --dest ~/work/mirrors

  # URLs without the .git suffix
  mirror_repo.sh --upstream https://github.com/dEitY719/equinest \
                 --origin git@ghes.example.com:my-user/equinest

  # Public mirror under a team owner (upstream must be PUBLIC)
  mirror_repo.sh --upstream https://github.com/dEitY719/herdr-skills.git \
                 --origin ssh://git@ghes.example.com/my-team/herdr-skills.git \
                 --visibility public
EOF
}
usage_die() { mirror_repo_help >&2; exit 1; }

# parse_url <flag> <url> — sets P_HOST P_OWNER P_REPO, or aborts. Offline.
parse_url() {
  local flag="$1" url="$2" path
  if [[ "$url" =~ ^(https?://|ssh://git@)([^/]+)/(.*)$ ]]; then
    P_HOST="${BASH_REMATCH[2]}" path="${BASH_REMATCH[3]}"
  elif [[ "$url" =~ ^git@([^:/]+):(.*)$ ]]; then
    P_HOST="${BASH_REMATCH[1]}" path="${BASH_REMATCH[2]}"
  else
    die "$flag '$url': unrecognized URL form (use https://, http://, git@<host>: or ssh://git@)"
  fi
  path="${path%.git}"
  [[ "$path" =~ ^([^/]+)/([^/]+)$ ]] \
    || die "$flag '$url': expected exactly <owner>/<repo> after the host"
  P_OWNER="${BASH_REMATCH[1]}" P_REPO="${BASH_REMATCH[2]}"
  [[ "$P_HOST" =~ ^[A-Za-z0-9.-]+$ ]] || die "$flag '$url': invalid host '$P_HOST'"
  [[ "$P_OWNER" =~ ^[A-Za-z0-9._-]+$ ]] || die "$flag '$url': invalid owner '$P_OWNER'"
  [[ "$P_REPO" =~ ^[A-Za-z0-9._-]+$ ]] || die "$flag '$url': invalid repo name '$P_REPO'"
}

UP_URL="" OR_URL="" DEST="$HOME/para/project" VISIBILITY="private" DRY_RUN=0 YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --upstream|--origin|--dest|--visibility)
      [ $# -ge 2 ] || die "$1 needs a value"
      case "$1" in
        --upstream) UP_URL="$2" ;; --origin) OR_URL="$2" ;;
        --dest) DEST="$2" ;; --visibility) VISIBILITY="$2" ;;
      esac
      shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes) YES=1; shift ;;
    -h|--help) mirror_repo_help; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage_die ;;
  esac
done
{ [ -n "$UP_URL" ] && [ -n "$OR_URL" ]; } || usage_die
case "$VISIBILITY" in
  public|private) ;;
  *) die "invalid --visibility '$VISIBILITY': allowed values are public|private" ;;
esac

# --- Step 1 (offline half): URL parsing + host guards ----------------------
parse_url --upstream "$UP_URL"
UP_HOST="$P_HOST" UP_OWNER="$P_OWNER" UP_REPO="$P_REPO"
parse_url --origin "$OR_URL"
OR_HOST="$P_HOST" OR_OWNER="$P_OWNER" NAME="$P_REPO"

OR_HOST_LC=$(lc "$OR_HOST")
[ "$OR_HOST_LC" != "$(lc "$UP_HOST")" ] \
  || die "origin host equals upstream host ($UP_HOST) — a mirror needs two different hosts"
MODE=""
[ ! -r "$HOME/.dotfiles-setup-mode" ] || MODE=$(tr -d '[:space:]' <"$HOME/.dotfiles-setup-mode")
if [ "$MODE" = internal ] && [ "$OR_HOST_LC" = github.com ]; then
  die "origin is on github.com but this is an internal PC (~/.dotfiles-setup-mode=internal) — never push to github.com from here"
fi

DEST="${DEST%/}"
TARGET="$DEST/$NAME"
[ ! -e "$TARGET" ] || die "$TARGET already exists — this skill creates new mirrors only"

# --- Step 0: auth ----------------------------------------------------------
for h in "$UP_HOST" "$OR_HOST"; do
  gh auth status --hostname "$h" >/dev/null 2>&1 \
    || die "not logged in to $h — run: gh auth login --hostname $h"
done

# --- Step 1 (online half): upstream must exist, mirror must not -----------
SRC_VIS=$(GH_HOST="$UP_HOST" gh repo view "$UP_OWNER/$UP_REPO" --json visibility --jq .visibility 2>/dev/null) \
  || die "upstream repo $UP_HOST/$UP_OWNER/$UP_REPO not found"
# A public mirror of a non-public source would publish code its owner kept private.
if [ "$VISIBILITY" = public ] && [ "$SRC_VIS" != PUBLIC ]; then
  die "upstream $UP_HOST/$UP_OWNER/$UP_REPO is ${SRC_VIS:-of unknown visibility}, not PUBLIC — refusing --visibility public"
fi
if repo_exists "$OR_HOST" "$OR_OWNER/$NAME"; then
  die "$OR_HOST/$OR_OWNER/$NAME already exists — this skill creates new mirrors only"
fi

# --- Step 2: plan (always) -------------------------------------------------
cat <<EOF
[PLAN] packaging:mirror-repo
  Source repo  : $UP_HOST/$UP_OWNER/$UP_REPO
  Mirror repo  : $OR_HOST/$OR_OWNER/$NAME
  Destination  : $TARGET/
  Remotes:
    origin    -> $OR_URL
    upstream  -> $UP_URL
  Visibility  : $VISIBILITY
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

# --- Step 3: clone from upstream -------------------------------------------
mkdir -p "$DEST"
git clone "$UP_URL" "$TARGET" || die "git clone $UP_URL failed"
BRANCH=$(git -C "$TARGET" symbolic-ref --short HEAD) || die "cannot read the cloned default branch"

# --- Step 4: create the mirror repo (confirm first) ------------------------
confirm "Create $VISIBILITY repo $OR_HOST/$OR_OWNER/$NAME?" \
  || die "mirror repo create declined — nothing created; the clone at $TARGET is local only (delete it to retry)"
GH_HOST="$OR_HOST" gh repo create "$OR_OWNER/$NAME" "--$VISIBILITY" \
  || die "gh repo create $OR_OWNER/$NAME on $OR_HOST failed"

# --- Step 5: remotes -------------------------------------------------------
git -C "$TARGET" remote set-url origin "$OR_URL"
git -C "$TARGET" remote add upstream "$UP_URL"

# --- Step 6: push (confirm first; never --force) ---------------------------
confirm "Push $BRANCH to $OR_URL?" \
  || die "push declined — mirror repo exists but is empty; push later with: git -C $TARGET push -u origin $BRANCH"
# push -u also sets $BRANCH's tracking to origin/$BRANCH (a separate
# --set-upstream-to cannot run before origin/$BRANCH exists).
git -C "$TARGET" push -u origin "$BRANCH" || die "push to $OR_URL rejected"

# --- Step 7: verify + report -----------------------------------------------
REMOTES=$(git -C "$TARGET" remote -v)
grep -qF "$OR_URL" <<<"$REMOTES" || die "origin is not $OR_URL after setup"
grep -qF "$UP_URL" <<<"$REMOTES" || die "upstream is not $UP_URL after setup"
repo_exists "$OR_HOST" "$OR_OWNER/$NAME" \
  || die "mirror repo $OR_OWNER/$NAME not visible after create"

cat <<EOF
[OK] packaging:mirror-repo
  Source  : $UP_URL
  Mirror  : $OR_URL
  Dest    : $TARGET/
  Remotes : origin=$OR_HOST, upstream=$UP_HOST
EOF
