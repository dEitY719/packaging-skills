/packaging:create — Create a new agent skill marketplace repo from scratch

Usage:
  /packaging:create <repo-name> [skill ...] --src <path> [--dest <path>]
                        [--host <ghes-host>] [--owner <owner>] [--plugin <name>] [--dry-run]
  /packaging:create help

Arguments:
  <repo-name>     Repo name in `<domain>-skills` form (required). A missing
                  `-skills` suffix is auto-appended (you are told). A
                  `claude-plugin-` prefix is REJECTED — that is the pre-#1410
                  naming. Lowercase + hyphens only (GitHub repo naming rules).
  [skill ...]     Skill directory names to copy (space-separated). Omitted ->
                  inferred from the conversation; if not inferable, you are
                  asked for the list (never guessed).

Flags:
  --src <path>    Skill source directory.   REQUIRED — no default.
  --dest <path>   Where the repo is created. default ~/para/project/skills/
  --host <host>   GitHub host.               default github.com
  --owner <owner> GitHub owner.              default dEitY719
  --plugin <name> Plugin key (inner name).   default = <repo-name> minus the
                  `-skills` suffix  (harness-skills -> harness)
  --dry-run       Print the plan only — no files, no repo, no commit.
  -h | --help     Print this help and stop. No filesystem or network calls.

Plan output (Step 2, always printed):
  [PLAN] packaging:create
    Repo name   : harness-skills
    Plugin key  : harness
    Destination : ~/para/project/skills/harness-skills/
    Skills to copy (N):
      <src>/<skill>                     -> skills/<skill>
      ...
    GH repo     : github.com/dEitY719/harness-skills
    Dry-run     : off
  (--dry-run stops here.)

Behavior (split golden layout — 1 repo = 1 plugin, dotfiles#1410 P-1):
  1. Parse & validate (naming, --src exists, dest not present, skill list).
  2. Print the plan (stop if --dry-run).
  3. Build the structure: root manifests for all seven harnesses
     (.claude-plugin/, .codex-plugin/, .kimi-plugin/, .hermes-plugin/,
     .opencode/, .agents/, gemini-extension.json), flat skills/,
     docs/skill-guides/, docs/skill-output/, .github/workflows/.
     NEVER a plugins/ directory — that is the pre-#1410 mono layout, which
     only Claude Code can resolve and which CI rejects.
  4. Copy each skill into skills/ (cp -r). Source is RE-VERIFIED unchanged,
     then each COPY's frontmatter is checked (bare name = directory,
     description, license: MIT, <= 100 lines). Violations are fixed in the
     copy or abort -- never in --src.
  5. Write manifests + CLAUDE.md (+ AGENTS.md symlink) + GEMINI.md + README
     + LICENSE + .gitignore + CI workflows from the templates.
  6. git init + checkout -B main.
  7. gh repo create (after gh auth status + user confirmation).
  8. git add + commit "feat: init <repo-name>" + push (after confirmation).
  9. packaging:structure-check --single -> confirm M1-M10 PASS.

Completion report (Step 9):
  [OK] packaging:create
    Repo  : https://<host>/<owner>/<repo-name>
    Skills: N copied
    Check : M1-M10 PASS
    Next  : /packaging:structure-check <dest>/<repo-name> --single  (re-verify)
            docs/skill-guides/ 시각 가이드 추가 -> /visuals:visualize

Safety:
  - --src is REQUIRED and has no default: a missing --src is a Step 1 HARD
    abort with an error, never a prompt and never a guessed path.
  - Source (--src) is COPY-ONLY — never modified, moved, deleted, symlinked.
    A frontmatter violation is fixed in the copy under <dest>, never at source.
  - <dest>/<repo-name> already exists -> ABORT (no overwrite; not idempotent).
  - Remote repo creation and push are outward-facing — confirmed before each.
  - gh auth status is checked before any gh call; never git push --force.

Examples:
  /packaging:create harness-skills ai-context --src <skills-dir>
  /packaging:create harness ai-context --src <skills-dir> --dry-run
  /packaging:create visuals-skills visualize --src <skills-dir> --owner acme
  /packaging:create help

Sister skills:
  /packaging:structure-check     — read-only audit (run after create)
  /packaging:structure-refactor  — fix an existing repo's structure
  /packaging:rename-repo         — rename a repo to the team convention
