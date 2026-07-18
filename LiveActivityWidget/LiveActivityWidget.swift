//  LiveActivityWidget.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import ActivityKit
import SwiftUI
import WidgetKit

@main
struct LiveActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        WalkingLiveActivity()
    }
}

struct WalkingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkingActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(context.attributes.destinationName, systemImage: "figure.walk")
                        .font(.headline)
                    Spacer()
                    Text(timerInterval: Date.now...context.state.estimatedArrival, countsDown: true)
                        .monospacedDigit().font(.headline)
                }
                if context.state.isOffRoute {
                    Label("경로를 벗어났습니다", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                } else {
                    Label(context.state.instruction, systemImage: context.state.maneuver.symbolName)
                        .lineLimit(2)
                }
                HStack {
                    Text("다음 안내 \(context.state.distanceToNextTurn)m")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    stopWalkingButton
                }
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.88))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context: context)
                }
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
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
        case .arriving:
            Image(systemName: "arrow.up.circle.fill").foregroundStyle(.blue)
        case .approaching:
            Image(systemName: context.state.maneuver.symbolName).foregroundStyle(.blue)
        case .cruising:
            Image(systemName: "arrow.up.circle.fill").foregroundStyle(.blue)
        }
    }

    @ViewBuilder
    private func compactTrailing(context: ActivityViewContext<WalkingActivityAttributes>) -> some View {
        switch DisplayMode(state: context.state) {
        case .offRoute:
            Text("이탈").foregroundStyle(.yellow)
        case .arriving:
            distanceOrTimeText(context.state).foregroundStyle(.green)
        case .approaching, .cruising:
            distanceOrTimeText(context.state)
        }
    }

    private func distanceOrTimeText(_ state: WalkingActivityAttributes.ContentState) -> Text {
        if state.showTimeInsteadOfDistance {
            let minutes = max(1, Int(ceil(Double(state.distanceToNextTurn) / 75.0)))
            return Text("\(minutes)분").monospacedDigit()
        } else {
            return Text("\(state.distanceToNextTurn)m").monospacedDigit()
        }
    }

    @ViewBuilder
    private func compactMinimal(context: ActivityViewContext<WalkingActivityAttributes>) -> some View {
        switch DisplayMode(state: context.state) {
        case .offRoute:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
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
            } else if state.maneuver == .destination && state.distanceToNextTurn < 10 {
                self = .arriving
            } else if state.isApproachingTurn {
                self = .approaching
            } else {
                self = .cruising
            }
        }
    }

    @ViewBuilder
    private func expandedLeading(context: ActivityViewContext<WalkingActivityAttributes>) -> some View {
        switch DisplayMode(state: context.state) {
        case .offRoute:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2).foregroundStyle(.yellow)
        case .arriving:
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2).foregroundStyle(.blue)
        case .approaching:
            Image(systemName: context.state.maneuver.symbolName)
                .font(.title2).foregroundStyle(.blue)
        case .cruising:
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2).foregroundStyle(.blue)
        }
    }

    @ViewBuilder
    private func expandedTrailing(context: ActivityViewContext<WalkingActivityAttributes>) -> some View {
        switch DisplayMode(state: context.state) {
        case .offRoute:
            Text("이탈").foregroundStyle(.yellow)
        case .arriving:
            Text("\(context.state.distanceToNextTurn)m")
                .monospacedDigit().foregroundStyle(.green)
        case .approaching, .cruising:
            Text("\(context.state.distanceToNextTurn)m").monospacedDigit()
        }
    }

    @ViewBuilder
    private func expandedBottom(context: ActivityViewContext<WalkingActivityAttributes>) -> some View {
        switch DisplayMode(state: context.state) {
        case .offRoute:
            // TODO: 경로 이탈 Expanded 디자인
            HStack {
                VStack(alignment: .leading) {
                    Text("경로를 벗어났습니다")
                        .font(.subheadline.weight(.bold))
                    Text("남은 거리 \(context.state.remainingDistance)m")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                stopWalkingButton
            }
        case .arriving:
            // TODO: 도착 Expanded 디자인
            HStack {
                VStack(alignment: .leading) {
                    Text("목적지에 거의 도착했습니다")
                        .font(.subheadline.weight(.bold))
                    Text(context.attributes.destinationName)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                stopWalkingButton
            }
        case .approaching:
            // TODO: 10m 미만 Expanded 디자인
            HStack {
                VStack(alignment: .leading) {
                    Text(context.state.instruction).lineLimit(2)
                    Text("\(context.state.distanceToNextTurn)m 앞")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                stopWalkingButton
            }
        case .cruising:
            // TODO: 10m 이상 Expanded 디자인
            HStack {
                VStack(alignment: .leading) {
                    Text(context.state.instruction).lineLimit(2)
                    Text("남은 거리 \(context.state.remainingDistance)m")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                stopWalkingButton
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
