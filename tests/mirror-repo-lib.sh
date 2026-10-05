#!/usr/bin/env bash
# tests/mirror-repo-lib.sh — offline check for skills/mirror-repo/lib/mirror_repo.sh.
#
# gh and git are stubs on PATH that log every call and touch nothing real, so
# no repo is ever cloned, created or pushed. Run: bash tests/mirror-repo-lib.sh

# shellcheck disable=SC2015  # `A && B || fail`: fail exits, so C never runs after a true A&&B
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/skills/mirror-repo/lib/mirror_repo.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin" LOG="$TMP/calls.log"
mkdir -p "$BIN"

# gh stub. Knobs: STUB_NOAUTH=<host>, STUB_UPSTREAM_MISSING=1, STUB_GHES_EXISTS=1.
cat >"$BIN/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh GH_HOST=${GH_HOST:-} $*" >>"$STUB_LOG"
case "$1 $2" in
  "auth status") [ "$4" != "${STUB_NOAUTH:-}" ] ;;
  "api --hostname") echo ghes-user ;;
  "repo view")
    if [ "$GH_HOST" = github.com ]; then [ -z "${STUB_UPSTREAM_MISSING:-}" ]
    else [ -n "${STUB_GHES_EXISTS:-}" ] || [ -f "$STUB_STATE/created" ]; fi ;;
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

pass=0
fail() { echo "FAIL: $1" >&2; echo "--- output:" >&2; cat "$TMP/out" >&2; exit 1; }
ok() { pass=$((pass + 1)); echo "ok    $1"; }

# run <stdin> <args...> — fresh dest/state/log per case; sets RC.
run() {
  local input="$1"; shift
  rm -rf "$TMP/dest" "$TMP/state"; mkdir -p "$TMP/dest" "$TMP/state"; : >"$LOG"
  export STUB_STATE="$TMP/state"
  RC=0
  printf '%s' "$input" | "$SCRIPT" "$@" --dest "$TMP/dest" --ghes-host ghes.example \
    >"$TMP/out" 2>&1 || RC=$?
}
log_has() { grep -qE -- "$1" "$LOG"; }

# 1. dry-run prints the plan and writes/creates/pushes nothing
run "" test-skills --dry-run
[ "$RC" -eq 0 ] || fail "dry-run exit $RC"
grep -q '^\[PLAN\] packaging:mirror-repo' "$TMP/out" || fail "dry-run: no [PLAN]"
grep -q 'origin    -> git@ghes.example:ghes-user/test-skills.git' "$TMP/out" || fail "dry-run: origin url"
grep -q 'Dry-run     : on' "$TMP/out" || fail "dry-run: flag line"
[ -z "$(ls -A "$TMP/dest")" ] || fail "dry-run wrote into dest"
log_has 'clone|repo create|push' && fail "dry-run ran a mutating call"
ok "dry-run writes nothing"

# 2. suffix auto-append
run "" test --dry-run
grep -q 'GHES repo    : ghes.example/ghes-user/test-skills' "$TMP/out" || fail "suffix not appended"
ok "-skills suffix auto-appended"

# 3. bad name rejected before any network call
run "" Bad_Name --dry-run
[ "$RC" -ne 0 ] && [ ! -s "$LOG" ] || fail "bad name accepted or hit network"
ok "bad name rejected offline"

# 4. claude-plugin- prefix rejected
run "" claude-plugin-video --dry-run
[ "$RC" -ne 0 ] && grep -q 'pre-#1410' "$TMP/out" && [ ! -s "$LOG" ] || fail "claude-plugin- not rejected"
ok "claude-plugin- prefix rejected"

# 5. dest exists -> abort, nothing touched
rm -rf "$TMP/state"; mkdir -p "$TMP/state" "$TMP/dest/test-skills"; : >"$LOG"; RC=0
"$SCRIPT" test-skills --dest "$TMP/dest" --ghes-host ghes.example --yes >"$TMP/out" 2>&1 || RC=$?
[ "$RC" -ne 0 ] && grep -q 'already exists' "$TMP/out" && [ ! -s "$LOG" ] || fail "dest-exists not aborted"
ok "dest exists aborts"

