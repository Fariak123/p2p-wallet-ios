//
//  SheetHeaderView.swift
//  p2p_wallet
//
//  Created by Ivan on 01.10.2022.
//

import Combine
import KeyAppUI
import SwiftUI

struct SheetHeaderModifier: ViewModifier {
    let title: String
    var withSeparator: Bool = true
    let close: () -> Void

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            SheetHeaderView(title: title, withSeparator: withSeparator, close: close)
            content
        }
    }
}

extension View {
    func sheetHeader(title: String, withSeparator: Bool = true, close: @escaping () -> Void) -> some View {
        modifier(SheetHeaderModifier(title: title, withSeparator: withSeparator, close: close))
    }
}

private struct SheetHeaderView: View {
    let title: String
    let withSeparator: Bool
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Color(Asset.Colors.rain.color)
                .frame(width: 31, height: 4)
                .cornerRadius(2)
                .padding(.top, 6)
            HStack(alignment: .bottom, spacing: 0) {
                Spacer()
                Text(L10n.tokenToDeposit)
                    .foregroundColor(Color(Asset.Colors.night.color))
                    .font(uiFont: .font(of: .title3, weight: .semibold))
                    .padding(.top, 18)
                Spacer()
                Button(
                    action: {
                        close()
                    },
                    label: {
                        Image(uiImage: .closeAction)
                    }
                )
            }
            .padding(.trailing, 16)
            .padding(.leading, 32)
            .padding(.bottom, 20)
            if withSeparator {
                Color(Asset.Colors.rain.color)
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
