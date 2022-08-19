// Copyright 2022 P2P Validator Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import Combine
import Foundation
import Onboarding
import SwiftUI

final class RestoreWalletCoordinator: Coordinator<Void> {
    // MARK: - NavigationController

    let parent: UIViewController
    let tKeyFacade: TKeyJSFacade = .init(
        wkWebView: GlobalWebView.requestWebView(),
        config: .init(
            metadataEndpoint: String.secretConfig("META_DATA_ENDPOINT") ?? "",
            torusEndpoint: String.secretConfig("TORUS_ENDPOINT") ?? "",
            torusVerifierMapping: [
                "google": String.secretConfig("TORUS_GOOGLE_VERIFIER") ?? "",
                "apple": String.secretConfig("TORUS_APPLE_VERIFIER") ?? "",
            ]
        )
    )

    let viewModel: RestoreWalletViewModel

    private var result = PassthroughSubject<Void, Never>()
    private(set) var navigationController: UINavigationController?

    let securitySetupDelegatedCoordinator: SecuritySetupDelegatedCoordinator

    init(parent: UIViewController) {
        self.parent = parent
        viewModel = RestoreWalletViewModel(tKeyFacade: tKeyFacade)

        securitySetupDelegatedCoordinator = .init(
            stateMachine: .init { [weak viewModel] event in
                try await viewModel?.stateMachine.accept(event: .securitySetup(event))
            }
        )

        super.init()
    }

    // MARK: - Methods

    override func start() -> AnyPublisher<Void, Never> {
        // Create root view controller
        let viewController = buildViewController(viewModel: viewModel) ?? UIViewController()
        navigationController = UINavigationController(rootViewController: viewController)
        navigationController?.modalPresentationStyle = .fullScreen

        viewModel.stateMachine
            .stateStream
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.navigate() }
            .store(in: &subscriptions)

        parent.present(navigationController!, animated: true)

        return result.eraseToAnyPublisher()
    }

    // MARK: Navigation

    private func navigate() {
        guard let navigationController = navigationController else { return }
        let vc = buildViewController(viewModel: viewModel) ?? UIViewController()
        navigationController.setViewControllers([vc], animated: true)
    }

    private func buildViewController(viewModel: RestoreWalletViewModel) -> UIViewController? {
        var stateMachine = viewModel.stateMachine
        let state = viewModel.stateMachine.currentState
        switch state {
        case .restore:
            let chooseRestoreOptionViewModel = ChooseRestoreOptionViewModel(options: viewModel
                .availableRestoreOptions)
            chooseRestoreOptionViewModel.optionChosen.sinkAsync(receiveValue: { option in
                switch option {
                case .keychain:
                    try await stateMachine <- .signInWithKeychain
                default:
                    break
                }
            })
                .store(in: &subscriptions)
            let view = ChooseRestoreOptionView(viewModel: chooseRestoreOptionViewModel)
            return UIHostingController(rootView: view)
        case let .securitySetup(_, _, _, _, innerState):
            return securitySetupDelegatedCoordinator.buildViewController(for: innerState)
        case let .restoredData(solPrivateKey: solPrivateKey, ethPublicKey: ethPublicKey):
            return RestoreResultViewController(sol: solPrivateKey, eth: ethPublicKey)
        case let .signInKeychain(accounts):
            let vm = ICloudRestoreViewModel(accounts: accounts)

            vm.coordinatorIO.back.sink { process in
                process.start { try await stateMachine <- .back }
            }.store(in: &subscriptions)

            vm.coordinatorIO.info.sink { _ in
                // TODO: show info screen
            }.store(in: &subscriptions)

            vm.coordinatorIO.restore.sink { process in
                process.start {
                    try await stateMachine <- .restoreICloudAccount(account: process.data)
                }
            }.store(in: &subscriptions)

            return UIHostingController(rootView: ICloudRestoreScreen(viewModel: vm))
        case .signInSeed:
            fatalError()
        case .enterPhone:
            fatalError()
        case let .enterOTP(phoneNumber: phoneNumber):
            fatalError()
        case let .social(result: result):
            fatalError()
        }
    }
}
