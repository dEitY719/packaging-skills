# 프롬프트: 권장 항목(R3/R6/R7) 처리 + GitHub Pages 활성화

`packaging:structure-check` 가 남긴 권장 WARN 중 R3 / R6 / R7 을 해소하고
GitHub Pages 를 켜는 작업을 AI 에게 시키기 위한 프롬프트다. 필수 항목
(M1-M10)이 이미 통과한 repo 를 전제로 한다. 아래 구분선부터 끝까지를 그대로
복사해 쓴다.

---

# 작업: 구조 감사 권장 항목(R3/R6/R7) 처리 + GitHub Pages 활성화

이 repo 는 `packaging:structure-check` 기준을 따르는 스킬 마켓플레이스 repo 다.
필수 항목(M1-M10)은 이미 통과한 상태를 전제로, 남은 권장 WARN 3건을 해소하고
GitHub Pages 를 켠다.

## 0. 사전 조사 — 이름과 경로를 하드코딩하지 말고 스캔해서 알아낼 것

1. `git remote get-url origin` 으로 host / owner / repo 를 파싱한다.
   `github.com` 을 하드코딩하지 말 것 (GHES 대응).
2. Pages base URL 은 `https://<owner>.github.io/<repo>` 이며
   **owner 는 전부 소문자로 변환한다** (`dEitY719` -> `deity719`).
   github.io 호스트명은 대문자를 허용하지 않는다.
3. 현재 상태를 실측해서 표로 먼저 보고한 뒤 시작한다:
   - `.claude-plugin/marketplace.json` 에 `$schema` 가 있는가 (R6)
   - 최상위 `description` 이 있는가 / `plugins[]` 의 **object** 원소마다
     `homepage` 가 있는가 (R7). string 형 원소는 대상 아님
   - `README.md` 에 `](docs/` 형태의 **상대** 링크가 있는가 (R3)
   - `gh api repos/<owner>/<repo>/pages` 응답 (404 면 비활성)
   - `git ls-tree --name-only origin/<default-branch>` 에 `docs/` 가 있는가

## 1. R6 — marketplace.json 에 `$schema` 선언

`.claude-plugin/marketplace.json` 최상위에 첫 키로 추가한다.

```json
"$schema": "https://anthropic.com/claude-code/marketplace.schema.json"
```

런타임 영향은 없고 에디터/LSP 검증용이다. 이미 있으면 건드리지 않는다(멱등).

## 2. R7 — 리스팅 메타데이터 보강

`plugins[]` 의 **object** 원소마다 비어 있지 않은 `homepage` 를 넣는다.
값은 같은 플러그인의 `plugin.json` 에 이미 있는 `homepage` 와 1:1로 맞춘다
(새로 지어내지 말고 기존 값을 재사용). 최상위 `description` 이 없으면 함께 채운다.

## 3. R3 — README 의 "Simple" 휴리스틱

**중요 — R3 와 R5 는 판정 방식이 다르다.**
R5 는 "상대경로 **또는** Pages 절대 URL 둘 다 인정"이라고 스펙에 명시돼 있지만,
R3 는 그 문구가 없고 `docs/` **경로 문자열** 존재로 판정된다.
따라서 README 가 Pages 절대 URL 로만 링크하고 있으면 R5 는 PASS 인데
R3 는 계속 WARN 이다. 이 상태를 실제로 확인한 뒤 진행할 것.

해소 방법: 기존 Pages 절대 URL 링크는 **그대로 두고**, `docs/` 상대 링크를
한 줄만 **추가**한다. 예:

```markdown
Each page is generated from a Markdown source under
[`docs/skill-guides/`](docs/skill-guides) and [`docs/skill-output/`](docs/skill-output).
```

README 의 다른 섹션(Install, Layout, CI, License 등)은 건드리지 않는다.
diff 가 순수 추가(insertions only)인지 `git diff --stat` 으로 확인한다.

## 4. GitHub Pages 활성화

**선행 조건을 먼저 확인하라.** Pages 소스를 `<default-branch>:/docs` 로 잡는데
그 브랜치에 `docs/` 가 아직 없으면, 활성화는 성공해도 첫 빌드는 `errored` 로
끝난다. `docs/` 가 기본 브랜치에 올라간 **뒤**에 켜거나, 먼저 켠다면 첫 빌드
실패가 정상임을 보고에 명시하라.

