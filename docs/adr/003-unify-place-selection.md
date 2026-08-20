# ADR-003: tappedCoordinate 제거, selectedPlace로 장소 선택 통합

## 상태
완료

## 날짜
2026-08-20

## 맥락
지도 탭 좌표(`tappedCoordinate`)와 검색 결과(`previewDestination`)가 별도 프로퍼티로 존재했다. (탭 좌표를 누른 이유는 테스트를 빠르게 하기 위해 기능을 추가함)

둘 다 "사용자가 선택한 장소"라는 같은 개념인데 경로가 달라서, 각각의 설정/해제 함수(`selectCoordinateAsDestination`, `clearTappedCoordinate`)가 따로 있었고 View 쪽에서도 두 경우를 구분해야 했다.

`main` ViewState 안에서도 orthogonal한 상태(장소 선택됨/안됨)가 암묵적으로 존재하는 문제도 있었다.

## 결정
- `tappedCoordinate`, `previewDestination` 제거 → `selectedPlace: Place?` 하나로 통합
- 지도 POI 탭: `NMFMapViewTouchDelegate.didTapSymbol`에서 `NMFSymbol`의 `caption`/`position`으로 `Place` 생성 → `onPlaceSelected` 콜백
- 빈 곳 탭: `didTapMap` → `onMapCleared` 콜백 → `clearSelectedPlace()`
- `clearSelectedPlace()`는 단순히 `selectedPlace = nil`만 수행. 경로 해제는 `dismissRoute()`가 담당.
- 대안으로 `main` 상태를 `.main(plain)` / `.main(placeSelected)` 서브 상태로 나누는 것도 고려했으나, `selectedPlace`의 nil 여부로 View가 분기하는 현재 구조가 더 단순하므로 유지.

## 결과
- 삭제: `tappedCoordinate`, `selectCoordinateAsDestination()`, `clearTappedCoordinate()`, `tappedDestinationPanel`
- 변경: `MapPresentationState`에서 `onMapTapped` → `onPlaceSelected`/`onMapCleared` 분리
- 변경: `placeSelected(_:)`에 목적지 정보 설정 + `setStartFromCurrentLocation()` 호출 추가
- NaverMapRouteView Coordinator 안에서 Place를 직접 생성하므로 외부 의존성 없음
