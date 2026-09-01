# packaging-skills

Four skills for building and maintaining agent skill marketplace repos —
scaffold a new one, rename it to convention, audit its layout, refactor it into
shape. Packaged as a single plugin named `packaging`, installable on six
coding-agent harnesses.

## Skills

| Skill | Invoke | What it does |
|-------|--------|--------------|
| `create` | `/packaging:create <name>` | Scaffolds a new marketplace repo from scratch: structure, manifests, copy-only skill import, `git init`, repo create, push. New repos only. |
| `rename-repo` | `/packaging:rename-repo <name>` | Renames an existing plugin repo to the team convention and fixes every hardcoded reference. Rename and push each need confirmation. |
| `structure-check` | `/packaging:structure-check` | Audits a repo's directory layout against the standard. Read-only — it reports, it never edits. |
| `structure-refactor` | `/packaging:structure-refactor` | Applies the fixes `structure-check` found. Prints a plan and stops unless you pass `--apply`. |

### Visual guides and worked examples (GitHub Pages)

Each page is generated from a Markdown source under [`docs/skill-guides/`](docs/skill-guides) and [`docs/skill-output/`](docs/skill-output).

- `create` — [visual guide](https://deity719.github.io/packaging-skills/skill-guides/create.html) · [usage example](https://deity719.github.io/packaging-skills/skill-output/create-usage.html) (skill source tree to repo creation plan)
- `rename-repo` — [visual guide](https://deity719.github.io/packaging-skills/skill-guides/rename-repo.html) · [usage example](https://deity719.github.io/packaging-skills/skill-output/rename-repo-usage.html) (git remote to rename proposal)
- `structure-check` — [visual guide](https://deity719.github.io/packaging-skills/skill-guides/structure-check.html) · [usage example](https://deity719.github.io/packaging-skills/skill-output/structure-check-usage.html) (repo path to PASS/WARN/FAIL report)
- `structure-refactor` — [visual guide](https://deity719.github.io/packaging-skills/skill-guides/structure-refactor.html) · [usage example](https://deity719.github.io/packaging-skills/skill-output/structure-refactor-usage.html) (repo path to dry-run change plan)

## Install

### Claude Code

```
/plugin marketplace add dEitY719/packaging-skills
/plugin install packaging@packaging-skills
```

### Codex

```
codex plugin install dEitY719/packaging-skills
```

### Kimi CLI

```
kimi plugin install dEitY719/packaging-skills
```

### Hermes Agent

```
hermes plugins install dEitY719/packaging-skills
```

### OpenCode

See [`.opencode/INSTALL.md`](.opencode/INSTALL.md).

### Gemini CLI / Antigravity

```
gemini extensions install https://github.com/dEitY719/packaging-skills
```

## Layout

Manifests live at the repo root and all point at one flat `skills/` directory:

```
.
├── skills/{create,rename-repo,structure-check,structure-refactor}/
│   ├── SKILL.md
│   └── references/
├── .claude-plugin/{marketplace,plugin}.json   Claude Code
├── .codex-plugin/plugin.json                  Codex
├── .kimi-plugin/plugin.json                   Kimi CLI
├── .hermes-plugin/{plugin.yaml,__init__.py}   Hermes Agent
├── .opencode/plugins/packaging.js + INSTALL.md  OpenCode
├── .agents/plugins/marketplace.json           Antigravity
├── gemini-extension.json + GEMINI.md          Gemini CLI
├── package.json
├── CLAUDE.md · AGENTS.md -> CLAUDE.md
└── LICENSE
```

Only Claude Code understands a nested `plugins/<name>/skills/` layout. The other
five harnesses resolve manifests at the repo root and a skills tree at
`./skills/`, so this repo keeps everything flat. See [`CLAUDE.md`](CLAUDE.md) for
the full rationale and contribution rules.

The `.kimi-plugin/` manifest is pre-provisioned: Kimi CLI is not installed on the
maintainer's machines yet, and shipping the manifest now costs nothing and saves
a migration later.

## Provenance

These skills were extracted from
[`dEitY719/dotfiles`](https://github.com/dEitY719/dotfiles)
(`claude/skills/claude-plugin-*`) as a content snapshot — no history rewriting.
The source commit SHA is recorded in this repo's first commit message.

This is the first repo split out of that dotfiles skill library, and it goes
first because it holds the tooling used to split out the rest.

## CI

[`.github/workflows/validate.yml`](.github/workflows/validate.yml) is a thin
caller. The checks themselves — manifests, skill frontmatter, progressive
disclosure, the Codex description budget, version agreement, shell scripts —
live once in
[`dEitY719/harness-skills`](https://github.com/dEitY719/harness-skills)'
reusable `skill-check.yml` workflow, which every split-out skill repo calls:

```yaml
jobs:
  validate:
    uses: dEitY719/harness-skills/.github/workflows/skill-check.yml@main
    with:
      plugin-name: packaging
```

To change what is checked, edit that workflow, not this repo. This resolves the
follow-up this README previously flagged (dotfiles #1410 D-10 / #1638 NF-2).

## License

MIT. See [LICENSE](LICENSE).
