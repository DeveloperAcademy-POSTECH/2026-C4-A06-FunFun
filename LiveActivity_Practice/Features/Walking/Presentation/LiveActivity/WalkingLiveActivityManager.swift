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
    private var approachingStateDistance: Double = 8

    func start(destinationName: String, route: WalkingRoute, initialProgress: WalkingProgress, showTime: Bool = false) async throws {
        await end()
        wasApproachingTurn = false
        hasTriggeredArrival = false
        approachingStartDate = nil
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = WalkingActivityAttributes.ContentState(progress: initialProgress, showTime: showTime)
        _ = try Activity.request(
            attributes: WalkingActivityAttributes(destinationName: destinationName),
            content: ActivityContent(state: state, staleDate: .now.addingTimeInterval(120)),
            pushType: nil
        )
    }

    func update(_ progress: WalkingProgress, showTime: Bool) async {
        var effectiveProgress = progress

        // approaching 최소 8초 유지
        if progress.isApproachingTurn && approachingStartDate == nil {
            approachingStartDate = .now
        } else if !progress.isApproachingTurn, let start = approachingStartDate {
            if Date.now.timeIntervalSince(start) < approachingStateDistance {
                effectiveProgress = WalkingProgress(
                    remainingDistance: progress.remainingDistance,
                    distanceToNextManeuver: progress.distanceToNextManeuver,
                    nextManeuver: progress.nextManeuver,
                    isOffRoute: progress.isOffRoute,
                    isApproachingTurn: true,
                    estimatedArrival: progress.estimatedArrival
                )
            } else {
                approachingStartDate = nil
            }
        }

        let state = WalkingActivityAttributes.ContentState(progress: effectiveProgress, showTime: showTime)
        let content = ActivityContent(state: state, staleDate: .now.addingTimeInterval(120))

        let justEnteredApproach = state.isApproachingTurn && !wasApproachingTurn
        wasApproachingTurn = state.isApproachingTurn

        let isArriving = state.maneuver == .destination && effectiveProgress.isApproachingTurn

        for activity in Activity<WalkingActivityAttributes>.activities {
            if isArriving && !hasTriggeredArrival {
                hasTriggeredArrival = true
                await activity.update(content, alertConfiguration: AlertConfiguration(
                    title: "목적지 근처에 도착했어요",
                    body: "길 안내를 종료할게요",
                    sound: .default
                ))
                Task { @MainActor in
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    await activity.end(content, dismissalPolicy: .after(.now.addingTimeInterval(5)))
                }
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
}
