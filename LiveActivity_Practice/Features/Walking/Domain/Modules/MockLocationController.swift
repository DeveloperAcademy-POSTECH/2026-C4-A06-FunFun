//  MockLocationController.swift
//  LiveActivity_Practice
//
//  디버깅용 가상 위치 컨트롤러.
//  실내에서도 내비게이션을 테스트할 수 있도록 사용자의 위치를 임의로 이동시킨다.
//

import CoreLocation
import Foundation

@Observable
final class MockLocationController {

    // MARK: - State & Properties

    private(set) var isEnabled = false
    private(set) var coordinate: Coordinate?
    private(set) var heading: CLLocationDirection = 0
    private(set) var isAutoWalking = false

    /// 경로가 있을 때 경로 위를 따라 이동할지 여부
    var followsRoute = true {
        didSet { if followsRoute { resyncRouteCursor() } }
    }
    /// 버튼 한 번에 이동하는 거리 (m)
    var stepDistance: Double = 5
    /// 버튼 한 번에 회전하는 각도 (도)
    var turnStep: Double = 15
    /// 자동 이동 속도 (m/s). 보행 속도는 약 1.4m/s
    var speed: Double = 2

    /// 이동할 때마다 새 좌표/방향을 전달한다.
    var onUpdate: ((Coordinate, CLLocationDirection) -> Void)?
    /// 현재 탐색된 경로의 좌표열을 제공한다.
    var routePathProvider: (() -> [Coordinate])?

    private var routeCursor = 0
    private var timer: Timer?
    private let tickInterval: TimeInterval = 0.5

    var coordinateText: String {
        guard let coordinate else { return "위치 없음" }
        return String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - 활성화

    func enable(at coordinate: Coordinate, heading: CLLocationDirection) {
        self.coordinate = coordinate
        self.heading = normalized(heading)
        isEnabled = true
        resyncRouteCursor()
        publish()
    }

    func disable() {
        stopAutoWalk()
        isEnabled = false
    }

    // MARK: - 수동 조작

    func moveForward() {
        move(meters: stepDistance)
    }

    func moveBackward() {
        move(meters: -stepDistance)
    }

    func turnLeft() {
        turn(by: -turnStep)
    }

    func turnRight() {
        turn(by: turnStep)
    }

    func turn(by degrees: CLLocationDirection) {
        guard isEnabled else { return }
        heading = normalized(heading + degrees)
        publish()
    }

    /// 지정한 좌표로 순간 이동한다.
    func jump(to coordinate: Coordinate) {
        guard isEnabled else { return }
        self.coordinate = coordinate
        resyncRouteCursor()
        publish()
    }

    /// 경로에서 가장 가까운 지점으로 이동하고 진행 방향을 경로에 맞춘다.
    func snapToRoute() {
        guard isEnabled, let current = coordinate else { return }
        let path = routePath()
        guard path.count >= 2 else { return }

        let nearest = path.enumerated().min { current.distance(to: $0.element) < current.distance(to: $1.element) }
        guard let nearest else { return }

        routeCursor = min(nearest.offset, path.count - 2)
        coordinate = nearest.element
        heading = Self.bearing(from: path[routeCursor], to: path[routeCursor + 1])
        publish()
    }

    /// 경로의 출발점으로 이동한다.
    func moveToRouteStart() {
        let path = routePath()
        guard isEnabled, let first = path.first else { return }
        routeCursor = 0
        coordinate = first
        if path.count >= 2 {
            heading = Self.bearing(from: path[0], to: path[1])
        }
        publish()
    }

    // MARK: - 자동 이동

    func toggleAutoWalk() {
        isAutoWalking ? stopAutoWalk() : startAutoWalk()
    }

    func startAutoWalk() {
        guard isEnabled, !isAutoWalking else { return }
        isAutoWalking = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.move(meters: self.speed * self.tickInterval)
        }
    }

    func stopAutoWalk() {
        timer?.invalidate()
        timer = nil
        isAutoWalking = false
    }

