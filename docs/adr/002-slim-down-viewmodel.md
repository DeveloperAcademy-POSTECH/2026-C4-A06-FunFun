# ADR-002: ViewModel의 책임 분리

## Status
제안됨

## Date
2026-08-21

## Context
ViewModel에 너무 많은 책임이 있다.

```swift

// MARK: - 장소 선택

func placeSelected(_ place: Place)

func clearSelectedPlace() // ViewModel 외부에서 selectedPlace = nil로 바꿈

func mainMode() // main mode로 바꾸는 데에 필요한 행동들

func setStartFromCurrentLocation() // 시작 위치를 현재 위치로 설정

// MARK: - 경로 탐색

func searchRoute()

func dismissRoute()
// 프로퍼티 초기화
// navigating이면 stopNavigation() 호출

// MARK: - 내비게이션

func startNavigating()

func stopNavigation()

func refreshLiveActivity() // Setting에서 사용 : 설정 값이 바뀌었을 때 사용

// MARK: - 경로 이탈

// Off-Route 상태에서 더 이상 경고를 주지 않아도 된다고 설정했을 때
func keepCurrentRoute()

func rerouteFromCurrentLocation()
// GPS 업데이트마다 호출되어 "경로 이탈 여부"를 판정하는 상태 머신
private func updateDeviationState(at current: Coordinate, routeMatch: RouteMatch, horizontalAccuracy: CLLocationAccuracy)

// navigating 상태에서 이탈이 아님을 감지하였을 때 호출
private func resetDeviationState()

// 이탈했을 때, 지나온 좌표를 추가해줌
private func appendDeviationCoordinate(_ coordinate: Coordinate)

// MARK: - 경로 진행 계산

private func initialProgress(_ route: WalkingRoute) -> WalkingProgress

private func calculateProgress(at current: Coordinate, route: WalkingRoute) -> WalkingProgress

private static func passedZoneCenter(for maneuver: WalkingManeuver, routePath: [Coordinate]) -> Coordinate?

// MARK: - 경로 매칭

private struct RouteMatch {
    let segmentIndex: Int
    let distance: CLLocationDistance
    let snappedCoordinate: Coordinate
}

// 현재 위치에서 가장 가까운 route element를 찾는다.
private func matchToRoute(current: Coordinate, routePath: [Coordinate]) -> RouteMatch?

// 사용자의 현재 위치가 경로에서 얼마나 떨어져 있는가
private func routeMatch(current: Coordinate, segmentStart: Coordinate, segmentEnd: Coordinate, segmentIndex: Int) -> RouteMatch

// MARK: - 카메라 방향

// 사용자의 진행 방향 = 화면 위쪽이 유지되도록 하는 카메라 회전 로직
private func updateNavigationBearing(at current: Coordinate, route: WalkingRoute)

// 경로 시작점에서 20m 앞까지의 방향 계산 (초기값용)
private func updateNavigationBearingFromRouteStart(_ route: WalkingRoute)

// 두 좌표 간 지리적 방위각 계산 (Haversine 공식)
private func bearing(from start: Coordinate, to end: Coordinate) -> CLLocationDirection

// 방위각 변화를 보간(0.35 비율)해서 카메라가 급격히 회전하지 않게 함
private func smoothedBearing(from previous: CLLocationDirection?, to candidate: CLLocationDirection) -> CLLocationDirection

// MARK: - 위치 권한

func startLocationTracking()

func requestLocationAccess()

// MARK: - CLLocationManagerDelegate

func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])

func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)

func locationManagerDidChangeAuthorization(_ manager: CLLocationManager)

func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading)
```

## Decision
무엇을 어떻게 바꾸기로 했는가? 대안이 있었다면 왜 이 방향을 택했는가?

## Result
이 결정으로 인해 어떤 코드가 추가/삭제/변경되었는가? 향후 주의할 점은?
