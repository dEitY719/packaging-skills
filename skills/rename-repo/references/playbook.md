# rename-repo 플레이북 (embedded SSOT)

출처: [dotfiles discussions #886](https://github.com/dEitY719/dotfiles/discussions/886)
— `xxx-yyy-zzz` 형태의 기존 레포 이름을 팀 컨벤션 `claude-plugin-<domain>`
으로 rename 하는 범용 작업 지시서. SKILL.md 의 각 Step 은 이 절차를 실행한다.
github.com / 사내 GHES 양쪽 모두 동작한다.

## 합의된 네이밍 컨벤션

- 새 레포 이름 형식: `claude-plugin-<domain>` (예: `xxx-yyy-zzz` →
  `claude-plugin-visuals`). `<domain>` 은 GitHub 레포 네이밍 규칙에 따라
  반드시 소문자와 하이픈(-)만 사용 (대문자/언더스코어 금지).
- 이유:
  - `plugin-` 이 `skills-` 보다 상위/범용 개념 — plugin 은 skills·commands·
    agents·hooks 를 모두 번들하며 `.claude-plugin/` 디렉터리 구조와 일치한다.
  - `claude-` prefix 로 프로필/조직에서 "무엇의 플러그인인지" 식별성을 확보한다.
- marketplace `name` 1:1 일치: `.claude-plugin/marketplace.json` 의 `name` 을
  새 레포 이름과 동일하게 맞춘다.

## 작업 절차

각 단계는 실행 전에 사용자가 확인할 수 있게 명령을 먼저 보여준다.

### 0단계 — 환경/호스트 확인

- 지금 디렉터리가 대상 레포의 클론인지 확인: `git remote -v`.
- `owner/repo`/host 는 `gh` 대신 `skills/rename-repo/lib/parse_remote.sh` 로
  얻는다: `eval "$(bash skills/rename-repo/lib/parse_remote.sh origin)"` →
  `$HOST` / `$OWNER` / `$REPO`. `https://`, `ssh://`, `git@` scp 형식 모두,
  임의의 GHE 호스트를 지원한다 (github.com 하드코딩 금지). 스크립트 출력은
  `%q` 로 이스케이프돼 있어 조작된 remote URL 이 있어도 `eval` 시 명령이
  실행되지 않는다.
- gh CLI 가 `$HOST` 로 인증돼 있는지 확인: `gh auth status --hostname
  "$HOST"` (호스트를 지정하지 않으면 기본 호스트만 검사해, github.com 세션이
  실제로는 미인증인 GHES 대상을 통과시킬 수 있다).
  - 대상 호스트가 안 보이면 `gh auth login --hostname <호스트>` 를 사용자가
    직접 실행하도록 안내 (대화형 로그인은 대신 못 함).
- 기본 브랜치에서 직접 작업하지 않는다 — 반드시 별도 작업 브랜치를 쓴다
  (default branch 위라면 그 자리에서 거부하고 브랜치부터 요구한다).

### 1단계 — 새 이름 결정

- 레포 안의 plugin 구성을 살핀다 (`.claude-plugin/marketplace.json` 의
  `plugins[]` 와 `plugins/` 디렉터리 구조).
- 그걸 근거로 `claude-plugin-<domain>` 형식의 새 이름을 1~2개 제안한다.
  - plugin 이 하나의 도메인이면: `claude-plugin-<그도메인>`.
  - 여러 도메인을 담은 marketplace 면: `claude-plugin-<팀/제품명>` 처럼 묶는 이름.
- 최종 이름은 사용자가 고른다. 선택을 받기 전에는 rename 하지 않는다.

### 2단계 — 레포 rename (파괴적 — 확인 필수)

- 사용자가 이름을 확정하면:
  `gh repo rename <새이름> --repo <host>/<org>/<OLD_REPO> --yes`.
  (`gh repo rename` 에는 `--hostname` 플래그가 없다 — `--repo` 의
  `[HOST/]OWNER/REPO` 형식 안에 호스트를 넣는다.) GHES 라면 gh 가 사내
  호스트로 인증돼 있어야 동작. 안 되면 웹 UI 의 Settings → Repository name
  에서 rename 하도록 안내한다.

### 3단계 — 로컬 remote URL 갱신

- gh 가 로컬 remote 를 자동 갱신 못 할 수 있으니 직접:
  `git remote set-url origin <새 레포 URL>`.
- 검증: `git remote get-url origin` /
  `git ls-remote --heads origin >/dev/null && echo REMOTE_OK`.

### 4단계 — 하드코딩된 옛 이름/URL 전부 스캔 & 수정

- 추적 파일 전체에서 옛 이름 잔재 검색: `git grep -Fn "<OLD_REPO>"` (`-F` 로
  리터럴 매치 — 레포 이름에 `.` 이 있으면 정규식 와일드카드로 오탐한다).
- 아래 위치를 빠짐없이 점검하고 새 이름으로 교체:
  - `.claude-plugin/marketplace.json` 의 `name` → 새 레포 이름과 1:1 일치.
  - `plugins/<plugin>/.claude-plugin/plugin.json` 의 `homepage` / `repository`.
  - `README.md` 의 제목과 `/plugin marketplace add <org>/<OLD_REPO>` 설치 명령.
  - 각 skill 의 README 안의 marketplace 링크 / 설치 명령.
- 단, `source` 가 `./plugins/...` 같은 상대경로면 레포명과 무관하니 건드리지 않는다.
- 수정 후 `git grep -Fn "<OLD_REPO>"` 가 0건인지 확인 — 이 결과가 SKILL.md
  Step 6 의 `[OK]`/`[FAIL]` 판정 근거다. (`git grep` 은 매치가 0건이면 종료
  코드 1, 출력 없음을 반환한다 — 그 1이 통과 조건이지, 스크립트 실패가
  아니다. 매치가 있으면 종료 코드 0 + 출력이 있다.)

### 5단계 — 커밋

- Conventional Commits 스타일로 커밋 (이 레포의 git log 스타일을 먼저 확인하고
  맞춘다): 제목 예) `chore: rename repo to <새이름> and update references`.
  본문에는 "왜"(컨벤션 채택 이유)와 바꾼 파일 목록을 적는다.
- push 는 사용자 확인을 받고 별도로.

## 주의

- GHES redirect 동작은 github.com 과 다를 수 있으니, 옛 설치 명령
  (`/plugin marketplace add ...`) 은 반드시 새 이름으로 갱신한다.
- 호스트가 GHES 면 URL 이 github.com 이 아니라
  `https://<GHES호스트>/<org>/<repo>` 형태인 점에 유의.
