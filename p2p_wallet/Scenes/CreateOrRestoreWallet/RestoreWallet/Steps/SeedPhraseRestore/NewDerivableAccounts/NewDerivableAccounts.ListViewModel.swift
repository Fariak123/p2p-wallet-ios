//
//  DerivableAccounts.ListViewModel.swift
//  p2p_wallet
//
//  Created by Chung Tran on 19/05/2021.
//

import BECollectionView_Combine
import Foundation
import Resolver
import SolanaPricesAPIs
import SolanaSwift

protocol NewDerivableAccountsListViewModelType: BECollectionViewModelType {
    func cancelRequest()
    func reload()
    func setDerivableType(_ derivableType: DerivablePath.DerivableType)
}

extension NewDerivableAccounts {
    class ListViewModel: BECollectionViewModel<DerivableAccount> {
        // MARK: - Dependencies

        @Injected private var pricesFetcher: SolanaPricesAPI
        @Injected private var solanaAPIClient: SolanaAPIClient

        // MARK: - Properties

        private let phrases: [String]
        var derivableType: DerivablePath.DerivableType?

        fileprivate let cache = Cache()

        init(phrases: [String]) {
            self.phrases = phrases
            super.init(initialData: [])
        }

        deinit {
            print("\(String(describing: self)) deinited")
        }

        override func createRequest() async throws -> [DerivableAccount] {
            let accounts = try await createDerivableAccounts()
            Task {
                try? await(
                    self.fetchSOLPrice(),
                    self.fetchBalances(accounts: accounts.map(\.info.publicKey.base58EncodedString))
                )
            }
            return accounts
        }

        private func createDerivableAccounts() async throws -> [DerivableAccount] {
            let phrases = self.phrases
            guard let derivableType else {
                throw SolanaError.unknown
            }
            return try await withThrowingTaskGroup(of: (Int, KeyPair).self) { group in
                var accounts = [(Int, DerivableAccount)]()

                for i in 0 ..< 5 {
                    group.addTask(priority: .userInitiated) {
                        (i, try await KeyPair(
                            phrase: phrases,
                            network: Defaults.apiEndPoint.network,
                            derivablePath: .init(type: derivableType, walletIndex: i)
                        ))
                    }
                }

                for try await(index, account) in group {
                    accounts.append(
                        (index, .init(
                            derivablePath: .init(type: derivableType, walletIndex: index),
                            info: account,
                            amount: await self.cache.balanceCache[account.publicKey.base58EncodedString],
                            price: await self.cache.solPriceCache,
                            isBlured: false
                        ))
                    )
                }

                return accounts.sorted(by: { $0.0 < $1.0 }).map(\.1)
            }
        }

        private func fetchSOLPrice() async throws {
            if await cache.solPriceCache != nil { return }

            try Task.checkCancellation()

            let solPrice = try await pricesFetcher.getCurrentPrices(coins: [.nativeSolana], toFiat: Defaults.fiat.code)
                .first?.value?.value ?? 0
            await cache.save(solPrice: solPrice)

            try Task.checkCancellation()

            if state == .loaded {
                let data = data.map { account -> DerivableAccount in
                    var account = account
                    account.price = solPrice
                    return account
                }
                overrideData(by: data)
            }
        }

        private func fetchBalances(accounts: [String]) async throws {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for account in accounts {
                    group.addTask {
                        try await self.fetchBalance(account: account)
                    }
                    try Task.checkCancellation()
                    for try await _ in group {}
                }
            }
        }

        private func fetchBalance(account: String) async throws {
            if await cache.balanceCache[account] != nil {
                return
            }

            try Task.checkCancellation()

            let amount = try await solanaAPIClient.getBalance(account: account, commitment: nil)
                .convertToBalance(decimals: 9)

            try Task.checkCancellation()
            await cache.save(account: account, amount: amount)

            try Task.checkCancellation()
            if state == .loaded {
                updateItem(
                    where: { $0.info.publicKey.base58EncodedString == account },
                    transform: { account in
                        var account = account
                        account.amount = amount
                        return account
                    }
                )
            }
        }
    }
}

extension NewDerivableAccounts.ListViewModel: NewDerivableAccountsListViewModelType {
    func cancelRequest() {
        task?.cancel()
    }

    func setDerivableType(_ derivableType: DerivablePath.DerivableType) {
        self.derivableType = derivableType
    }
}
