//  NaverMapEngine.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import SwiftUI

struct NaverMapEngine: WalkingMapEngine {
    func makeMapView(state: MapPresentationState) -> some View {
        NaverMapRouteView(state: state)
    }
}
