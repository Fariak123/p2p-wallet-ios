//
//  WormholeClaimReceiving.swift
//  p2p_wallet
//
//  Created by Giang Long Tran on 06.03.2023.
//

import KeyAppUI
import Kingfisher
import SolanaSwift
import SwiftUI

struct WormholeClaimView: View {
    @ObservedObject var viewModel: WormholeClaimViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text(L10n.confirmClaimingTheTokens)
                .fontWeight(.medium)
                .apply(style: .title2)
                .padding(.top, 16)

            // Logo

            if let url = viewModel.model.icon {
                KFImage
                    .url(url)
                    .setProcessor(
                        DownsamplingImageProcessor(size: .init(width: 128, height: 128))
                            |> RoundCornerImageProcessor(cornerRadius: 64)
                    )
                    .resizable()
                    .diskCacheExpiration(.days(7))
                    .fade(duration: 0.1)
                    .frame(width: 64, height: 64)
                    .padding(.top, 28)

            } else {
                Circle()
                    .fill(Color(Asset.Colors.smoke.color))
                    .overlay(
                        Image(uiImage: .imageOutlineIcon)
                            .renderingMode(.template)
                            .foregroundColor(Color(Asset.Colors.mountain.color))
                    )
                    .clipped()
                    .frame(width: 64, height: 64)
                    .padding(.top, 28)
            }

            // Amount in crypto
            Text(viewModel.model.title)
                .fontWeight(.bold)
                .apply(style: .largeTitle)
                .padding(.top, 16)

            // Amount in currency
            if !viewModel.model.subtitle.isEmpty {
                Text(viewModel.model.subtitle)
                    .apply(style: .text2)
                    .foregroundColor(Color(Asset.Colors.mountain.color))
                    .padding(.top, 4)
            }

            // Fee
            HStack(alignment: .center) {
                // Title
                Text(L10n.fee)
                Spacer()

                // Amount
                Text(viewModel.feeAmountInFiat)
                    .skeleton(
                        with: viewModel.bundle.state.isFetching,
                        size: .init(width: 100, height: 24)
                    )

                // Button
                Button {
                    viewModel.action.send(.openFee(viewModel.bundle))
                } label: {
                    Image(uiImage: .info)
                        .resizable()
                        .foregroundColor(Color(Asset.Colors.mountain.color))
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(Asset.Colors.snow.color))
            )
            .padding(.top, 32)

            Spacer()

            // Button
            TextButtonView(title: L10n.claim(viewModel.model.title), style: .primaryWhite, size: .large) {
                viewModel.claim()
            }
            .disabled(viewModel.bundle.state.status != .ready)
            .frame(height: TextButton.Size.large.height)
        }
        .padding(.horizontal, 16)
        .background(
            Color(Asset.Colors.smoke.color)
                .ignoresSafeArea()
        )
    }
}

struct WormholeClaimView_Previews: PreviewProvider {
    static var previews: some View {
        WormholeClaimView(viewModel:
            .init(
                model: .init(
                    icon: URL(string: Token.eth.logoURI!)!,
                    title: "0.999717252 ETH",
                    subtitle: "~ $1 219.87"
                )
            )
        )
    }
}
