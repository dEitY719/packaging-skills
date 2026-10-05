# mirror-repo

**산출물** — github.com 에만 있던 기존 `<domain>-skills` repo 의 GHES 미러 한 벌.
GHES 위의 private repo, 로컬 클론(`origin`=GHES over SSH, `upstream`=github.com
over HTTPS), 그리고 그 GHES repo 로 push 된 기본 브랜치까지.

## 언제 쓰고, 언제 안 쓰는가

| 상황 | 쓸 스킬 |
|---|---|
| 외부 repo 가 github.com 에는 **있는데 GHES 에는 없다** (`git-clone-skills.sh` 가 실패한다) | `mirror-repo` |
| 이미 미러된 repo 를 **최신으로 당긴다** | `git-pull-skills.sh` (스킬 아님) |
| repo 가 아직 **없다**. 흩어진 스킬을 묶어 새로 만든다 | `scaffold-repo` |
| repo 는 있는데 **이름**이 컨벤션에 안 맞는다 | `rename-repo` |
| 미러한 repo 의 **구조**가 표준에서 벗어났는지 알고 싶다 | `structure-check` |
| 그 구조를 실제로 **고친다** | `structure-refactor` |

`mirror-repo` 는 신규 미러 전용이다. 대상 디렉터리나 GHES repo 가 이미 존재하면
덮어쓰지 않고 중단한다 — 멱등하지 않다. 기존 미러 갱신은 `git-pull-skills.sh` 의 몫이다.

## 호출 형식

```
/packaging:mirror-repo <repo-name> [--owner <owner>] [--ghes-owner <owner>]
                       [--dest <path>] [--host <host>] [--ghes-host <host>] [--dry-run]
/packaging:mirror-repo help
```

| 인자 / 플래그 | 의미 | 기본값 |
|---|---|---|
| `<repo-name>` | `<domain>-skills` 형식 repo 이름 (필수). `-skills` 접미어가 없으면 자동으로 붙이고 알려 준다. `claude-plugin-` prefix 는 pre-#1410 옛 규칙이라 거부한다 | — |
| `--owner <owner>` | upstream owner | `dEitY719` |
| `--ghes-owner <owner>` | 미러를 만들 GHES owner | 활성 GHES 로그인 (`gh api --hostname <ghes-host> user`) |
| `--dest <path>` | 클론할 부모 디렉터리 | `~/para/project/skills/` |
| `--host <host>` | upstream 호스트 | `github.com` |
| `--ghes-host <host>` | GHES 호스트 | dotfiles SSOT `_gh_resolve_host` |
| `--dry-run` | 계획만 출력, 클론 / repo 생성 / push 없음 | off |

엔진 스크립트 `lib/mirror_repo.sh` 에는 사용자 플래그가 아닌 `--yes` 가 하나 더 있다.
사용자가 repo 생성과 push **둘 다** 승낙했을 때만 스킬이 붙여 넘긴다.

## 동작 단계

0. 호스트 해석 + 인증 — upstream 호스트와 GHES 호스트를 정하고 양쪽 `gh auth status`, GHES owner 감지. GHES 호스트를 못 찾거나 upstream 호스트와 같으면 중단
1. 검증 — `-skills` 접미어 보정, `claude-plugin-` prefix 거부, 소문자-하이픈 강제. dest 중복, upstream repo 부재, GHES repo 이미 존재 시 중단
2. `[PLAN]` 블록 출력 (항상). `--dry-run` 이면 여기서 정지
3. 클론 — `git clone https://<host>/<owner>/<repo-name>.git <dest>/<repo-name>`
4. **사용자 확인**을 받고 `gh repo create <ghes-owner>/<repo-name> --private` (GHES)
5. remote 설정 — `origin` -> `git@<ghes-host>:<ghes-owner>/<repo-name>.git`, `upstream` -> `https://<host>/<owner>/<repo-name>.git`
6. **사용자 확인**을 받고 `git push -u origin <branch>`
7. `git remote -v` 와 GHES 쪽 `gh repo view` 로 재확인 후 `[OK]` 리포트

## 주의사항 / 제약

- **신규 미러 전용.** `<dest>/<repo-name>` 이나 GHES repo 가 이미 있으면 무조건 중단한다.
  기존 미러 갱신은 `git-pull-skills.sh` 를 쓴다.
- **호스트는 추측하지 않는다.** `--ghes-host` 도 없고 `_gh_resolve_host` 도 못 읽으면 중단,
  GHES 호스트가 upstream 호스트와 같아도(공용 PC 에서 `github.com` 이 나오는 경우) 중단한다.
  GHES 호스트나 사용자를 하드코딩하지 않는다.
- 4단계(repo 생성)와 6단계(push)는 외부에 영향을 주므로 각각 확인을 받는다.
  `[y/N]` 에서 EOF 는 거절로 친다. `git push --force` 는 절대 쓰지 않는다.
- **`--dry-run` 은 아무것도 쓰지 않는다.** 클론도, repo 생성도, push 도 없다.
- 하드 중단 지점 — 0단계 인증 실패, 1단계 검증 실패, 4단계 `gh repo create` 실패, push 거부.
- `marketplaces.json` 은 수정하지 않는다. 매니페스트에 추가할지는 사용자 선택이다.
