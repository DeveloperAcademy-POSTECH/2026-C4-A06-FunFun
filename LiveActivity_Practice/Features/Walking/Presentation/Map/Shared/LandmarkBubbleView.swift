//  LandmarkBubbleView.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import UIKit

final class LandmarkBubbleView: UIView {
    private let indexLabel = UILabel()
    private let nameLabel = UILabel()
    private let bubbleLayer = CAShapeLayer()
    private let bodyHeight: CGFloat = 50
    private let tailHeight: CGFloat = 11

    init(index: Int, name: String, isPassed: Bool = false) {
        super.init(frame: CGRect(x: 0, y: 0, width: 148, height: 61))
        backgroundColor = .clear
        let accentColor: UIColor = isPassed ? .systemGray : .blue
        bubbleLayer.fillColor = accentColor.cgColor
        bubbleLayer.strokeColor = UIColor.white.withAlphaComponent(0.5).cgColor
        bubbleLayer.lineWidth = 1
        bubbleLayer.shadowColor = UIColor.black.cgColor
        bubbleLayer.shadowOpacity = 0.18
        bubbleLayer.shadowOffset = CGSize(width: 0, height: 2)
        bubbleLayer.shadowRadius = 3
        layer.insertSublayer(bubbleLayer, at: 0)

        indexLabel.text = "\(index)"
        indexLabel.font = .systemFont(ofSize: 13, weight: .bold)
        indexLabel.textColor = accentColor
        indexLabel.textAlignment = .center
        indexLabel.backgroundColor = .white
        indexLabel.layer.cornerRadius = 12
        indexLabel.clipsToBounds = true

        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 2
        nameLabel.lineBreakMode = .byTruncatingTail
        addSubview(indexLabel)
        addSubview(nameLabel)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bodyRect = CGRect(x: 0, y: 0, width: bounds.width, height: bodyHeight)
        let path = UIBezierPath(roundedRect: bodyRect, cornerRadius: 17)
        path.move(to: CGPoint(x: bounds.midX - 8, y: bodyHeight - 1))
        path.addLine(to: CGPoint(x: bounds.midX, y: bodyHeight + tailHeight))
        path.addLine(to: CGPoint(x: bounds.midX + 8, y: bodyHeight - 1))
        path.close()
        bubbleLayer.path = path.cgPath
        bubbleLayer.shadowPath = path.cgPath
        indexLabel.frame = CGRect(x: 5, y: 13, width: 24, height: 24)
        nameLabel.frame = CGRect(x: 36, y: 5, width: bounds.width - 44, height: 40)
    }
}
