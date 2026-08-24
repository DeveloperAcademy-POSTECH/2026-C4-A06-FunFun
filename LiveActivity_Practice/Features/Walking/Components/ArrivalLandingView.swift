//  ArrivalLandingView.swift
//  LiveActivity_Practice

import SwiftUI

struct ArrivalLandingView: View {
    let destinationName: String

    var body: some View {
        HStack(spacing: 20) {
            Image("ic-arrived")
                .resizable()
                .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                Text(destinationName + " 근처에 도착")
                    .appTypography(.title3)
                    .foregroundStyle(Color("Colors/text-text-1"))
                Text("5초 뒤에 길안내가 종료됩니다")
                    .appTypography(.captionM)
                    .foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.92, blue: 0.90),
                    Color(red: 0.96, green: 0.96, blue: 0.96)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 80)
        )
        .padding(.horizontal, 16)
    }
}
