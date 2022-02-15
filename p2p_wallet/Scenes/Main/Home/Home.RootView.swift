//
//  Home.RootView.swift
//  p2p_wallet
//
//  Created by Chung Tran on 28/10/2021.
//

import Action
import BECollectionView
import BEPureLayout
import RxSwift
import UIKit

extension Home {
    class RootView: BECompositionView {
        private let disposeBag = DisposeBag()
        private let viewModel: HomeViewModelType
        
        // swiftlint:disable weak_delegate
        private var bannersDelegate: UICollectionViewDelegate!
        private var bannersDataSource: BannersCollectionViewDataSource!
        private var headerViewScrollDelegate = HeaderScrollDelegate()
        
        private var collectionView: BEStaticSectionsCollectionView!
        
        init(viewModel: HomeViewModelType) {
            self.viewModel = viewModel
            super.init(frame: .zero)
        }
        
        override func build() -> UIView {
            BESafeArea {
                BEVStack {
                    BEVStack {
                        // Title
                        BEHStack {
                            UILabel(textAlignment: .center)
                                .setupWithType(UILabel.self) { label in
                                    let p2pWallet = NSMutableAttributedString()
                                        .text(L10n.p2PWallet, size: 17, weight: .semibold)
                                        .text(" ")
                                        .text(L10n.beta, size: 17, weight: .semibold, color: .secondaryLabel)
                                    label.attributedText = p2pWallet
                                }
                        }.padding(.init(x: 0, y: 12))
                        
                        // Indicator
                        WLStatusIndicatorView(forAutoLayout: ()).setupWithType(WLStatusIndicatorView.self) { view in
                            viewModel.currentPricesDriver
                                .map { $0.state }
                                .drive(onNext: { [weak view] state in
                                    switch state {
                                    case .notRequested:
                                        view?.isHidden = true
                                    case .loading:
                                        view?.setUp(state: .loading, text: L10n.updatingPrices)
                                    case .loaded:
                                        view?.setUp(state: .success, text: L10n.pricesUpdated)
                                    case .error:
                                        view?.setUp(state: .error, text: L10n.errorWhenUpdatingPrices)
                                    }
                                })
                                .disposed(by: disposeBag)
                        }
                    }
                    
                    BEZStack {
                        // Tokens
                        BEZStackPosition(mode: .fill) {
                            WalletsCollectionView(
                                walletsRepository: viewModel.walletsRepository,
                                activeWalletsSection: .init(
                                    index: 0,
                                    viewModel: viewModel.walletsRepository,
                                    cellType: WalletCell.self
                                ),
                                hiddenWalletsSection: HiddenWalletsSection(
                                    index: 1,
                                    viewModel: viewModel.walletsRepository,
                                    header: .init(viewClass: HiddenWalletsSectionHeaderView.self)
                                )
                            ).setupWithType(WalletsCollectionView.self) { collectionView in
                                self.collectionView = collectionView
                                collectionView.delegate = self
                                collectionView.scrollDelegate = headerViewScrollDelegate
                                collectionView.walletCellEditAction = Action<Wallet, Void> { [weak self] wallet in
                                    self?.viewModel.navigate(to: .walletSettings(wallet: wallet))
                                    return .just(())
                                }
                                collectionView.showHideHiddenWalletsAction = CocoaAction { [weak self] in
                                    self?.viewModel.walletsRepository.toggleIsHiddenWalletShown()
                                    return .just(())
                                }
                                collectionView.contentInset.modify(dTop: 220, dBottom: 50)
                                collectionView.refresh()
                            }
                        }
    
                        BEZStackPosition(mode: .pinEdges(top: true, left: true, bottom: false, right: true)) {
                            FloatingHeaderView()
                                .setupWithType(FloatingHeaderView.self) { view in
                                    headerViewScrollDelegate.headerView = view
                                    let walletsRepository = viewModel.walletsRepository
                                    walletsRepository
                                        .dataObservable
                                        .withLatestFrom(walletsRepository.stateObservable, resultSelector: { ($0 ?? [], $1) })
                                        .asDriver(onErrorJustReturn: ([], .loaded))
                                        .drive(view.balanceView.rx.balance)
                                        .disposed(by: disposeBag)
                                }
                                .padding(.init(x: 18, y: 0))
                        }
                    }
                }
            }
        }
    }
}

extension Home.RootView: BECollectionViewDelegate {
    func beCollectionView(collectionView: BECollectionViewBase, didSelect item: AnyHashable) {
        guard let wallet = item as? Wallet else { return }
        viewModel.navigate(to: .walletDetail(wallet: wallet))
    }
}
