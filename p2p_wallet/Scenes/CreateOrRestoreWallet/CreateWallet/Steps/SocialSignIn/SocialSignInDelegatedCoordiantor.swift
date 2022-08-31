// Copyright 2022 P2P Validator Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import Combine
import Foundation
import Onboarding
import SwiftUI

class SocialSignInDelegatedCoordinator: DelegatedCoordinator<SocialSignInState> {
    override func buildViewController(for state: SocialSignInState) -> UIViewController? {
        switch state {
        case .socialSelection:
            let vm = SocialSignInViewModel(parameters: socialSignInParameters())
            let vc = SocialSignInView(viewModel: vm)
            vc.viewModel.outInfo.sink { [weak self] in self?.openInfo() }
                .store(in: &subscriptions)

            vc.viewModel.outBack.sinkAsync { [stateMachine] process in
                process.start { try await stateMachine <- .signInBack }
            }.store(in: &subscriptions)

            vc.viewModel.outLogin.sinkAsync { [stateMachine] process in
                process.start { try await stateMachine <- .signIn(socialProvider: process.data) }
            }.store(in: &subscriptions)

            return UIHostingController(rootView: vc)
        case let .socialSignInAccountWasUsed(provider, usedEmail):
            let vm = SocialSignInAccountHasBeenUsedViewModel(
                email: usedEmail,
                signInProvider: provider
            )

            vm.coordinator.useAnotherAccount.sink { [stateMachine] process in
                process.start { try await stateMachine <- .signIn(socialProvider: .google) }
            }.store(in: &subscriptions)

            vm.coordinator.back.sink { [stateMachine] process in
                process.start { try await stateMachine <- .signInBack }
            }.store(in: &subscriptions)

            vm.coordinator.switchToRestoreFlow.sink { [stateMachine] process in
                process.start { try await stateMachine <- .restore(authProvider: provider, email: usedEmail) }
            }.store(in: &subscriptions)

            let vc = SocialSignInAccountHasBeenUsedView(viewModel: vm)
            return UIHostingController(rootView: vc)
        case let .socialSignInTryAgain(socialProvider, _):
            let vm = SocialSignInTryAgainViewModel(signInProvider: socialProvider)

            vm.coordinator.startScreen.sinkAsync { [weak vm, stateMachine] in
                if vm?.input.isLoading.value ?? false { return }
                vm?.input.isLoading.send(true)
                defer { vm?.input.isLoading.send(false) }

                do {
                    try await stateMachine <- .signInBack
                } catch {
                    vm?.input.onError.send(error)
                }
            }.store(in: &subscriptions)

            vm.coordinator.tryAgain.sinkAsync { [weak vm, stateMachine] in
                vm?.input.isLoading.send(true)
                defer { vm?.input.isLoading.send(false) }

                do {
                    try await stateMachine <- .signIn(socialProvider: socialProvider)
                } catch {
                    vm?.input.onError.send(error)
                }
            }.store(in: &subscriptions)

            let vc = SocialSignInTryAgainViewController(viewModel: vm)
            return vc
        default: return nil
        }
    }

    public func openInfo() {
        let vc = WLMarkdownVC(
            title: L10n.termsOfUse.uppercaseFirst,
            bundledMarkdownTxtFileName: "Terms_of_service"
        )
        rootViewController?.present(vc, animated: true)
    }

    private func socialSignInParameters() -> SocialSignInParameters {
        let content = OnboardingContentData(
            image: .introWelcomeToP2pFamily,
            title: L10n.protectingTheFunds,
            subtitle: L10n.WeUseMultiFactorAuthentication.youCanEasilyRegainAccessToTheWalletUsingSocialAccounts
        )
        let parameters = SocialSignInParameters(
            title: L10n.createAccount,
            content: content,
            appleButtonTitle: L10n.signInWithApple,
            googleButtonTitle: L10n.signInWithGoogle,
            isBackAvailable: true
        )
        return parameters
    }
}
