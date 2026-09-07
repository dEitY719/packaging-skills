---
name: create
description: >-
  Create an agent skill marketplace repo from scratch — manifests for every
  harness, flat skills/, copy-only import, git init, create, push. Use for
  "새 플러그인 만들어", "스킬 묶어서 플러그인으로", "skills repo 신규 생성",
  "/packaging:create <name>". New repos only.
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
structure (1 repo = 1 plugin), copy skills **without mutating the source**,
write manifests/README, then `git init` -> repo create -> push.

## Layout: split (root manifests + flat `skills/`), never mono

`plugins/<plugin>/skills/` is the pre-#1410 mono layout and **this skill no
longer emits it** (dEitY719/dotfiles#1410 P-1). Rationale, per-harness file list,
CI gates, and the two reference repos: `references/options.md`.

## Help

If arg #1 is `-h`/`--help`/`help`, output `references/help.md` verbatim and
stop. No filesystem or network calls.

## Step 1: Parse & Validate

Full flag/argument table and validation rules: `references/options.md`.
`<repo-name>` (required) + optional `[skill ...]`; abort if `--src` is missing
or `<dest>/<repo-name>` already exists; infer skills from chat, else ask.

## Step 2: Plan (always)

Print the `[PLAN]` block per `references/help.md`. `--dry-run` stops here.

## Step 3: Build the Directory Structure + Mechanical Manifests

Run `skills/create/lib/scaffold_repo.sh --name <repo-name> --plugin <plugin> --dest <dest> --owner <owner> --host <host> --description "<one-line>" --plugin-description "<plugin desc>" --skill <skill> [--skill <skill> ...]` —
builds the split golden tree (never `plugins/`; CI rejects one) plus every mechanically-derivable file (manifests, `package.json`, CI workflows, `LICENSE`, `.gitignore`).
Full list + CI's version/license gate: `references/options.md`, `references/manifest-templates.md`. Aborts, no writes, if the dest exists.

## Step 4: Copy Skills (source is read-only) + Verify Frontmatter

`cp -r <src>/<skill> <dest>/<repo-name>/skills/` per skill — copy **into** the
parent `skills/` dir, never target `skills/<skill>` (nests to
`skills/<skill>/<skill>/`). Re-confirm each source dir unchanged afterward, then
run `references/options.md` -> "Copied-skill frontmatter" against the **copies**
(bare `name:` = dir, `description:`, `license: MIT`). Fix in the copy or abort —
never in `--src`.

## Step 5: Write the Prose Docs

Write `CLAUDE.md` (+ `AGENTS.md` symlink), `GEMINI.md`, `README.md` from
`references/manifest-templates.md` + `references/readme-template.md`, naming
each copied skill (Step 4) with its real `description:` — Step 3's script
can't compose this.

## Step 6: git init & Branch

`git init <dest>/<repo-name>` then `git -C <dest>/<repo-name> checkout -B main`
(`-B`, not `-b` — Git may default to `main` already, where `-b` fails).

## Step 7: Create the Remote Repo (outward-facing — confirm first)

After `GH_HOST=<host> gh auth status` and explicit confirmation: `gh repo create
<owner>/<repo-name> --public --description "<desc>"`, then `git remote add
origin git@<host>:<owner>/<repo-name>.git`. On GHES failure, use the web UI.

## Step 8: Initial Commit & Push (confirm first)

`git add .` -> `git commit -m "feat: init <repo-name>"` -> after confirmation, `git push -u origin main`. **Never `git push --force`.**

## Step 9: Verify & Report

Run `packaging:structure-check <dest>/<repo-name> --single`, confirm M1-M10 PASS,
then emit the `[OK]` report from `references/help.md`.

## Constraints

- **HARD-abort** on Step 1 validation, a Step 4 frontmatter violation, Step 7
  `gh auth status` failure, and any push rejection. Everything else fails loudly.
- **Source is copy-only** — never modify/delete/symlink `--src`. Abort if dest
  exists (not idempotent); `--dry-run` writes nothing. Confirm repo-create and
  push; never force-push, never emit a `plugins/` dir or `claude-plugin-` name.

## Related Skills

`packaging:structure-check` (verify after create) · `packaging:structure-refactor` (fix an existing repo's layout) · `packaging:rename-repo` (rename to the team convention). This skill creates.
