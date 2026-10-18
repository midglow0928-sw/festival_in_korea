# SPEC.md — 대한민국 2주 내 축제 지도 구현 명세서

## 1. 시스템 아키텍처 및 디렉터리 구조

```text
festival_in_korea/
├── AGENT.md                                     # 개발 목적, 타겟 정의 및 가이드라인
├── SPEC.md                                      # 상세 기능 및 기술 구현 명세서
├── pubspec.yaml                                 # 패키지 의존성 및 에셋(앱 아이콘) 설정
├── assets/
│   └── icon/
│       └── app_icon.png                         # 앱 헤더 및 런처 아이콘 원본 에셋 (512x512)
├── android/
│   └── app/
│       ├── build.gradle.kts                     # Android 빌드 설정 (minSdk >= 23, applicationId)
│       └── src/main/
│           ├── AndroidManifest.xml              # 인터넷/GPS 위치 권한 및 앱 라벨·아이콘 설정
│           └── res/
│               ├── mipmap-*/                    # 해상도별 ic_launcher.png & ic_launcher_foreground.png
│               ├── mipmap-anydpi-v26/           # Android 8.0+ Adaptive Icon (ic_launcher.xml)
│               └── values/                      # ic_launcher_background.xml (#1D2549)
└── lib/
    ├── main.dart                                # 앱 진입점 및 네이버 지도 SDK 초기화
    ├── models/
    │   ├── korea_region.dart                    # 전국 17개 광역 시·도 모델, 폴리곤, 중심 좌표, GPS 최근접 계산
    │   └── festival.dart                        # 축제 데이터 모델 및 2주(14일) 기간 중첩 계산 로직
    ├── data/
    │   └── sample_festivals.dart                # 전국 17개 시·도 실제 GPS 좌표 기반 기본 축제 데이터셋
    ├── services/
    │   └── festival_service.dart                # 한국관광공사 TourAPI 연동 및 로컬 데이터 병합/폴백 서비스
    ├── screens/
    │   └── home_screen.dart                     # 메인 화면 (스크롤 레이아웃, 지도, 검색/필터 도구, 축제 카드)
    └── widgets/
        ├── naver_festival_map_widget.dart       # 네이버 지도 위젯 (GPS 현위치 추적, 지역·축제 마커, 카메라 이동)
        ├── korea_map_widget.dart                # 전국 17개 시·도 행정구역 커스텀 벡터 폴리곤 지도 위젯
        └── festival_detail_sheet.dart           # 축제 상세 정보 모달 바텀 시트 및 네이버 지도 위치 보기 연동
```

---

## 2. 핵심 데이터 모델 구현

### 2.1 전국 17개 광역자치단체 모델 (`lib/models/korea_region.dart`)
- **열거형 `KoreaRegion`**:
  - `all`(전국 전체) 및 17개 시·도(`seoul`, `incheon`, `gyeonggi`, `gangwon`, `daejeon`, `sejong`, `chungbuk`, `chungnam`, `daegu`, `gyeongbuk`, `busan`, `ulsan`, `gyeongnam`, `gwangju`, `jeonbuk`, `jeonnam`, `jeju`) 정의.
- **포함 속성**:
  - 한글 약칭(`shortName`) 및 공식 명칭(`fullName`)
  - 한국관광공사 TourAPI 지역코드(`tourApiAreaCode`)
  - 네이버 지도 카메라 중심 위·경도(`latitude`, `longitude`) 및 기본 줌 레벨(`defaultZoom`)
  - 시·도별 테마 색상(`baseColor`) 및 벡터 지도 폴리곤/라벨 좌표(`polygons`, `labelNormalizedOffset`)
- **GPS 좌표 기반 최근접 지역 판별**:
  - `KoreaRegion.isWithinKoreaBounds(lat, lng)`: 위도 `32.8 ~ 38.9`, 경도 `124.5 ~ 131.2` 범위 내 대한민국 좌표 여부 검증.
  - `KoreaRegion.nearestToLatLng(lat, lng)`: 위도/경도 비율(`cos(36.5°)`)을 보정한 유클리드 거리 계산으로 사용자 현위치에서 가장 가까운 광역 시·도를 반환.

