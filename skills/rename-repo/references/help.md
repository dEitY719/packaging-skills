/packaging:rename-repo — Rename a claude-plugin repo to the team convention

Usage:
  /packaging:rename-repo <new-name>   Rename to an explicit name
  /packaging:rename-repo              Auto-propose a name, you choose
  /packaging:rename-repo help         Print this usage

Arguments:
  <new-name>   Full new repo name in lowercase with hyphens, including the
               claude-plugin- prefix (e.g. claude-plugin-visuals). Optional —
               when omitted, the skill inspects the plugin composition and
               proposes 1-2 names.

Behavior (per-step):
  0  Env/host check     git remote -v + gh auth status; identify github.com
                        vs GHES; refuse the default branch
  1  Name decision      use the arg, or propose claude-plugin-<domain> names
  2  gh repo rename     DESTRUCTIVE — confirm first (GHES: --hostname / web UI)
  3  Remote URL update  git remote set-url origin + ls-remote verification
  4  Reference scan/fix  git grep "<OLD>" → fix marketplace.json name,
                        plugin.json homepage/repository, README install cmds;
                        skip relative ./plugins/... source paths; verify 0 hits
  5  Commit             Conventional Commits style; push only after confirm

Safety:
  - Destructive steps (repo rename, push) require explicit user confirmation.
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
  /skill:check   — audit a SKILL.md's content quality
  /sh:check      — audit a shell script's quality
