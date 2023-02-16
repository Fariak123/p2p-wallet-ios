//
//  NewHistoryView.swift
//  p2p_wallet
//
//  Created by Giang Long Tran on 31.01.2023.
//

import History
import KeyAppUI
import SwiftUI

struct NewHistoryView: View {
    @ObservedObject var viewModel: NewHistoryViewModel

    var body: some View {
        VStack {
            ScrollView {
                // Display error if no result
                if
                    viewModel.historyTransactionList.state.error != nil,
                    viewModel.historyTransactionList.state.data.isEmpty
                {
                    NewHistoryListErrorView {
                        viewModel.reload()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 38)
                }

                // Render list
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.sections) { (section: NewHistorySection) in
                        Text(section.title)
                            .apply(style: .text4)
                            .foregroundColor(Color(Asset.Colors.mountain.color))
                            .padding(.top, viewModel.sections.first == section ? 0 : 24)
                            .padding(.bottom, 12)

                        ForEach(section.items, id: \.id) { (item: NewHistoryItem) in
                            Group {
                                switch item {
                                case let .rendable(rendableItem):
                                    NewHistoryItemView(item: rendableItem) {
                                        viewModel.onTap(item: rendableItem)
                                    }
                                case let .placeHolder(_, fetchable):
                                    NewHistoryListSkeletonView()
                                        // Load next item if the item is last
                                        .onAppear(perform: fetchable ? { viewModel.fetch() } : nil)
                                case let .button(_, title, action):
                                    TextButtonView(
                                        title: title,
                                        style: .second,
                                        size: .large,
                                        onPressed: action
                                    )
                                    .frame(height: TextButton.Size.large.height)
                                    .padding(.all, 16)
                                }
                            }
                            .padding(.top, section.items.first == item ? 4 : 0)
                            .padding(.bottom, section.items.last == item ? 4 : 0)
                            .background(Color(Asset.Colors.snow.color))
                            .roundedList(
                                radius: 16,
                                isFirst: section.items.first == item,
                                isLast: section.items.last == item
                            )
                        }
                    }.padding(.horizontal, 16)
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color(Asset.Colors.smoke.color))
        .onAppear { viewModel.fetch() }
    }
}

private extension View {
    func roundedList(radius: CGFloat, isFirst: Bool, isLast: Bool) -> some View {
        var corner: UIRectCorner = []

        if isFirst {
            corner = [.topLeft, .topRight]
        }

        if isLast {
            corner = [.bottomLeft, .bottomRight]
        }

        if isFirst && isLast {
            corner = .allCorners
        }

        if isFirst || isLast {
            return AnyView(
                self
                    .cornerRadius(
                        radius: radius,
                        corners: corner
                    )
            )
        } else {
            return AnyView(self)
        }
    }
}

struct NewHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NewHistoryView(
            viewModel: .init(
                provider: MockKeyAppHistoryProvider()
            )
        )
    }
}
