// Copyright 2022 P2P Validator Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import KeyAppUI
import SwiftUI

struct PincodeChangeStartView: View {
    var startChanging: (() -> Void)?
    @State var isOn: Bool = false

    var body: some View {
        ExplainLayoutView {
            VStack {
                Image(uiImage: .pincodeIllustration)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 192)
                Text(L10n.pinCode)
                    .fontWeight(.bold)
                    .apply(style: .title1)
                    .padding(.bottom, 48)
            }
        } content: {
            VStack {
                VStack(spacing: 12) {
                    ExplainText(text: L10n.KeepYourPinSafe.hideYourPinFromOtherPeople)
                    ExplainText(text: L10n.donTUseTheSamePinForMultipleAccounts)
                }
                .padding(.leading, 12)
                .padding(.trailing, 16)
                .padding(.top, 24)

                Spacer()

                BottomActionContainer {
                    SliderButtonView(
                        title: L10n.changeMyPIN,
                        image: Asset.Icons.key.image,
                        style: .white,
                        isOn: $isOn
                    )
                        .accessibilityIdentifier("PincodeChangeStartView.ExplainLayoutView.SliderButtonView")
                        .onChange(of: isOn, perform: { newValue in
                            if newValue {
                                startChanging?()
                                isOn = false
                            }
                        })
                        .frame(height: 56)
                }
            }
        } hint: {
            SwiftUI.EmptyView()
        }
    }
}

struct PincodeChangeInfoView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PincodeChangeStartView()
                .navigationBarTitle(Text("Pincode"))
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
