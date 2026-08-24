//  BearingTracker.swift
//  LiveActivity_Practice

import CoreLocation
import Foundation

@Observable
final class BearingTracker {

    private(set) var bearing: CLLocationDirection?

    // 현재 위치에서 경로상 20m 앞 지점까지의 경로 방향을 계산
    func update(at current: Coordinate, route: WalkingRoute, accuracy: CLLocationAccuracy) {
        guard accuracy <= 30,
              route.path.count >= 2,
              let nearest = route.path.enumerated().min(by: {
                  $0.element.distance(to: current) < $1.element.distance(to: current)
              }) else {
            bearing = nil
            return
        }

        let lookAheadDistance: CLLocationDistance = 20
        var targetIndex = nearest.offset
        var accumulatedDistance: CLLocationDistance = 0
        while targetIndex < route.path.count - 1, accumulatedDistance < lookAheadDistance {
            accumulatedDistance += route.path[targetIndex].distance(to: route.path[targetIndex + 1])
            targetIndex += 1
        }

        guard targetIndex > nearest.offset else { return }
        let candidate = calculateBearing(from: route.path[nearest.offset], to: route.path[targetIndex])
        bearing = smoothed(from: bearing, to: candidate)
    }

    // 경로 시작점에서 20m 앞까지의 방향 계산 (초기값용)
    func updateFromRouteStart(_ route: WalkingRoute) {
        guard route.path.count >= 2 else { return }

        let lookAheadDistance: CLLocationDistance = 20
        var targetIndex = 0
        var accumulatedDistance: CLLocationDistance = 0
        while targetIndex < route.path.count - 1, accumulatedDistance < lookAheadDistance {
            accumulatedDistance += route.path[targetIndex].distance(to: route.path[targetIndex + 1])
            targetIndex += 1
        }

        guard targetIndex > 0 else { return }
        bearing = calculateBearing(from: route.path[0], to: route.path[targetIndex])
    }

    func reset() {
        bearing = nil
    }

    // MARK: - Private

    // 두 좌표 간 지리적 방위각 계산 (Haversine 공식)
    private func calculateBearing(from start: Coordinate, to end: Coordinate) -> CLLocationDirection {
        let startLatitude = start.latitude * .pi / 180
        let endLatitude = end.latitude * .pi / 180
        let longitudeDelta = (end.longitude - start.longitude) * .pi / 180
        let y = sin(longitudeDelta) * cos(endLatitude)
        let x = cos(startLatitude) * sin(endLatitude)
            - sin(startLatitude) * cos(endLatitude) * cos(longitudeDelta)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    // 방위각 변화를 보간(0.35 비율)해서 카메라가 급격히 회전하지 않게 함
    private func smoothed(from previous: CLLocationDirection?, to candidate: CLLocationDirection) -> CLLocationDirection {
        guard let previous else { return candidate }
        let shortestDelta = (candidate - previous + 540).truncatingRemainder(dividingBy: 360) - 180
        guard abs(shortestDelta) >= 3 else { return previous }
        return (previous + shortestDelta * 0.35 + 360).truncatingRemainder(dividingBy: 360)
    }
}
