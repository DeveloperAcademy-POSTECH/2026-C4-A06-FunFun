//
//  CustomBottomSheet.swift
//  LiveActivity_Practice
//

import SwiftUI

/// 도보 안내를 접힘/펼침 형태로 보여주는 바텀 시트입니다.
///     /// - Parameters:
///   - route: 표시할 전체 도보 경로입니다.
///   - progress: 현재 위치를 기준으로 계산된 경로 진행 정보입니다.
///   - destinationName: 하단에 표시할 목적지 이름입니다.
///   - isExpanded: 펼침 상태를 외부에서 제어하기 위한 바인딩입니다.
///   - expandedHeight: 펼친 콘텐츠의 높이입니다.
///
struct CustomBottomSheet: View {
    let route: WalkingRoute
    let progress: WalkingProgress?
    let destinationName: String

    private let expandedHeight: CGFloat
    private let expansionBinding: Binding<Bool>?
    @State private var internalIsExpanded: Bool
    
    init(
        route: WalkingRoute,
        progress: WalkingProgress?,
        destinationName: String = "목적지",
        isExpanded: Binding<Bool>? = nil,
        expandedHeight: CGFloat = 500
    ) {
        self.route = route
        self.progress = progress
        self.destinationName = destinationName
        self.expansionBinding = isExpanded
        self.expandedHeight = expandedHeight
        _internalIsExpanded = State(initialValue: isExpanded?.wrappedValue ?? false)
    }

    private var isExpanded: Bool {
        expansionBinding?.wrappedValue ?? internalIsExpanded
    }

    private var currentManeuver: WalkingManeuver? {
        progress?.nextManeuver ?? orderedManeuvers.first
    }

    private var orderedManeuvers: [WalkingManeuver] {
        route.maneuvers.sorted {
            if $0.routeIndex == $1.routeIndex { return $0.id < $1.id }
            return $0.routeIndex < $1.routeIndex
        }
    }

