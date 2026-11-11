#!/usr/bin/env bash
# tests/mirror-repo-lib.sh — offline check for skills/mirror-repo/lib/mirror_repo.sh.
#
# gh and git are stubs on PATH that log every call and touch nothing real, so
# no repo is ever cloned, created or pushed. HOME points into the temp dir so
# ~/.dotfiles-setup-mode is under test control. Run: bash tests/mirror-repo-lib.sh

# shellcheck disable=SC2015  # `A && B || fail`: fail exits, so C never runs after a true A&&B
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/skills/mirror-repo/lib/mirror_repo.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin" LOG="$TMP/calls.log"
mkdir -p "$BIN" "$TMP/home"
export HOME="$TMP/home"

# gh stub. Knobs: STUB_NOAUTH=<host>, STUB_UPSTREAM_MISSING=1, STUB_MIRROR_EXISTS=1,
# STUB_UPSTREAM_VIS=<PUBLIC|PRIVATE|INTERNAL> (default PUBLIC),
# STUB_UP_HOST=<host> (which GH_HOST is the upstream; default github.com).
cat >"$BIN/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh GH_HOST=${GH_HOST:-} $*" >>"$STUB_LOG"
case "$1 $2" in
  "auth status") [ "$4" != "${STUB_NOAUTH:-}" ] ;;
  "repo view")
    if [ "$GH_HOST" = "${STUB_UP_HOST:-github.com}" ]; then
      [ -z "${STUB_UPSTREAM_MISSING:-}" ] || exit 1; echo "${STUB_UPSTREAM_VIS:-PUBLIC}"
    else [ -n "${STUB_MIRROR_EXISTS:-}" ] || [ -f "$STUB_STATE/created" ]; fi ;;
  "repo create") touch "$STUB_STATE/created" ;;
  *) exit 1 ;;
esac
EOF
# git stub: clone makes the dir, remotes live in a file inside it.
cat >"$BIN/git" <<'EOF'
#!/usr/bin/env bash
echo "git $*" >>"$STUB_LOG"
if [ "$1" = clone ]; then mkdir -p "$3"; echo "origin $2" >"$3/.remotes"; exit 0; fi
[ "$1" = -C ] || exit 1
d="$2"; shift 2
case "$1 ${2:-}" in
  "symbolic-ref --short") echo main ;;
  "remote set-url") sed -i "s#^origin .*#origin $4#" "$d/.remotes" ;;
  "remote add") echo "$3 $4" >>"$d/.remotes" ;;
  "remote -v") cat "$d/.remotes" ;;
  "push "*) : ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$BIN/gh" "$BIN/git"
export PATH="$BIN:$PATH" STUB_LOG="$LOG"

UP=https://github.com/dEitY719/equinest.git
OR=git@ghes.example:ghes-user/equinest.git

pass=0
fail() { echo "FAIL: $1" >&2; echo "--- output:" >&2; cat "$TMP/out" >&2; exit 1; }
ok() { pass=$((pass + 1)); echo "ok    $1"; }

# run <stdin> <args...> — fresh dest/state/log per case; sets RC. No --dest added.
run_raw() {
  local input="$1"; shift
  rm -rf "$TMP/dest" "$TMP/state"; mkdir -p "$TMP/dest" "$TMP/state"; : >"$LOG"
  export STUB_STATE="$TMP/state"
  RC=0
  printf '%s' "$input" | "$SCRIPT" "$@" >"$TMP/out" 2>&1 || RC=$?
}
run() { local input="$1"; shift; run_raw "$input" "$@" --dest "$TMP/dest"; }
log_has() { grep -qE -- "$1" "$LOG"; }
offline() { [ ! -s "$LOG" ]; }

# 1. dry-run prints the plan and writes/creates/pushes nothing
run "" --upstream "$UP" --origin "$OR" --dry-run
[ "$RC" -eq 0 ] || fail "dry-run exit $RC"
grep -q '^\[PLAN\] packaging:mirror-repo' "$TMP/out" || fail "dry-run: no [PLAN]"
grep -qF "origin    -> $OR" "$TMP/out" || fail "dry-run: origin url"
grep -qF "upstream  -> $UP" "$TMP/out" || fail "dry-run: upstream url"
grep -q 'Dry-run     : on' "$TMP/out" || fail "dry-run: flag line"
grep -q 'Visibility  : private' "$TMP/out" || fail "dry-run: default visibility line"
[ -z "$(ls -A "$TMP/dest")" ] || fail "dry-run wrote into dest"
log_has 'clone|repo create|push' && fail "dry-run ran a mutating call"
ok "dry-run writes nothing"

