//  WalkingMapEngine.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import SwiftUI

@MainActor
protocol WalkingMapEngine {
    associatedtype MapContent: View

    @ViewBuilder
    func makeMapView(state: MapPresentationState) -> MapContent
}
