# Options — full flag reference for packaging:mirror-repo

Every flag maps 1:1 onto `lib/mirror_repo.sh`; `--yes` is the script-only
confirmation hand-off.

| Option | Required | Default | Description |
|--------|----------|---------|-------------|
| `--upstream <url>` | yes | — | Source repo URL. Cloned verbatim and set as the `upstream` remote. |
| `--origin <url>` | yes | — | Mirror repo URL. Created on its host, set as the `origin` remote and pushed to. Its repo name is the clone directory name, used verbatim. |
| `--dest <path>` | no | `~/para/project/` | Parent directory the repo is cloned into. |
| `--visibility <public\|private>` | no | `private` | Visibility of the created mirror repo, passed to `gh repo create` as `--public` / `--private`. Any other value, or a missing value, aborts offline. |
| `--dry-run` | no | off | Steps 0-2 only: plan, no clone, no repo, no push. |
| `--yes` | no | off | Script only. Answers both confirmations — pass it only after the user said yes to create **and** push. |
| `-h` / `--help` / `help` | no | — | Print `references/help.md` verbatim and stop. The script's own `--help` prints usage with Examples. |

## URL forms

Both flags accept, with the `.git` suffix optional in every form:

```
https://<host>/<owner>/<repo>.git   http://<host>/<owner>/<repo>.git
git@<host>:<owner>/<repo>.git       ssh://git@<host>/<owner>/<repo>.git
```

The URL strings are used verbatim for `git clone` and for the `origin` /
`upstream` remotes. Host, owner and repo name are parsed from them; there are
no separate host/owner flags and no naming convention (no `-skills` suffix).

## Validation rules (Steps 0-1)

Offline, before any network call:

- Missing `--upstream` or `--origin` prints usage and exits 1.
- Unrecognized scheme aborts.
- The path after the host must be exactly `<owner>/<repo>`; anything else aborts.
- Embedded credentials (`user@` / `user:token@`) abort without echoing the
  URL; use a credential helper or SSH. A port in the URL aborts (not supported).
- Host must match `^[A-Za-z0-9.-]+$` with no leading or trailing dot; owner
  and repo `^[A-Za-z0-9._-]+$`.
- A bare positional argument (the removed `<repo-name>` form) aborts with a
  pointer to `--upstream` / `--origin`.
- Origin host must differ from upstream host (case-insensitive) — a mirror
  needs two different hosts.
- **Internal-PC guard**: when `~/.dotfiles-setup-mode` reads `internal`, an
  origin on `github.com` (or `www.github.com`, any case) aborts — never push
  to `github.com` from an internal PC. Other modes (or no file) proceed.
- `--visibility` must be `public` or `private` (default `private`).
- Abort if `<dest>/<repo>` already exists — not idempotent.

Online:

- `gh auth status --hostname <h>` must pass for both hosts.
- `GH_HOST=<upstream-host> gh repo view <owner>/<repo>` must succeed (upstream exists).
- `--visibility public` requires the upstream to be `PUBLIC`; a private or
  internal upstream aborts, so a mirror never publishes code kept private.
- `GH_HOST=<origin-host> gh repo view <owner>/<repo>` must fail (mirror does
  not exist yet) — otherwise abort.

## Confirmation gates

Without `--yes`, the script asks `[y/N]` on stdin before `gh repo create` and
again before `git push`. Only `y`/`yes` proceeds; EOF or anything else aborts:

| Declined at | State left behind |
|-------------|-------------------|
| create | local clone only — delete `<dest>/<repo>` to retry |
| push | mirror repo exists but is empty — push later with `git -C <dest>/<repo> push -u origin <branch>` |

## Push

`git push -u origin <branch>`, where `<branch>` is the cloned default branch
(normally `main`). `-u` sets the branch's tracking to `origin/<branch>`; a
separate `--set-upstream-to` cannot run before that ref exists. Never
`--force`, never a `+` refspec.

## Not in scope

`marketplaces.json` is not modified — adding the repo to the manifest is the
user's choice. Refreshing an existing mirror is a plain `git pull` /
`git-pull-skills.sh`.
