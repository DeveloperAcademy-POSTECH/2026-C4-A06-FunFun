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
    let mapHeading: CLLocationDirection?
    let indicatorPosition: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            if let indicator = indicator(in: proxy) {
                directionalEdgeGradient(
                    color: Color("Colors/Green-green-400"),
                    indicator: indicator,
                    size: proxy.size
                )
                    .animation(.easeOut(duration: 0.18), value: indicator)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func directionalEdgeGradient(
        color: Color,
        indicator: EdgeIndicator,
        size: CGSize
    ) -> some View {
        let startPoint = UnitPoint(
            x: indicator.position.x / size.width,
            y: indicator.position.y / size.height
        )
        let fadeDistance: CGFloat = 150
        let endPoint = UnitPoint(
            x: (indicator.position.x - indicator.directionX * fadeDistance) / size.width,
            y: (indicator.position.y - indicator.directionY * fadeDistance) / size.height
        )

        return LinearGradient(
            stops: [
                .init(color: color.opacity(0.85), location: 0),
                .init(color: color.opacity(0.42), location: 0.35),
                .init(color: .clear, location: 1)
            ],
            startPoint: startPoint,
            endPoint: endPoint
        )
            .mask {
                EdgeBandShape(thickness: 110, cornerRadius: 52)
                    .fill(style: FillStyle(eoFill: true))
                    .mask {
                        RadialGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white.opacity(0.8), location: 0.45),
                                .init(color: .clear, location: 1)
                            ],
                            center: startPoint,
                            startRadius: 0,
                            endRadius: 170
                        )
                    }
            }
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

private struct EdgeIndicator: Equatable {
    let position: CGPoint
    let directionX: CGFloat
    let directionY: CGFloat
}

private struct EdgeBandShape: Shape {
    let thickness: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: cornerRadius)
        let innerRect = rect.insetBy(dx: thickness, dy: thickness)

        path.addRoundedRect(
            in: innerRect,
            cornerSize: CGSize(
                width: max(0, cornerRadius - thickness),
                height: max(0, cornerRadius - thickness)
            )
        )

        return path
    }
}
