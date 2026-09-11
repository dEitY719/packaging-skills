# packaging:scaffold-repo — README Template

Written in Step 5 at `<dest>/<repo-name>/README.md`. Placeholders:
`<repo-name>` = repo name, `<plugin>` = plugin key, `<owner>`/`<host>`
from the flags, `<skill>` rows from the discovered skill list.

This template is designed to satisfy `packaging:structure-check`'s
recommended checks out of the box: R3 ("Simple" — at least one `docs/` link,
a skill section), and R5 (per-skill guide **and** usage links). The
`docs/skill-guides/<skill>.html` and `docs/skill-output/<skill>-usage.md`
files are placeholder stubs at create time — fill them later with
`/visuals:visualize` (that satisfies R1/R2).

## Template

````markdown
# <repo-name>

> 에이전트 스킬 마켓플레이스 repo. `<plugin>` 플러그인 하나가 아래 스킬들을 번들합니다.

## 설치

Claude Code:

```
/plugin marketplace add <owner>/<repo-name>
/plugin install <plugin>@<repo-name>
```

다른 하네스(Codex / Kimi / Hermes / OpenCode / Antigravity / Gemini CLI)는 각자의
플러그인 설치 경로를 씁니다. 매니페스트는 모두 repo 루트에 있습니다.

## 스킬 목록

| 스킬 | 설명 | 가이드 / 사용 예시 |
|------|------|--------------------|
| `<skill>` | <SKILL.md description 첫 문장> | [guide](docs/skill-guides/<skill>.html) · [usage](docs/skill-output/<skill>-usage.md) |

> 표의 각 행은 스킬 1개에 대응합니다. 가이드/사용 예시 링크는
> `docs/skill-guides/`, `docs/skill-output/` 의 문서를 가리킵니다
> (생성 시 placeholder, 이후 `/visuals:visualize` 로 채움).

## 구조

1 repo = 1 plugin. 매니페스트는 루트, 스킬은 평면 `skills/` 하나입니다.

```
.
├── .claude-plugin/{marketplace,plugin}.json   Claude Code
├── .codex-plugin/plugin.json                  Codex
├── .kimi-plugin/plugin.json                   Kimi CLI
├── .hermes-plugin/{plugin.yaml,__init__.py}   Hermes Agent
├── .opencode/plugins/<plugin>.js              OpenCode
├── .agents/plugins/marketplace.json           Antigravity
├── gemini-extension.json + GEMINI.md          Gemini CLI
├── skills/<skill>/SKILL.md                    스킬 본체
├── docs/skill-guides/ · docs/skill-output/
└── README.md
```

## License

MIT © <year> <owner>
````

## Notes

- One table row per discovered skill — both the `skill-guides/<skill>.html`
  guide link and the `skill-output/<skill>-usage.md` usage link must be
  present (R5).
- Keep the body "Simple" (R3): it links into `docs/`, names the plugin and its
  skills, and stays short.
- The structure block must show the root manifests and the flat `skills/` tree.
  Never show `plugins/<plugin>/skills/` — that is the pre-#1410 mono layout.
