# mirror-repo

**산출물** — 한 호스트에 있는 기존 repo 의 다른 호스트(보통 github.com -> GHES) 미러 한 벌.
미러 호스트 위의 repo(기본 private), 로컬 클론(`origin`=`--origin` URL,
`upstream`=`--upstream` URL), 그리고 그 미러 repo 로 push 된 기본 브랜치까지.
`*-skills` 가 아닌 repo (예: `dEitY719/equinest`) 도 그대로 미러한다.

## 언제 쓰고, 언제 안 쓰는가

| 상황 | 쓸 스킬 |
|---|---|
| repo 가 github.com 에는 **있는데 GHES 에는 없다** (`git-clone-skills.sh` 가 실패한다) | `mirror-repo` |
| 이미 미러된 repo 를 **최신으로 당긴다** | `git-pull-skills.sh` (스킬 아님) |
| repo 가 아직 **없다**. 흩어진 스킬을 묶어 새로 만든다 | `scaffold-repo` |
| repo 는 있는데 **이름**이 컨벤션에 안 맞는다 | `rename-repo` |
| 미러한 repo 의 **구조**가 표준에서 벗어났는지 알고 싶다 | `structure-check` |
| 그 구조를 실제로 **고친다** | `structure-refactor` |

`mirror-repo` 는 신규 미러 전용이다. 대상 디렉터리나 미러 repo 가 이미 존재하면
덮어쓰지 않고 중단한다 — 멱등하지 않다. 기존 미러 갱신은 `git-pull-skills.sh` 의 몫이다.

## 호출 형식

```
/packaging:mirror-repo --upstream <url> --origin <url> [--dest <path>]
                       [--visibility public|private] [--dry-run]
/packaging:mirror-repo help
```

| 플래그 | 의미 | 기본값 |
|---|---|---|
| `--upstream <url>` | 원본 repo URL (필수). 그대로 클론하고 `upstream` remote 가 된다 | — |
| `--origin <url>` | 미러 repo URL (필수). 그 호스트에 repo 를 만들고 `origin` remote 로 push 한다. repo 이름은 그대로 쓴다 (`-skills` 접미어 보정 없음) | — |
| `--dest <path>` | 클론할 부모 디렉터리 | `~/para/project/` |
| `--visibility <v>` | 미러 repo 공개 범위 (`public`\|`private`) | `private` |
| `--dry-run` | 계획만 출력, 클론 / repo 생성 / push 없음 | off |

URL 형식 (두 플래그 공통, `.git` 생략 가능):

```
https://<host>/<owner>/<repo>.git   http://<host>/<owner>/<repo>.git
git@<host>:<owner>/<repo>.git       ssh://git@<host>/<owner>/<repo>.git
```

엔진 스크립트 `lib/mirror_repo.sh` 에는 사용자 플래그가 아닌 `--yes` 가 하나 더 있다.
사용자가 repo 생성과 push **둘 다** 승낙했을 때만 스킬이 붙여 넘긴다.
스크립트의 `--help` 는 dry-run, SSH origin, HTTPS origin + `--dest`, `.git` 생략,
팀 owner 아래 `--visibility public` 미러 예시를 보여 준다.

## 동작 단계

0. URL 파싱 + 인증 — 두 URL 에서 호스트 / owner / repo 이름을 오프라인으로 뽑고, 양쪽 호스트 `gh auth status`
1. 검증 — 형식이 틀린 URL, origin 호스트 == upstream 호스트, 내부 PC(`~/.dotfiles-setup-mode` = `internal`)에서 github.com origin 이면 중단. dest 중복, upstream repo 부재, 미러 repo 이미 존재 시 중단
2. `[PLAN]` 블록 출력 (항상). `--dry-run` 이면 여기서 정지
3. 클론 — `git clone <upstream-url> <dest>/<repo>`
4. **사용자 확인**을 받고 미러 호스트에서 `gh repo create <owner>/<repo> --private|--public`
5. remote 설정 — `origin` -> `<origin-url>`, `upstream` -> `<upstream-url>` (둘 다 입력 그대로)
6. **사용자 확인**을 받고 `git push -u origin <branch>`
7. `git remote -v` 와 미러 쪽 `gh repo view` 로 재확인 후 `[OK]` 리포트

## 주의사항 / 제약

- **신규 미러 전용.** `<dest>/<repo>` 이나 미러 repo 가 이미 있으면 무조건 중단한다.
  기존 미러 갱신은 `git-pull-skills.sh` 를 쓴다.
- **호스트는 URL 에서만 온다.** origin 호스트가 upstream 호스트와 같으면 중단한다.
  내부 PC 에서는 github.com 으로 push 하지 않는다 (github.com origin 이면 중단).
  호스트나 사용자를 하드코딩하지 않는다.
- `--visibility public` 은 upstream repo 가 `PUBLIC` 일 때만 허용한다.
- 4단계(repo 생성)와 6단계(push)는 외부에 영향을 주므로 각각 확인을 받는다.
  `[y/N]` 에서 EOF 는 거절로 친다. `git push --force` 는 절대 쓰지 않는다.
- **`--dry-run` 은 아무것도 쓰지 않는다.** 클론도, repo 생성도, push 도 없다.
- 하드 중단 지점 — 0단계 URL 파싱 / 인증 실패, 1단계 검증 실패, 4단계 `gh repo create` 실패, push 거부.
- `marketplaces.json` 은 수정하지 않는다. 매니페스트에 추가할지는 사용자 선택이다.
