//
//  LandmarkIndexView.swift
//  LiveActivity_Practice
//

import UIKit

/// 지도 위 랜드마크의 순서를 간결하게 표시하는 공통 번호 뷰입니다.
final class LandmarkIndexView: UIView {
    static let preferredSize = CGSize(width: 21, height: 21)
    static var defaultAccentColor: UIColor {
        UIColor(named: "Colors/Blue-blue-700")!
    }

    private let circleLayer = CAShapeLayer()
    private let indexLabel = UILabel()
    private var accentColor: UIColor

    var index: Int {
        didSet {
            updateIndexLabel()
        }
    }

    init(
        index: Int,
        accentColor: UIColor = LandmarkIndexView.defaultAccentColor
    ) {
        self.index = index
        self.accentColor = accentColor
        super.init(frame: CGRect(origin: .zero, size: Self.preferredSize))
        configureView()
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        index = 0
        accentColor = Self.defaultAccentColor
        super.init(coder: coder)
        configureView()
        updateAppearance()
    }

    override var intrinsicContentSize: CGSize {
        Self.preferredSize
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        updateCirclePath()
    }

    private func updateCirclePath() {
        circleLayer.frame = bounds
        circleLayer.path = UIBezierPath(
            ovalIn: bounds.insetBy(dx: circleLayer.lineWidth / 2, dy: circleLayer.lineWidth / 2)
        ).cgPath
    }

    func setAccentColor(_ color: UIColor) {
        accentColor = color
        updateAppearance()
    }

    private func configureView() {
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = .staticText

        circleLayer.fillColor = UIColor.white.cgColor
        circleLayer.lineWidth = 2
        circleLayer.contentsScale = UIScreen.main.scale
        layer.insertSublayer(circleLayer, at: 0)
        updateCirclePath()

        indexLabel.textAlignment = .center
        indexLabel.adjustsFontSizeToFitWidth = true
        indexLabel.minimumScaleFactor = 0.7
        indexLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(indexLabel)
        NSLayoutConstraint.activate([
            indexLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            indexLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            indexLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 3),
            indexLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -3)
        ])

        updateIndexLabel()
    }

    private func updateAppearance() {
        circleLayer.strokeColor = accentColor.cgColor
        indexLabel.textColor = accentColor
        accessibilityLabel = "\(index)번 랜드마크"
    }

    private func updateIndexLabel() {
        let fontSize: CGFloat = abs(index) >= 10 ? 11 : 14
        indexLabel.text = String(index)
        indexLabel.font = UIFont(
            name: PretendardWeight.bold.fontName,
            size: fontSize
        ) ?? .systemFont(ofSize: fontSize, weight: .bold)
        accessibilityLabel = "\(index)번 랜드마크"
    }
}

#Preview {
    LandmarkIndexView(index: 5)
}