    private var upcomingManeuvers: [WalkingManeuver] {
        guard let currentManeuver else { return orderedManeuvers }
        return orderedManeuvers.filter {
            $0.routeIndex > currentManeuver.routeIndex && $0.turn != .destination
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            expansionButton

            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                currentInstructionCard(isInset: false)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 14)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .background(sheetBackground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.5), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 18, y: 5)
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: isExpanded)
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onTapGesture {
            setExpanded(!isExpanded)
        }
        .simultaneousGesture(expansionDragGesture)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: isExpanded ? "전체 경로 접기" : "전체 경로 펼치기") {
            setExpanded(!isExpanded)
        }
    }

    private var sheetBackground: some ShapeStyle {
        .ultraThinMaterial
    }

    private var expansionButton: some View {
        Capsule()
            .fill(Color(white: 0.64))
            .frame(width: 48, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 9)
            .accessibilityHidden(true)
    }

    private var expansionDragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let verticalDistance = value.translation.height
                let horizontalDistance = value.translation.width

                guard abs(verticalDistance) > abs(horizontalDistance),
                      abs(verticalDistance) >= 40 else { return }

                setExpanded(verticalDistance < 0)
            }
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            currentInstructionCard(isInset: true)
                .padding(.horizontal, 13)

            if upcomingManeuvers.isEmpty {
                Spacer(minLength: 12)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(upcomingManeuvers) { maneuver in
                            upcomingRow(maneuver)
                        }
                    }
                    .padding(.horizontal, 22)
                }
                .scrollIndicators(.hidden)
            }

            destinationFooter
                .padding(.horizontal, 22)
        }
        .frame(height: expandedHeight)
    }

    @ViewBuilder
    private func currentInstructionCard(isInset: Bool) -> some View {
        if let maneuver = currentManeuver {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("남은 거리 \(distanceText(progress?.distanceToNextManeuver ?? route.totalDistance))")
                        .font(.system(size: isInset ? 18 : 15, weight: .bold))
                        .foregroundStyle(Color(white: 0.5))

                    Text(instructionText(for: maneuver))
                        .font(.system(size: isInset ? 25 : 21, weight: .bold))
                        .foregroundStyle(.black)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)
                }
                .padding(18)

                Spacer(minLength: 8)

                Image(systemName: maneuver.turn.symbolName)
                    .font(.system(size: isInset ? 46 : 42, weight: .semibold))
                    .foregroundStyle(Color(red: 0.075, green: 0.42, blue: 1))
                    .frame(width: isInset ? 48 : 48, height: 48)
            }
            .padding(.horizontal, isInset ? 28 : 16)
            .frame(minHeight: isInset ? 114 : 80)
            .background {
                if isInset {
                    RoundedRectangle(cornerRadius: 55, style: .continuous)
                        .fill(Color(white: 0.88).opacity(0.82))
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            HStack {
                Text("경로 안내를 확인해 주세요")
                    .font(.headline)
                Spacer()
                Image(systemName: "figure.walk")
                    .font(.title)
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 80)
        }
    }

    private func upcomingRow(_ maneuver: WalkingManeuver) -> some View {
        HStack(spacing: 16) {
            Text(maneuver.landmark?.name ?? shortInstruction(for: maneuver))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(white: 0.48))
                .lineLimit(2)

            Spacer(minLength: 8)

            Image(systemName: maneuver.turn.symbolName)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(Color(red: 0.60, green: 0.75, blue: 1))
                .frame(width: 24, height: 24)
        }
        .padding(.horizontal, 24)
        .frame(minHeight: 76)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(white: 0.82))
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var destinationFooter: some View {
        HStack(spacing: 14) {
            Image(systemName: "mappin")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color(red: 1, green: 0.42, blue: 0.44), in: Circle())
                .background(Color(red: 1, green: 0.80, blue: 0.81), in: Circle().inset(by: -8))
                .padding(8)

            Text(destinationName.isEmpty ? "목적지" : destinationName)
                .appTypography(.headlineM)
                .foregroundStyle(Color(white: 0.48))
                .lineLimit(2)

            Spacer(minLength: 8)

            Text("남은 시간 \(remainingMinutes)분")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(white: 0.5))
                .fixedSize()
        }
        .frame(minHeight: 82)
        .accessibilityElement(children: .combine)
    }

    private var remainingMinutes: Int {
        guard route.totalDistance > 0, let progress else {
            return max(1, Int(ceil(Double(route.totalTime) / 60)))
        }
        let remainingSeconds = Double(route.totalTime) * Double(progress.remainingDistance) / Double(route.totalDistance)
        return max(1, Int(ceil(remainingSeconds / 60)))
    }

    private func instructionText(for maneuver: WalkingManeuver) -> String {
        guard let landmark = maneuver.landmark else { return maneuver.description }
        let direction = switch maneuver.turn {
        case .left, .slightLeft: "왼쪽"
        case .right, .slightRight: "오른쪽"
        case .straight: "직진"
        case .crosswalk: "횡단보도 건너기"
        case .stairs: "계단 이용"
        case .destination: "목적지 도착"
        case .unknown: "이동"
        }
        return "\(landmark.name)에서 \(direction)"
    }

    private func shortInstruction(for maneuver: WalkingManeuver) -> String {
        switch maneuver.turn {
        case .left, .slightLeft: "왼쪽으로 이동"
        case .right, .slightRight: "오른쪽으로 이동"
        case .straight: "직진"
        case .crosswalk: "횡단보도"
        case .stairs: "계단"
        case .destination: "목적지"
        case .unknown: maneuver.description
        }
    }

    private func setExpanded(_ expanded: Bool) {
        if let expansionBinding {
            expansionBinding.wrappedValue = expanded
        } else {
            internalIsExpanded = expanded
        }
    }

    private func distanceText(_ meters: Int) -> String {
        meters >= 1_000
            ? String(format: "%.1fkm", Double(meters) / 1_000)
            : "\(meters)m"
    }
}
