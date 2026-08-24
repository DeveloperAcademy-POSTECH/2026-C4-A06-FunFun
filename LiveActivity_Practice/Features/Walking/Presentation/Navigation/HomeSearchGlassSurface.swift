//
//  HomeSearchGlassSurface.swift
//  LiveActivity_Practice
//

import SwiftUI

struct HomeSearchGlassSurface: ViewModifier {
    private let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

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
