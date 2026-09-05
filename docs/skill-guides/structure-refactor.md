# structure-refactor

**산출물** — 현재 구조에서 표준 구조로 가는 순서 있는 변경 계획서. `--apply`
를 줬을 때만 그 계획이 실제 파일 생성 / `git mv` 이동 / 매니페스트 수정으로
집행되고, 마지막에 적용 건수 요약 리포트가 나온다.

## 언제 쓰고, 언제 안 쓰는가

`structure-check` 가 찾아낸 것을 **고칠 때** 쓴다. check 는 감사만 하고, 이
스킬이 편집한다. 반대로 repo 를 처음부터 만드는 건 `create`, 이름을 바꾸는 건
`rename-repo` 다.

single 레이아웃과 mono 레이아웃 사이의 **변환은 하지 않는다**. 감지된 현재
레이아웃과 다른 모드를 강제하면 `[convert]` 경고 한 줄만 찍고, `--apply` 라도
아무것도 쓰지 않고 멈춘다.

## 호출 형식

```
/packaging:structure-refactor [repo-path] [--apply] [--mp|--op] [--single|--mono]
/packaging:structure-refactor help
```

| 플래그 | 의미 |
|---|---|
| `--apply` | 계획을 실제로 집행한다. 없으면 **dry-run** — 계획만 찍고 아무것도 쓰지 않는다 |
| `--mandatory` / `--mp` | 범위 = 필수 M1-M10 만 (기본값) |
| `--recommended` / `--op` | 범위 = M1-M10 + 권장 R1-R5. R6-R8 은 감사 전용이라 절대 자동 적용되지 않는다 |
| `--single` / `--mono` | **목표** 레이아웃 모드 강제. 상호 배타적, 마지막 것이 이김 |

`--mp` 와 `--op` 를 같이 주면 오류로 중단한다.

## 동작 단계

1. 인자 파싱, 경로 확인. git repo 가 아니면 경고(이동은 `mv` 로 대체),
   dirty tree 면 dry-run 계획을 보여주고 명시적 `--apply` 를 요구
2. 모드 감지 → 변환 가드 → plugin root 집합 계산 → 스킬 발견 → 현재↔목표 diff 산출
3. 검사 ID 가 붙은 순서 있는 변경 목록 작성. 이미 맞는 항목은 줄을 만들지 않는다
4. dry-run 이면 출력만, `--apply` 면 순서대로 집행
5. `[OK]` / `[FAIL]` 과 `key=value` 요약, 그리고 다음 행동 힌트

집행 순서: mkdir → 이동 → 스켈레톤 → M7 `plugins[].source` 주입 →
M10 미지원 `plugin.json` 필드 제거(`.bak` 백업). `--op` 면 여기에 R1 가이드
생성(`/visuals:visualize` 위임), R2 usage stub, GitHub Pages 활성화, R4 명명 교정,
R5 README 링크 보강이 더해진다.

## 주의사항 / 제약

- **기본값이 dry-run 이다.** `--apply` 없이는 파일이 절대 바뀌지 않는다.
- **멱등하다.** 이미 표준을 만족하는 repo 를 돌리면 `총 0 변경` 이 나온다.
  스켈레톤은 기존 파일을 덮어쓰지 않고, 링크 보강은 중복을 만들지 않으며,
  Pages 가 이미 켜져 있으면 건너뛴다.
- git repo 안에서는 이동에 `git mv` 를 써서 히스토리를 보존한다.
- single↔mono 변환은 범위 밖이다 — 유효한 single repo 를 강제로 mono 로 재배치해
  업스트림 호환을 깨는 사고를 막는 안전장치다.
- Pages 활성화와 R5 링크 보강은 soft-fail 이다. 토큰 스코프가 없거나 호스트에
  못 닿으면 경고만 하고 계속 진행한다.
- R1 가이드는 실제 내용이지만 R2 usage 는 stub 수준이다. `/visuals:excalidraw-diagram`
  은 이 스킬이 호출하지 않는다.
