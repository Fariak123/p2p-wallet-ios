//
//  TransactionDetail.ViewController.swift
//  p2p_wallet
//
//  Created by Chung Tran on 08/03/2022.
//

import BEPureLayout
import Foundation
import TransactionParser
import UIKit
import RxSwift

extension TransactionDetail {
    class ViewController: BaseViewController {
        // MARK: - Dependencies

        private let viewModel: TransactionDetailViewModelType
        private let disposeBag = DisposeBag()

        // MARK: - Initializer

        init(viewModel: TransactionDetailViewModelType) {
            self.viewModel = viewModel
            super.init()
        }

        // MARK: - Methods

        override func build() -> UIView {
            BEVStack {
                // Scrollable View
                BEScrollView(
                    axis: .vertical,
                    contentInsets: .init(x: 18, y: 12),
                    spacing: 18
                ) {
                    // Status View
                    StatusView()
                        .driven(with: viewModel.parsedTransactionDriver)

                    // Summary View
                    UIView.floatingPanel(contentInset: .init(x: 8, y: 16)) {
                        SummaryView(viewModel: viewModel)
                    }
                    .setup { view in
                        viewModel.isSummaryAvailableDriver
                            .map { !$0 }
                            .drive(view.rx.isHidden)
                            .disposed(by: disposeBag)
                    }

                    // Tap and hold to copy
                    UIView.greyBannerView {
                        TapAndHoldView()
                            .setup { view in
                                view.closeHandler = { [unowned view] in
                                    UIView.animate(withDuration: 0.3) {
                                        view.superview?.superview?.isHidden = true
                                    }
                                }
                            }
                    }

                    // Transaction id
                    BEHStack(spacing: 12, alignment: .top) {
                        titleLabel(text: L10n.transactionID)

                        BEVStack(spacing: 4) {
                            // Transaction id
                            BEHStack(spacing: 4, alignment: .center) {
                                UILabel(text: "4gj7UK2mG...NjweNS39N", textSize: 15, textAlignment: .right)
                                    .setup { label in
                                        viewModel.parsedTransactionDriver
                                            .map {
                                                $0?.signature?
                                                    .truncatingMiddle(numOfSymbolsRevealed: 9,
                                                                      numOfSymbolsRevealedInSuffix: 9)
                                            }
                                            .drive(label.rx.text)
                                            .disposed(by: disposeBag)
                                    }
                                UIImageView(
                                    width: 16,
                                    height: 16,
                                    image: .transactionShowInExplorer,
                                    tintColor: .textSecondary
                                )
                            }

                            UILabel(
                                text: L10n.tapToViewInExplorer,
                                textSize: 15,
                                textColor: .textSecondary,
                                textAlignment: .right
                            )
                        }
                        .onTap { [unowned self] in
                            self.viewModel.navigate(to: .explorer)
                        }
                        .onLongTap { [unowned self] gesture in
                            guard gesture.state == .ended else { return }
                            self.viewModel.copyTransactionIdToClipboard()
                        }
                    }

                    // From to section
                    FromToSection(viewModel: viewModel)
                        .setup { section in
                            viewModel.isFromToSectionAvailableDriver
                                .map { !$0 }
                                .drive(section.rx.isHidden)
                                .disposed(by: disposeBag)
                        }

                    // Amount section
                    AmountSection(viewModel: viewModel)

                    // Separator
                    UIView.defaultSeparator()

                    // Block number
                    BEHStack(spacing: 12) {
                        titleLabel(text: L10n.blockNumber)

                        UILabel(text: "#5387498763", textSize: 15, textAlignment: .right)
                            .setup { label in
                                viewModel.parsedTransactionDriver
                                    .map { "#\($0?.slot ?? 0)" }
                                    .drive(label.rx.text)
                                    .disposed(by: disposeBag)
                            }
                    }
                }
            }
        }

        override func bind() {
            super.bind()

            viewModel.navigationDriver
                .drive(onNext: { [weak self] in self?.navigate(to: $0) })
                .disposed(by: disposeBag)
            viewModel.navigationTitle
                .drive(onNext: { [weak self] title in
                    DispatchQueue.main.async { [weak self] in
                        self?.navigationController?.navigationBar.topItem?.title = title
                    }
                })
                .disposed(by: disposeBag)
        }

        // MARK: - Navigation

        private func navigate(to scene: NavigatableScene?) {
            guard let scene = scene else { return }
            switch scene {
            case .explorer:
                showWebsite(url: "https://explorer.solana.com/tx/\(viewModel.getTransactionId() ?? "")")
            case .freeFeeInfo:
                showAlert(
                    title: L10n.paidByKeyApp,
                    message: L10n.OnTheSolanaNetworkTheFirstTransactionsInADayArePaidByKeyApp
                        .subsequentTransactionsWillBeChargedBasedOnTheSolanaBlockchainGasFee(100)
                )
            }
        }

        private func titleLabel(text: String) -> UILabel {
            UILabel(text: text, textSize: 15, textColor: .textSecondary, numberOfLines: 2)
        }
    }
}
