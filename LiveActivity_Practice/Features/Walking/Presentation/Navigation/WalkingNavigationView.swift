//  WalkingNavigationView.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import CoreLocation
import SwiftUI

struct WalkingNavigationView: View {
    @StateObject private var viewModel = WalkingNavigationViewModel()
    @State private var cameraCommand: MapCameraCommand?
    @State private var cameraCommandSequence = 0
    @State private var isSearchExpanded = false
    @State private var searchQuery = ""
    @State private var showSettings = false
    @State private var isExitAlertPresented = false
    @State private var isNavigationSheetExpanded = false
    @State private var mapHeading: CLLocationDirection = 0
    @State private var indicatorPosition: CGPoint?
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PersistentWalkingMapView(
                state: MapPresentationState(
                    route: viewModel.route,
                    deviationPath: viewModel.deviationPath,
                    passedRouteIndex: viewModel.passedRouteIndex,
                    currentLocation: viewModel.currentLocation,
                    currentHeading: viewModel.currentHeading,
                    currentLocationAccuracy: viewModel.currentLocationAccuracy,
                    navigationBearing: viewModel.navigationBearing,
                    navigationAlignmentID: viewModel.navigationAlignmentID,
                    isNavigating: viewModel.isNavigating,
                    cameraCommand: cameraCommand,
                    showLandmarks: viewModel.showLandmarks,
                    landmarkScaleThreshold: viewModel.landmarkMinZoom,
                    showTurnMarkers: viewModel.showTurnMarkers,
                    approachingThreshold: viewModel.approachingThreshold,
                    previewDestination: viewModel.previewDestination,
                    locationButtonBottomInset: locationButtonBottomInset,
                    onMapTapped: { coordinate in
                        guard !viewModel.isNavigating, !isSearchExpanded else { return }
                        viewModel.selectCoordinateAsDestination(coordinate)
                    },
                    onMapViewportChanged: { heading, position in
                        mapHeading = heading
                        indicatorPosition = position
                    }
                )
            )
            .ignoresSafeArea()
            
            if viewModel.isNavigating && viewModel.showGradientOverlay {
                HeadingSafeAreaGradientOverlay(
                    heading: viewModel.currentHeading,
                    mapHeading: mapHeading,
                    indicatorPosition: indicatorPosition
                )
                .ignoresSafeArea()
            }
            