### 2.2 축제 모델 및 2주 이내 필터링 (`lib/models/festival.dart`)
- **`Festival` 클래스**:
  - 축제 식별자(`id`), 축제명(`title`), 광역 시·도(`region`), 상세 시·군·구(`cityOrDistrict`), 시작일(`startDate`), 종료일(`endDate`), 장소(`venue`), 주소(`address`), 위·경도(`latitude`, `longitude`), 카테고리(`category`), 요약 및 상세 설명(`summary`, `description`), 요금(`fee`), 문의처(`contact`), 대표 색상(`accentColor`), 썸네일 이미지(`imageUrl`) 보유.
- **2주(14일) 기간 중첩 판별 (`isWithinNextTwoWeeks`)**:
  - 기준일 `referenceDate`의 자정(`windowStart`)부터 `referenceDate + 14일`(`windowEnd`) 사이에 축제가 진행 중이거나 시작하는지 검사:
    ```dart
    !start.isAfter(windowEnd) && !end.isBefore(windowStart)
    ```
- **축제 진행 상태 (`FestivalScheduleStatus`)**:
  - `ongoing`: 기준일 현재 진행 중인 축제 (`진행중` 또는 `오늘 종료`)
  - `upcoming`: 기준일 이후 14일 이내 개막 예정 축제 (`오늘 개막` 또는 `D-N`)
  - `ended`: 종료된 축제

---

## 3. 지도 및 위치(GPS) 연동 구현

### 3.1 네이버 지도 SDK 초기화 (`lib/main.dart`)
- 앱 시작 시 `WidgetsFlutterBinding.ensureInitialized()` 호출 후 `FlutterNaverMap().init(clientId: kNaverMapClientId)`를 통해 네이버 클라우드 플랫폼(NCP) Maps SDK를 초기화합니다.
- 구버전 호환을 위해 초기화 예외 발생 시 `NaverMapSdk.instance.initialize`로 자동 폴백합니다.

### 3.2 네이버 지도 위젯 및 실시간 GPS 추적 (`lib/widgets/naver_festival_map_widget.dart`)
- **초기 구동 및 GPS 현위치 이동 (`_moveToCurrentLocation`)**:
  - 지도가 준비(`onMapReady`)되면 `NDefaultMyLocationTracker`를 통해 Android 위치 권한(`ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`)을 요청하고 기기의 실제 GPS 좌표를 취득합니다.
  - 네이버 지도의 `NLocationOverlay`를 활성화하여 현재 위치에 파란색 현위치 아이콘을 표시하고, `NCameraUpdate.scrollAndZoomTo`로 카메라를 이동합니다.
  - 취득한 GPS 좌표가 대한민국 범위 내일 경우 `KoreaRegion.nearestToLatLng`로 가장 가까운 시·도를 자동 선택하고 상단 배지에 `내 위치 · OO`을 표시합니다.
- **마커(Marker) 및 인터랙션**:
  - **전국 전체 보기**: 17개 시·도별 2주 이내 축제 개수를 표시하는 캡슐형 마커(`서울 4건` 등)와 각 축제 위치 마커를 동시에 렌더링합니다.
  - **특정 시·도 선택 시**: 해당 시·도 중심 좌표 및 줌 레벨로 카메라가 부드럽게 이동하며, 해당 지역의 축제 마커와 정보창(`NInfoWindow`)을 강조 표시합니다.
  - **내 위치 버튼**: 우측 컨트롤 버튼 또는 네이버 지도 기본 현위치 버튼 터치 시 언제든 현재 GPS 위치를 재측정하여 이동합니다.

