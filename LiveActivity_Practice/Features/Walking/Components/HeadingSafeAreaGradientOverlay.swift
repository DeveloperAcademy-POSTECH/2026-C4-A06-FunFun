//  HeadingSafeAreaGradientOverlay.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import CoreLocation
import SwiftUI

/// `CLHeading`이 가리키는 실제 방위의 safe area 경계에만 글로우를 표시한다.
/// 화면의 위쪽이 기기가 향하는 전방이므로, 북쪽은 상단·동쪽은 오른쪽에 나타난다.
struct HeadingSafeAreaGradientOverlay: View {
    let heading: CLLocationDirection?

    var body: some View {
        GeometryReader { proxy in
            if let indicator = indicator(in: proxy) {
                edgeGradient(for: indicator)
                    .position(indicator.position)
                    .animation(.easeOut(duration: 0.18), value: indicator)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func edgeGradient(for indicator: EdgeIndicator) -> some View {
        switch indicator.edge {
        case .top:
            verticalGradient(from: .top)
                .frame(width: indicator.length, height: indicator.depth)
        case .bottom:
            verticalGradient(from: .bottom)
                .frame(width: indicator.length, height: indicator.depth)
        case .leading:
            horizontalGradient(from: .leading)
                .frame(width: indicator.depth, height: indicator.length)
        case .trailing:
            horizontalGradient(from: .trailing)
                .frame(width: indicator.depth, height: indicator.length)
        }
    }

    private func verticalGradient(from edge: VerticalEdge) -> some View {
        LinearGradient(
            colors: [.red.opacity(0.78), .red.opacity(0.26), .clear],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
        .mask(horizontalFalloff)
    }

    private func horizontalGradient(from edge: HorizontalEdge) -> some View {
        LinearGradient(
            colors: [.red.opacity(0.78), .red.opacity(0.26), .clear],
            startPoint: edge == .leading ? .leading : .trailing,
            endPoint: edge == .leading ? .trailing : .leading
        )
        .mask(verticalFalloff)
    }

    private var horizontalFalloff: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.22),
                .init(color: .black, location: 0.78),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var verticalFalloff: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.22),
                .init(color: .black, location: 0.78),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func indicator(in proxy: GeometryProxy) -> EdgeIndicator? {
        guard let heading, heading >= 0 else { return nil }

        let safeArea = CGRect(
            x: proxy.safeAreaInsets.leading,
            y: proxy.safeAreaInsets.top,
            width: proxy.size.width - proxy.safeAreaInsets.leading - proxy.safeAreaInsets.trailing,
            height: proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom
        )
        guard safeArea.width > 0, safeArea.height > 0 else { return nil }

        let radians = heading.truncatingRemainder(dividingBy: 360) * .pi / 180
        let directionX = sin(radians)
        let directionY = -cos(radians)
        let center = CGPoint(x: safeArea.midX, y: safeArea.midY)
        let horizontalDistance = safeArea.width / 2 / max(abs(directionX), 0.0001)
        let verticalDistance = safeArea.height / 2 / max(abs(directionY), 0.0001)
        let depth: CGFloat = 84
        let length = min(220, max(120, min(safeArea.width, safeArea.height) * 0.55))

        if verticalDistance <= horizontalDistance {
            let isTop = directionY < 0
            return EdgeIndicator(
                edge: isTop ? .top : .bottom,
                position: CGPoint(
                    x: center.x + directionX * verticalDistance,
                    y: isTop ? safeArea.minY + depth / 2 : safeArea.maxY - depth / 2
                ),
                length: length,
                depth: depth
            )
        } else {
            let isLeading = directionX < 0
            return EdgeIndicator(
                edge: isLeading ? .leading : .trailing,
                position: CGPoint(
                    x: isLeading ? safeArea.minX + depth / 2 : safeArea.maxX - depth / 2,
                    y: center.y + directionY * horizontalDistance
                ),
                length: length,
                depth: depth
            )
        }
    }
}

private struct EdgeIndicator: Equatable {
    enum Edge: Equatable { case top, bottom, leading, trailing }

    let edge: Edge
    let position: CGPoint
    let length: CGFloat
    let depth: CGFloat
}

private enum VerticalEdge: Equatable { case top, bottom }
private enum HorizontalEdge: Equatable { case leading, trailing }
