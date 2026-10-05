# mirror-repo 사용 결과

> **한 줄 요약** — github.com 에만 있는 기존 `*-skills` repo 이름을 받아 GHES 미러 생성 계획
> (클론 위치, GHES repo, `origin` / `upstream` remote)을 산출합니다.

```
upstream repo (github.com)  ──▶  /packaging:mirror-repo --dry-run  ──▶  [PLAN] 블록
```

## 1. 실행한 명령

```
범용:  /packaging:mirror-repo <repo-name> [--ghes-host <host>] [--dest <path>] [--dry-run]
이번:  /packaging:mirror-repo test-skills --dry-run --ghes-host ghes.example.com
         (--dest <scratchpad>/dest)
```

## 2. 입력

`github.com/dEitY719/test-skills` — upstream 에 있는 repo 1개를 미러 대상으로 지정.
`gh` / `git` 은 스텁으로 바꿔 실제 호스트에는 아무것도 닿지 않았다. Step 0-1 은 읽기 전용
호출만으로 통과했다.

- `gh auth status` — upstream (`github.com`) 과 GHES (`ghes.example.com`) 양쪽 OK
- `gh api user` (GHES) — GHES owner `ghes-user` 감지
- `gh repo view dEitY719/test-skills` (upstream) — 존재
- `gh repo view ghes-user/test-skills` (GHES) — 없음, 미러 생성 가능

## 3. 결과

Step 2 에서 `[PLAN]` 이 출력되고 `--dry-run` 이라 그 자리에서 정지했다.

```
[PLAN] packaging:mirror-repo
  Source repo  : github.com/dEitY719/test-skills
  GHES repo    : ghes.example.com/ghes-user/test-skills
  Destination  : <scratchpad>/dest/test-skills/
  Remotes:
    origin    -> git@ghes.example.com:ghes-user/test-skills.git
    upstream  -> https://github.com/dEitY719/test-skills.git
  Dry-run     : on
```

클론, `gh repo create`, push 는 호출되지 않았고 `<scratchpad>/dest` 는 빈 채로 남았다.

스킬 설명서: [mirror-repo.html](../skill-guides/mirror-repo.html)
