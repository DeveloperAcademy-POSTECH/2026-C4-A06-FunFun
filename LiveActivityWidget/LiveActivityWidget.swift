//  LiveActivityWidget.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct OpenAppIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "앱 열기"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult { .result() }
}

@main
struct LiveActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        WalkingLiveActivity()
    }
}

struct WalkingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkingActivityAttributes.self) { context in
            lockScreenView(context: context)
                .padding(24)
                .activityBackgroundTint(.black.opacity(0.88))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context: context)
                }
            } compactLeading: {
                compactTrailing(context: context)
            } compactTrailing: {
                compactLeading(context: context)
            } minimal: {
                compactMinimal(context: context)
            }
            .keylineTint(.blue)
        }
    }

    // MARK: - Compact 분기

    @ViewBuilder
    private func compactLeading(context: ActivityViewContext<WalkingActivityAttributes>) -> some View {
        switch DisplayMode(state: context.state) {
        case .offRoute:
            Text("\(context.state.remainingDistance)m")
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
        case .arriving:
            Image(systemName: "arrow.up").foregroundStyle(livePrimary)
        case .approaching:
            Image(systemName: context.state.maneuver.symbolName).foregroundStyle(livePrimary)
        case .cruising:
            Image(systemName: "arrow.up").foregroundStyle(livePrimary)
        }
    }

    @ViewBuilder
    private func compactTrailing(context: ActivityViewContext<WalkingActivityAttributes>) -> some View {
        switch DisplayMode(state: context.state) {
        case .offRoute:
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, iconWarning)
        case .arriving:
            Text(context.state.distanceToNextTurnText)
                .monospacedDigit()
                .foregroundStyle(livePrimary)
        case .approaching, .cruising:
            Text(context.state.distanceToNextTurnText)
                .monospacedDigit()
                .foregroundStyle(livePrimary)
        }
    }

    @ViewBuilder
    private func compactMinimal(context: ActivityViewContext<WalkingActivityAttributes>) -> some View {
        switch DisplayMode(state: context.state) {
        case .offRoute:
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, iconWarning)
        case .arriving:
            Image(systemName: "flag.checkered").foregroundStyle(.green)
        case .approaching:
            Image(systemName: context.state.maneuver.symbolName).foregroundStyle(.blue)
        case .cruising:
            Image(systemName: "figure.walk").foregroundStyle(.blue)
        }
    }

    // MARK: - Expanded 분기

    private enum DisplayMode {
        case offRoute       // 경로 이탈
        case arriving       // 목적지 도착 (maneuver == .destination && < 10m)
        case approaching    // turnType 10m 미만
        case cruising       // turnType 10m 이상 (직진 중)

        init(state: WalkingActivityAttributes.ContentState) {
            if state.isOffRoute {
                self = .offRoute
            } else if state.maneuver == .destination && state.isApproachingTurn {
                self = .arriving
            } else if state.isApproachingTurn {
                self = .approaching
            } else {
                self = .cruising
            }
        }
    }

    @ViewBuilder
    private func expandedBottom(context: ActivityViewContext<WalkingActivityAttributes>) -> some View {
        switch DisplayMode(state: context.state) {
        case .offRoute:
            VStack(spacing: 8) {
                HStack(alignment: .center) {
                    warningIcon
                    VStack(alignment: .leading, spacing: 4) {
                        Text("경로에서 벗어난 것 같아요")
                            .appTypography(.title2)
                        Text("현재 위치에서 재탐색할까요?")
                            .appTypography(.body2)
                            .foregroundStyle(Color(white: 0.5))
                    }
                    Spacer()
                    Text("\(context.state.remainingDistance)m")
                        .appTypography(.labelM)
                        .monospacedDigit()
                }
                HStack(spacing: 12) {
                    Button(intent: OpenAppIntent()) {
                        Text("앱으로 가기")
                            .appTypography(.labelL)
                            .foregroundStyle(livePrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .background(Color(white: 0.2), in: Capsule())
                }
            }
        case .arriving:
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("목적지 근처에 도착했어요")
                        .appTypography(.title2)
                    Text("길 안내를 종료할게요")
                        .appTypography(.body2)
                        .foregroundStyle(Color(white: 0.7))
                }
//                Button(intent: OpenAppIntent()) {
//                    Text("앱으로 가기")
//                        .appTypography(.labelL)
//                        .foregroundStyle(livePrimary)
//                        .frame(maxWidth: .infinity)
//                        .padding(.vertical, 12)
//                }
//                .buttonStyle(.plain)
//                .background(Color(red: 16.0/255, green: 31.0/255, blue: 23.0/255), in: Capsule())
            }
        case .approaching:
            // TODO: 10m 미만 Expanded 디자인
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.distanceToNextTurnText)
                        .appTypography(.labelL)
                        .foregroundStyle(livePrimary)
                    Spacer()
                    Text(context.state.landmarkName.map { "\($0)에서" } ?? " ")
                        .appTypography(.title2)
                    Text(context.state.maneuver.instruction)
                        .appTypography(.labelL)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: context.state.maneuver.symbolName)
                    .font(.system(size: 60, weight: .regular))
                    .foregroundStyle(livePrimary)
                    .frame(width: 78, height: 78)
            }
            .padding([.horizontal], 8)
        case .cruising:
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.distanceToNextTurnText)
                        .appTypography(.labelL)
                        .foregroundStyle(livePrimary)
                    Spacer()
                    Text(context.state.landmarkName.map { "\($0)까지" } ?? "다음 안내까지")
                        .appTypography(.title2)
                    Text("앞으로 가세요")
                        .appTypography(.labelL)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.up")
                    .font(.system(size: 60, weight: .regular))
                    .foregroundStyle(livePrimary)
                    .frame(width: 78, height: 78)
            }
            .padding([.horizontal], 8)
        }
    }

    // #00FF77 — Figma: live-activity/live-primary
    private let livePrimary = Color(red: 0, green: 1, blue: 119.0 / 255.0)
    // Icon-warning: RGB(1.0, 0.714, 0.098)
    private let iconWarning = Color(red: 1, green: 0.714, blue: 0.098)
    // Icon-warning-bg: RGB(1.0, 0.882, 0.627)
    private let iconWarningBg = Color(red: 1, green: 0.882, blue: 0.627)

    private var warningIcon: some View {
        ZStack {
            Circle()
                .fill(iconWarningBg)
                .frame(width: 44, height: 44)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, iconWarning)
        }
    }

    // MARK: - Lock Screen

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<WalkingActivityAttributes>) -> some View {
        switch DisplayMode(state: context.state) {
        
        case .approaching:
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 16) {
                    if let landmarkName = context.state.landmarkName {
                        Text("\(landmarkName)에서")
                            .appTypography(.captionM)
                            .foregroundStyle(Color.white)
                    }
                    Text(context.state.maneuver.instruction)
                        .appTypography(.title1)
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: context.state.maneuver.symbolName)
                    .font(.system(size: 60, weight: .regular))
                    .foregroundStyle(livePrimary)
                    .frame(width: 78, height: 78)
            }
            
        case .offRoute:
            HStack {
                warningIcon
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("경로를 벗어난 것 같아요")
                        .appTypography(.title1)
                        .foregroundStyle(Color.white)
                    Text("앱에서 지도를 확인하세요")
                        .appTypography(.body2)
                        .foregroundStyle(Color(white: 0.7))
                }
                Spacer()
            }
            .padding([.horizontal], 8)
        case .arriving:
            VStack(alignment: .leading, spacing: 4) {
                Text("목적지 근처에 도착했어요")
                    .appTypography(.title2)
                    .foregroundStyle(Color.white)
                Text("길 안내를 종료할게요")
                    .appTypography(.body2)
                    .foregroundStyle(Color(white: 0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .cruising:
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 2) {
                        Text(context.state.landmarkName.map { "\($0)까지" } ?? "다음 안내까지")
                            .appTypography(.captionM)
                            .foregroundStyle(Color.white)
                        Text(context.state.distanceToNextTurnText)
                            .appTypography(.captionM)
                            .foregroundStyle(Color.white)
                    }
                    Text("앞으로 가세요")
                        .appTypography(.title1)
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.up")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(livePrimary)
                    .frame(width: 78, height: 78)
            }
        }
    }

    private var stopWalkingButton: some View {
        Button(intent: StopWalkingIntent()) {
            Image(systemName: "xmark").frame(width: 32, height: 32)
        }
        .buttonStyle(.borderedProminent).buttonBorderShape(.circle).tint(.red)
        .accessibilityLabel("도보 안내 종료")
    }
}
