//
//  WalletVC.swift
//  p2p_wallet
//
//  Created by Chung Tran on 11/2/20.
//

import Foundation
import Action
import RxSwift

protocol MainScenesFactory {
    func makeWalletDetailVC(wallet: Wallet) -> WalletDetailVC
    func makeReceiveTokenViewController() -> ReceiveTokenVC
    func makeSendTokenViewController(activeWallet: Wallet?, destinationAddress: String?) -> WLModalWrapperVC
    func makeSwapTokenViewController(fromWallet wallet: Wallet?) -> SwapTokenViewController
    func makeMyProductsVC() -> MyProductsVC
    func makeProfileVC() -> ProfileVC
    func makeTokenSettingsViewController() -> TokenSettingsViewController
}

enum MainVCItem: ListItemType {
    static func placeholder(at index: Int) -> MainVCItem {
        .wallet(Wallet.placeholder(at: index))
    }
    
    var id: String {
        switch self {
        case .wallet(let wallet):
            return "\(wallet.id)#wallet"
        case .friend:
            return "friend"
        }
    }
    case wallet(Wallet)
    case friend // TODO: - Friend
    
    var wallet: Wallet? {
        switch self {
        case .wallet(let wallet):
            return wallet
        default:
            break
        }
        return nil
    }
}

class MainVC: CollectionVC<MainVCItem> {
    override var preferredNavigationBarStype: BEViewController.NavigationBarStyle {.hidden}
    let numberOfWalletsToShow = 4
    let scenesFactory: MainScenesFactory
    
    init(viewModel: ListViewModel<MainVCItem>, scenesFactory: MainScenesFactory) {
        self.scenesFactory = scenesFactory
        super.init(viewModel: viewModel)
    }
    
    // MARK: - Methods
    override func setUp() {
        super.setUp()
        view.backgroundColor = .white
        setStatusBarColor(.h1b1b1b)
    }
    
    // MARK: - Layout
    override var sections: [CollectionViewSection] {
        [
            CollectionViewSection(
                header: CollectionViewSection.Header(viewClass: ActiveWalletsSectionHeaderView.self, title: ""),
                cellType: MainWalletCell.self,
                interGroupSpacing: 30,
                itemHeight: .absolute(45),
                horizontalInterItemSpacing: NSCollectionLayoutSpacing.fixed(16),
                background: ActiveWalletsSectionBackgroundView.self
            ),
            CollectionViewSection(
                header: CollectionViewSection.Header(
                    viewClass: HiddenWalletsSectionHeaderView.self, title: "Hidden wallet"
                ),
                footer: CollectionViewSection.Footer(viewClass: WalletsSectionFooterView.self),
                cellType: MainWalletCell.self,
                interGroupSpacing: 30,
                itemHeight: .absolute(45),
                horizontalInterItemSpacing: NSCollectionLayoutSpacing.fixed(16),
                background: ActiveWalletsSectionBackgroundView.self
            ),
            CollectionViewSection(
                header: CollectionViewSection.Header(viewClass: FriendsSectionHeaderView.self, title: ""),
                cellType: FriendCell.self,
                background: FriendsSectionBackgroundView.self
            )
        ]
    }
    
    override func mapDataToSnapshot() -> NSDiffableDataSourceSnapshot<String, MainVCItem> {
        let viewModel = self.viewModel as! MainVM
        
        // initial snapshot
        var snapshot = NSDiffableDataSourceSnapshot<String, MainVCItem>()
        
        // activeWallet
        let activeWalletSections = L10n.wallets
        snapshot.appendSections([activeWalletSections])
        
        let allWallets = filterWallet(viewModel.walletsVM.items)
        
        var items = allWallets
            .filter {!$0.isHidden}
            .prefix(numberOfWalletsToShow)
            .map {MainVCItem.wallet($0)}
        switch viewModel.walletsVM.state.value {
        case .loading:
            items += [MainVCItem.placeholder(at: 0), MainVCItem.placeholder(at: 1)]
        case .loaded, .error, .initializing:
            break
        }
        snapshot.appendItems(items, toSection: activeWalletSections)
        
        // hiddenWallet
        let hiddenWalletSections = sections[2].header?.title ?? "Hidden"
        snapshot.appendSections([hiddenWalletSections])
        let hiddenItems = allWallets.filter {$0.isHidden}.map {MainVCItem.wallet($0)}
        snapshot.appendItems(hiddenItems, toSection: hiddenWalletSections)
        
        // section 2
        let friendsSection = L10n.friends
        snapshot.appendSections([friendsSection])
//        snapshot.appendItems([MainVCItem.friend], toSection: section2)
        return snapshot
    }
    
