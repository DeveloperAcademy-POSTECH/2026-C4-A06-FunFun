import ActivityKit
import Foundation

@MainActor
final class WalkingLiveActivityManager {
    func start(destinationName: String, route: WalkingRoute) async throws {
        await end()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let progress = initialProgress(route)
        let state = makeState(progress: progress)
        _ = try Activity.request(
            attributes: WalkingActivityAttributes(destinationName: destinationName),
            content: ActivityContent(state: state, staleDate: .now.addingTimeInterval(120)),
            pushType: nil
        )
    }

    func update(_ progress: WalkingProgress) async {
        let content = ActivityContent(state: makeState(progress: progress), staleDate: .now.addingTimeInterval(120))
        for activity in Activity<WalkingActivityAttributes>.activities {
            await activity.update(content)
        }
    }

    func end() async {
        for activity in Activity<WalkingActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func initialProgress(_ route: WalkingRoute) -> WalkingProgress {
        let next = route.maneuvers.first
        return WalkingProgress(
            remainingDistance: route.totalDistance,
            distanceToNextManeuver: next.map { Int(route.path.first?.distance(to: $0.coordinate) ?? 0) } ?? route.totalDistance,
            nextManeuver: next,
            isOffRoute: false
        )
    }

    private func makeState(progress: WalkingProgress) -> WalkingActivityAttributes.ContentState {
        let walkingSpeed = 1.25
        return WalkingActivityAttributes.ContentState(
            remainingDistance: progress.remainingDistance,
            estimatedArrival: .now.addingTimeInterval(Double(progress.remainingDistance) / walkingSpeed),
            distanceToNextTurn: progress.distanceToNextManeuver,
            maneuver: progress.nextManeuver?.turn ?? .destination,
            landmarkName: progress.nextManeuver?.landmark?.name,
            instruction: progress.nextManeuver?.instruction ?? "목적지에 도착했습니다",
            isOffRoute: progress.isOffRoute
        )
    }
}
