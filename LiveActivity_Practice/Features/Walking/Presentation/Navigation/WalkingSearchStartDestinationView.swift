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
                .foregroundStyle(.gray)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            }
        }
        .padding([.horizontal], 12)
        .padding([.vertical], 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 29))
    }
}

#Preview {
    WalkingSearchStartDestinationView()
}
