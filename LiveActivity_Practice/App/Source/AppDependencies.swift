//  AppDependencies.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import Foundation
import NMapsMap

/// 외부 지도 SDK 초기화를 앱 진입점으로 모아 테스트와 SDK 교체를 쉽게 한다.
struct AppDependencies {
    let naverMapAuthenticator: any NaverMapAuthenticating
    let naverMapClientID: String

    init(
        naverMapAuthenticator: any NaverMapAuthenticating,
        naverMapClientID: String
    ) {
        self.naverMapAuthenticator = naverMapAuthenticator
        self.naverMapClientID = naverMapClientID
    }

    static let live = AppDependencies(
        naverMapAuthenticator: NaverMapAuthenticator(),
        naverMapClientID: Bundle.main.object(forInfoDictionaryKey: "NCP_CLIENT_KEY") as? String ?? ""
    )

    func configureMapSDKs() {
        naverMapAuthenticator.configure(clientID: naverMapClientID)
    }
}

protocol NaverMapAuthenticating {
    func configure(clientID: String)
}

struct NaverMapAuthenticator: NaverMapAuthenticating {
    func configure(clientID: String) {
        guard !clientID.isEmpty, clientID != "$(NCP_CLIENT_KEY)" else { return }
        NMFAuthManager.shared().ncpKeyId = clientID
    }
}
