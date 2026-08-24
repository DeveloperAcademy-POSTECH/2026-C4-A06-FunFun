//  LandmarkBubbleView.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import UIKit

final class LandmarkBubbleView: UIView {
    static let preferredSize = CGSize(width: 132, height: 48)

    enum Placement: String {
        /// 랜드마크를 기준으로 말풍선 본문이 펼쳐지는 방향
        case left
        case right

        var anchor: CGPoint {
            switch self {
            case .left:
                CGPoint(x: 1, y: 0.5)
            case .right:
                CGPoint(x: 0, y: 0.5)
            }
        }
    }

    private let indexLabel = UILabel()
    private let nameLabel = UILabel()
    private let bubbleLayer = CAShapeLayer()
    private let bodyHeight: CGFloat = 38
    private let tailLength: CGFloat = 9
    private let accentColor: UIColor
    private let placement: Placement

    init(
        index: Int,
        name: String,
        isPassed: Bool = false,
        placement: Placement = .left
    ) {
        accentColor = isPassed
            ? (UIColor(named: "Colors/Gray-gray-500") ?? .systemGray)
            : LandmarkIndexView.defaultAccentColor
        self.placement = placement
        super.init(frame: CGRect(origin: .zero, size: Self.preferredSize))
        backgroundColor = .clear

        bubbleLayer.fillColor = accentColor.cgColor
        bubbleLayer.shadowColor = accentColor.cgColor
        bubbleLayer.shadowOpacity = 0.24
        bubbleLayer.shadowOffset = CGSize(width: 0, height: 1)
        bubbleLayer.shadowRadius = 3
        layer.insertSublayer(bubbleLayer, at: 0)

        indexLabel.text = "\(index)"
        indexLabel.font = AppTypography.Style.title3.uiFont()
        indexLabel.textColor = accentColor
        indexLabel.textAlignment = .center
        indexLabel.backgroundColor = .white
        indexLabel.layer.borderColor = accentColor.cgColor
        indexLabel.layer.borderWidth = 2
        indexLabel.layer.cornerRadius = 17
        indexLabel.clipsToBounds = true

        nameLabel.text = name
        nameLabel.font = AppTypography.Style.labelS.uiFont()
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.textAlignment = .center

        addSubview(indexLabel)
        addSubview(nameLabel)
        isAccessibilityElement = true
        accessibilityLabel = "\(index)번 랜드마크, \(name)"
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()

        let bodyMinX = placement == .left ? 0 : tailLength
        let bodyRect = CGRect(
            x: bodyMinX,
            y: (bounds.height - bodyHeight) / 2,
            width: bounds.width - tailLength,
            height: bodyHeight
        )
        let path = makeBubblePath(bodyRect: bodyRect)
        bubbleLayer.path = path.cgPath
        bubbleLayer.shadowPath = path.cgPath

        indexLabel.frame = CGRect(x: bodyRect.minX + 2, y: bodyRect.minY + 2, width: 34, height: 34)
        nameLabel.frame = CGRect(
            x: bodyRect.minX + 40,
            y: bodyRect.minY,
            width: bodyRect.width - 47,
            height: bodyHeight
        )
    }

    private func makeBubblePath(bodyRect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let cornerRadius: CGFloat = 14
        let tailHalfBase: CGFloat = 5

        path.move(to: CGPoint(x: bodyRect.minX + cornerRadius, y: bodyRect.minY))
        path.addLine(to: CGPoint(x: bodyRect.maxX - cornerRadius, y: bodyRect.minY))
        path.addQuadCurve(
            to: CGPoint(x: bodyRect.maxX, y: bodyRect.minY + cornerRadius),
            controlPoint: CGPoint(x: bodyRect.maxX, y: bodyRect.minY)
        )

        if placement == .left {
            path.addLine(to: CGPoint(x: bodyRect.maxX, y: bodyRect.midY - tailHalfBase))
            path.addQuadCurve(
                to: CGPoint(x: bounds.maxX, y: bodyRect.midY),
                controlPoint: CGPoint(x: bodyRect.maxX + tailLength * 0.65, y: bodyRect.midY - 3)
            )
            path.addQuadCurve(
                to: CGPoint(x: bodyRect.maxX, y: bodyRect.midY + tailHalfBase),
                controlPoint: CGPoint(x: bodyRect.maxX + tailLength * 0.65, y: bodyRect.midY + 3)
            )
        }

        path.addLine(to: CGPoint(x: bodyRect.maxX, y: bodyRect.maxY - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: bodyRect.maxX - cornerRadius, y: bodyRect.maxY),
            controlPoint: CGPoint(x: bodyRect.maxX, y: bodyRect.maxY)
        )
        path.addLine(to: CGPoint(x: bodyRect.minX + cornerRadius, y: bodyRect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: bodyRect.minX, y: bodyRect.maxY - cornerRadius),
            controlPoint: CGPoint(x: bodyRect.minX, y: bodyRect.maxY)
        )

        if placement == .right {
            path.addLine(to: CGPoint(x: bodyRect.minX, y: bodyRect.midY + tailHalfBase))
            path.addQuadCurve(
                to: CGPoint(x: bounds.minX, y: bodyRect.midY),
                controlPoint: CGPoint(x: bodyRect.minX - tailLength * 0.65, y: bodyRect.midY + 3)
            )
            path.addQuadCurve(
                to: CGPoint(x: bodyRect.minX, y: bodyRect.midY - tailHalfBase),
                controlPoint: CGPoint(x: bodyRect.minX - tailLength * 0.65, y: bodyRect.midY - 3)
            )
        }

        path.addLine(to: CGPoint(x: bodyRect.minX, y: bodyRect.minY + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: bodyRect.minX + cornerRadius, y: bodyRect.minY),
            controlPoint: CGPoint(x: bodyRect.minX, y: bodyRect.minY)
        )
        path.close()
        return path
    }
}
