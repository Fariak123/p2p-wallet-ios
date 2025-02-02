//
//  RendableAccountDetail.swift
//  p2p_wallet
//
//  Created by Giang Long Tran on 19.02.2023.
//

import Foundation
import SolanaSwift

protocol RendableAccountDetail {
    var title: String { get }

    var amountInToken: String { get }
    var amountInFiat: String { get }

    var actions: [RendableAccountDetailAction] { get }
    var onAction: (RendableAccountDetailAction) -> Void { get }
}

enum RendableAccountDetailAction: Identifiable {
    case buy
    case receive(ReceiveParam)
    case send
    case swap
}

extension RendableAccountDetailAction {
    enum ReceiveParam {
        case wallet(Wallet)
        case none
    }

    var id: Int {
        switch self {
        case .buy:
            return 0
        case .receive:
            return 1
        case .send:
            return 2
        case .swap:
            return 3
        }
    }

    var title: String {
        switch self {
        case .buy:
            return L10n.buy
        case .receive:
            return L10n.receive
        case .send:
            return L10n.send
        case .swap:
            return L10n.swap
        }
    }

    var icon: UIImage {
        switch self {
        case .receive:
            return .buttonReceive
        case .buy:
            return .buttonBuy
        case .send:
            return .buttonSend
        case .swap:
            return .buttonSwap
        }
    }
}
