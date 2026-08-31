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

[`.github/workflows/validate.yml`](.github/workflows/validate.yml) validates the
manifests, the skill frontmatter, and version agreement across manifests.

It is currently a self-contained workflow. Once the shared `harness-skills` repo
exists, this should be converted to call its reusable workflow instead, so all
the split-out skill repos validate identically from one definition. That
conversion is deliberately deferred — tracked as a follow-up.

## License

MIT. See [LICENSE](LICENSE).
