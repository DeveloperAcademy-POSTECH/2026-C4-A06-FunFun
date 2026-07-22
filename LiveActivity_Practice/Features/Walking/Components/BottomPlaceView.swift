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
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(place.name)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(Color("Colors/text-text-1"))
                        .lineLimit(1)

                    Text(place.category)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color("Colors/Gray-gray-500"))
                        .lineLimit(1)
                }

                if !place.address.isEmpty {
                    Text(place.address)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color("Colors/Gray-gray-500"))
                        .lineLimit(2)
                }
            }

            Button(action: onConfirm) {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.blue)
                    } else {
                        Text("도착지로 설정")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Color.blue.opacity(0.17), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .padding(.horizontal, 24)
        .padding(.top, 34)
        .padding(.bottom, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 38, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .stroke(.white.opacity(0.5), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.1), radius: 18, y: 6)
    }
}
