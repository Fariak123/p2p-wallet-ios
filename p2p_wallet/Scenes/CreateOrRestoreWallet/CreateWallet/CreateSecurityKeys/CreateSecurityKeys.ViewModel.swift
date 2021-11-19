//
//  CreateSecurityKeys.ViewModel.swift
//  p2p_wallet
//
//  Created by Chung Tran on 22/02/2021.
//

import UIKit
import RxSwift
import RxCocoa

protocol CreateSecurityKeysViewModelType: AnyObject {
    var navigationDriver: Driver<CreateSecurityKeys.NavigatableScene?> { get }
    var phrasesDriver: Driver<[String]> { get }
    var errorSignal: Signal<String> { get }
    var isCheckboxSelectedDriver: Driver<Bool> { get }
    
    func toggleCheckbox()
    func createPhrases()
    func copyToClipboard()
    func saveToICloud()
    func next()
    func back()
    func verifyPhrase()
    func termsAndConditions()
}

extension CreateSecurityKeys {
    class ViewModel {
        // MARK: - Dependencies
        @Injected private var accountStorage: KeychainAccountStorage
        @Injected private var analyticsManager: AnalyticsManagerType
        @Injected private var createWalletViewModel: CreateWalletViewModelType
        
        // MARK: - Properties
        private let disposeBag = DisposeBag()
        
        // MARK: - Subjects
        private let navigationSubject = BehaviorRelay<NavigatableScene?>(value: nil)
        private let phrasesSubject = BehaviorRelay<[String]>(value: [])
        private let errorSubject = PublishRelay<String>()
        private let isCheckboxSelectedSubject = BehaviorRelay<Bool>(value: false)
        
        // MARK: - Initializer
        init() {
            createPhrases()
        }
    }
}

extension CreateSecurityKeys.ViewModel: CreateSecurityKeysViewModelType {
    var navigationDriver: Driver<CreateSecurityKeys.NavigatableScene?> {
        navigationSubject.asDriver()
    }

    var phrasesDriver: Driver<[String]> {
        phrasesSubject.asDriver()
    }
    
    var errorSignal: Signal<String> {
        errorSubject.asSignal()
    }
    
    var isCheckboxSelectedDriver: Driver<Bool> {
        isCheckboxSelectedSubject.asDriver()
    }
    
    // MARK: - Actions
    func toggleCheckbox() {
        isCheckboxSelectedSubject.accept(!isCheckboxSelectedSubject.value)
    }
    
    func createPhrases() {
        let mnemonic = Mnemonic()
        phrasesSubject.accept(mnemonic.phrase)
        isCheckboxSelectedSubject.accept(false)
    }
    
    @objc func copyToClipboard() {
        analyticsManager.log(event: .createWalletCopySeedClick)
        UIApplication.shared.copyToClipboard(phrasesSubject.value.joined(separator: " "), alertMessage: L10n.seedPhraseCopiedToClipboard)
    }
    
    @objc func saveToICloud() {
        analyticsManager.log(event: .createWalletBackupToIcloudClick)
        let result = accountStorage.saveToICloud(
            account: .init(
                name: nil,
                phrase: phrasesSubject.value.joined(separator: " "),
                derivablePath: .default
            )
        )
        
        if result {
            UIApplication.shared.showToast(message: "✅ " + L10n.savedToICloud)
            createWalletViewModel.handlePhrases(phrasesSubject.value)
        } else {
            errorSubject.accept(L10n.SecurityKeyCanTBeSavedIntoIcloud.pleaseTryAgain)
        }
    }

    func termsAndConditions() {
        navigationSubject.accept(.termsAndConditions)
    }
    
    func verifyPhrase() {
        createWalletViewModel.verifyPhrase(phrasesSubject.value)
    }
    
    @objc func next() {
        if isCheckboxSelectedSubject.value {
            analyticsManager.log(event: .createWalletIHaveSavedWordsClick)
        }
        analyticsManager.log(event: .createWalletNextClick)
        createWalletViewModel.handlePhrases(self.phrasesSubject.value)
    }
    
    @objc func back() {
        createWalletViewModel.back()
    }
}
