---
name: rename-repo
description: >-
  Rename a claude-plugin marketplace repo to the team convention
  (claude-plugin-<domain>) and fix every hardcoded reference. Rename and push
  need confirmation. Use for "rename this plugin repo", "이 레포 이름 바꿔",
  "/packaging:rename-repo <name>".
license: MIT
compatibility:
  tools: Read, Bash, Edit, Write, Grep
metadata:
  model_recommendation:
    tier: sonnet
    reason: "multi-step repo rename: git/gh CLI, regex scan, multi-file edit; needs tool orchestration but not deep reasoning"
    claude: prefer
    non_claude: advisory-only
---

# claude-plugin Repo Renamer

Rename an existing `claude-plugin-*` marketplace repo to the team naming
convention `claude-plugin-<domain>`, then fix every hardcoded reference.
Full procedure (the embedded SSOT): `references/playbook.md`.

## Help

If arg #1 is `-h`, `--help`, or `help`, read `references/help.md` and output
its content verbatim, then stop. No git/gh calls.

## Step 0: Environment + Host Check

Confirm this directory is a clone of the target repo (`git remote -v`),
resolve `owner/repo`/host with `eval "$(bash skills/rename-repo/lib/parse_remote.sh
<remote>)"` (host-agnostic — never hardcode `github.com`, so GHES works too),
confirm `gh auth status` for that host, and refuse to work on the default
branch. Detail: `references/playbook.md` 0단계.

## Step 1: Decide the New Name

Use `<new-name>` verbatim if given (must carry the `claude-plugin-` prefix,
lowercase + hyphens only). Otherwise inspect the plugin composition and
propose 1-2 `claude-plugin-<domain>` names — the user picks; never rename
before their choice. Detail: `references/playbook.md` 1단계.

## Step 2: Rename the Repo (DESTRUCTIVE — confirm first)

`gh repo rename <new-name> --repo <org>/<OLD_REPO> --yes` (add `--hostname
<host>` on GHES; web UI fallback if `gh` can't reach it). Detail:
`references/playbook.md` 2단계.

## Step 3: Update the Local Remote + Verify

`git remote set-url origin <new repo URL>`, then confirm with
`git remote get-url origin` and `git ls-remote --heads origin`. Detail:
`references/playbook.md` 3단계.

## Step 4: Scan + Fix Hardcoded Old Names

`git grep -Fn "<OLD_REPO>"` (literal match — repo names can contain `.`),
fix every hit (`marketplace.json` `name`, `plugin.json`
`homepage`/`repository`, README + skill-README install commands), skip
relative `./plugins/...` sources, then re-grep for 0 hits. Detail:
`references/playbook.md` 4단계.

## Step 5: Commit (push is separate — confirm first)

Conventional-Commits style, matching this repo's git-log; push only after
explicit confirmation. Detail: `references/playbook.md` 5단계.

## Step 6: Verify & Report

Confirm the Step 4 re-grep is 0 hits and Step 3's `git ls-remote` verified,
then emit the `[OK]`/`[FAIL]` completion report from `references/help.md`.

## Constraints

- **HARD-abort** on: Step 0 host/auth failure or default-branch refusal,
  Step 2 `gh repo rename` failure, and any push rejection. A non-zero Step 4
  re-grep is reported as `[FAIL]` in the Step 6 verdict, not swallowed.
- Destructive/outward actions (repo rename, push) require confirmation first.
- Never edit a field whose value is a relative `source` path.
- `marketplace.json` `name` must equal the new repo name 1:1.

## Related Skills

`packaging:structure-check` (audits the layout) · `packaging:structure-refactor` (fixes the layout) · `packaging:create` (builds a new repo from scratch). This skill renames.
