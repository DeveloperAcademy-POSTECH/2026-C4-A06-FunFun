//  StopWalkingIntent.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import ActivityKit
import AppIntents

struct StopWalkingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "도보 안내 종료"
    static var description = IntentDescription("진행 중인 도보 안내를 종료합니다.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        for activity in Activity<WalkingActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}
