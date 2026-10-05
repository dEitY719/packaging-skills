# Options — full flag/argument reference for packaging:mirror-repo

Positional `<repo-name>` (required) plus the flags below. Every flag maps 1:1
onto `lib/mirror_repo.sh`; `--yes` is the script-only confirmation hand-off.

| Option | Required | Default | Description |
|--------|----------|---------|-------------|
| `<repo-name>` | yes | — | Repo name in `<domain>-skills` form. A missing `-skills` suffix is auto-appended. |
| `--owner <owner>` | no | `dEitY719` | Upstream owner. |
| `--ghes-owner <owner>` | no | active GHES login | GHES owner the mirror is created under (`gh api --hostname <ghes-host> user`). |
| `--dest <path>` | no | `~/para/project/skills/` | Parent directory the repo is cloned into. |
| `--host <host>` | no | `github.com` | Upstream host. |
| `--ghes-host <host>` | no | `_gh_resolve_host` | GHES host. Read from the dotfiles SSOT `shell-common/functions/gh_host.sh` (honours `$SHELL_COMMON`). |
| `--dry-run` | no | off | Steps 0-2 only: plan, no clone, no repo, no push. |
| `--yes` | no | off | Script only. Answers both confirmations — pass it only after the user said yes to create **and** push. |
| `-h` / `--help` / `help` | no | — | Print `references/help.md` verbatim and stop. |

## Validation rules (Steps 0-1)

Offline, before any network call:

- **Reject a `claude-plugin-` prefix** — pre-#1410 naming; the error proposes
  the `<domain>-skills` rewrite.
- Lowercase letters, digits and single hyphens only (`^[a-z0-9]+(-[a-z0-9]+)*$`).
- Append `-skills` when missing (`video` -> `video-skills`), with an `[INFO]` line.
- Abort if `<dest>/<repo-name>` already exists — not idempotent.

Host resolution:

- No `--ghes-host` and no readable `gh_host.sh` -> abort; a host is never guessed.
- GHES host equal to the upstream host (a public PC where `_gh_resolve_host`
  returns `github.com`) -> abort; pass `--ghes-host`.

Online:

- `gh auth status --hostname <h>` must pass for both hosts.
- `GH_HOST=<host> gh repo view <owner>/<repo-name>` must succeed (upstream exists).
- `GH_HOST=<ghes-host> gh repo view <ghes-owner>/<repo-name>` must fail
  (mirror does not exist yet) — otherwise abort and point at `git-pull-skills.sh`.

## Confirmation gates

Without `--yes`, the script asks `[y/N]` on stdin before `gh repo create` and
again before `git push`. Only `y`/`yes` proceeds; EOF or anything else aborts:

| Declined at | State left behind |
|-------------|-------------------|
| create | local clone only — delete `<dest>/<repo-name>` to retry |
| push | GHES repo exists but is empty — push later with `git -C <dest>/<repo-name> push -u origin <branch>` |

## Push

`git push -u origin <branch>`, where `<branch>` is the cloned default branch
(normally `main`). `-u` sets the branch's tracking to `origin/<branch>`; a
separate `--set-upstream-to` cannot run before that ref exists. Never
`--force`, never a `+` refspec.

## Not in scope

`marketplaces.json` is not modified — adding the repo to the manifest is the
user's choice. Refreshing an existing mirror is `git-pull-skills.sh`.
