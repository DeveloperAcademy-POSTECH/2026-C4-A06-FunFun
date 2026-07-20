//  MyLocationButton.swift
//  LiveActivity_Practice

import NMapsMap
import UIKit

/// 현 위치 찾기 버튼
final class MyLocationButton: NMFLocationButton {
    private let symbolImageView: UIImageView = {
        let configuration = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        let imageView = UIImageView(image: UIImage(systemName: "dot.scope", withConfiguration: configuration))
        imageView.tintColor = .label
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = false
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAppearance()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
        imageView?.isHidden = true
    }

    private func configureAppearance() {
        backgroundColor = UIColor.white.withAlphaComponent(0.25)
        clipsToBounds = true
        setBackgroundImage(nil, for: .normal)
        setBackgroundImage(nil, for: .highlighted)
        setBackgroundImage(nil, for: .selected)

        addSubview(symbolImageView)
        NSLayoutConstraint.activate([
            symbolImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            symbolImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbolImageView.widthAnchor.constraint(equalToConstant: 24),
            symbolImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
}
