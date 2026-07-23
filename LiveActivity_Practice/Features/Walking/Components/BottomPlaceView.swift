//
//  BottomPlaceView.swift
//  LiveActivity_Practice
//

import SwiftUI

/// 경로 검색 전에 선택한 목적지 정보를 확인하는 하단 카드입니다.
struct BottomPlaceView: View {
    let place: PlaceSearchResult
    let isLoading: Bool
    let onConfirm: () -> Void

    /// - Parameters:
    ///   - place: 표시할 장소 정보입니다.
    ///   - isLoading: 경로 검색 진행 여부입니다.
    ///   - onConfirm: 도착지 설정 버튼을 눌렀을 때 실행할 동작입니다.
    init(
        place: PlaceSearchResult,
        isLoading: Bool,
        onConfirm: @escaping () -> Void
    ) {
        self.place = place
        self.isLoading = isLoading
        self.onConfirm = onConfirm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(place.name)
                        .appTypography(.title1)
                        .foregroundStyle(Color("Colors/text-text-1"))
                        .lineLimit(1)

                    Text(place.category)
                        .appTypography(.labelL)
                        .foregroundStyle(Color("Colors/Gray-gray-500"))
                        .lineLimit(1)
                }

                if !place.address.isEmpty {
                    Text(place.address)
                        .appTypography(.captionL)
                        .foregroundStyle(Color("Colors/Gray-gray-500"))
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 8)

            Button(action: onConfirm) {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(Color("Colors/brand-primary"))
                    } else {
                        Text("도착지로 설정")
                            .appTypography(.labelL)
                    }
                }
                .foregroundStyle(Color("Colors/brand-primary"))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    Color("Colors/brand-opacity"),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 21)
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .modifier(BottomPlaceGlassSurface())
        .shadow(color: .black.opacity(0.08), radius: 18, y: 5)
        .accessibilityElement(children: .contain)
    }
}

private struct BottomPlaceGlassSurface: ViewModifier {
    private let shape = RoundedRectangle(cornerRadius: 40, style: .continuous)

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background {
                    Color("Colors/Gray-gray-500")
                        .opacity(0.1)
                        .background(.ultraThinMaterial)
                }
                .clipShape(shape)
                .overlay {
                    shape.stroke(.white.opacity(0.5), lineWidth: 1)
                }
        }
    }
}

#Preview("목적지 확인") {
    ZStack(alignment: .bottom) {
        LinearGradient(
            colors: [
                Color("Colors/Blue-blue-200"),
                Color("Colors/Green-green-400").opacity(0.65),
                Color("Colors/Gray-gray-100")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        BottomPlaceView(
            place: PlaceSearchResult(
                id: "preview-seven-eleven",
                name: "세븐일레븐",
                category: "편의점",
                address: "경북 포항시 남구 효성로15번길 24(효자동)",
                coordinate: Coordinate(
                    latitude: 36.0190,
                    longitude: 129.3435
                )
            ),
            isLoading: false,
            onConfirm: {}
        )
    }
    .preferredColorScheme(.light)
}