```bash
gh api --hostname "$HOST" "repos/$OWNER/$REPO" \
  --jq '{visibility, default_branch, admin: .permissions.admin}'   # 권한 확인
gh api --hostname "$HOST" "repos/$OWNER/$REPO/pages"                # 현재 상태(404=비활성)

echo '{"source":{"branch":"main","path":"/docs"}}' \
  | gh api --hostname "$HOST" "repos/$OWNER/$REPO/pages" -X POST --input -
```

이미 200 으로 응답하면 건너뛴다(멱등). 토큰 스코프 부족이나 호스트 접근 실패는
중단이 아니라 경고로 처리하고 나머지를 계속 진행한다.

활성화 후 응답의 `html_url` 이 0-2 에서 계산한 Pages base URL 과 **문자 단위로
일치**하는지 대조하라. 불일치는 owner 대소문자 실수의 신호다.

## 5. 검증 (끝내기 전에 반드시)

1. `python3 -m json.tool` 로 수정한 JSON 이 유효한지 확인한다.
2. **회귀 검사** — `plugins[].source` 값이 그대로인지 확인한다 (M7/M8).
3. **버전 일치** — CI 가 검사하므로, 모든 매니페스트의 `version` 이 여전히
   동일한지 확인한다. 이번 작업은 버전을 바꾸지 않는다.
4. R3/R6/R7 을 각각 재판정해 PASS 인지 확인한다.
5. `git status` 로 의도한 파일만 바뀌었는지 확인한다.
6. 결과를 표로 보고한다: 항목 / 이전 / 이후 / 근거 명령.

## 6. 커밋과 push (사용자가 명시적으로 요청했을 때만)

요청받기 전에는 파일 생성/수정까지만 하고 멈춘다. 요청받았다면:

- repo 의 기존 `git log` 스타일(Conventional Commits)에 맞춘다.
- push 후 CI 결과를 **끝까지 확인**한다. 실패하면 로그를 읽고 원인을 고친다.
  `gh run list --workflow <name> --limit 1 --json status,conclusion,headSha`
- Pages 빌드 상태를 확인한다:
  `gh api "repos/$OWNER/$REPO/pages/builds" --jq '.[0]|{status,error:.error.message,commit}'`
- 마지막으로 README 가 링크한 **모든** URL 에 실제로 접근해 HTTP 200 인지
  `curl -s -o /dev/null -w '%{http_code}'` 로 확인한다. 200 을 확인하기 전에는
  "링크가 살아 있다"고 보고하지 마라.

## 함정 (이전 실행에서 실제로 발생한 것들)

- **이모지 CI.** 이 repo 는 이모지를 금지하고 CI 가 `No emojis in tracked text`
  로 강제한다. 생성 도구(예: `/visuals:visualize` 스켈레톤의 유틸리티 메뉴)가
  이모지를 넣는 경우가 있으니, 커밋 전에 추적 파일 전체를 검사하라.
  도구의 기본 템플릿보다 **repo 규칙이 우선**이다. 인라인 SVG 로 교체하고,
  교체 후 해당 기능(테마 토글 등)이 여전히 동작하는지 확인하라.
- **이모지 검사 정규식.** 화살표(U+2192, U+2194)나 체크(U+2713)까지 잡는 넓은
  범위를 쓰면 기존에 CI 를 통과해 온 파일이 오탐된다. 이모지 범위만 좁게 잡고,
  걸린 문자가 정말 신규인지 `git grep <통과했던-커밋>` 으로 대조하라.
- **Pages 첫 빌드 실패.** 위 4번 참조.

## 금지사항

- 수치·출력·URL 을 지어내지 마라. 모든 보고는 실제 명령 결과여야 한다.
- README 산문과 매니페스트에 이모지를 쓰지 마라.
- 요청 없이 커밋하거나 push 하지 마라.
- `version` 을 바꾸지 마라. 버전 범프는 별도 작업이고 매니페스트 전체를
  함께 올려야 한다.
- README 의 기존 섹션과 기존 Pages 절대 URL 링크를 재작성하지 마라 — 추가만 한다.
