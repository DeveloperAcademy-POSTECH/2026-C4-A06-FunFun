//  NavigationSession.swift
//  LiveActivity_Practice

import Foundation

@Observable
final class NavigationSession {

    private(set) var isActive = false
    private(set) var isArrived = false
    private let activityManager: WalkingLiveActivityManager

    init(activityManager: WalkingLiveActivityManager? = nil) {
        self.activityManager = activityManager ?? WalkingLiveActivityManager()
    }

    func start(
        destinationName: String,
        route: WalkingRoute,
        initialProgress: WalkingProgress,
        showTime: Bool
    ) async throws {
        try await activityManager.start(
            destinationName: destinationName,
            route: route,
            initialProgress: initialProgress,
            showTime: showTime
        )
        isActive = true
    }

    func stop() async {
        await activityManager.end()
        isActive = false
        isArrived = false
    }

    func updateActivity(_ progress: WalkingProgress, showTime: Bool) async {
        await activityManager.update(progress, showTime: showTime)
    }

    func markArrived() {
        isArrived = true
    }
}
