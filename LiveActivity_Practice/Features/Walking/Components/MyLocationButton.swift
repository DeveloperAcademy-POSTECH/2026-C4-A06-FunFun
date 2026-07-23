//  MyLocationButton.swift
//  LiveActivity_Practice

import UIKit

/// 현 위치 찾기 버튼
final class MyLocationButton: UIButton {
    var onTap: (() -> Void)?

    private let glassEffectView: UIVisualEffectView = {
        let effect: UIVisualEffect
        if #available(iOS 26.0, *) {
            let glassEffect = UIGlassEffect(style: .clear)
            glassEffect.isInteractive = true
            effect = glassEffect
        } else {
            effect = UIBlurEffect(style: .systemUltraThinMaterial)
        }

        let effectView = UIVisualEffectView(effect: effect)
        effectView.isUserInteractionEnabled = false
        effectView.clipsToBounds = true
        effectView.translatesAutoresizingMaskIntoConstraints = false
        return effectView
    }()

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
        configureAction()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAppearance()
        configureAction()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let cornerRadius = min(bounds.width, bounds.height) / 2
        glassEffectView.layer.cornerRadius = cornerRadius
        glassEffectView.layer.borderWidth = 0.5
        glassEffectView.layer.borderColor = UIColor.white.withAlphaComponent(0.7).cgColor
        imageView?.isHidden = true
    }

    private func configureAppearance() {
        backgroundColor = .clear
        clipsToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
        setBackgroundImage(nil, for: .normal)
        setBackgroundImage(nil, for: .highlighted)
        setBackgroundImage(nil, for: .selected)

        insertSubview(glassEffectView, at: 0)
        addSubview(symbolImageView)
        NSLayoutConstraint.activate([
            glassEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassEffectView.topAnchor.constraint(equalTo: topAnchor),
            glassEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            symbolImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            symbolImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbolImageView.widthAnchor.constraint(equalToConstant: 24),
            symbolImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    private func configureAction() {
        addAction(
            UIAction { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.onTap?()
                }
            },
            for: .touchUpInside
        )
    }
}
