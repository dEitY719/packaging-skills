---
name: structure-refactor
description: >-
  Fix a claude-plugin marketplace repo's structure toward the standard
  layout. Dry-run unless `--apply`. Use for "fix my claude-plugin repo
  structure", "/packaging:structure-refactor". Edits —
  `packaging:structure-check` only audits.
license: MIT
compatibility:
  tools: Read, Glob, Grep, Write, Edit, Bash
  network: required
metadata:
  model_recommendation:
    tier: sonnet
    reason: "structure correction: dir creation + git mv history-preserving moves + JSON skeletons + placeholder stubs; bounded multi-file write, no deep reasoning"
    claude: prefer
    non_claude: advisory-only
---

# claude-plugin Structure Refactorer

## Help

If arg #1 is `-h`, `--help`, or `help`, read `references/help.md` and output
its content verbatim, then stop. No filesystem changes.

## Step 1: Parse Args + Resolve Path

Positional `[repo-path]` (default = current dir). Full flag table:
`references/help.md`. In short:

- `--apply` — execute changes. Absent → dry-run (plan only, no writes).
- `--mandatory` / `--mp` (default scope) — M1-M10 only; `--recommended` /
  `--op` — M1-M10 + R1-R5 (R6-R8 stay audit-only WARNs, never auto-applied).
- `--single` / `--mono` — force the **target** layout mode, overriding Step 2
  auto-detection. Mutually exclusive, last wins. `--mp` + `--op` → error, stop.

Confirm the path exists. `test -d <path>/.git`: not a git repo → warn (moves
fall back to `mv`). Dirty tree → show the dry-run plan and require an explicit
`--apply` before writing (never auto-apply on a dirty tree).

## Step 2: Detect Mode + Compute Plugin Roots + Evaluate Current ↔ Target

Read `../structure-check/references/structure-spec.md` (the SSOT this skill
shares with `structure-check` — one spec, not two drifting copies) for layout
modes, mode detection/override, and mandatory items by mode.

1. **Detect the current mode** (priority: flag → manifest `plugins[].source`
   → filesystem → default `mono`).
2. **Conversion guard** — forced mode ≠ detected current layout → out of
   scope (rules in `references/plan-and-report-templates.md` →
   "Layout-conversion warning").
3. **Compute the plugin-root set**: `mono` → each `plugins/*/`; `single` →
   repo root `./` (exactly one).
4. **Discover skills** and run M1-M10 / R1-R8 evaluation over the roots to
   compute the current → target diff.

## Step 3: Build the Plan

Read `references/plan-and-report-templates.md`. Produce an ordered change list,
each tagged with its driving check ID (M1-M10, and R1-R5 only when scope is
`--op`; R6-R8 are audit-only and never produce a plan line). **Paths are
plugin-root relative** — single targets root `./` (no `plugins/` dir ever
created); mono targets `plugins/<p>/`. Already-correct items produce no action
(idempotent). The plan header states the detected/forced mode; an unsupported
conversion produces only the `[convert]` warning line.

## Step 4: Dry-run or Apply

- **Conversion required (forced mode ≠ detected)**: print the `[convert]`
  warning and stop — even under `--apply`, don't run the script below.
- Otherwise, under `--op`, generate real R1 guides first: call
  `/visuals:visualize <SKILL.md>` for each skill still missing
  `docs/skill-guides/<s>.html`; on failure, warn and move on (the script's
  fallback stub covers it next).
- Run `bash skills/structure-refactor/lib/refactor_apply.sh "$REPO" --mode
  "$MODE" --scope "$SCOPE" ${APPLY:+--apply}` (dry-run omits `--apply`). It
  executes every mkdir/skeleton/M7-source/M10-prune/R1-fallback/R2-stub/
  Pages/R4-rename/R5-link step — rule-by-rule detail is in
  `references/plan-and-report-templates.md`. M2, M4, M8, M9 have no
  auto-fix (same file explains why) and are left for a human.

## Step 5: Report

Use the completion report template in
`references/plan-and-report-templates.md` — end with `[OK]`/`[FAIL]` + a
key=value summary, then the next-action hint:

- after a dry-run: `Next: /packaging:structure-refactor <path> --apply [--op]`
- after `--apply`: `Next: /packaging:structure-check <path>` (re-verify)

## Constraints

See `references/plan-and-report-templates.md` → "Constraints (Never /
Always)" for the full rule set (dry-run default, idempotency, `git mv`
preference, the single↔mono conversion guard, soft-fail behaviors).

## Related Skills

`packaging:structure-check` (audits what this fixes) · `packaging:rename-repo` (renames the repo to the team convention) · `packaging:create` (builds a new repo from scratch).
