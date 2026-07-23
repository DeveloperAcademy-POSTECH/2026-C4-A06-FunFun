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
        toolbarContent
        .frame(maxWidth: .infinity)
    }

    private var toolbarContent: some View {
        HStack(spacing: 20) {
            toolbarButton(
                systemName: "chevron.left",
                accessibilityLabel: "뒤로가기",
                action: onBack
            )

            Spacer()

            toolbarButton(
                systemName: "gearshape",
                accessibilityLabel: "설정",
                action: onSettings
            )
        }
    }

    private var displayDestinationName: String {
        destinationName.isEmpty ? "목적지" : destinationName
    }

    @ViewBuilder
    private func toolbarButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                toolbarButtonLabel(systemName: systemName)
            }
            .buttonStyle(.plain)
            .buttonBorderShape(.circle)
            .accessibilityLabel(accessibilityLabel)
            .glassEffect(.regular, in: Circle())
        } else {
            Button(action: action) {
                toolbarButtonLabel(systemName: systemName)
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

    private func toolbarButtonLabel(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(Color("Colors/text-text-1"))
            .frame(width: 48, height: 48)
    }
}

#Preview("Custom Top Toolbar") {
    ZStack(alignment: .top) {
        LinearGradient(
            colors: [
                .blue,
                .purple,
                .orange,
                .green
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
