// Copyright 2022 P2P Validator Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import Combine
import Foundation
import KeyAppUI
import Resolver
import Send
import SolanaPricesAPIs
import SolanaSwift

class SendInputViewModel: ObservableObject {
    // MARK: - Sub view models

    let actionButtonViewModel: SendInputActionButtonViewModel
    let inputAmountViewModel: SendInputAmountViewModel
    let tokenViewModel: SendInputTokenViewModel

    @Published var currentToken: Wallet
    @Published var feeToken: Wallet

    @Published var feeTitle = L10n.fees("")
    @MainActor @Published var isFeeLoading: Bool = true
    let feeInfoPressed = PassthroughSubject<Void, Never>()
    let openFeeInfo = PassthroughSubject<Bool, Never>()

    let snackbar = PassthroughSubject<SnackBar, Never>()
    let transaction = PassthroughSubject<SendTransaction, Never>()

    var currentState: SendInputState { stateMachine.currentState }

    // MARK: - Private

    private let walletsRepository: WalletsRepository
    private let pricesService: PricesServiceType
    private let stateMachine: SendInputStateMachine
    private let sendAction: SendActionService

    private var subscriptions = Set<AnyCancellable>()

    init(recipient: Recipient) {
        let repository = Resolver.resolve(WalletsRepository.self)
        walletsRepository = repository

        let pricesService = Resolver.resolve(PricesService.self)
        self.pricesService = pricesService

        let wallets = repository.getWallets()
        let tokenInWallet = wallets
            .first(where: { $0.token.address == Token.nativeSolana.address }) ?? Wallet(token: Token.nativeSolana)
        currentToken = tokenInWallet
        let feeTokenInWallet = wallets
            .first(where: { $0.token.address == Token.usdc.address }) ?? Wallet(token: Token.usdc)
        feeToken = feeTokenInWallet

        var exchangeRate = [String: CurrentPrice]()
        var tokens = Set<Token>()
        wallets.forEach {
            exchangeRate[$0.token.symbol] = pricesService.currentPrice(for: $0.token.symbol)
            tokens.insert($0.token)
        }

        let env = UserWalletEnvironments(wallets: wallets, exchangeRate: exchangeRate, tokens: tokens)

        let state = SendInputState(
            status: .ready,
            recipient: recipient,
            token: tokenInWallet,
            tokenFee: feeTokenInWallet,
            userWalletEnvironments: env,
            amountInFiat: .zero,
            amountInToken: .zero,
            fee: .zero,
            feeInToken: .zero
        )

        let accountStorage = Resolver.resolve(AccountStorageType.self)
        stateMachine = .init(
            initialState: state,
            services: .init(
                swapService: MockedSwapService(result: nil),
                feeService: SendFeeCalculatorImpl(
                    contextManager: Resolver.resolve(),
                    env: env,
                    orcaSwap: Resolver.resolve(),
                    feeRelayer: Resolver.resolve(),
                    feeRelayerAPIClient: Resolver.resolve(),
                    solanaAPIClient: Resolver.resolve()
                )
            )
        )
        sendAction = SendActionServiceImpl(
            contextManager: Resolver.resolve(),
            solanaAPIClient: Resolver.resolve(),
            blockchainClient: Resolver.resolve(),
            feeRelayer: Resolver.resolve(),
            account: accountStorage.account
        )

        inputAmountViewModel = SendInputAmountViewModel()
        actionButtonViewModel = SendInputActionButtonViewModel()
        tokenViewModel = SendInputTokenViewModel()

        tokenViewModel.isTokenChoiceEnabled = wallets.count > 1

        bind()
    }
}

private extension SendInputViewModel {
    func bind() {
        stateMachine.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                guard let self = self else { return }
                switch value.status {
                case .error(reason: .networkConnectionError(_)):
                    self.handleConnectionError()
                default:
                    self.inputAmountViewModel.maxAmountToken = value.maxAmountInputInToken
                    self.updateFeeTitle()
                }
            }
            .store(in: &subscriptions)

        inputAmountViewModel.changeAmount
            .sinkAsync(receiveValue: { [weak self] value in
                guard let self = self else { return }
                switch value.type {
                case .token:
                    _ = await self.stateMachine.accept(action: .changeAmountInToken(value.amount))
                case .fiat:
                    _ = await self.stateMachine.accept(action: .changeAmountInFiat(value.amount))
                }
                await self.updateInputAmountView()
            })
            .store(in: &subscriptions)

