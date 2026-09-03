# packaging-skills — Contributor Guidelines

This file is the AI context document for this repo. `AGENTS.md` is a symlink to
it, so Claude Code, Codex, Gemini CLI, and every other harness read the same
text. Edit `CLAUDE.md`; never replace the symlink with a second copy.

## What this repo is

A single-plugin skill marketplace. The plugin is named `packaging` and it
bundles four skills used to build and maintain *other* skill marketplace repos:

| Skill | Role |
|-------|------|
| `plugin-create` | Scaffold a new marketplace repo end to end. New repos only. |
| `rename-repo` | Rename an existing repo to convention, fixing every hardcoded reference. |
| `structure-check` | Audit a repo's layout. Read-only. |
| `structure-refactor` | Apply the fixes. Dry-run unless `--apply`. |

The skills were extracted from `dEitY719/dotfiles` (`claude/skills/claude-plugin-*`)
as a snapshot — see the first commit for the source SHA. The dotfiles copies
remain in place for now; they are removed in a later phase of that repo's
migration plan.

## Layout: root manifests, one flat `skills/`

This repo deliberately does **not** use the nested `plugins/<name>/skills/`
"mono" layout. Every harness manifest sits at the repo root and points at a
single flat `./skills/` directory:

```
.claude-plugin/{marketplace,plugin}.json   Claude Code
.codex-plugin/plugin.json                  Codex
.kimi-plugin/plugin.json                   Kimi CLI
.hermes-plugin/{plugin.yaml,__init__.py}   Hermes Agent
.opencode/plugins/packaging.js             OpenCode
.agents/plugins/marketplace.json           Antigravity
gemini-extension.json + GEMINI.md          Gemini CLI
skills/<name>/SKILL.md                     the skills themselves
```

Only Claude Code understands the nested mono layout. The other five harnesses
resolve manifests at the repo root and a skills tree at `./skills/`, so nesting
would silently cut this plugin down to Claude-Code-only. **Do not move the
manifests under a `plugins/` directory.**

## Rules for changing skills

- **Skill directory name is the identity.** `skills/<name>/` must match the
  `name:` field in that skill's `SKILL.md` frontmatter, and that field is the
  **bare** name (`structure-check`), never namespaced (`packaging:structure-check`).
  The harness supplies the `packaging:` prefix at invocation time.
- **Invocation form in prose is namespaced.** Body text referring to a skill as
  a command writes `/packaging:structure-check`.
- **Progressive disclosure.** `SKILL.md` stays short and names which
  `references/` file to read and when. Detail lives in `references/`. Do not
  inline a reference file back into `SKILL.md`.
- **Honour each skill's safety contract.** `structure-check` is read-only.
  `structure-refactor` is dry-run unless `--apply`. `plugin-create` and `rename-repo`
  both push to a remote and must confirm with the user first.

## Version bumps

The version appears in six manifests: `.claude-plugin/marketplace.json`,
`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`,
`.kimi-plugin/plugin.json`, `.hermes-plugin/plugin.yaml`,
`gemini-extension.json`, and `package.json`. CI checks that they agree — bump
all of them together.

## No emojis

Anywhere in this repo. Token efficiency.
