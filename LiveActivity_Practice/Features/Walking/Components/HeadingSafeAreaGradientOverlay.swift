//  HeadingSafeAreaGradientOverlay.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import CoreLocation
import SwiftUI

/// 지도 회전을 반영한 인디케이터 방향의 화면 가장자리에서 안쪽으로 글로우를 표시한다.
struct HeadingSafeAreaGradientOverlay: View {
    let heading: CLLocationDirection?
    let navigationBearing: CLLocationDirection?
    let mapHeading: CLLocationDirection?
    let indicatorPosition: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            if let indicator = indicator(in: proxy) {
                BloomingEdgeGradient(
                    alignedColor: Color("Colors/Green-green-400"),
                    misalignedColor: Color("Colors/Yellow-yellow-500"),
                    indicator: indicator,
                    heading: heading,
                    navigationBearing: navigationBearing,
                    size: proxy.size
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func indicator(in proxy: GeometryProxy) -> EdgeIndicator? {
        guard let heading, heading >= 0 else { return nil }

        let bounds = CGRect(origin: .zero, size: proxy.size)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let screenHeading = (heading - (mapHeading ?? 0) + 360)
            .truncatingRemainder(dividingBy: 360)
        let radians = screenHeading * .pi / 180
        let directionX = sin(radians)
        let directionY = -cos(radians)
        let origin = indicatorPosition ?? CGPoint(x: bounds.midX, y: bounds.midY)
        guard origin.x >= bounds.minX,
              origin.x <= bounds.maxX,
              origin.y >= bounds.minY,
              origin.y <= bounds.maxY else { return nil }

        let horizontalDistance: CGFloat
        if directionX > 0.0001 {
            horizontalDistance = (bounds.maxX - origin.x) / directionX
        } else if directionX < -0.0001 {
            horizontalDistance = (bounds.minX - origin.x) / directionX
        } else {
            horizontalDistance = .greatestFiniteMagnitude
        }

        let verticalDistance: CGFloat
        if directionY > 0.0001 {
            verticalDistance = (bounds.maxY - origin.y) / directionY
        } else if directionY < -0.0001 {
            verticalDistance = (bounds.minY - origin.y) / directionY
        } else {
            verticalDistance = .greatestFiniteMagnitude
        }

        let distance = min(horizontalDistance, verticalDistance)
        guard distance.isFinite, distance >= 0 else { return nil }

        return EdgeIndicator(
            position: CGPoint(
                x: min(bounds.maxX, max(bounds.minX, origin.x + directionX * distance)),
                y: min(bounds.maxY, max(bounds.minY, origin.y + directionY * distance))
            ),
            directionX: directionX,
            directionY: directionY
        )
    }
}

private struct BloomingEdgeGradient: View {
    let alignedColor: Color
    let misalignedColor: Color
    let indicator: EdgeIndicator
    let heading: CLLocationDirection?
    let navigationBearing: CLLocationDirection?
    let size: CGSize

    @State private var displayedIndicator: EdgeIndicator?
    @State private var alignmentState: Bool?

    var body: some View {
        ZStack {
            if let displayedIndicator {
                DirectionalEdgeGradient(
                    color: isDirectionAligned ? alignedColor : misalignedColor,
                    indicator: displayedIndicator,
                    size: size
                )
                .animation(.easeOut(duration: 0.2), value: isDirectionAligned)
            }
        }
        .onAppear {
            displayedIndicator = indicator
            updateAlignment()
        }
        .onChange(of: indicator) { _, newIndicator in
            guard shouldUpdatePosition(for: newIndicator) else { return }

            displayedIndicator = newIndicator
        }
        .onChange(of: heading) {
            updateAlignment()
        }
        .onChange(of: navigationBearing) {
            updateAlignment()
        }
    }

    private var isDirectionAligned: Bool {
        alignmentState ?? calculatedAlignment(threshold: 20)
    }

    private func shouldUpdatePosition(for newIndicator: EdgeIndicator) -> Bool {
        guard let displayedIndicator else { return true }

        let deltaX = newIndicator.position.x - displayedIndicator.position.x
        let deltaY = newIndicator.position.y - displayedIndicator.position.y
        let regenerationDistance: CGFloat = 28
        return deltaX * deltaX + deltaY * deltaY
            >= regenerationDistance * regenerationDistance
    }

    private func updateAlignment() {
        let threshold: CLLocationDirection = alignmentState == true ? 30 : 20
        alignmentState = calculatedAlignment(threshold: threshold)
    }

    private func calculatedAlignment(threshold: CLLocationDirection) -> Bool {
        guard let heading,
              heading >= 0,
              heading.isFinite,
              let navigationBearing,
              navigationBearing >= 0,
              navigationBearing.isFinite else { return false }

        let difference = abs(
            (heading - navigationBearing + 540)
                .truncatingRemainder(dividingBy: 360) - 180
        )
        return difference <= threshold
    }
}

private struct DirectionalEdgeGradient: View {
    let color: Color
    let indicator: EdgeIndicator
    let size: CGSize

    var body: some View {
        let startPoint = UnitPoint(
            x: indicator.position.x / size.width,
            y: indicator.position.y / size.height
        )
        let fadeDistance: CGFloat = 240
        let endPoint = UnitPoint(
            x: (indicator.position.x - indicator.directionX * fadeDistance) / size.width,
            y: (indicator.position.y - indicator.directionY * fadeDistance) / size.height
        )
        let horizontalScale = 1 + 0.4 * abs(indicator.directionY)
        let verticalScale = 1 + 0.4 * abs(indicator.directionX)

        LinearGradient(
            stops: [
                .init(color: color.opacity(0.85), location: 0),
                .init(color: color.opacity(0.42), location: 0.35),
                .init(color: .clear, location: 1)
            ],
            startPoint: startPoint,
            endPoint: endPoint
        )
        .mask {
            RadialGradient(
                stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white.opacity(0.55), location: 0.3),
                    .init(color: .white.opacity(0.18), location: 0.7),
                    .init(color: .clear, location: 1)
                ],
                center: startPoint,
                startRadius: 0,
                endRadius: 260
            )
            .scaleEffect(
                x: horizontalScale,
                y: verticalScale,
                anchor: startPoint
            )
        }
        .modifier(GradientBloomModifier(anchor: startPoint))
    }
}

private struct GradientBloomModifier: ViewModifier {
    let anchor: UnitPoint

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.7, anchor: anchor)
            .onAppear {
                withAnimation(.easeOut(duration: 0.35)) {
                    isVisible = true
                }
            }
    }
}

private struct EdgeIndicator: Equatable {
    let position: CGPoint
    let directionX: CGFloat
    let directionY: CGFloat
}