# 6. upstream missing -> abort
STUB_UPSTREAM_MISSING=1 run "" test-skills --yes
[ "$RC" -ne 0 ] && grep -q 'not found' "$TMP/out" || fail "upstream-missing not aborted"
log_has 'clone|repo create|push' && fail "upstream-missing still mutated"
ok "upstream missing aborts"

# 7. GHES repo exists -> abort
STUB_GHES_EXISTS=1 run "" test-skills --yes
[ "$RC" -ne 0 ] && grep -q 'git-pull-skills.sh' "$TMP/out" || fail "ghes-exists not aborted"
log_has 'clone|repo create|push' && fail "ghes-exists still mutated"
ok "GHES repo exists aborts"

# 8. auth missing on GHES -> abort
STUB_NOAUTH=ghes.example run "" test-skills --yes
[ "$RC" -ne 0 ] && grep -q 'not logged in to ghes.example' "$TMP/out" || fail "auth failure not aborted"
ok "auth failure aborts"

# 9. no confirmation (EOF / "n") -> no create, no push
run "" test-skills
[ "$RC" -ne 0 ] || fail "EOF confirmation proceeded"
log_has 'repo create|push' && fail "create/push ran without confirmation"
run $'n\n' test-skills
log_has 'repo create|push' && fail "create/push ran after 'n'"
ok "create gated on confirmation"

# 10. create confirmed, push declined -> create yes, push no
run $'y\nn\n' test-skills
[ "$RC" -ne 0 ] && log_has 'repo create ghes-user/test-skills --private' || fail "create after y missing"
log_has ' push' && fail "push ran after 'n'"
ok "push gated on its own confirmation"

# 11. full confirmed run: create, remotes, push, [OK]; never --force
run $'y\ny\n' test-skills
[ "$RC" -eq 0 ] || fail "confirmed run exit $RC"
log_has '^git clone https://github.com/dEitY719/test-skills.git ' || fail "clone not via HTTPS"
log_has 'GH_HOST=ghes.example repo create ghes-user/test-skills --private' || fail "create call"
log_has 'remote set-url origin git@ghes.example:ghes-user/test-skills.git' || fail "origin set-url"
log_has 'remote add upstream https://github.com/dEitY719/test-skills.git' || fail "upstream add"
log_has 'push -u origin main$' || fail "push call"
grep -q '\[OK\] packaging:mirror-repo' "$TMP/out" || fail "no [OK] report"
ok "confirmed run mirrors and reports"

# 12. --yes is equivalent to confirming both; still no --force anywhere
run "" test-skills --yes
[ "$RC" -eq 0 ] && log_has 'push -u origin main$' || fail "--yes run"
grep -qE -- '--force|-f( |$)|\+main' "$LOG" && fail "force push issued"
grep -vE '^[[:space:]]*#' "$SCRIPT" | grep -qE -- 'push[^#]*(--force|-f |\+)' && fail "script contains a force push"
ok "--yes path, never --force"

# 13. no --ghes-host and no dotfiles helper -> abort, never guess a host
rm -rf "$TMP/state" "$TMP/dest"; mkdir -p "$TMP/state"; : >"$LOG"; RC=0
SHELL_COMMON="$TMP/none" "$SCRIPT" test-skills --dest "$TMP/dest" --dry-run >"$TMP/out" 2>&1 || RC=$?
[ "$RC" -ne 0 ] && grep -q 'pass --ghes-host' "$TMP/out" || fail "unresolvable GHES host not aborted"
ok "unresolvable GHES host aborts"

# 14. host-agnostic: no github.<corp>.<tld> host literal in the skill
if grep -rqE 'github\.[A-Za-z0-9-]+\.[a-z]+' "$ROOT/skills/mirror-repo"; then
  fail "hardcoded github.<corp>.<tld> GHES host in skills/mirror-repo"
fi
ok "no hardcoded GHES host"

echo "ok    $pass mirror-repo checks passed"
