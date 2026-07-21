//
//  CustomTopToolbar.swift
//  LiveActivity_Practice
//

import SwiftUI

/// 뒤로가기, 목적지, 설정 버튼을 표시하는 상단 툴바입니다.
struct CustomTopToolbar: View {
    let destinationName: String
    let onBack: () -> Void
    let onSettings: () -> Void

    /// - Parameters:
    ///   - destinationName: 중앙 영역에 표시할 목적지 이름입니다.
    ///   - onBack: 뒤로가기 버튼을 눌렀을 때 실행할 동작입니다.
    ///   - onSettings: 설정 버튼을 눌렀을 때 실행할 동작입니다.
    init(
        destinationName: String,
        onBack: @escaping () -> Void,
        onSettings: @escaping () -> Void
    ) {
        self.destinationName = destinationName
        self.onBack = onBack
        self.onSettings = onSettings
    }

    var body: some View {
        HStack(spacing: 16) {
            toolbarButton(
                systemName: "chevron.left",
                accessibilityLabel: "뒤로가기",
                action: onBack
            )

            Text(displayDestinationName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color("Colors/Gray-gray-700"))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .padding(.horizontal, 20)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.5), lineWidth: 1)
                }
                .accessibilityLabel("목적지 " + displayDestinationName)

            toolbarButton(
                systemName: "gearshape",
                accessibilityLabel: "설정",
                action: onSettings
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var displayDestinationName: String {
        destinationName.isEmpty ? "목적지" : destinationName
    }

    private func toolbarButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(Color("Colors/text-text-1"))
                .frame(width: 50, height: 50)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.5), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("Custom Top Toolbar") {
    ZStack(alignment: .top) {
        Color.green.opacity(0.7)
            .ignoresSafeArea()

        CustomTopToolbar(
            destinationName: "담박집",
            onBack: {},
            onSettings: {}
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}
