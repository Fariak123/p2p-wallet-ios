//
//  OrcaSwap2.MainSwapView.swift
//  p2p_wallet
//
//  Created by Andrew Vasiliev on 30.11.2021.
//

import BEPureLayout
import RxCocoa
import RxSwift
import UIKit
import KeyAppUI

extension OrcaSwapV2 {
    final class MainSwapView: WLFloatingPanelView {
        private lazy var fromWalletView = WalletView(type: .source, viewModel: viewModel)
        private let switchButton = UIButton(width: 32, height: 32)
        private lazy var toWalletView = WalletView(type: .destination, viewModel: viewModel)
        #if !RELEASE
        private lazy var routeLabel = UILabel(text: nil, textColor: .alert, numberOfLines: 0)
        #endif
        private let receiveAtLeastView = HorizontalLabelsWithSpacer()

        private let viewModel: OrcaSwapV2ViewModelType
        private let disposeBag = DisposeBag()

        init(viewModel: OrcaSwapV2ViewModelType) {
            self.viewModel = viewModel
            super.init(cornerRadius: 12, contentInset: .init(all: 18))
        }

        override func commonInit() {
            super.commonInit()

            configureSubviews()
            layout()
            bind()
        }

        func makeFromFirstResponder() {
            fromWalletView.makeFirstResponder()
        }

        private func configureSubviews() {
            configureReceiveAtLeast()

            switchButton.setImage(.arrowUpDown.withTintColor(Asset.Colors.night.color), for: .normal)
            switchButton.backgroundColor = Asset.Colors.snow.color
            switchButton.layer.borderColor = Asset.Colors.night.color.cgColor
            switchButton.layer.borderWidth = 1
            switchButton.layer.cornerRadius = 12
            switchButton.layer.masksToBounds = true
            switchButton.addTarget(self, action: #selector(switchTapped), for: .touchUpInside)
        }

        private func configureReceiveAtLeast() {
            let configureLabel: (UILabel) -> Void = { label in
                label.font = .systemFont(ofSize: 15, weight: .medium)
                label.textColor = .h8e8e93
            }

            receiveAtLeastView.configureLeftLabel { label in
                configureLabel(label)
                label.text = L10n.colonReceiveAtLeast
            }
            receiveAtLeastView.configureRightLabel(configure: configureLabel)
        }

        private func setAtLeastText(string: String?) {
            receiveAtLeastView.configureRightLabel { label in
                label.text = string
                label.isHidden = string == nil
            }

            receiveAtLeastView.configureLeftLabel { label in
                label.isHidden = string == nil
            }
        }

        private func layout() {
            stackView.spacing = 16
            receiveAtLeastView.autoSetDimension(.height, toSize: 18)
            stackView.addArrangedSubviews {
                fromWalletView
                UIStackView(axis: .horizontal) {
                    BEStackViewSpacing(6)
                    switchButton
                    UIView.spacer
                }
                toWalletView
                #if !RELEASE
                routeLabel
                #endif
                receiveAtLeastView
            }
        }

        private func bind() {
            Driver.combineLatest(
                viewModel.minimumReceiveAmountDriver,
                viewModel.destinationWalletDriver
            )
                .map { minReceiveAmount, wallet -> String? in
                    guard let minReceiveAmount = minReceiveAmount else { return nil }

                    let formattedReceiveAmount = minReceiveAmount.toString(maximumFractionDigits: 9)

                    guard let fiatPrice = wallet?.priceInCurrentFiat else { return formattedReceiveAmount }

                    let receiveFiatPrice = (minReceiveAmount * fiatPrice).toString(maximumFractionDigits: 2)
                    let formattedReceiveFiatAmount = "(~\(Defaults.fiat.symbol)\(receiveFiatPrice))"

                    return formattedReceiveAmount + " " + formattedReceiveFiatAmount
                }
                .drive { [weak self] in
                    self?.setAtLeastText(string: $0)
                }
                .disposed(by: disposeBag)
            
            #if !RELEASE
            viewModel.routeDriver.drive(routeLabel.rx.text).disposed(by: disposeBag)
            viewModel.routeDriver.map {$0 == nil}.drive(routeLabel.rx.isHidden).disposed(by: disposeBag)
            #endif
        }

        @objc
        private func switchTapped() {
            viewModel.swapSourceAndDestination()
        }
    }
}
