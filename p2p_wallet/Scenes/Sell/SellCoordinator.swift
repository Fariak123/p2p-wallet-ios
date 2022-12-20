import Combine
import Foundation
import SwiftUI
import UIKit
import SafariServices

enum SellCoordinatorResult {
    case completed
    case none
}

final class SellCoordinator: Coordinator<SellCoordinatorResult> {
    private let navigationController: UINavigationController
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    private let viewModel = SellViewModel()
    private let resultSubject = PassthroughSubject<SellCoordinatorResult, Never>()
    override func start() -> AnyPublisher<SellCoordinatorResult, Never> {
        // create viewController
        let vc = UIHostingController(rootView: SellView(viewModel: viewModel))
        vc.hidesBottomBarWhenPushed = true
        navigationController.pushViewController(vc, animated: true)
        
        // scene navigation
        viewModel.navigationPublisher
            .compactMap {$0}
            .flatMap { [unowned self, unowned vc] in
                navigate(to: $0, mainSellVC: vc)
            }
            .sink { _ in }
            .store(in: &subscriptions)

        return Publishers.Merge(
            vc.deallocatedPublisher().map { SellCoordinatorResult.none },
            resultSubject.eraseToAnyPublisher()
        )
            .prefix(1)
            .eraseToAnyPublisher()
    }

    // MARK: - Navigation

    private func navigate(to scene: SellNavigation, mainSellVC: UIViewController) -> AnyPublisher<Void, Never> {
        switch scene {
        case .webPage(let url):
            return navigateToProviderWebPage(url: url)
                .deallocatedPublisher()
                .handleEvents(receiveOutput: { [unowned self] _ in
                    viewModel.warmUp()
                }).eraseToAnyPublisher()

        case .showPending(let transactions, let fiat):
            return Publishers.MergeMany(
                transactions.map { transaction in
                    coordinate(
                        to: SellPendingCoordinator(
                            transaction: transactions[0],
                            fiat: fiat,
                            navigationController: navigationController
                        )
                    )
                }
            )
                .handleEvents(receiveOutput: { [weak self, unowned mainSellVC] result in
                    switch result {
                    case .transactionRemoved, .cancelled:
                        self?.navigationController.popViewController(animated: true)
                    case .cashOutInterupted:
                        self?.navigationController.popToRootViewController(animated: true)
                        self?.resultSubject.send(.none)
                    case .transactionSent:
                        self?.navigationController.popToViewController(mainSellVC, animated: true)
                    }
                    print("SellNavigation result: \(result)")
                }, receiveCompletion: { compl in
                    print("SellNavigation compl: \(compl)")
                })
                .map { _ in }
                .eraseToAnyPublisher()

        case .swap:
            return navigateToSwap().deallocatedPublisher()
                .handleEvents(receiveOutput: { [unowned self] _ in
                    self.viewModel.warmUp()
                }).eraseToAnyPublisher()
        }
    }

    private func navigateToProviderWebPage(url: URL) -> UIViewController {
        let vc = SFSafariViewController(url: url)
        vc.modalPresentationStyle = .automatic
        navigationController.present(vc, animated: true)
        return vc
    }

    private func navigateToSwap() -> UIViewController {
        let vm = OrcaSwapV2.ViewModel(initialWallet: nil)
        let vc = OrcaSwapV2.ViewController(viewModel: vm)
        vc.hidesBottomBarWhenPushed = true
        navigationController.present(vc, animated: true)
        return vc
    }
}
