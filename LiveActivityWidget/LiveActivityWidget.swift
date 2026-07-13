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
                    Image(systemName: context.state.maneuver.symbolName)
                        .font(.title2).foregroundStyle(.blue)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.distanceToNextTurn)m").monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
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
            } compactLeading: {
                Image(systemName: context.state.maneuver.symbolName).foregroundStyle(.blue)
            } compactTrailing: {
                Text("\(context.state.distanceToNextTurn)m").monospacedDigit()
            } minimal: {
                Image(systemName: "figure.walk").foregroundStyle(.blue)
            }
            .keylineTint(.blue)
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
