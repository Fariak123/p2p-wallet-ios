//
//  PayingFee.swift
//  p2p_wallet
//
//  Created by Chung Tran on 30/09/2021.
//

import Foundation

struct PayingFee {
    enum FeeType: Equatable {
        case liquidityProviderFee
        case accountCreationFee(token: String?)
        case orderCreationFee
        case transactionFee
        case depositWillBeReturned
        
        var headerString: String {
            switch self {
            case .liquidityProviderFee:
                return L10n.liquidityProviderFee
            case let .accountCreationFee(token: token):
                if let token = token {
                    return "\(token) \(L10n.accountCreationFee)"
                } else {
                    return L10n.accountCreationFee
                }
            case .orderCreationFee:
                return L10n.serumOrderCreationPaidOncePerPair
            case .transactionFee:
                return L10n.transactionFee
            case .depositWillBeReturned:
                return L10n.depositWillBeReturned
            }
        }
    }
    
    let type: FeeType
    let lamports: SolanaSDK.Lamports
    let token: SolanaSDK.Token
    var toString: (() -> String?)?
}

extension Array where Element == PayingFee {
    @available(*, deprecated, message: "Don't use this methods any more")
    var totalFee: (lamports: SolanaSDK.Lamports, token: SolanaSDK.Token)? {
        // exclude liquidityProviderFee
        let array = self.filter {$0.type != .liquidityProviderFee}
        
        guard !array.isEmpty,
              let token = array.first?.token
        else {
            return nil
        }
        
        let lamports = array.reduce(SolanaSDK.Lamports(0), {$0 + $1.lamports})
        
        return (lamports: lamports, token: token)
    }
    
    func transactionFees(of token: String) -> SolanaSDK.Lamports {
        filter {$0.type == .transactionFee && $0.token.symbol == token}
            .reduce(SolanaSDK.Lamports(0), {$0 + $1.lamports})
    }
    
    func all(ofToken tokenSymbol: String) -> SolanaSDK.Lamports? {
        filter {$0.token.symbol == tokenSymbol}.reduce(UInt64(0), {$0 + $1.lamports})
    }
}
