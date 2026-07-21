//  PersistentWalkingMapView.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import SwiftUI

/// 지도 SDK의 네이티브 뷰를 최초 한 번만 만들고 재사용한다.
struct PersistentWalkingMapView: View {
    let state: MapPresentationState

    var body: some View {
        NaverMapEngine().makeMapView(state: state)
    }
}
