# SimpleRepu (평판 가이드) 애드온

> 공통사항(레포 구조, 릴리즈 절차, 코딩 규칙)은 상위 폴더의 [`../CLAUDE.md`](../CLAUDE.md)를 참조.

## 개요
- **애드온**: SimpleRepu v1.0.0
- **레포**: `cdcdcd050/SimpleRepu`
- **대상 클라이언트**: WoW BCC (Interface: 20505)
- **용도**: TBC 평판과 관련 던전을 표시하는 가이드
- **제작 배경**: TBC 던전 평판 관계를 한눈에 파악하기 위해 제작

### 의존성
- **필수**: 없음 (독립 실행 가능, 라이브러리 번들 포함)
- **선택**: Arcana — 데이터 바에 평판 브로커 표시

### SavedVariables
- **`SimpleRepuDB`**: 설정 저장
  ```lua
  SimpleRepuDB = {
      minimapPos = 180,       -- 미니맵 버튼 각도
      popupPos = nil,         -- 팝업 창 위치 { point, relPoint, x, y }
  }
  ```

## 기능

### 미니맵 버튼
- WoW 내장 텍스처를 사용한 자체 미니맵 버튼 (LibDBIcon 미사용)
- 아이콘: `Achievement_Reputation_01` (평판 아이콘)
- 좌클릭/우클릭: 팝업 창 토글
- 우클릭 드래그: 미니맵 주변 위치 이동
- 마우스오버: 평판 현황 툴팁 표시

### 팝업 창
- `GameTooltipTemplate` 기반 — 툴팁과 동일한 형태
- 화면 중앙에 표시, 좌클릭 드래그로 이동 가능
- 위치 기억 (`SimpleRepuDB.popupPos`)
- ESC로 닫기 (`UISpecialFrames` 등록)

### 평판 표시
- 진영명: Blizzard API (`GetFactionInfoByID`) 사용 — 클라이언트 로캘 자동 적용
- 등급: 색상 코딩 (적대~확고한 동맹, 8단계)
- 수치: 현재 등급 내 진행량 / 최대값
- 던전: 만렙 미달 시 관련 던전 표시 (레이드는 빨간색, 일반 던전은 회색)
- 진영 필터링: 얼라이언스/호드 전용 진영 자동 필터

### LDB (LibDataBroker) 연동
- LDB data source 이름: `"SimpleRepu"`
- 아이콘: `Interface\Icons\Achievement_Reputation_01`
- 마우스오버: 팝업과 동일한 평판 툴팁
- 클릭: 팝업 창 토글

## 수록 진영 (11개)

### 던전 진영
| 진영 | Faction ID | 타입 | 관련 던전 |
|------|-----------|------|----------|
| Honor Hold | 946 | 얼라 전용 | 지옥불 성루, 피의 용광로, 으스러진 손의 전당 |
| Thrallmar | 947 | 호드 전용 | 지옥불 성루, 피의 용광로, 으스러진 손의 전당 |
| Cenarion Expedition | 942 | 공통 | 강제노역소, 지하수렁, 증기 저장고 |
| Lower City | 1011 | 공통 | 마나 무덤, 아키나이 납골당, 세데크 전당, 그림자 미궁 |
| The Sha'tar | 935 | 공통 | 메카나르, 식물원 |
| Keepers of Time | 989 | 공통 | 옛 힐스브래드 구릉지, 검은늪 |

### 샤트라스 진영
| 진영 | Faction ID | 비고 |
|------|-----------|------|
| The Aldor | 932 | 납품 아이템으로 평판 획득 |
| The Scryers | 934 | 납품 아이템으로 평판 획득 |

### 레이드 진영
| 진영 | Faction ID | 관련 레이드 |
|------|-----------|------------|
| Ashtongue Deathsworn | 1012 | 검은 사원 |
| The Scale of the Sands | 990 | 하이잘 산 전투 |
| The Violet Eye | 967 | 카라잔 |

## 코드 구조

### Data.lua
- `SR.FACTIONS` — 진영 목록 테이블
  ```lua
  { id = 946, name_en = "Honor Hold", alliance = true, dungeons = {
      { en = "Hellfire Ramparts", kr = "지옥불 성루" },
  }}
  ```
  - `id`: Blizzard 진영 ID (`GetFactionInfoByID`에 사용)
  - `name_en`: 영어 이름 (API 실패 시 폴백)
  - `alliance`/`horde`: 진영 필터 (없으면 공통)
  - `dungeons`: 관련 던전 목록, `raid = true`로 레이드 구분
- `SR.STANDING` — 평판 등급 라벨 (영어/한글)
- `SR.STANDING_COLORS` — 등급별 색상 (1=적대 ~ 8=확고한 동맹)

### Core.lua
| 함수/변수 | 역할 |
|----------|------|
| `L(en, kr)` | 로캘 헬퍼 (`koKR`이면 한글 반환) |
| `GetFactionData(factionID)` | Blizzard API로 평판 데이터 조회 |
| `IsFactionRelevant(factionData)` | 플레이어 진영에 맞는 팩션 필터 |
| `ShowRepTooltip(tooltip)` | 평판 정보 툴팁 렌더링 |
| `TogglePopup()` | 팝업 창 생성/토글 |

## 수정 시 참고사항
- 평판/던전 데이터 추가는 `Data.lua`의 `SR.FACTIONS` 테이블에 항목 추가
- 진영 이름은 API가 제공하므로 `name_en`은 폴백용 — `name_kr` 불필요
- 던전 이름은 API 미제공이므로 `en`/`kr` 수동 관리 필요
- UI/로직 수정은 `Core.lua`에서 이루어짐
- 팝업은 `GameTooltipTemplate` 기반 — 커스텀 프레임이 아님
