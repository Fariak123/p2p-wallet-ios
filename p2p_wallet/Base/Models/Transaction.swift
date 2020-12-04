//
//  Transaction.swift
//  p2p_wallet
//
//  Created by Chung Tran on 27/11/2020.
//

import Foundation

struct Transaction {
    let signature: String // signature
    let amount: Double
    let symbol: String
    var status: Status
    var subscription: UInt64?
}

extension Transaction {
    enum Status {
        case processing, confirmed
        var localizedString: String {
            switch self {
            case .processing:
                return L10n.processing
            case .confirmed:
                return L10n.confirmed
            }
        }
    }
}
