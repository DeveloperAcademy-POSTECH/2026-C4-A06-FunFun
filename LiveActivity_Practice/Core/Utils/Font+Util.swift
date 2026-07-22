//
//  Font+Util.swift
//  LiveActivity_Practice
//
//  Created by 조원경 on 7/21/26.


import SwiftUI
import UIKit

enum AppTypography {
    struct Style {
        let size: CGFloat
        let lineHeight: CGFloat
        let weight: PretendardWeight
        let relativeTo: Font.TextStyle
    }
}

extension AppTypography.Style {
    // MARK: - Headline

    static let headlineL = Self(
        size: 36,
        lineHeight: 45,
        weight: .bold,
        relativeTo: .largeTitle
    )

    static let headlineM = Self(
        size: 32,
        lineHeight: 40,
        weight: .bold,
        relativeTo: .largeTitle
    )

    static let headlineS = Self(
        size: 28,
        lineHeight: 35,
        weight: .bold,
        relativeTo: .title
    )

    // MARK: - Title

    static let title1 = Self(
        size: 24,
        lineHeight: 30,
        weight: .bold,
        relativeTo: .title2
    )

    static let title2 = Self(
        size: 20,
        lineHeight: 25,
        weight: .bold,
        relativeTo: .title3
    )

    static let title3 = Self(
        size: 18,
        lineHeight: 22.5,
        weight: .bold,
        relativeTo: .headline
    )

    // MARK: - Label

    static let labelL = Self(
        size: 16,
        lineHeight: 24,
        weight: .semiBold,
        relativeTo: .callout
    )

    static let labelM = Self(
        size: 14,
        lineHeight: 20,
        weight: .bold,
        relativeTo: .subheadline
    )

    static let labelS = Self(
        size: 12,
        lineHeight: 16,
        weight: .bold,
        relativeTo: .caption
    )

    // MARK: - Body

    static let body1 = Self(
        size: 16,
        lineHeight: 24,
        weight: .regular,
        relativeTo: .body
    )

    static let body2 = Self(
        size: 14,
        lineHeight: 20,
        weight: .regular,
        relativeTo: .subheadline
    )

    // MARK: - Caption

    static let captionL = Self(
        size: 16,
        lineHeight: 24,
        weight: .regular,
        relativeTo: .caption
    )

    static let captionM = Self(
        size: 14,
        lineHeight: 20,
        weight: .regular,
        relativeTo: .caption
    )

    static let captionS = Self(
        size: 12,
        lineHeight: 20,
        weight: .regular,
        relativeTo: .caption2
    )
}

enum PretendardWeight {
    case light
    case regular
    case semiBold
    case bold

    var fontName: String {
        switch self {
        case .light:
            "Pretendard-Light"
        case .regular:
            "Pretendard-Regular"
        case .semiBold:
            "Pretendard-SemiBold"
        case .bold:
            "Pretendard-Bold"
        }
    }

    var fallbackWeight: UIFont.Weight {
        switch self {
        case .light:
            .light
        case .regular:
            .regular
        case .semiBold:
            .semibold
        case .bold:
            .bold
        }
    }
}

private struct AppTypographyModifier: ViewModifier {
    let style: AppTypography.Style

    @ScaledMetric private var scaledSize: CGFloat
    @ScaledMetric private var scaledLineHeight: CGFloat

    init(style: AppTypography.Style) {
        self.style = style
        _scaledSize = ScaledMetric(
            wrappedValue: style.size,
            relativeTo: style.relativeTo
        )
        _scaledLineHeight = ScaledMetric(
            wrappedValue: style.lineHeight,
            relativeTo: style.relativeTo
        )
    }

    func body(content: Content) -> some View {
        let uiFont = makeFont()
        let lineSpacing = max(0, scaledLineHeight - uiFont.lineHeight)

        content
            .font(Font(uiFont))
            .lineSpacing(lineSpacing)
    }

    private func makeFont() -> UIFont {
        guard let font = UIFont(
            name: style.weight.fontName,
            size: scaledSize
        ) else {
            assertionFailure(
                "\(style.weight.fontName) 폰트가 등록되지 않았습니다."
            )

            return UIFont.systemFont(
                ofSize: scaledSize,
                weight: style.weight.fallbackWeight
            )
        }

        return font
    }
}

extension View {
    func appTypography(_ style: AppTypography.Style) -> some View {
        modifier(AppTypographyModifier(style: style))
    }
}