    // MARK: - 이동 계산

    private func move(meters: Double) {
        guard isEnabled, let current = coordinate else { return }
        let path = routePath()

        if followsRoute, path.count >= 2 {
            let moved = advanceAlongRoute(path: path, from: current, meters: meters)
            coordinate = moved.coordinate
            heading = moved.heading
        } else {
            coordinate = Self.offset(current, distance: meters, bearing: heading)
        }
        publish()
    }

    /// 경로 위를 따라 이동한 결과 좌표와 진행 방향을 계산한다.
    private func advanceAlongRoute(
        path: [Coordinate],
        from start: Coordinate,
        meters: Double
    ) -> (coordinate: Coordinate, heading: CLLocationDirection) {
        var position = start
        var remaining = abs(meters)
        var cursor = min(max(routeCursor, 0), path.count - 2)
        let isForward = meters >= 0

        while remaining > 0 {
            let target = isForward ? path[cursor + 1] : path[cursor]
            let distanceToTarget = position.distance(to: target)

            if distanceToTarget > remaining {
                position = Self.offset(
                    position,
                    distance: remaining,
                    bearing: Self.bearing(from: position, to: target)
                )
                remaining = 0
                break
            }

            remaining -= distanceToTarget
            position = target

            if isForward {
                guard cursor + 2 <= path.count - 1 else { break } // 도착점
                cursor += 1
            } else {
                guard cursor - 1 >= 0 else { break } // 출발점
                cursor -= 1
            }
        }

        routeCursor = cursor
        let segmentHeading = Self.bearing(from: path[cursor], to: path[cursor + 1])
        return (position, isForward ? segmentHeading : normalized(segmentHeading + 180))
    }

    private func resyncRouteCursor() {
        let path = routePath()
        guard let current = coordinate, path.count >= 2 else {
            routeCursor = 0
            return
        }
        let nearest = path.enumerated().min { current.distance(to: $0.element) < current.distance(to: $1.element) }
        routeCursor = min(nearest?.offset ?? 0, path.count - 2)
    }

    private func routePath() -> [Coordinate] {
        routePathProvider?() ?? []
    }

    private func publish() {
        guard let coordinate else { return }
        onUpdate?(coordinate, heading)
    }

    private func normalized(_ degrees: CLLocationDirection) -> CLLocationDirection {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    // MARK: - 좌표 계산 유틸

    private static let earthRadius: Double = 6_371_000

    /// 기준 좌표에서 특정 방향으로 distance(m)만큼 떨어진 좌표
    static func offset(_ origin: Coordinate, distance: Double, bearing: CLLocationDirection) -> Coordinate {
        let angularDistance = distance / earthRadius
        let bearingRadians = bearing * .pi / 180
        let latitude = origin.latitude * .pi / 180
        let longitude = origin.longitude * .pi / 180

        let movedLatitude = asin(
            sin(latitude) * cos(angularDistance)
            + cos(latitude) * sin(angularDistance) * cos(bearingRadians)
        )
        let movedLongitude = longitude + atan2(
            sin(bearingRadians) * sin(angularDistance) * cos(latitude),
            cos(angularDistance) - sin(latitude) * sin(movedLatitude)
        )

        return Coordinate(
            latitude: movedLatitude * 180 / .pi,
            longitude: movedLongitude * 180 / .pi
        )
    }

    /// 두 좌표 사이의 진행 방위각 (0 = 북쪽)
    static func bearing(from origin: Coordinate, to destination: Coordinate) -> CLLocationDirection {
        let latitude1 = origin.latitude * .pi / 180
        let latitude2 = destination.latitude * .pi / 180
        let deltaLongitude = (destination.longitude - origin.longitude) * .pi / 180

        let y = sin(deltaLongitude) * cos(latitude2)
        let x = cos(latitude1) * sin(latitude2) - sin(latitude1) * cos(latitude2) * cos(deltaLongitude)
        let degrees = atan2(y, x) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }
}
