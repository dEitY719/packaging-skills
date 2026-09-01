# structure-check 사용 결과

> **한 줄 요약** — repo 경로 하나를 받아 M1-M10 / R1-R8 채점 리포트를 생성합니다.

```
repo 경로  ──▶  /packaging:structure-check  ──▶  PASS/WARN/FAIL 리포트
```

## 1. 실행한 명령

```
범용:  /packaging:structure-check [repo-path] [--single|--mono]
이번:  /packaging:structure-check          (인자 없음 = 현재 디렉터리)
```

## 2. 입력

이 repo 자신 (`packaging-skills`) — 실행 시점에 `docs/` 디렉터리가 아직 없던 상태.
모드는 `marketplace.json` 의 `plugins[0].source == "./"` 로 **single** 감지,
plugin root 는 repo 루트 1개, 스킬은 스캔으로 4개 발견.

## 3. 결과

판정 **FAIL** — 필수 1, 권장 6, N/A 1.

```
[필수] M1 PASS  M2 PASS  M3 PASS  M4 PASS  M5 FAIL  M6 PASS
       M7 PASS  M8 PASS  M9 N/A   M10 PASS
[권장] R1 WARN  R2 WARN  R3 WARN  R4 PASS  R5 WARN  R6 WARN  R7 WARN  R8 PASS
```

- **M5 FAIL** — `docs/skill-guides/`, `docs/skill-output/` 부재 (`docs/` 자체가 없음)
- R1/R2/R3/R5 는 전부 M5 에서 파생된 WARN
- R6 — `marketplace.json` 에 `$schema` 없음
- R7 — `plugins[0]` 에 `homepage` 없음
- 설치 필수 항목(M1-M4, M7-M10)은 전부 PASS

파일은 하나도 변경되지 않았다 (읽기 전용 스킬).

스킬 설명서: [structure-check.html](../skill-guides/structure-check.html)
