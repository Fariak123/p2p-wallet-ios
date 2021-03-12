//
//  TokenSettingsViewModel.swift
//  p2p_wallet
//
//  Created by Chung Tran on 25/02/2021.
//

import UIKit
import RxSwift
import RxCocoa
import Action

enum TokenSettingsNavigatableScene {
    case alert(title: String?, description: String)
    case closeConfirmation
    case processTransaction
}

class TokenSettingsViewModel: ListViewModel<TokenSettings> {
    // MARK: - Properties
    let walletsVM: WalletsVM
    let pubkey: String
    let solanaSDK: SolanaSDK
    let transactionManager: TransactionsManager
    let accountStorage: KeychainAccountStorage
    var wallet: Wallet? {walletsVM.items.first(where: {$0.pubkey == pubkey})}
    lazy var processTransactionViewModel: ProcessTransactionViewModel = {
        let viewModel = ProcessTransactionViewModel(transactionsManager: transactionManager)
        viewModel.tryAgainAction = CocoaAction {
            self.closeWallet()
            return .just(())
        }
        return viewModel
    }()
    
    // MARK: - Subject
    let navigationSubject = PublishSubject<TokenSettingsNavigatableScene>()
//    private let wallet = BehaviorRelay<Wallet?>(value: nil)
    
    // MARK: - Input
//    let textFieldInput = BehaviorRelay<String?>(value: nil)
    init(walletsVM: WalletsVM, pubkey: String, solanaSDK: SolanaSDK, transactionManager: TransactionsManager, accountStorage: KeychainAccountStorage) {
        self.walletsVM = walletsVM
        self.pubkey = pubkey
        self.solanaSDK = solanaSDK
        self.transactionManager = transactionManager
        self.accountStorage = accountStorage
        super.init()
    }
    
    override func bind() {
        super.bind()
        walletsVM.dataObservable
            .map {$0?.first(where: {$0.pubkey == self.pubkey})}
            .map {wallet -> [TokenSettings] in
                [
                    .visibility(!(wallet?.isHidden ?? false)),
                    .close
                ]
            }
            .subscribe(onNext: { (settings) in
                self.items = settings
                self.state.accept(.loaded(settings))
            })
            .disposed(by: disposeBag)
    }
    
    override func reload() {}
    
    // MARK: - Actions
    @objc func toggleHideWallet() {
        guard let wallet = wallet else {return}
        if wallet.isHidden {
            walletsVM.unhideWallet(wallet)
        } else {
            walletsVM.hideWallet(wallet)
        }
    }
    
    @objc func showProcessingAndClose() {
        navigationSubject.onNext(.processTransaction)
        closeWallet()
    }
    
    private func closeWallet() {
        var transaction = Transaction(
            type: .send,
            symbol: "SOL",
            status: .processing
        )
        
        self.processTransactionViewModel.transactionHandler.accept(
            TransactionHandler(transaction: transaction)
        )
        
        Single.zip(
            solanaSDK.closeTokenAccount(tokenPubkey: pubkey),
            solanaSDK.getCreatingTokenAccountFee().catchErrorJustReturn(0)
        )
            .subscribe(onSuccess: { signature, fee in
                transaction.amount = fee.convertToBalance(decimals: 9)
                transaction.signatureInfo = .init(signature: signature)
                self.processTransactionViewModel.transactionHandler.accept(
                    TransactionHandler(transaction: transaction)
                )
                self.transactionManager.process(transaction)
                self.walletsVM.removeItem(where: {$0.pubkey == self.pubkey})
            }, onError: {error in
                self.processTransactionViewModel.transactionHandler.accept(
                    TransactionHandler(transaction: transaction, error: error)
                )
            })
            .disposed(by: disposeBag)
    }
}
