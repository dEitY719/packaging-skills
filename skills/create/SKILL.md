---
name: create
description: >-
  Create an agent skill marketplace repo from scratch — root manifests for all
  six harnesses, flat skills/, copy-only skill import, git init, repo create,
  push. Use for "새 플러그인 만들어", "스킬 묶어서 플러그인으로",
  "skills repo 신규 생성", "/packaging:create <name>". New repos only.
license: MIT
compatibility:
  tools: Read, Write, Edit, Bash, Glob
metadata:
  model_recommendation:
    tier: sonnet
    reason: "multi-step composition: file writes + git/gh CLI orchestration; moderate complexity, no deep reasoning"
    claude: prefer
    non_claude: advisory-only
---

# Skills Marketplace Repo Creator

Compose a fresh `<domain>-skills` marketplace repo end-to-end: the split golden
structure (one repo = one plugin), copy skills **without mutating the source**,
write the harness manifests/README, then `git init` -> repo create -> push —
the "new repo" entry point the three sister skills do not cover.

## Layout: split (root manifests + flat `skills/`), never mono

`plugins/<plugin>/skills/` is the pre-#1410 mono layout and **this skill no
longer emits it** (dEitY719/dotfiles#1410 P-1). Rationale + six-harness file
list: `references/options.md`. Reference repos: `dEitY719/packaging-skills`,
`dEitY719/harness-skills`.

## Help

If arg #1 is `-h`, `--help`, or `help`, read `references/help.md` and output it verbatim, then stop. No filesystem or network calls.

## Step 1: Parse & Validate

Read `references/options.md` for the full flag/argument table and validation
rules. In short: `<repo-name>` (required) + optional `[skill ...]`, flags
`--src/--dest/--host/--owner/--plugin/--dry-run/-h`. Append `-skills` if
missing, enforce lowercase-hyphen naming, abort if `--src` missing or dest
exists (NOT idempotent), infer skills from chat else ask.

## Step 2: Plan (always)

Print the `[PLAN]` block per `references/help.md` -> "Plan output". `--dry-run` stops here — write nothing, create no repo.

## Step 3: Build the Directory Structure

Create the split golden layout under `<dest>/<repo-name>/` — full tree in
`references/options.md`. Never create a `plugins/` directory; CI fails the repo
if one exists.

## Step 4: Copy Skills (source is read-only)

`cp -r <src>/<skill> <dest>/<repo-name>/skills/` per skill — copy **into** the
parent `skills/` dir, never target `skills/<skill>` (nests to
`skills/<skill>/<skill>/`). Re-confirm each source dir unchanged afterward.

## Step 5: Write Manifests, Docs, CI, LICENSE, .gitignore

Fill every file from `references/manifest-templates.md` (harness manifests,
`package.json`, `CLAUDE.md` + the `AGENTS.md` symlink, `GEMINI.md`, the two CI
workflows, MIT LICENSE, `.gitignore`) and `references/readme-template.md`. One
`version` across all six version-bearing manifests, `license` = `MIT`
everywhere — CI gates both.

## Step 6: git init & Branch

`git init <dest>/<repo-name>`, then `git -C <dest>/<repo-name> checkout -B main`
(`-B` not `-b` — Git may already default to `main`, where `-b` fails).

## Step 7: Create the Remote Repo (outward-facing — confirm first)

After `GH_HOST=<host> gh auth status` and explicit confirmation: `gh repo create
<owner>/<repo-name> --public --description "<desc>"`, then `git remote add
origin git@<host>:<owner>/<repo-name>.git`. On GHES `gh` failure, use the web UI.

## Step 8: Initial Commit & Push (confirm first)

`git add .` -> `git commit -m "feat: init <repo-name>"` -> after confirmation,
`git push -u origin main`. **Never `git push --force`.**

## Step 9: Verify & Report

Run `packaging:structure-check <dest>/<repo-name> --single`, confirm M1-M10 PASS, emit the `[OK]` report per `references/help.md` -> "Completion report".

## Constraints

- **HARD-abort** on Step 1 validation, Step 7 `gh auth status` failure, and any
  push rejection. Everything else fails loudly, without partial cleanup.
- **Source is copy-only** — never modify/delete/symlink `--src`. Abort if dest
  exists (not idempotent); `--dry-run` writes nothing. Confirm repo-create +
  push; never force-push. Never emit a `plugins/` directory or a
  `claude-plugin-` repo name.

## Related Skills

`packaging:structure-check` (verify after create) · `packaging:structure-refactor` (fix an existing repo's layout) · `packaging:rename-repo` (rename to the team convention). This skill creates.
