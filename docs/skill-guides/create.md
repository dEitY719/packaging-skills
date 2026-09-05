# create

**산출물** — `claude-plugin-<domain>` 형태의 마켓플레이스 repo 한 벌. 골든
`mono` 디렉터리 구조, 매니페스트(`marketplace.json` / `plugin.json`), README,
LICENSE, `.gitignore`, 그리고 초기 커밋이 올라간 GitHub 원격 저장소까지.

## 언제 쓰고, 언제 안 쓰는가

| 상황 | 쓸 스킬 |
|---|---|
| repo 가 아직 **없다**. 흩어진 스킬을 묶어 새로 만든다 | `create` |
| repo 는 있는데 **이름**이 컨벤션에 안 맞는다 | `rename-repo` |
| repo 는 있는데 **구조**가 표준에서 벗어났는지 알고 싶다 | `structure-check` |
| 그 구조를 실제로 **고친다** | `structure-refactor` |

`create` 는 신규 repo 전용이다. 대상 디렉터리가 이미 존재하면 덮어쓰지 않고
중단한다 — 멱등하지 않다.

## 호출 형식

```
/packaging:create <plugin-name> [skill ...] --src <path> [--dest <path>]
                  [--host <host>] [--owner <owner>] [--plugin <name>] [--dry-run]
/packaging:create help
```

| 인자 / 플래그 | 의미 | 기본값 |
|---|---|---|
| `<plugin-name>` | `claude-plugin-<domain>` 형식 repo 이름 (필수). prefix 없으면 자동으로 붙이고 알려 준다 | — |
| `[skill ...]` | 복사할 스킬 디렉터리 이름들 | 대화에서 추론, 안 되면 질문 |
| `--src <path>` | 스킬 원본 디렉터리 (**필수** — 기본값 없음) | — |
| `--dest <path>` | repo 를 만들 위치 | `~/para/project/` |
| `--host <host>` | GitHub 호스트 (GHES 지원) | `github.com` |
| `--owner <owner>` | GitHub owner | `dEitY719` |
| `--plugin <name>` | 내부 plugin key | `<plugin-name>` 의 domain 부분 |
| `--dry-run` | 계획만 출력, 아무것도 쓰지 않음 | off |

## 동작 단계

1. 인자 검증 — prefix 보정, 소문자-하이픈 강제, `--src` 누락 / dest 중복 시 중단
2. `[PLAN]` 블록 출력 (항상). `--dry-run` 이면 여기서 정지
3. 골든 `mono` 구조 생성
4. 스킬 복사 — `cp -r`, 원본은 읽기 전용
5. 매니페스트 / README / LICENSE / `.gitignore` 작성
6. `git init` + `git checkout -B main`
7. `gh auth status` 후 **사용자 확인**을 받고 `gh repo create`
8. 초기 커밋 후 **사용자 확인**을 받고 `git push -u origin main`
9. `packaging:structure-check` 로 M1-M10 PASS 확인 후 `[OK]` 리포트

## 주의사항 / 제약

- **원본은 복사 전용.** `--src` 를 수정 / 이동 / 삭제 / 심볼릭 링크 하지 않는다.
- **멱등하지 않다.** `<dest>/<plugin-name>` 이 이미 있으면 무조건 중단한다.
- 스킬 복사는 부모 `skills/` 디렉터리를 대상으로 한다. `skills/<skill>` 을
  대상으로 잡으면 `skills/<skill>/<skill>/` 로 중첩된다.
- 7단계(repo 생성)와 8단계(push)는 외부에 영향을 주므로 각각 확인을 받는다.
  `git push --force` 는 절대 쓰지 않는다.
- 하드 중단 지점은 3곳뿐이다 — 1단계 검증 실패, 7단계 `gh auth status` 실패,
  push 거부. 나머지는 부분 정리 없이 크게 실패한다.
