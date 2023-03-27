//
//  WormholeClaimFee.swift
//  p2p_wallet
//
//  Created by Giang Long Tran on 06.03.2023.
//

import KeyAppKitCore
import KeyAppUI
import SwiftUI
import Wormhole

struct WormholeClaimFee: View {
    @ObservedObject var viewModel: WormholeClaimFeeViewModel

    var body: some View {
        VStack {
            Image(uiImage: .fee)
                .padding(.top, 33)

            HStack {
                Circle()
                    .fill(Color(Asset.Colors.smoke.color))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(uiImage: .lightningFilled)
                            .renderingMode(.template)
                            .resizable()
                            .foregroundColor(Color(Asset.Colors.mountain.color))
                            .frame(width: 15, height: 21.5)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.enjoyFreeTransactions)
                        .fontWeight(.semibold)
                        .apply(style: .text1)
                    Text(L10n.AllTransactionsOverAreFree.keyAppWillCoverAllFeesForYou("$50"))
                        .apply(style: .text4)
                        .multilineTextAlignment(.leading)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.all, 16)
            .background(Color(Asset.Colors.cloud.color))
            .cornerRadius(12)
            .padding(.top, 20)

            VStack(spacing: 24) {
                if let receive = viewModel.adapter?.receive {
                    WormholeFeeView(
                        title: "You will get",
                        subtitle: receive.crypto,
                        detail: receive.fiat,
                        isFree: receive.isFree
                    )
                }

                if let networkFee = viewModel.adapter?.networkFee {
                    WormholeFeeView(
                        title: "Network Fee",
                        subtitle: networkFee.crypto,
                        detail: networkFee.fiat,
                        isFree: networkFee.isFree
                    )
                }

                if let accountsFee = viewModel.adapter?.accountCreationFee {
                    WormholeFeeView(
                        title: "Account creation Fee",
                        subtitle: accountsFee.crypto,
                        detail: accountsFee.fiat,
                        isFree: accountsFee.isFree
                    )
                }

                if let wormholeBridgeAndTrxFee = viewModel.adapter?.wormholeBridgeAndTrxFee {
                    WormholeFeeView(
                        title: "Wormhole Bridge and Transaction Fee",
                        subtitle: wormholeBridgeAndTrxFee.crypto,
                        detail: wormholeBridgeAndTrxFee.fiat,
                        isFree: wormholeBridgeAndTrxFee.isFree
                    )
                }
            }
            .padding(.top, 16)

            Button(
                action: {
                    viewModel.close()
                },
                label: {
                    Text(L10n.ok)
                        .font(uiFont: TextButton.Style.second.font(size: .large))
                        .foregroundColor(Color(TextButton.Style.second.foreground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(TextButton.Style.second.backgroundColor))
                        .cornerRadius(12)
                }
            )
            .padding(.top, 20)
        }
        .padding(.horizontal, 16)
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(UIColor(red: 0.82, green: 0.82, blue: 0.839, alpha: 1)))
                .frame(width: 30, height: 4)
                .padding(.top, 6),
            alignment: .top
        )
    }
}

private struct WormholeFeeView: View {
    let title: String
    let subtitle: String
    let detail: String
    let isFree: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .apply(style: .text3)
                Text(subtitle)
                    .apply(style: .label1)
                    .foregroundColor(Color(isFree ? Asset.Colors.mint.color : Asset.Colors.mountain.color))
            }
            Spacer()
            Text(detail)
                .apply(style: .label1)
                .foregroundColor(Color(Asset.Colors.mountain.color))
        }
    }
}

struct WormholeClaimFee_Previews: PreviewProvider {
    static var previews: some View {
        WormholeClaimFee(
            viewModel: .init(
                receive: ("0.999717252 ETH", "~ $1,215.75", false),
                networkFee: ("Paid by Key App", "Free", true),
                accountCreationFee: ("0.999717252 WETH", "~ $1,215.75", false),
                wormholeBridgeAndTrxFee: ("0.999717252 WETH", "~ $1,215.75", false)
            )
        )
    }
}
