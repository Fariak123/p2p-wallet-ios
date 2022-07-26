import Combine
import KeyAppUI
import SolanaSwift
import SwiftUI

struct ContinueView: View {
    @ObservedObject var viewModel: ContinueViewModel

    var body: some View {
        ZStack {
            Color(Asset.Colors.lime.color)
                .edgesIgnoringSafeArea(.all)
            VStack(spacing: .zero) {
                Spacer()

                StartPageView(data: viewModel.data, subtitleFontWeight: .regular)
                    .padding(.horizontal, 40)

                Spacer()

                bottomActionsView
            }
            .edgesIgnoringSafeArea(.bottom)
        }
    }
}

extension ContinueView {
    private var bottomActionsView: some View {
        VStack(spacing: .zero) {
            TextButtonView(title: L10n.continue, style: .inverted, size: .large)
                .styled()
                .padding(.top, 20)
                .onTapGesture(perform: viewModel.continuePressed)
            TextButtonView(title: L10n.startingScreen, style: .ghostLime, size: .large)
                .styled()
                .padding(.top, 12)
                .onTapGesture(perform: viewModel.startPressed)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
        .bottomActionsStyle()
    }
}

// MARK: - Style Helpers

private extension TextButtonView {
    func styled() -> some View {
        frame(height: 56).frame(maxWidth: .infinity)
    }
}