        $currentToken
            .sinkAsync(receiveValue: { [weak self] value in
                guard let self = self else { return }
                await MainActor.run { self.isFeeLoading = true }
                _ = await self.stateMachine.accept(action: .changeUserToken(value))
                await MainActor.run {
                    self.inputAmountViewModel.token = value
                    self.tokenViewModel.token = value
                    self.isFeeLoading = false
                }
            })
            .store(in: &subscriptions)

        $isFeeLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                if isLoading {
                    self.feeTitle = L10n.fees("")
                    self.actionButtonViewModel.actionButton = .init(isEnabled: false, title: L10n.calculatingTheFees)
                } else {
                    Task { await self.updateInputAmountView() }
                }
            }
            .store(in: &subscriptions)

        feeInfoPressed
            .sink { [weak self] in
                guard let self = self else { return }
                self.openFeeInfo.send(self.currentState.fee == .zero)
            }
            .store(in: &subscriptions)

        inputAmountViewModel.maxAmountPressed
            .sink { [weak self] _ in
                guard let self = self else { return }
                let text: String
                if self.feeToken.mintAddress == self.currentToken.mintAddress {
                    text = L10n.calculatedBySubtractingTheAccountCreationFeeFromYourBalance
                } else {
                    text = L10n.usingTheMaximumAmount(self.currentToken.token.symbol)
                }
                self.snackbar.send(SnackBar(title: "✅", text: text))
                self.vibrate()
            }
            .store(in: &subscriptions)

        $feeToken
            .sinkAsync { [weak self] newFeeToken in
                guard let self = self else { return }
                await MainActor.run { self.isFeeLoading = true }
                _ = await self.stateMachine.accept(action: .changeFeeToken(newFeeToken))
                await MainActor.run { self.isFeeLoading = false }
            }
            .store(in: &subscriptions)

        actionButtonViewModel.$isSliderOn
            .sinkAsync(receiveValue: { [weak self] isSliderOn in
                guard let self = self else { return }
                if isSliderOn {
                    await self.send()
                }
            })
            .store(in: &subscriptions)
    }
}

private extension SendInputViewModel {
    @MainActor
    func updateInputAmountView() {
        switch currentState.status {
        case .error(.inputTooHigh):
            inputAmountViewModel.isError = true
            actionButtonViewModel.actionButton = .init(
                isEnabled: false,
                title: L10n.max(currentState.maxAmountInputInToken.tokenAmount(symbol: currentToken.token.symbol))
            )
        case let .error(.inputTooLow(minAmount)):
            inputAmountViewModel.isError = true
            actionButtonViewModel.actionButton = .init(
                isEnabled: false,
                title: L10n.min(minAmount.tokenAmount(symbol: currentToken.token.symbol))
            )
        case .error(reason: .inputZero):
            inputAmountViewModel.isError = false
            actionButtonViewModel.actionButton = .init(isEnabled: false, title: L10n.enterTheAmount)
        default:
            inputAmountViewModel.isError = false
            actionButtonViewModel.actionButton = .init(isEnabled: true, title: L10n.enterTheAmount)
        }
    }

    func vibrate() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func updateFeeTitle() {
        if currentState.fee == .zero {
            feeTitle = L10n.enjoyFreeTransactions
        } else {
            feeTitle = L10n
                .fees(
                    "\(currentState.fee.total.convertToBalance(decimals: 9).tokenAmount(symbol: feeToken.token.symbol))"
                )
        }
    }

    
    func handleConnectionError() {
        snackbar.send(SnackBar(
            title: "🥺",
            text: L10n.youHaveNoInternetConnection,
            buttonTitle: L10n.hide,
            buttonAction: { SnackBar.hide() }
        ))
    }

    func handleUnknownError() {
        snackbar
            .send(SnackBar(title: "🥺", text: L10n.somethingWentWrong, buttonTitle: L10n.hide,
                           buttonAction: { SnackBar.hide() }))
    }

    func send() async {
        do {
            let transactionId = try await sendAction.send(
                from: currentState.token,
                receiver: currentState.recipient.address,
                amount: currentState.amountInToken,
                feeWallet: currentState.tokenFee
            )
            await MainActor.run {
                self.actionButtonViewModel.showFinished = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.transaction.send(SendTransaction(transactionId: transactionId, state: self.currentState))
                }
            }
        } catch {
            print(error)
            if let error = error as? NSError,
               error.code == NSURLErrorNetworkConnectionLost || error.code == NSURLErrorNotConnectedToInternet
            {
                await MainActor.run { handleConnectionError() }
            } else {
                await MainActor.run { handleUnknownError() }
            }
        }
    }
}
