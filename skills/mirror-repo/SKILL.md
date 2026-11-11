---
name: mirror-repo
description: >-
  Mirror any existing repo onto another host (e.g. github.com -> GHES) from
  two URLs: clone, create the mirror repo, origin=mirror + upstream=source,
  push. Use for "외부 레포 GHES로 미러링해", "GHES에 레포 복사",
  "mirror repo to GHES", "/packaging:mirror-repo --upstream <url> --origin <url>".
  New mirrors only.
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

# External Repo -> Mirror

Mirrors an existing repo from one host onto another — typically a github.com
repo onto GHES — once: clone the `--upstream` URL, create the `--origin` repo,
wire `origin`=mirror and `upstream`=source, push. Any repo works; no naming
convention is enforced. Refreshing an existing mirror is a plain pull.

## Help

If arg #1 is `-h`/`--help`/`help`, output `references/help.md` verbatim and
stop. No filesystem or network calls.

## Engine

Every step below runs inside one script — never re-implement it in prose:

```
bash skills/mirror-repo/lib/mirror_repo.sh --upstream <url> --origin <url>
     [--dest <path>] [--visibility public|private] [--dry-run] [--yes]
```

Full flag table, URL forms and validation rules: `references/options.md`.

## Step 0: Parse URLs + Auth

Both URLs are required (`https://`, `http://`, `git@<host>:` or
`ssh://git@`, `.git` optional); host, owner and repo name are parsed from
them offline. Both hosts need `gh auth status`. Any failure HARD-aborts.

## Step 1: Validate

Abort on a malformed URL, origin host equal to upstream host, or — on an
internal PC (`~/.dotfiles-setup-mode` = `internal`) — an origin on
`github.com`. Abort if `<dest>/<repo>` exists, the upstream repo is missing,
or the mirror repo already exists. The origin repo name is used verbatim.

## Step 2: Plan (always)

Run the script with `--dry-run` first and show the user the `[PLAN]` block.
`--dry-run` stops there: no clone, no repo, no push.

## Steps 3-6: Clone, Create, Remotes, Push (confirm first)

Ask the user two explicit questions from the plan: create the mirror repo with
the `Visibility` the plan shows (`--visibility`, default `private`)? push to
it? Only when **both** are yes, re-run without `--dry-run` and with `--yes`.
Without `--yes` the script asks `[y/N]` on stdin and EOF counts as no. It then
clones, runs `gh repo create --public|--private`, sets the remotes and runs
`git push -u origin <branch>`. **Never `git push --force`.**

## Step 7: Verify + Report

The script re-reads `git remote -v` and `gh repo view` on the mirror host, then prints
the `[OK]` block (format in `references/help.md`). Relay it verbatim.

## Constraints

- **HARD-abort** on auth failure, any Step 1 validation failure, a
  `gh repo create` failure, or a push rejection.
- **Confirm first** on mirror repo create and on push; never pass `--yes`
  without both answers. `--dry-run` writes nothing, creates nothing.
- Host-agnostic: every host comes from the URLs; never hardcode one. Does not edit
  `marketplaces.json`.

## Related Skills

`packaging:scaffold-repo` (creates a new repo from scratch) ·
`packaging:rename-repo` (renames a repo) · `packaging:structure-check` (audits
the mirrored repo's layout). This skill mirrors an existing external repo.