            VStack(spacing: 12) {
                if viewModel.isNavigating {
                    CustomTopToolbar(
                        destinationName: viewModel.destinationName,
                        onBack: {
                            isExitAlertPresented = true
                        },
                        onSettings: {
                            showSettings = true
                        }
                    )
                } else {
                    HStack {
                        if viewModel.route != nil || viewModel.tappedCoordinate != nil || viewModel.previewDestination != nil {
                            backButton
                        }
                        Spacer()
                        settingsButton
                    }

                    if viewModel.route != nil && !viewModel.isNavigating {
                        WalkingSearchStartDestinationView(
                            destinationName: viewModel.destinationName
                        ) {
                            isSearchExpanded = true
                        }
                        .frame(height: 117)
                    }
                }

                if viewModel.isNavigating {
                    if viewModel.isOffRoute && !viewModel.isOffRouteBannerHidden {
                        offRouteBanner
                    }
                }
                
                Spacer()
                
                if viewModel.isNavigating, let route = viewModel.route {
                    CustomBottomSheet(
                        route: route,
                        progress: viewModel.progress,
                        destinationName: viewModel.destinationName,
                        isExpanded: $isNavigationSheetExpanded
                    )
                } else if let place = viewModel.previewDestination {
                    BottomPlaceView(
                        place: place,
                        isLoading: viewModel.isLoading,
                        onConfirm: {
                            Task { await viewModel.searchRoute() }
                        }
                    )
                } else if let route = viewModel.route {
                    routeSummary(route)
                } else if viewModel.isLoading {
                    ProgressView("최단 경로와 랜드마크 검색 중…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                } else if viewModel.tappedCoordinate != nil {
                    tappedDestinationPanel
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                
                if !viewModel.isNavigating,
                   viewModel.route == nil,
                   viewModel.previewDestination == nil,
                   viewModel.tappedCoordinate == nil,
                   !viewModel.isLoading {
                    homeSearchPanel
                }
            }
            .padding()
            
        }
        .overlay(alignment: .bottom) {
            if viewModel.isArrived {
                ArrivalLandingView(destinationName: viewModel.destinationName)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isArrived)
        .overlay(alignment: .center) {
            if isExitAlertPresented {
                ZStack {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                    
                    NavigationExitAlert(
                        onContinue: {
                            isExitAlertPresented = false
                        },
                        onExit: exitNavigation
                    )
                    .padding(.horizontal, 50)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExitAlertPresented)
        .task {
            viewModel.startLocationTracking()
            issueCameraCommand(.userLocation)
        }
        .onChange(of: viewModel.route) { _, route in
            isNavigationSheetExpanded = false
            if route != nil { issueCameraCommand(.route) }
        }
        .onChange(of: viewModel.previewDestination) { _, destination in
            if let destination {
                issueCameraCommand(.coordinate(destination.coordinate))
            }
        }
        .onChange(of: viewModel.isNavigating) { _, isNavigating in
            if !isNavigating {
                isExitAlertPresented = false
                isNavigationSheetExpanded = false
            }
        }
        .sheet(isPresented: $isSearchExpanded) {
            WalkingSearchModalView(
                viewModel: viewModel,
                isPresented: $isSearchExpanded,
                searchQuery: $searchQuery
            )
            .presentationDetents([.fraction(0.9)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(30)
        }
        .sheet(isPresented: $showSettings) {
            settingsView
                .presentationDetents([.medium])
        }
    }

    private var locationButtonBottomInset: CGFloat {
        guard viewModel.isNavigating else {
            return viewModel.route != nil ? 250 : 104
        }

        let sheetHeight: CGFloat = isNavigationSheetExpanded ? 520 : 120
        let sheetBottomMargin: CGFloat = 16
        let buttonToSheetGap: CGFloat = 16

        return sheetHeight + sheetBottomMargin + buttonToSheetGap
    }
    
    private var backButton: some View {
        Button {
            viewModel.clearTappedCoordinate()
            Task { await viewModel.dismissRoute() }
            issueCameraCommand(.userLocation)
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color("Colors/text-text-1"))
                .frame(width: 44, height: 44)
        }
        .modifier(WalkingToolbarButtonStyle())
        .accessibilityLabel("뒤로가기")
    }
    
    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color("Colors/text-text-1"))
                .frame(width: 44, height: 44)
        }
        .modifier(WalkingToolbarButtonStyle())
        .accessibilityLabel("설정")
    }
    
    private var settingsView: some View {
        NavigationStack {
            Form {
                Section("Compact 표시") {
                    Toggle("남은 거리를 시간(분)으로 표시", isOn: $viewModel.showTimeInsteadOfDistance)
                        .onChange(of: viewModel.showTimeInsteadOfDistance) {
                            viewModel.refreshLiveActivity()
                        }
                }
                Section("화면 효과") {
                    Toggle("그라디언트 오버레이", isOn: $viewModel.showGradientOverlay)
                }
                Section("지도") {
                    Toggle("턴 마커 표시", isOn: $viewModel.showTurnMarkers)
                    Toggle("랜드마크 표시", isOn: $viewModel.showLandmarks)
                    if viewModel.showLandmarks {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("축척 \(Int(viewModel.landmarkMinZoom))m 이하에서 표시")
                                .font(.subheadline)
                            Slider(value: $viewModel.landmarkMinZoom, in: 10...100, step: 10)
                        }
                    }
                }
                Section("Approaching 기준 거리") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(viewModel.approachingThreshold))m")
                            .font(.subheadline.monospacedDigit())
                        Slider(value: $viewModel.approachingThreshold, in: 0...30, step: 1)
                            .onChange(of: viewModel.approachingThreshold) {
                                viewModel.refreshLiveActivity()
                            }
                    }
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { showSettings = false }
                }
            }
        }
    }
    
    private var tappedDestinationPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.red)
                    .font(.title3)
                Text(viewModel.destinationName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
            }
            
            Button {
                Task { await viewModel.searchRoute() }
            } label: {
                Label("경로 찾기", systemImage: "figure.walk")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 8)
    }
    
    private var homeSearchPanel: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(Color(.systemGray3))
                .frame(width: 51, height: 5)
            
            Button {
                isSearchExpanded = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color("Colors/text-text-1"))
                    
                    Text("어디로 갈까요?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.3))
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.06), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .modifier(HomeSearchGlassSurface())
    }
    
    private var navigationDestinationPanel: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.red)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("목적지")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.destinationName.isEmpty ? "목적지" : viewModel.destinationName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 8)
    }
    
    private var offRouteBanner: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(red: 1, green: 0.882, blue: 0.627))
                        .frame(width: 44, height: 44)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 22))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color(red: 1, green: 0.714, blue: 0.098))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    if viewModel.isRerouting {
                        Text("경로 재탐색 중…")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
                    } else {
                        Text("경로에서 벗어난 것 같아요")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
                        Text("현재 위치에서 재탐색할까요?")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.3))
                    }
                }
                
                Spacer()
                
                if viewModel.isRerouting {
                    ProgressView()
                }
            }
            
            if !viewModel.isRerouting {
                VStack(spacing: 6) {
                    Button {
                        Task { await viewModel.rerouteFromCurrentLocation() }
                    } label: {
                        Text("재탐색")
                            .appTypography(.labelL)
                            .foregroundStyle(Color(red: 0.075, green: 0.42, blue: 1))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .background(Color(red: 0.678, green: 0.8, blue: 1).opacity(0.8), in: Capsule())
                    
                    Button {
                        viewModel.keepCurrentRoute()
                    } label: {
                        Text("기존 경로 유지")
                            .appTypography(.labelL)
                            .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .background(Color(red: 0.9, green: 0.9, blue: 0.9), in: Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 25))
    }
    
    private func exitNavigation() {
        isExitAlertPresented = false
        viewModel.clearTappedCoordinate()
        Task {
            await viewModel.dismissRoute()
            issueCameraCommand(.userLocation)
        }
    }
    
    private func issueCameraCommand(_ target: MapCameraCommand.Target) {
        cameraCommandSequence += 1
        cameraCommand = MapCameraCommand(id: cameraCommandSequence, target: target)
    }
    
    private func routeSummary(_ route: WalkingRoute) -> some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text("전체 랜드마크 \(viewModel.landmarkCount)개")
                        .foregroundStyle(Color("Colors/brand-primary"))
                        .appTypography(.captionM)
                    Text(formattedTime(route.totalTime))
                        .appTypography(.title1)
                }
                Spacer()
                Button {
                    Task {
                        await viewModel.startNavigation()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .frame(width: 68, height: 68)
                            .foregroundColor(Color("Colors/brand-primary"))
                        VStack {
                            Image(systemName: "figure.walk")
                            Text("시작")
                                .appTypography(.labelM)
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
        .padding([.horizontal], 24)
        .padding([.vertical], 27)
        .modifier(RouteSummaryGlassSurface())
    }
    
    private func formattedTime(_ totalSeconds: Int) -> String {
        let minutes = max(1, totalSeconds / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours >= 1 {
            return remainingMinutes > 0 ? "\(hours)시간 \(remainingMinutes)분" : "\(hours)시간"
        }
        return "\(minutes)분"
    }

    @ViewBuilder
    private func navigationDetails(for route: WalkingRoute) -> some View {
        if let progress = viewModel.progress, let next = progress.nextManeuver {
            Label(next.instruction, systemImage: next.turn.symbolName)
                .lineLimit(2)
            Text("다음 안내까지 \(distanceText(progress.distanceToNextManeuver))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        let landmarkCount = Set(route.maneuvers.compactMap(\.landmark?.id)).count
        Text("경로 랜드마크 \(landmarkCount)개")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func distanceText(_ meters: Int) -> String {
        meters >= 1000 ? String(format: "%.1fkm", Double(meters) / 1000) : "\(meters)m"
    }

}

private struct RouteSummaryGlassSurface: ViewModifier {
    private let shape = RoundedRectangle(cornerRadius: 100)

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(.regularMaterial, in: shape)
        }
    }
}

private struct WalkingToolbarButtonStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        } else {
            content
                .buttonStyle(.plain)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.5), lineWidth: 1)
                }
        }
    }
}
