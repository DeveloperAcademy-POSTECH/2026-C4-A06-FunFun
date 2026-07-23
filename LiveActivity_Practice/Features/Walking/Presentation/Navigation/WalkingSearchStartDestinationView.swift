//
//  WalkingSearchStartDestinationView.swift
//  LiveActivity_Practice
//
//  Created by Seungjun Lee on 7/23/26.
//

import SwiftUI

struct WalkingSearchStartDestinationView: View {
    var destinationName: String = ""
    var onSearchTapped: () -> Void = {}

    var body: some View {
        VStack {
            HStack(spacing: 11) {
                Image(systemName: "location.circle.fill")
                    .resizable()
                    .frame(width: 27, height: 26)
                    .foregroundStyle(Color(String(stringLiteral: "Colors/brand-primary")))
                Text("내 위치")
                    .appTypography(.body1)
                    .foregroundStyle(Color(String(stringLiteral: "Colors/text-text-2")))
                Spacer()
            }
            .padding(12)
            Button {
                onSearchTapped()
            } label: {
                HStack(spacing: 11) {
                    Image("ic-graphic-destination")
                        .resizable()
                        .frame(width: 20, height: 27)
                    Text(destinationName.isEmpty ? "목적지" : destinationName)
                        .foregroundStyle(destinationName.isEmpty ? .gray : .black)
                        .appTypography(.labelL)
                    Spacer()
                }
                .padding([.horizontal], 16)
                .padding([.vertical], 12)
                .background(
                    Color.black.opacity(0.08),
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
        }
        .padding([.horizontal], 12)
        .padding([.vertical], 8)
        .modifier(WalkingSearchGlassSurface())
    }
}

private struct WalkingSearchGlassSurface: ViewModifier {
    private let shape = RoundedRectangle(
        cornerRadius: 29,
        style: .continuous
    )

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(.white.opacity(0.5), lineWidth: 1)
                }
        }
    }
}

#Preview {
    WalkingSearchStartDestinationView()
}
