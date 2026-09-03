# plugin-create 사용 결과

> **한 줄 요약** — 스킬 원본 디렉터리와 새 repo 이름을 받아 골든 `mono` 구조의
> 마켓플레이스 repo 생성 계획을 산출합니다.

```
스킬 원본 (skills/)  ──▶  /packaging:plugin-create --dry-run  ──▶  [PLAN] 블록
```

## 1. 실행한 명령

```
범용:  /packaging:plugin-create <plugin-name> [skill ...] --src <path> --dest <path> [--dry-run]
이번:  /packaging:plugin-create claude-plugin-demo structure-check \
         --src skills --dest <scratchpad> --owner dEitY719 --host github.com --dry-run
```

## 2. 입력

`skills/structure-check/` — 이 repo 의 스킬 디렉터리 1개를 `--src skills` 트리에서
복사 대상으로 지정. Step 1 검증은 `src exists: yes`, `dest collision: none-ok` 으로 통과.

## 3. 결과

Step 2 에서 `[PLAN]` 이 출력되고 `--dry-run` 이라 그 자리에서 정지했다.

```
[PLAN] packaging:plugin-create
  Plugin name : claude-plugin-demo
  Plugin key  : demo
  Destination : <scratchpad>/claude-plugin-demo/
  Skills to copy (1):
    skills/structure-check  -> plugins/demo/skills/structure-check
  GH repo     : github.com/dEitY719/claude-plugin-demo
  Dry-run     : on
```

디렉터리는 생성되지 않았고 `gh repo create` 와 push 는 호출되지 않았다.

스킬 설명서: [plugin-create.html](../skill-guides/plugin-create.html)