    override func setUpCell(cell: UICollectionViewCell, withItem item: MainVCItem) {
        switch item {
        case .wallet(let wallet):
            (cell as! MainWalletCell).setUp(with: wallet)
            (cell as! MainWalletCell).editAction = CocoaAction {
                let vc = self.scenesFactory.makeTokenSettingsViewController()
                self.present(vc, animated: true, completion: nil)
                return .just(())
            }
            (cell as! MainWalletCell).hideAction = CocoaAction {
                if let wallet = item.wallet {
                    (self.viewModel as? MainVM)?.walletsVM.hideWallet(wallet)
                }
                return .just(())
            }
        case .friend:
            break
        }
    }
    
    override func configureHeaderForSectionAtIndexPath(_ indexPath: IndexPath, inCollectionView collectionView: UICollectionView) -> UICollectionReusableView? {
        let header = super.configureHeaderForSectionAtIndexPath(indexPath, inCollectionView: collectionView)
        
        switch indexPath.section {
        case 0:
            if let view = header as? ActiveWalletsSectionHeaderView {
                view.openProfileAction = self.openProfile
            }
        case 2:
            if let view = header as? FriendsSectionHeaderView {
                view.receiveAction = self.receiveAction
                view.sendAction = self.sendAction()
                view.exchangeAction = self.swapAction
            }
        default:
            break
        }
        
        return header
    }
    
    override func configureFooterForSectionAtIndexPath(_ indexPath: IndexPath, inCollectionView collectionView: UICollectionView) -> UICollectionReusableView? {
        let footer = super.configureFooterForSectionAtIndexPath(indexPath, inCollectionView: collectionView)
        
        switch indexPath.section {
        case 1:
            if let view = footer as? WalletsSectionFooterView {
                view.showProductsAction = self.showAllProducts
            }
        default:
            break
        }
        
        return footer
    }
    
    // MARK: - Actions
    override func itemDidSelect(_ item: MainVCItem) {
        switch item {
        case .wallet(let wallet):
            let vc = scenesFactory.makeWalletDetailVC(wallet: wallet)
            present(vc, animated: true, completion: nil)
        default:
            break
        }
    }
    
    var receiveAction: CocoaAction {
        CocoaAction { _ in
            let vc = self.scenesFactory.makeReceiveTokenViewController()
            self.present(vc, animated: true, completion: nil)
            return .just(())
        }
    }
    
    func sendAction(address: String? = nil) -> CocoaAction {
        CocoaAction { _ in
            let vc = self.scenesFactory
                .makeSendTokenViewController(activeWallet: nil, destinationAddress: address)
            self.present(vc, animated: true, completion: nil)
            return .just(())
        }
    }
    
    var swapAction: CocoaAction {
        CocoaAction { _ in
            let vc = self.scenesFactory.makeSwapTokenViewController(fromWallet: nil)
            self.present(vc, animated: true, completion: nil)
            return .just(())
        }
    }
    
    var showAllProducts: CocoaAction {
        CocoaAction { _ in
            let vc = self.scenesFactory.makeMyProductsVC()
            self.present(vc, animated: true, completion: nil)
            return .just(())
        }
    }
    
    var openProfile: CocoaAction {
        CocoaAction { _ in
            let profileVC = self.scenesFactory.makeProfileVC()
            self.present(profileVC, animated: true, completion: nil)
            return .just(())
        }
    }
    
    // MARK: - Helpers
    func filterWallet(_ items: [Wallet]) -> [Wallet] {
        var wallets = [Wallet]()
        
        if let solWallet = items.first(where: {$0.symbol == "SOL"}) {
            wallets.append(solWallet)
        }
        wallets.append(
            contentsOf: items
                .filter {$0.symbol != "SOL"}
                .sorted(by: {$0.amountInUSD > $1.amountInUSD})
        )
        
        return wallets
    }
}
