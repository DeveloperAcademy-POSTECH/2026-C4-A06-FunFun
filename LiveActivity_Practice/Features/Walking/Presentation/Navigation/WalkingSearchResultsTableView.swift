//
//  WalkingSearchResultsTableView.swift
//  LiveActivity_Practice
//

import SwiftUI
import UIKit

struct WalkingSearchResultsTableView: UIViewRepresentable {
    let places: [PlaceSearchResult]
    let isLoading: Bool
    let onSelect: (PlaceSearchResult) -> Void
    let onLoadMore: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITableView {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.delegate = context.coordinator
        tableView.rowHeight = 56
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.showsVerticalScrollIndicator = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: ReuseID.place)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: ReuseID.loading)

        context.coordinator.dataSource = UITableViewDiffableDataSource<Section, Item>(
            tableView: tableView
        ) { tableView, indexPath, item in
            switch item {
            case .place(let place):
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: ReuseID.place,
                    for: indexPath
                )
                var content = cell.defaultContentConfiguration()
                content.text = place.name
                content.secondaryText = place.address
                content.textProperties.font = AppTypography.Style.labelM.uiFont()
                content.textProperties.color = UIColor(white: 0.1, alpha: 1)
                content.textProperties.numberOfLines = 1
                content.secondaryTextProperties.font = AppTypography.Style.captionS.uiFont()
                content.secondaryTextProperties.color = UIColor(white: 0.7, alpha: 1)
                content.secondaryTextProperties.numberOfLines = 1
                content.directionalLayoutMargins = NSDirectionalEdgeInsets(
                    top: 6,
                    leading: 16,
                    bottom: 6,
                    trailing: 16
                )
                cell.contentConfiguration = content
                cell.backgroundColor = UIColor.clear
                cell.selectionStyle = .default
                return cell

            case .loading:
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: ReuseID.loading,
                    for: indexPath
                )
                cell.contentConfiguration = UIHostingConfiguration {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
                .margins(.all, 8)
                cell.backgroundColor = UIColor.clear
                cell.selectionStyle = .none
                return cell
            }
        }

        context.coordinator.applySnapshot(animatingDifferences: false)
        return tableView
    }

    func updateUIView(_ tableView: UITableView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.applySnapshot(animatingDifferences: true)
    }

    final class Coordinator: NSObject, UITableViewDelegate {
        var parent: WalkingSearchResultsTableView
        fileprivate var dataSource: UITableViewDiffableDataSource<Section, Item>?

        init(parent: WalkingSearchResultsTableView) {
            self.parent = parent
        }

        func applySnapshot(animatingDifferences: Bool) {
            var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
            snapshot.appendSections([.main])
            snapshot.appendItems(parent.places.map(Item.place), toSection: .main)

            if parent.isLoading {
                snapshot.appendItems([.loading], toSection: .main)
            }

            dataSource?.apply(snapshot, animatingDifferences: animatingDifferences)
        }

        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)

            guard case .place(let place) = dataSource?.itemIdentifier(for: indexPath) else {
                return
            }

            parent.onSelect(place)
        }

        func tableView(
            _ tableView: UITableView,
            willDisplay cell: UITableViewCell,
            forRowAt indexPath: IndexPath
        ) {
            guard !parent.isLoading,
                  case .place(let place) = dataSource?.itemIdentifier(for: indexPath),
                  place.id == parent.places.last?.id else {
                return
            }

            parent.onLoadMore()
        }
    }
}

nonisolated private enum Section: Hashable, Sendable {
    case main
}

nonisolated private enum Item: Hashable, Sendable {
    case place(PlaceSearchResult)
    case loading
}

nonisolated private enum ReuseID {
    static let place = "WalkingSearchPlaceCell"
    static let loading = "WalkingSearchLoadingCell"
}
