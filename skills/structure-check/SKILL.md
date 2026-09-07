---
name: structure-check
description: >-
  Audit a claude-plugin marketplace repo's directory layout. Read-only;
  `packaging:structure-refactor` fixes. Use for "check my claude-plugin
  repo structure", "/packaging:structure-check". Not SKILL.md
  (`authoring:skill-check`) or shell (`authoring:sh-check`).
license: MIT
compatibility:
  tools: Read, Glob, Grep, Bash
metadata:
  model_recommendation:
    tier: haiku
    reason: "read-only directory-structure audit; dynamic scan + JSON/frontmatter validation; bounded PASS/WARN/FAIL report"
    claude: prefer
    non_claude: advisory-only
---

# claude-plugin Structure Auditor

## Help

If arg #1 is `-h`, `--help`, or `help`, read `references/help.md` and output
its content verbatim, then stop. No filesystem scan.

## Step 1: Parse Args + Resolve Repo Path

- Positional `[repo-path]` → audit that path. None → audit the current
  directory.
- Flags `--single` / `--mono` → force the layout mode, overriding
  auto-detection (Step 2). Mutually exclusive; if both given, last wins.
- Confirm the path exists; if not, stop with a one-line error pointing to
  `/packaging:structure-check path/to/repo`.
- Check `test -d <path>/.git`; not a git repo → continue, but note it
  (one warning line — the audit still runs).

## Step 2: Detect Mode + Discover Plugin Roots + Skills

Read `references/structure-spec.md` for the full standard (embedded SSOT) —
see "Layout modes", "Mode detection", and "Mandatory items by mode". The same
logic is executable in `lib/structure_check.sh` (run in Step 3); spec and
script must agree.

Record the detected mode, plugin-root list, and skill list for the report
header and the per-skill recommended checks (R1/R2/R5).

## Step 3: Evaluate M1-M10 and R1-R8

Run `bash lib/structure_check.sh "$REPO" ${MODE_FLAG:-}` — the script sits
next to this SKILL.md (resolve its path from where this skill is installed,
not from `$REPO`). `$REPO` = Step 1's resolved path; `$MODE_FLAG` =
`--single`/`--mono` if forced, else omitted. It prints `MODE`/`PLUGINS`/
`SKILLS`/`GIT` context lines, one `<ID> <RESULT> [detail]` line for every
M1-M10 and R1/R2/R4-R8 item, and a `SUMMARY` line — see its header comment
for the exact contract. Mandatory items FAIL when missing, including M7-M9
marketplace `plugins[].source` install integrity and M10 `plugin.json`
known-field schema (dEitY719/dotfiles#1084).

**R3 is scored by you, not the script** — it needs judgment (README length +
whether it substantively mentions plugins/skills). Apply the heuristic in
`references/structure-spec.md` yourself and fold it into the script's
FAIL/WARN/N/A counts for the final verdict. Item table: `references/help.md`.

## Step 4: Output the Report

Read `references/report-template.md` for the exact format, including the
summary-verdict rule and the install/runtime disclaimer — both are owned
there; this step just applies them.

## Constraints

- Read-only — never create, move, or edit any file. Fixing is
  `packaging:structure-refactor`'s job.
- N/A is not FAIL — a missing *subject* (no skills, no plugins beyond M2)
  yields N/A for dependent checks.
- Do not audit SKILL.md *content* (that is `authoring:skill-check`) or shell
  script quality (that is `authoring:sh-check`) — only the directory structure.
- Repo-agnostic: detect mode + discover plugin roots/skills by scan; the
  spec is embedded, not read from the target repo. A `--single`/`--mono`
  override means "score by *that* mode" — a wrong override surfaces as a
  normal M2 FAIL, never a silent skip.

## Related Skills

`packaging:structure-refactor` (fixes what this finds) · `packaging:rename-repo` (renames the repo to the team convention) · `packaging:create` (builds a new repo from scratch).
