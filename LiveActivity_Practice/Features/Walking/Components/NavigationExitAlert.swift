//
//  NavigationExitAlert.swift
//  LiveActivity_Practice
//

import SwiftUI

/// 경로 안내 종료 여부를 확인하는 커스텀 Alert입니다.
struct NavigationExitAlert: View {
    let onContinue: () -> Void
    let onExit: () -> Void

    /// - Parameters:
    ///   - onContinue: `계속 안내` 버튼을 눌렀을 때 실행할 동작입니다.
    ///   - onExit: `종료` 버튼을 눌렀을 때 실행할 동작입니다.
    init(
        onContinue: @escaping () -> Void,
        onExit: @escaping () -> Void
    ) {
        self.onContinue = onContinue
        self.onExit = onExit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("경로 안내를 종료할까요?")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color("Colors/text-text-1"))
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 16) {
                alertButton(
                    title: "계속 안내",
                    foregroundStyle: Color("Colors/text-text-1"),
                    action: onContinue
                )

                alertButton(
                    title: "종료",
                    foregroundStyle: .red,
                    action: onExit
                )
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 40, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .stroke(.white.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        .accessibilityElement(children: .contain)
    }

    private func alertButton(
        title: String,
        foregroundStyle: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(foregroundStyle)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.black.opacity(0.07), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

#Preview("Navigation Exit Alert") {
    ZStack {
        Color.green.opacity(0.2)
            .ignoresSafeArea()

        NavigationExitAlert(
            onContinue: {},
            onExit: {}
        )
        .padding(.horizontal, 16)
    }
}
