//  MockLocationRemoteView.swift
//  LiveActivity_Practice
//
//  디버깅용 위치 리모콘. 실내에서 사용자의 위치를 임의로 조종한다.
//

import SwiftUI

struct MockLocationRemoteView: View {

    let controller: MockLocationController
    var onRecenter: () -> Void
    var onClose: () -> Void

    @State private var isExpanded = true
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if isExpanded {
                statusRow
                directionPad
                actionRow
                sliders
            }
        }
        .padding(12)
        .frame(width: isExpanded ? 220 : 150)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.orange.opacity(0.7), lineWidth: 1)
        }
        .shadow(radius: 10)
        .offset(offset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in lastOffset = offset }
        )
    }

    // MARK: - 헤더

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 13))
                .foregroundStyle(.orange)
            Text("위치 리모콘")
                .font(.system(size: 13, weight: .bold))
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "리모콘 접기" : "리모콘 펼치기")

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("리모콘 끄기")
        }
    }

    private var statusRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(controller.coordinateText)
                .font(.system(size: 11, design: .monospaced))
            Text("방위 \(Int(controller.heading))°")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 방향 패드

    private var directionPad: some View {
        VStack(spacing: 6) {
            padButton(systemName: "arrow.up", label: "전진", action: controller.moveForward)

            HStack(spacing: 6) {
                padButton(systemName: "arrow.counterclockwise", label: "좌회전", action: controller.turnLeft)
                Button(action: controller.snapToRoute) {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 15, weight: .bold))
                        .rotationEffect(.degrees(controller.heading))
                        .frame(width: 46, height: 46)
                        .background(Color.orange.opacity(0.18), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("경로 위로 스냅")
                padButton(systemName: "arrow.clockwise", label: "우회전", action: controller.turnRight)
            }

            padButton(systemName: "arrow.down", label: "후진", action: controller.moveBackward)
        }
        .frame(maxWidth: .infinity)
    }

    private func padButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        HoldRepeatButton(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 46, height: 46)
                .background(Color.primary.opacity(0.08), in: Circle())
        }
        .accessibilityLabel(label)
    }

    // MARK: - 동작 버튼

    private var actionRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Button(action: controller.toggleAutoWalk) {
                    Label(
                        controller.isAutoWalking ? "정지" : "자동 이동",
                        systemImage: controller.isAutoWalking ? "pause.fill" : "play.fill"
                    )
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        (controller.isAutoWalking ? Color.red : Color.orange).opacity(0.2),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                compactButton("경로 시작", systemImage: "flag.fill", action: controller.moveToRouteStart)
                compactButton("카메라", systemImage: "dot.scope", action: onRecenter)
            }

            Toggle(isOn: Binding(
                get: { controller.followsRoute },
                set: { controller.followsRoute = $0 }
            )) {
                Text("경로 따라 이동")
                    .font(.system(size: 12))
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
    }

    private func compactButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 설정 슬라이더

    private var sliders: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("한 번에 \(Int(controller.stepDistance))m")
                .font(.system(size: 11))
            Slider(
                value: Binding(get: { controller.stepDistance }, set: { controller.stepDistance = $0 }),
                in: 1...50,
                step: 1
            )
            .controlSize(.mini)

            Text(String(format: "속도 %.1fm/s", controller.speed))
                .font(.system(size: 11))
            Slider(
                value: Binding(get: { controller.speed }, set: { controller.speed = $0 }),
                in: 0.5...20,
                step: 0.5
            )
            .controlSize(.mini)
        }
    }
}

/// 누르고 있는 동안 반복 실행되는 버튼
private struct HoldRepeatButton<Label: View>: View {

    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var timer: Timer?
    @State private var isPressed = false

    var body: some View {
        label()
            .foregroundStyle(Color.primary)
            .scaleEffect(isPressed ? 0.92 : 1)
            .contentShape(Circle())
            .animation(.easeOut(duration: 0.1), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        action()
                        startRepeating()
                    }
                    .onEnded { _ in
                        isPressed = false
                        stopRepeating()
                    }
            )
            .onDisappear(perform: stopRepeating)
    }

    private func startRepeating() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            Task { @MainActor in action() }
        }
    }

    private func stopRepeating() {
        timer?.invalidate()
        timer = nil
    }
}
