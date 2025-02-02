import AnalyticsManager
import Combine
import Foundation
import Resolver
import SafariServices
import SolanaSwift
import SwiftUI
import Moonpay

final class BuyCoordinator: Coordinator<Void> {
    private var navigationController: UINavigationController!
    private let presentingViewController: UIViewController?
    private let context: Context
    private var shouldPush = true
    private var defaultToken: Token?
    private let targetTokenSymbol: String?

    private let vcPresentedPercentage = PassthroughSubject<CGFloat, Never>()
    @Injected private var analyticsManager: AnalyticsManager

    init(
        navigationController: UINavigationController? = nil,
        context: Context,
        defaultToken: Token? = nil,
        presentingViewController: UIViewController? = nil,
        shouldPush: Bool = true,
        targetTokenSymbol: String? = nil
    ) {
        self.navigationController = navigationController
        self.presentingViewController = presentingViewController
        self.context = context
        self.shouldPush = shouldPush
        self.defaultToken = defaultToken
        self.targetTokenSymbol = targetTokenSymbol
    }

    override func start() -> AnyPublisher<Void, Never> {
        let result = PassthroughSubject<Void, Never>()
        let viewModel = BuyViewModel(defaultToken: defaultToken, targetSymbol: targetTokenSymbol)
        let viewController = UIHostingController(rootView: BuyView(viewModel: viewModel))
        viewController.title = L10n.buy
        viewController.hidesBottomBarWhenPushed = true
        if navigationController == nil {
            navigationController = UINavigationController(rootViewController: viewController)
        }
        
        if let presentingViewController = presentingViewController {
            DispatchQueue.main.async {
                presentingViewController.show(self.navigationController, sender: nil)
            }
        } else {
            if shouldPush {
                navigationController?.interactivePopGestureRecognizer?.addTarget(self, action: #selector(onGesture))
                navigationController?.pushViewController(viewController, animated: true)
            } else {
                let navigation = UINavigationController(rootViewController: viewController)
                navigationController = navigation
                navigationController?.present(navigation, animated: true)
            }
        }

        analyticsManager.log(event: .buyScreenOpened(lastScreen: context == .fromHome ? "Main_Screen" : "Token_Screen"))

        viewController.onClose = {
            result.send()
        }
        
        viewController.navigationItem.largeTitleDisplayMode = .never

        viewModel.coordinatorIO.showDetail
            .receive(on: RunLoop.main)
            .flatMap { [unowned self] exchangeOutput, exchangeRate, currency, token in
                self.coordinate(to:
                    TransactionDetailsCoordinator(
                        controller: viewController,
                        model: .init(
                            price: exchangeRate,
                            purchaseCost: exchangeOutput.purchaseCost,
                            processingFee: exchangeOutput.processingFee,
                            networkFee: exchangeOutput.networkFee,
                            total: exchangeOutput.total,
                            currency: currency,
                            token: token
                        )
                    ))
            }.sink(receiveValue: { _ in })
            .store(in: &subscriptions)

        viewModel.coordinatorIO.showTokenSelect.flatMap { [unowned self] tokens in
            self.coordinate(
                to: BuySelectCoordinator<TokenCellViewItem, BuySelectTokenCellView>(
                    title: L10n.coinsToBuy,
                    controller: viewController,
                    items: tokens,
                    contentHeight: 395,
                    selectedModel: tokens.first { $0.token.symbol == viewModel.token.symbol }
                )
            ).eraseToAnyPublisher()
        }.compactMap { result in
            switch result {
            case let .result(model):
                return model.token
            default:
                return nil
            }
        }
        .assignWeak(to: \.value, on: viewModel.coordinatorIO.tokenSelected)
        .store(in: &subscriptions)

        viewModel.coordinatorIO.showFiatSelect.flatMap { [unowned self] fiats in
            self.coordinate(
                to: BuySelectCoordinator<Fiat, FiatCellView>(
                    title: L10n.currency,
                    controller: viewController,
                    items: fiats,
                    contentHeight: 436,
                    selectedModel: viewModel.fiat
                )
            ).eraseToAnyPublisher()
        }.compactMap { result in
            switch result {
            case let .result(model):
                return model
            default:
                return nil
            }
        }
        .assignWeak(to: \.value, on: viewModel.coordinatorIO.fiatSelected)
        .store(in: &subscriptions)

        vcPresentedPercentage.eraseToAnyPublisher()
            .sink(receiveValue: { val in
                viewModel.coordinatorIO.navigationSlidingPercentage.send(val)
            })
            .store(in: &subscriptions)

        viewModel.coordinatorIO.buy.sink(receiveValue: { [weak self] url in
            let vc = SFSafariViewController(url: url)
            vc.modalPresentationStyle = .automatic
            viewController.present(vc, animated: true)

            vc.onClose = { [weak self] in
                self?.analyticsManager.log(event: .moonpayWindowClosed)
            }
        }).store(in: &subscriptions)

        viewModel.coordinatorIO.license
            .sink(receiveValue: { url in
                let vc = SFSafariViewController(url: url)
                vc.modalPresentationStyle = .automatic
                viewController.present(vc, animated: true)
            })
            .store(in: &subscriptions)
        viewModel.coordinatorIO.close
            .sink(receiveValue: { [unowned self] in
                navigationController.popViewController(animated: true)
            })
            .store(in: &subscriptions)
        viewModel.coordinatorIO.chooseCountry
            .sink(receiveValue: { [weak self] selectedCountry in
                guard let self else { return }
                
                let selectCountryViewModel = SelectCountryViewModel(selectedCountry: selectedCountry)
                let selectCountryViewController = SelectCountryView(viewModel: selectCountryViewModel)
                    .asViewController(withoutUIKitNavBar: false)
                viewController.navigationController?.pushViewController(selectCountryViewController, animated: true)
                
                selectCountryViewModel.selectCountry
                    .sink(receiveValue: { item in
                        viewModel.countrySelected(item.0, buyAllowed: item.buyAllowed)
                        viewController.navigationController?.popViewController(animated: true)
                    })
                    .store(in: &self.subscriptions)
                selectCountryViewModel.currentSelected
                    .sink(receiveValue: {
                        viewController.navigationController?.popViewController(animated: true)
                    })
                    .store(in: &self.subscriptions)
            })
            .store(in: &subscriptions)
        
        return result.prefix(1).eraseToAnyPublisher()
    }

    // MARK: - Gesture

    private var currentTransitionCoordinator: UIViewControllerTransitionCoordinator?

    @objc private func onGesture(sender: UIGestureRecognizer) {
        switch sender.state {
        case .began, .changed:
            if let ct = navigationController.transitionCoordinator {
                currentTransitionCoordinator = ct
            }
        case .cancelled, .ended:
            //            currentTransitionCoordinator = nil
            break
        case .possible, .failed:
            break
        @unknown default:
            break
        }
//        if let currentTransitionCoordinator = currentTransitionCoordinator {
//            vcPresentedPercentage.send(currentTransitionCoordinator.percentComplete)
//        }
        vcPresentedPercentage.send(navigationController.transitionCoordinator?.percentComplete ?? 1)
    }
}

// MARK: - Context

extension BuyCoordinator {
    enum Context {
        case fromHome
        case fromToken
        case fromRenBTC
        case fromInvest
        case fromHistory

        var screenName: String {
            switch self {
            case .fromHome: return "MainScreen"
            case .fromToken: return "TokenScreen"
            case .fromRenBTC: return "RenBTCScreen"
            case .fromInvest: return "SolendScreen"
            case .fromHistory: return "HistoryScreen"
            }
        }
    }
}