### 3.3 17개 시·도 커스텀 벡터 지도 (`lib/widgets/korea_map_widget.dart`)
- 상단 배너의 `네이버 지도` / `행정구역도` 토글을 통해 전환 가능합니다.
- `CustomPainter`와 `InteractiveViewer`(핀치 줌·패닝 지원)를 사용하여 전국 17개 광역 시·도의 다각형 경계를 그리며, 각 지역 내 2주 이내 축제 수에 따라 색상 농도와 건수 배지를 표시합니다.

---

## 4. 화면 레이아웃 및 검색/필터 UX (`lib/screens/home_screen.dart`)

### 4.1 첫 화면 구성 (지도 + 검색 도구 집중형 스크롤 레이아웃)
- 전체 본문을 `LayoutBuilder` + `CustomScrollView`로 구성하여 작은 화면에서도 오버플로우 없이 동작하며, **첫 화면에는 대형 지도와 검색/필터 도구만 보이도록** 설계했습니다.
- **동적 대형 지도 높이**:
  - `(화면 가용 높이 - 검색 도구 높이 224px).clamp(340.0, 720.0)` 공식으로 첫 화면의 대부분을 시원한 지도가 채웁니다.
- **검색 및 필터 도구 영역**:
  1. **17개 시·도 빠른 선택 가로 스크롤 칩 바**: 각 지역의 2주 내 축제 건수를 함께 표시하며 터치 시 즉시 해당 지역으로 지도와 목록을 필터링합니다.
  2. **키워드 검색창**: 축제명, 시·군·구, 장소명, 카테고리 실시간 검색 및 초기화 버튼을 제공합니다.
  3. **진행 상태 필터 칩**: `전체`, `진행중`, `개막 예정(D-14)` 필터링 및 조회 건수 요약을 제공합니다.

### 4.2 스크롤 기반 축제 섹션 카드 및 상세 시트
- 화면을 아래로 스크롤하면 선택된 지역의 축제 카드 리스트(`SliverList`)가 나타납니다.
- 각 축제 카드는 진행 상태 배지(`진행중` / `D-N`), 카테고리, 지역·도시 태그, 축제명, 요약 설명, 일정 및 개최 장소를 표시합니다.
- 카드를 터치하면 [`FestivalDetailSheet`](file:///D:/workspace/2_Android/festival_in_korea/lib/widgets/festival_detail_sheet.dart) 모달 바텀 시트가 열리며, 상세 정보 확인 및 **'네이버 지도에서 위치 보기'** 버튼으로 즉시 지도 위 해당 축제 마커로 포커스할 수 있습니다.

---

## 5. 데이터 연동 및 앱 아이콘 구성

### 5.1 한국관광공사 TourAPI 연동 (`lib/services/festival_service.dart`)
- 상단 설정 아이콘(`Icons.tune_rounded`)을 통해 공공데이터포털 TourAPI 서비스 키를 입력하면 `https://apis.data.go.kr/B551011/KorService1/searchFestival1` 엔드포인트에서 기준일 ~ 2주 뒤 기간의 실시간 축제를 조회합니다.
- API 키를 입력하지 않거나 네트워크 오류가 발생할 경우, [`buildSampleFestivals`](file:///D:/workspace/2_Android/festival_in_korea/lib/data/sample_festivals.dart)를 통해 생성된 전국 17개 시·도 30여 개 대표 축제 데이터셋으로 끊김 없이 동작합니다.

### 5.2 앱 아이콘 설정
- 사용자 지정 아이콘 이미지를 기반으로 Android 전 해상도(`mdpi` ~ `xxxhdpi`) [`ic_launcher.png`](file:///D:/workspace/2_Android/festival_in_korea/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png) 및 Android 8.0+ Adaptive Icon([`ic_launcher.xml`](file:///D:/workspace/2_Android/festival_in_korea/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml), 배경색 `#1D2549`, 전경 [`ic_launcher_foreground.png`](file:///D:/workspace/2_Android/festival_in_korea/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png))을 구성했습니다.
- 앱 상단 `AppBar` 타이틀 좌측에도 [`assets/icon/app_icon.png`](file:///D:/workspace/2_Android/festival_in_korea/assets/icon/app_icon.png) 에셋이 표시됩니다.
