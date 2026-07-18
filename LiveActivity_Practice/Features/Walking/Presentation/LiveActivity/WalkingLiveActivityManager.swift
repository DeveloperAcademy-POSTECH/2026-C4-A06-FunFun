//  WalkingLiveActivityManager.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import ActivityKit
import Foundation

@MainActor
final class WalkingLiveActivityManager {
    private var wasApproachingTurn = false

    func start(destinationName: String, route: WalkingRoute) async throws {
        await end()
        wasApproachingTurn = false
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let progress = initialProgress(route)
        let state = makeState(progress: progress)
        _ = try Activity.request(
            attributes: WalkingActivityAttributes(destinationName: destinationName),
            content: ActivityContent(state: state, staleDate: .now.addingTimeInterval(120)),
            pushType: nil
        )
    }

    func update(_ progress: WalkingProgress, showTime: Bool = false) async {
        let state = makeState(progress: progress, showTime: showTime)
        let content = ActivityContent(state: state, staleDate: .now.addingTimeInterval(120))
        let justEnteredApproach = state.isApproachingTurn && !wasApproachingTurn
        wasApproachingTurn = state.isApproachingTurn

        for activity in Activity<WalkingActivityAttributes>.activities {
            if justEnteredApproach {
                await activity.update(content, alertConfiguration: AlertConfiguration(
                    title: "\(state.instruction)",
                    body: "\(state.distanceToNextTurn)m 앞",
                    sound: .default
                ))
            } else {
                await activity.update(content)
            }
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

    private func makeState(progress: WalkingProgress, showTime: Bool = false) -> WalkingActivityAttributes.ContentState {
        let walkingSpeed = 1.25
        return WalkingActivityAttributes.ContentState(
            remainingDistance: progress.remainingDistance,
            estimatedArrival: .now.addingTimeInterval(Double(progress.remainingDistance) / walkingSpeed),
            distanceToNextTurn: progress.distanceToNextManeuver,
            maneuver: progress.nextManeuver?.turn ?? .destination,
            landmarkName: progress.nextManeuver?.landmark?.name,
            instruction: progress.nextManeuver?.instruction ?? "목적지에 도착했습니다",
            isOffRoute: progress.isOffRoute,
            isApproachingTurn: progress.distanceToNextManeuver < 10,
            showTimeInsteadOfDistance: showTime
        )
    }
}
