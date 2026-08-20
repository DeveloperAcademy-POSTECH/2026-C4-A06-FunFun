# ADR-002: SearchViewModel 분리

## 상태
완료

## 날짜
2026-08-19

## 맥락
`WalkingNavigationViewModel`에 검색, 경로 탐색, 내비게이션, 이탈 감지, Live Activity 등 너무 많은 책임이 몰려 있었다.
검색은 독립적인 화면(SearchModalView)에서만 사용되므로 분리 가능한 첫 번째 후보였다.

Delegate 패턴 vs 클로저 전달 두 가지를 고민했고, 검색 결과 `Place` 하나만 넘기면 되므로 클로저가 더 단순하다고 판단했다.

## 결정
- `SearchViewModel`을 별도 `@Observable` 클래스로 분리 (NSObject 상속, CLLocationManagerDelegate 포함)
- 검색에 필요한 현위치는 SearchViewModel 자체 CLLocationManager로 획득 (WalkingNavigationViewModel 의존성 제거)
- 검색 결과 선택 시 `placeSelected: (Place) -> Void` 클로저로 상위 View에 전달
- `TMAPClientProtocol`을 init 주입하여 테스트 가능하게 구성
- `Place.init?(from: LandmarkPoiDTO)`는 앱 타겟 전용 extension(`Place+LandmarkPoiDTO.swift`)으로 분리 (위젯 타겟 빌드 에러 방지)

## 결과
- SearchViewModel: 검색, 페이징, 결과 초기화만 담당
- WalkingNavigationViewModel: 검색 관련 코드 제거, `placeSelected(_:)`로 결과만 수신
- ViewState에서 `.searching` case 제거 — 검색이 fullScreenCover로 분리되면서 main View 상태로 존재할 이유가 없어짐
- 테스트 분리: `SearchViewModelTests` / `WalkingNavigationViewModelTests`