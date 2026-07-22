//  LiveActivity_PracticeApp.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import SwiftUI

@main
struct LiveActivity_PracticeApp: App {
    private let dependencies: AppDependencies

    init() {
        self.init(dependencies: .live)
    }

    private init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        dependencies.configureMapSDKs()
    }

    var body: some Scene {
        WindowGroup {
            WalkingMapRootView()
        }
    }
}