# 2. repo name used verbatim — no -skills suffix, no naming convention
grep -qF "Mirror repo  : ghes.example/ghes-user/equinest" "$TMP/out" || fail "mirror name not verbatim"
grep -qF "Destination  : $TMP/dest/equinest/" "$TMP/out" || fail "dest name not verbatim"
grep -q 'equinest-skills' "$TMP/out" && fail "-skills leaked into output"
run "" --upstream https://github.com/o/claude-plugin-Foo_Bar.git --origin git@ghes.example:u/claude-plugin-Foo_Bar.git --dry-run
[ "$RC" -eq 0 ] && grep -qF 'ghes.example/u/claude-plugin-Foo_Bar' "$TMP/out" || fail "name convention still enforced"
ok "repo name used verbatim"

# 3. HTTPS origin supported end to end
OR_HTTPS=https://ghes.example/ghes-user/equinest.git
run "" --upstream "$UP" --origin "$OR_HTTPS" --yes
[ "$RC" -eq 0 ] || fail "https origin exit $RC"
log_has "GH_HOST=ghes.example repo create ghes-user/equinest --private" || fail "https origin create"
log_has "remote set-url origin $OR_HTTPS\$" || fail "https origin set-url"
ok "HTTPS origin end to end"

# 4. scp-form upstream without .git parses
run "" --upstream git@github.com:dEitY719/equinest --origin "$OR" --dry-run
[ "$RC" -eq 0 ] && grep -qF 'Source repo  : github.com/dEitY719/equinest' "$TMP/out" \
  && grep -qF 'upstream  -> git@github.com:dEitY719/equinest' "$TMP/out" || fail "scp upstream without .git"
ok "scp-form upstream without .git parses"

# 5. ssh:// form parses
run "" --upstream "$UP" --origin ssh://git@ghes.example/team/equinest.git --dry-run
[ "$RC" -eq 0 ] && grep -qF 'Mirror repo  : ghes.example/team/equinest' "$TMP/out" || fail "ssh:// origin"
ok "ssh:// form parses"

# 6. malformed URLs rejected offline
for bad in https://github.com/equinest.git https://github.com/dEitY719/ \
           github.com/dEitY719/equinest.git ftp://github.com/a/b.git \
           https://github.com/a/b/c.git 'git@gh!x:a/b.git' 'https://github.com/a/b;c'; do
  run "" --upstream "$bad" --origin "$OR" --dry-run
  [ "$RC" -ne 0 ] && grep -q '^\[ABORT\]' "$TMP/out" && offline || fail "malformed upstream accepted: $bad"
done
run "" --upstream "$UP" --origin git@ghes.example:equinest.git --dry-run
[ "$RC" -ne 0 ] && offline || fail "ownerless origin accepted"
ok "malformed URLs rejected offline"

# 7. missing --upstream/--origin prints usage, offline; --help shows Examples
run "" --origin "$OR" --dry-run
[ "$RC" -ne 0 ] && grep -q '^Usage:' "$TMP/out" && offline || fail "missing --upstream"
run "" --upstream "$UP" --dry-run
[ "$RC" -ne 0 ] && grep -q '^Usage:' "$TMP/out" && offline || fail "missing --origin"
run_raw "" --help
[ "$RC" -eq 0 ] && grep -q '^Examples:' "$TMP/out" && offline || fail "--help lacks Examples"
ok "missing URL prints usage offline; --help has Examples"

# 8. origin host equals upstream host aborts
run "" --upstream "$UP" --origin git@GitHub.com:me/equinest.git --dry-run
[ "$RC" -ne 0 ] && grep -q 'two different hosts' "$TMP/out" && offline || fail "same host accepted"
ok "same host aborts"

# 9. internal-PC guard (upstream on a third host so the same-host guard stays quiet)
echo internal >"$HOME/.dotfiles-setup-mode"
STUB_UP_HOST=src.example run "" --upstream https://src.example/a/equinest.git --origin git@github.com:me/equinest.git --dry-run
[ "$RC" -ne 0 ] && grep -q 'internal PC' "$TMP/out" && offline || fail "internal github.com origin accepted"
echo external >"$HOME/.dotfiles-setup-mode"
STUB_UP_HOST=src.example run "" --upstream https://src.example/a/equinest.git --origin git@github.com:me/equinest.git --dry-run
[ "$RC" -eq 0 ] && grep -q '^\[PLAN\]' "$TMP/out" || fail "external github.com origin refused"
rm -f "$HOME/.dotfiles-setup-mode"
ok "internal-PC github.com origin guard"

