//
//  SendToken.SelectNetworkViewController.swift
//  p2p_wallet
//
//  Created by Chung Tran on 01/12/2021.
//

import Foundation
import BEPureLayout
import UIKit

extension SendToken {
    final class SelectNetworkViewController: BaseViewController {
        // MARK: - Properties
        private let selectableNetworks: [Network]
        private let recipientAddress: String?
        private let isTestnet: Bool
        private let prices: [String: Double]
        private var selectedNetwork: Network {
            didSet {
                reloadData()
            }
        }
        private var selectNetworkCompletion: ((Network) -> Void)?
        
        // MARK: - Subviews
        private lazy var networkViews: [_NetworkView] = {
            var networkViews = selectableNetworks
                .map {network -> _NetworkView in
                    let view = _NetworkView()
                    view.network = network
                    view.setUp(network: network, prices: prices)
                    if network == .solana {
                        view.insertArrangedSubview(
                            UILabel(text: L10n.paidByP2p, textSize: 13, textColor: .h34c759)
                                .withContentHuggingPriority(.required, for: .horizontal)
                                .padding(.init(x: 12, y: 8), backgroundColor: .f5fcf7, cornerRadius: 12)
                                .border(width: 1, color: .h34c759)
                                .withContentHuggingPriority(.required, for: .horizontal),
                            at: 2
                        )
                    }
                    return view.onTap(self, action: #selector(networkViewDidTouch(_:)))
                }
            
            return networkViews
        }()
        
        // MARK: - Initializer
        init(
            selectableNetworks: [Network],
            recipientAddress: String?,
            isTestnet: Bool,
            prices: [String: Double],
            selectedNetwork: Network,
            selectNetworkCompletion: ((Network) -> Void)?
        ) {
            self.selectableNetworks = selectableNetworks
            self.recipientAddress = recipientAddress
            self.isTestnet = isTestnet
            self.prices = prices
            self.selectedNetwork = selectedNetwork
            self.selectNetworkCompletion = selectNetworkCompletion
            super.init()
        }
        
        // MARK: - Methods
        override func setUp() {
            super.setUp()
            // navigation bar
            navigationBar.titleLabel.text = L10n.chooseTheNetwork
            
            // container
            let rootView = ScrollableVStackRootView()
            view.addSubview(rootView)
            rootView.autoPinEdge(.top, to: .bottom, of: navigationBar)
            rootView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
            rootView.stackView.spacing = 0
            rootView.stackView.addArrangedSubviews {
                UIView.greyBannerView {
                    UILabel(text: L10n.P2PWaletWillAutomaticallyMatchYourWithdrawalTargetAddressToTheCorrectNetworkForMostWithdrawals.howeverBeforeSendingYourFundsMakeSureToDoubleCheckTheSelectedNetwork, textSize: 15, numberOfLines: 0)
                }
                
                BEStackViewSpacing(10)
            }
            
            // networks
            for (index, view) in networkViews.enumerated() {
                rootView.stackView.addArrangedSubview(view.padding(.init(x: 0, y: 26)))
                if index < networkViews.count - 1 {
                    rootView.stackView.addArrangedSubview(.separator(height: 1, color: .separator))
                }
            }
            
            reloadData()
        }
        
        private func reloadData() {
            for view in self.networkViews {
                view.tickView.alpha = view.network == selectedNetwork ? 1: 0
            }
        }
        
        // MARK: - Actions
        @objc private func networkViewDidTouch(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? _NetworkView, let network = view.network else {
                return
            }
            selectedNetwork = network
            selectNetworkCompletion?(selectedNetwork)
        }
    }
    
    private class _NetworkView: SendToken.NetworkView {
        fileprivate var network: SendToken.Network?
        fileprivate lazy var tickView = UIImageView(width: 14.3, height: 14.19, image: .tick, tintColor: .h5887ff)
        override init() {
            super.init()
            addArrangedSubview(tickView)
        }
        
        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
