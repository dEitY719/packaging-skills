---
name: mirror-repo
description: >-
  Mirror an external `*-skills` repo onto GHES: clone, create the GHES repo,
  origin=GHES + upstream=github.com, push. Use for "외부 skills 레포 GHES로
  미러링해", "GHES에 레포 복사", "mirror repo to GHES",
  "/packaging:mirror-repo <name>". New mirrors only.
license: MIT
compatibility:
  tools: Read, Bash
  network: required
metadata:
  model_recommendation:
    tier: sonnet
    reason: "multi-step git/gh CLI orchestration: clone, repo create, remote setup, push; moderate complexity, no deep reasoning"
    claude: prefer
    non_claude: advisory-only
---

# External Repo -> GHES Mirror

`git-clone-skills.sh` fails for any `*-skills` repo that exists on github.com
but was never mirrored to GHES. This skill does the mirror once: clone over
HTTPS, create the GHES repo, wire `origin`=GHES (SSH) and `upstream`=github.com
(HTTPS), push. Refreshing an existing mirror is `git-pull-skills.sh`'s job.

## Help

If arg #1 is `-h`/`--help`/`help`, output `references/help.md` verbatim and
stop. No filesystem or network calls.

## Engine

Every step below runs inside one script — never re-implement it in prose:

```
bash skills/mirror-repo/lib/mirror_repo.sh <repo-name> [--owner <o>] [--ghes-owner <o>]
     [--dest <path>] [--host <h>] [--ghes-host <h>] [--dry-run] [--yes]
```

Full flag table, defaults and validation rules: `references/options.md`.

## Step 0: Hosts + Auth

Upstream host `--host` (default `github.com`); GHES host `--ghes-host`, else
the dotfiles SSOT `_gh_resolve_host`. Both need `gh auth status`; the GHES
owner is the active GHES login unless `--ghes-owner`. Any failure HARD-aborts.

## Step 1: Validate

Lowercase-hyphen names only; reject a `claude-plugin-` prefix (pre-#1410);
auto-append `-skills`. Abort if `<dest>/<repo-name>` exists, the upstream
repo is missing, or the GHES repo already exists.

## Step 2: Plan (always)

Run the script with `--dry-run` first and show the user the `[PLAN]` block.
`--dry-run` stops there: no clone, no repo, no push.

## Steps 3-6: Clone, Create, Remotes, Push (confirm first)

Ask the user two explicit questions from the plan: create the private GHES
repo? push to it? Only when **both** are yes, re-run without `--dry-run` and
with `--yes`. Without `--yes` the script asks `[y/N]` on stdin and EOF counts
as no. It then clones, runs `gh repo create --private`, sets the remotes and
runs `git push -u origin <branch>`. **Never `git push --force`.**

## Step 7: Verify + Report

The script re-reads `git remote -v` and `gh repo view` on GHES, then prints
the `[OK]` block (format in `references/help.md`). Relay it verbatim.

## Constraints

- **HARD-abort** on auth failure, any Step 1 validation failure, a
  `gh repo create` failure, or a push rejection.
- **Confirm first** on GHES repo create and on push; never pass `--yes`
  without both answers. `--dry-run` writes nothing, creates nothing.
- Host-agnostic: never hardcode a GHES host or user. Does not edit
  `marketplaces.json`.

## Related Skills

`packaging:scaffold-repo` (creates a new repo from scratch) ·
`packaging:rename-repo` (renames a repo) · `packaging:structure-check` (audits
the mirrored repo's layout). This skill mirrors an existing external repo.
