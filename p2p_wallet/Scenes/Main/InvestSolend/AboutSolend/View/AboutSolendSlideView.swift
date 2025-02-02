//
//  AboutSolendSlideView.swift
//  p2p_wallet
//
//  Created by Ivan on 05.10.2022.
//

import KeyAppUI
import SwiftUI

struct AboutSolendSlideView: View {
    let image: UIImage
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
            Text(title)
                .fontWeight(.bold)
                .apply(style: .title3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(Color(Asset.Colors.night.color))
                .font(uiFont: .font(of: .text2))
                .padding(.horizontal, 20)
        }
    }
}

struct AboutSolendSlideView_Previews: PreviewProvider {
    static var previews: some View {
        AboutSolendSlideView(
            image: .whatIsSolendSecond,
            title: "Earn interest on your crypto",
            subtitle: "Deposit with interest\nDeposit USDT or USDC and get your\nguaranteed yield on it."
        )
    }
}
