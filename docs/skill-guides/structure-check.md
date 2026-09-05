# structure-check

**산출물** — repo 하나의 디렉터리 구조를 필수 10항목(M1-M10) / 권장 8항목
(R1-R8)으로 채점한 PASS·WARN·FAIL·N/A 리포트 1장. 파일은 하나도 바뀌지 않는다.

## 언제 쓰고, 언제 안 쓰는가

플러그인 마켓플레이스 repo 의 **배치**가 표준에 맞는지 알고 싶을 때 쓴다.
읽기 전용이므로 먼저 이걸 돌리고, 나온 지적을 `structure-refactor` 가 고친다.

경계가 헷갈리는 이웃 스킬:

| 검사 대상 | 쓸 스킬 |
|---|---|
| 디렉터리 구조 / 매니페스트 배치 | `structure-check` (이 스킬) |
| `SKILL.md` 의 **내용** 품질 | `authoring:skill-check` |
| 셸 스크립트 품질 | `authoring:sh-check` |

## 호출 형식

```
/packaging:structure-check [repo-path] [--single|--mono]
/packaging:structure-check help
```

- `[repo-path]` — 생략하면 현재 디렉터리.
- `--single` / `--mono` — 레이아웃 모드 자동 감지를 무시하고 강제한다.
  상호 배타적이며 둘 다 주면 마지막 것이 이긴다. 잘못 준 override 는 조용히
  넘어가지 않고 평범한 M2 FAIL 로 드러난다.

## 채점 항목

| 그룹 | 내용 | 위반 시 |
|---|---|---|
| M1-M6 | `marketplace.json` 유효성, plugin root 존재, `plugin.json` 유효성, `SKILL.md` frontmatter, `docs/skill-guides/` + `docs/skill-output/`, `README.md` | FAIL |
| M7-M9 | `plugins[].source` 설치 무결성 — 각 원소가 자기 source 를 갖는지, shape 이 유효한지, mono 로 선언된 디렉터리가 실재하는지 | FAIL |
| M10 | `plugin.json` 최상위 필드가 알려진 스키마 화이트리스트 안에 있는지 | FAIL |
| R1-R8 | 스킬별 guide/usage 문서, README 의 Simple 휴리스틱과 스킬별 링크, 명명 일관성, `$schema`, 리스팅 메타데이터, add URL 힌트 | WARN |

## 동작 단계

1. 인자 파싱, repo 경로 확인, `.git` 유무 확인(없어도 감사는 진행)
2. 레이아웃 모드 감지 → plugin root 와 스킬 목록을 **스캔으로** 발견
3. M1-M10 / R1-R8 채점
4. `[필수]` / `[권장]` 블록과 요약 판정 출력

모드 감지 우선순위: 플래그 → `marketplace.json` 의 `plugins[].source`
(`"./"` 는 single, `"./plugins/.."` 는 mono) → 파일시스템 → 그래도 모호하면
`mono` 로 두고 헤더에 `추정` 표시.

판정: FAIL 하나라도 있으면 FAIL, 없고 WARN 이 있으면 WARN, 전부 PASS/N/A 면 PASS.

## 주의사항 / 제약

- **읽기 전용이다.** 파일을 만들거나 옮기거나 고치지 않는다.
- **N/A 는 FAIL 이 아니다.** 대상 자체가 없으면(스킬 0개 등) 의존 항목은 N/A 이고,
  "없다"는 사실은 M2 가 FAIL 하나로만 센다 — 이중 계상하지 않는다.
- repo 에 종속되지 않는다. 스펙은 스킬 안에 임베드돼 있고, plugin/스킬 이름은
  하드코딩 없이 매번 스캔해서 찾는다.
- **PASS 가 install/runtime 성공을 보장하지 않는다.** 구조만 본다. 실제로
  `/plugin install` 이 실패하거나 세션에 스킬이 안 뜨면 marketplace source 필드와
  `SKILL.md` frontmatter 를 따로 확인해야 한다.
