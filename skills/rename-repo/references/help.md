/packaging:rename-repo — Rename a claude-plugin repo to the team convention

Usage:
  /packaging:rename-repo <new-name>   Rename to an explicit name
  /packaging:rename-repo              Auto-propose a name, you choose
  /packaging:rename-repo help         Print this usage

Arguments:

| Option | Description | Default |
|--------|-------------|---------|
| `<new-name>` | new repo name, `claude-plugin-<domain>` form, lowercase + hyphens | inferred from plugin composition, user picks |
| `-h`/`--help`/`help` | print this help and stop — no git/gh calls | — |

Behavior (per-step — full detail in SKILL.md / references/playbook.md):
  0  Env/host check     parse_remote.sh + gh auth status; refuse default branch
  1  Name decision      use the arg, or propose claude-plugin-<domain> names
  2  gh repo rename     DESTRUCTIVE — confirm first (GHES: --hostname / web UI)
  3  Remote URL update  git remote set-url origin + ls-remote verification
  4  Reference scan/fix  git grep -F "<OLD>" → fix, verify 0 hits
  5  Commit + push      Conventional Commits; push only after confirm
  6  Verify & report    emit the completion report below

Completion report (Step 6):
  [OK] packaging:rename-repo
    Old   : <org>/<OLD_REPO>
    New   : <org>/<NEW_REPO>
    Files : <n> updated (marketplace.json, plugin.json, README.md, ...)
    Grep  : 0 remaining hits for "<OLD_REPO>"
    Pushed: yes | no (awaiting confirmation)
    Next  : /packaging:structure-check .   (re-verify the renamed repo)

  [FAIL] when the Step 4 re-grep is non-zero or `git ls-remote` did not
  verify — same fields, with the non-zero grep count or the failed check
  named in place of "0 remaining hits".

Safety:
  - Destructive/outward steps (repo rename, push) require explicit confirmation.
  - Never works on the default branch — needs a feature branch.
  - Interactive gh login (gh auth login) must be run by the user, not the skill.
  - Relative `source` paths are repo-name-independent — left untouched.

Examples:
  /packaging:rename-repo claude-plugin-visuals
  /packaging:rename-repo
  /packaging:rename-repo help

Sister skills:
  /packaging:structure-check     — audit a claude-plugin repo's layout
  /packaging:structure-refactor  — fix that layout toward the standard

Not this skill:
  /authoring:skill-check   — audit a SKILL.md's content quality
  /authoring:sh-check      — audit a shell script's quality