# 10. dest exists / upstream missing / mirror exists / auth failure abort without mutating
rm -rf "$TMP/state" "$TMP/dest"; mkdir -p "$TMP/state" "$TMP/dest/equinest"; : >"$LOG"; RC=0
"$SCRIPT" --upstream "$UP" --origin "$OR" --dest "$TMP/dest" --yes >"$TMP/out" 2>&1 || RC=$?
[ "$RC" -ne 0 ] && grep -q 'already exists' "$TMP/out" && offline || fail "dest-exists not aborted"
STUB_UPSTREAM_MISSING=1 run "" --upstream "$UP" --origin "$OR" --yes
[ "$RC" -ne 0 ] && grep -q 'not found' "$TMP/out" || fail "upstream-missing not aborted"
log_has 'clone|repo create|push' && fail "upstream-missing still mutated"
STUB_MIRROR_EXISTS=1 run "" --upstream "$UP" --origin "$OR" --yes
[ "$RC" -ne 0 ] && grep -q 'already exists' "$TMP/out" || fail "mirror-exists not aborted"
log_has 'clone|repo create|push' && fail "mirror-exists still mutated"
STUB_NOAUTH=ghes.example run "" --upstream "$UP" --origin "$OR" --yes
[ "$RC" -ne 0 ] && grep -q 'not logged in to ghes.example' "$TMP/out" || fail "auth failure not aborted"
log_has 'clone|repo create|push' && fail "auth failure still mutated"
ok "dest/upstream/mirror/auth failures abort"

# 11. both confirmation gates enforced independently
run "" --upstream "$UP" --origin "$OR"
[ "$RC" -ne 0 ] || fail "EOF confirmation proceeded"
log_has 'repo create|push' && fail "create/push ran without confirmation"
run $'n\n' --upstream "$UP" --origin "$OR"
log_has 'repo create|push' && fail "create/push ran after 'n'"
run $'y\nn\n' --upstream "$UP" --origin "$OR"
[ "$RC" -ne 0 ] && log_has 'repo create ghes-user/equinest --private' || fail "create after y missing"
log_has ' push' && fail "push ran after 'n'"
ok "create and push gated independently"

# 12. full confirmed run: URLs verbatim, create with visibility, push, [OK]
run $'y\ny\n' --upstream "$UP" --origin "$OR"
[ "$RC" -eq 0 ] || fail "confirmed run exit $RC"
log_has "^git clone $UP " || fail "clone not from upstream URL verbatim"
log_has 'GH_HOST=ghes.example repo create ghes-user/equinest --private' || fail "create call"
log_has "remote set-url origin $OR\$" || fail "origin set-url"
log_has "remote add upstream $UP\$" || fail "upstream add"
log_has 'push -u origin main$' || fail "push call"
grep -q '\[OK\] packaging:mirror-repo' "$TMP/out" || fail "no [OK] report"
ok "confirmed run mirrors and reports"

# 13. --yes is equivalent to confirming both; still no --force anywhere
run "" --upstream "$UP" --origin "$OR" --yes
[ "$RC" -eq 0 ] && log_has 'push -u origin main$' || fail "--yes run"
grep -qE -- '--force|-f( |$)|\+main' "$LOG" && fail "force push issued"
grep -vE '^[[:space:]]*#' "$SCRIPT" | grep -qE -- 'push[^#]*(--force|-f |\+)' && fail "script contains a force push"
ok "--yes path, never --force"

# 14. --visibility: plan, confirm, create; invalid/missing offline; public of non-public refused
run "" --upstream "$UP" --origin "$OR" --visibility public --dry-run
[ "$RC" -eq 0 ] && grep -q 'Visibility  : public' "$TMP/out" || fail "dry-run: public visibility line"
run $'y\nn\n' --upstream "$UP" --origin "$OR" --visibility public
log_has 'repo create ghes-user/equinest --public' || fail "create not public"
grep -q 'Create public repo ghes.example/ghes-user/equinest?' "$TMP/out" || fail "confirm text lacks visibility"
run "" --upstream "$UP" --origin "$OR" --visibility internal --dry-run
[ "$RC" -ne 0 ] && grep -q 'public|private' "$TMP/out" && offline || fail "invalid visibility accepted"
run_raw "" --upstream "$UP" --origin "$OR" --visibility
[ "$RC" -ne 0 ] && grep -q 'needs a value' "$TMP/out" && offline || fail "missing visibility value accepted"
STUB_UPSTREAM_VIS=PRIVATE run "" --upstream "$UP" --origin "$OR" --visibility public --yes
[ "$RC" -ne 0 ] && grep -q 'refusing --visibility public' "$TMP/out" || fail "private upstream mirrored public"
log_has 'clone|repo create|push' && fail "private-upstream public mirror still mutated"
ok "--visibility reaches plan/confirm/create; validated; public-of-private refused"

# 15. host-agnostic: no hardcoded mirror host literal in lib/
if grep -rqE 'github\.[A-Za-z0-9-]+\.[a-z]+' "$ROOT/skills/mirror-repo"; then
  fail "hardcoded github.<corp>.<tld> mirror host in skills/mirror-repo"
fi
ok "no hardcoded mirror host in lib/"

echo "ok    $pass mirror-repo checks passed"
