//
//  TransactionsRepository.swift
//  p2p_wallet
//
//  Created by Chung Tran on 07/04/2021.
//

import Foundation
import RxSwift

protocol TransactionsRepository {
    func getTransactionsHistory(account: String, before: String?, limit: Int) -> Single<[SolanaSDK.AnyTransaction]>
    func getTransaction(signature: String, parser: SolanaSDK.TransactionParser) -> Single<SolanaSDK.AnyTransaction>
}

extension SolanaSDK: TransactionsRepository {
    func getTransactionsHistory(account: String, before: String?, limit: Int) -> Single<[AnyTransaction]> {
        getConfirmedSignaturesForAddress2(account: account, configs: RequestConfiguration(limit: limit, before: before))
            .flatMap {activities in
                let signatures = activities.map {$0.signature}
                let parser = SolanaSDK.TransactionParser(solanaSDK: self)
                return Single.zip(signatures.map {
                    self.getTransaction(signature: $0, parser: parser)
                })
            }
    }
    
    func getTransaction(signature: String, parser: SolanaSDK.TransactionParser) -> Single<AnyTransaction> {
        getConfirmedTransaction(transactionSignature: signature)
            .flatMap { info in
                parser.parse(signature: signature, transactionInfo: info)
            }
    }
}
