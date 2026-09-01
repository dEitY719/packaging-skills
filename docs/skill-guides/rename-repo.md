# rename-repo

**산출물** — 새 이름으로 바뀐 GitHub 저장소, 갱신된 로컬 `origin` URL, 그리고
옛 이름을 하드코딩하고 있던 모든 파일을 고친 커밋 1건.

## 언제 쓰고, 언제 안 쓰는가

repo 는 이미 있고 **이름만** 팀 컨벤션 `claude-plugin-<domain>` 에서 벗어난
경우에 쓴다. repo 자체가 없으면 `create`, 이름이 아니라 **디렉터리 배치**가
문제라면 `structure-check` / `structure-refactor` 다.

이 스킬이 고치는 것은 이름과 그 이름을 참조하는 문자열뿐이다. 레이아웃은
건드리지 않는다.

## 호출 형식

```
/packaging:rename-repo <new-name>   새 이름을 명시해 rename
/packaging:rename-repo              이름을 1-2개 제안받고 고르기
/packaging:rename-repo help         사용법 출력
```

`<new-name>` 은 `claude-plugin-` prefix 를 포함한 소문자 + 하이픈 형태여야
한다. 대문자나 언더스코어는 `gh repo rename` 을 깨거나 컨벤션을 위반한다.

## 동작 단계

| 단계 | 하는 일 |
|---|---|
| 0 | `git remote -v` 로 클론 확인, remote URL 을 호스트 독립 패턴으로 파싱해 `owner/repo` 추출, `gh auth status`, 기본 브랜치면 거부 |
| 1 | 인자를 쓰거나, plugin 구성을 보고 `claude-plugin-<domain>` 후보 1-2개 제안 — 사용자가 고를 때까지 rename 하지 않음 |
| 2 | **파괴적, 확인 필수** — `gh repo rename <new> --repo <org>/<OLD> --yes` |
| 3 | `git remote set-url origin <new URL>` + `git ls-remote` 로 검증 |
| 4 | `git grep -n "<OLD_REPO>"` → `marketplace.json` 의 `name`, `plugin.json` 의 `homepage`/`repository`, README 제목과 설치 명령을 교체. 끝나고 0건인지 재확인 |
| 5 | Conventional Commits 스타일로 커밋. push 는 별도 확인 후 |

## 주의사항 / 제약

- **기본 브랜치에서 동작하지 않는다.** 작업 브랜치를 먼저 따야 한다.
- rename(2단계)과 push(5단계)는 각각 명시적 사용자 확인이 필요하다.
- `gh auth login` 같은 대화형 로그인은 대신 실행하지 않는다 — 사용자에게 안내만 한다.
- github.com 과 사내 GHES 양쪽에서 동작한다. `github.com` 을 하드코딩하지 않고
  remote URL 에서 호스트를 판별한다. GHES 에서 `gh` 가 실패하면 웹 UI 경로를 안내한다.
- `source` 가 `./plugins/...` 같은 **상대경로인 필드는 건드리지 않는다** —
  repo 이름과 무관하기 때문이다.
- `marketplace.json` 의 `name` 은 새 repo 이름과 1:1 로 일치해야 한다.
