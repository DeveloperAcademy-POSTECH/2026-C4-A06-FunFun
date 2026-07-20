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
    private var hasTriggeredArrival = false
    private var approachingStartDate: Date?

    func start(destinationName: String, route: WalkingRoute) async throws {
        await end()
        wasApproachingTurn = false
        hasTriggeredArrival = false
        approachingStartDate = nil
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let progress = initialProgress(route)
        let state = makeState(progress: progress)
        _ = try Activity.request(
            attributes: WalkingActivityAttributes(destinationName: destinationName),
            content: ActivityContent(state: state, staleDate: .now.addingTimeInterval(120)),
            pushType: nil
        )
    }

    func update(_ progress: WalkingProgress, showTime: Bool = false, approachingThreshold: Int = 10) async {
        var state = makeState(progress: progress, showTime: showTime, approachingThreshold: approachingThreshold)

        // approaching 최소 8초 유지
        if state.isApproachingTurn && approachingStartDate == nil {
            approachingStartDate = .now
        } else if !state.isApproachingTurn, let start = approachingStartDate {
            if Date.now.timeIntervalSince(start) < 8 {
                state = WalkingActivityAttributes.ContentState(
                    remainingDistance: state.remainingDistance,
                    estimatedArrival: state.estimatedArrival,
                    distanceToNextTurn: state.distanceToNextTurn,
                    maneuver: state.maneuver,
                    landmarkName: state.landmarkName,
                    instruction: state.instruction,
                    isOffRoute: state.isOffRoute,
                    isApproachingTurn: true,
                    showTimeInsteadOfDistance: state.showTimeInsteadOfDistance
                )
            } else {
                approachingStartDate = nil
            }
        }

        let content = ActivityContent(state: state, staleDate: .now.addingTimeInterval(120))
        let justEnteredApproach = state.isApproachingTurn && !wasApproachingTurn
        wasApproachingTurn = state.isApproachingTurn

        let isArriving = state.maneuver == .destination && state.distanceToNextTurn < approachingThreshold

        for activity in Activity<WalkingActivityAttributes>.activities {
            if isArriving && !hasTriggeredArrival {
                hasTriggeredArrival = true
                await activity.end(content, dismissalPolicy: .after(.now.addingTimeInterval(8)))
            } else if justEnteredApproach {
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

    private func makeState(progress: WalkingProgress, showTime: Bool = false, approachingThreshold: Int = 10) -> WalkingActivityAttributes.ContentState {
        let walkingSpeed = 1.25
        return WalkingActivityAttributes.ContentState(
            remainingDistance: progress.remainingDistance,
            estimatedArrival: .now.addingTimeInterval(Double(progress.remainingDistance) / walkingSpeed),
            distanceToNextTurn: progress.distanceToNextManeuver,
            maneuver: progress.nextManeuver?.turn ?? .destination,
            landmarkName: progress.nextManeuver?.landmark?.name,
            instruction: progress.nextManeuver?.instruction ?? "목적지에 도착했습니다",
            isOffRoute: progress.isOffRoute,
            isApproachingTurn: progress.distanceToNextManeuver < approachingThreshold,
            showTimeInsteadOfDistance: showTime
        )
    }
}
