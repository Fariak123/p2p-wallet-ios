import Combine
import Foundation
import SwiftUI
import UIKit

typealias SellPendingCoordinatorResult = Void

final class SellPendingCoordinator: Coordinator<SellPendingCoordinatorResult> {
    let navigationController: UINavigationController
    let transactions: [SellDataServiceTransaction]
    let fiat: Fiat

    init(transactions: [SellDataServiceTransaction], fiat: Fiat, navigationController: UINavigationController) {
        self.navigationController = navigationController
        self.transactions = transactions
        self.fiat = fiat
    }

    override func start() -> AnyPublisher<SellPendingCoordinatorResult, Never> {
        let tokenSymbol = "SOL"
        let vcs = transactions.map { transction in
            let viewModel = SellPendingViewModel(
                model: SellPendingViewModel.Model(
                    id: transction.id,
                    tokenImage: .solanaIcon,
                    tokenSymbol: tokenSymbol,
                    tokenAmount: transction.baseCurrencyAmount,
                    fiatAmount: 5,
                    currency: fiat,
                    receiverAddress: "FfRBerfgeritjg43fBeJEr"
                )
            )

            viewModel.dismiss
                .sink { [weak self] in
                    self?.navigationController.popViewController(animated: true)
                }
                .store(in: &subscriptions)
            viewModel.send
                .sink(receiveValue: {
                    
                })
                .store(in: &subscriptions)

            let viewController = SellPendingView(viewModel: viewModel).asViewController(withoutUIKitNavBar: false)
            viewController.navigationItem.title = "\(L10n.cashOut) \(tokenSymbol)"
            return viewController
        }

        let beneathVCs = navigationController.viewControllers//[0..<navigationController.viewControllers.count-1]
        navigationController.viewControllers = beneathVCs + vcs
        return Publishers
            .MergeMany(vcs.map { $0.deallocatedPublisher() }).collect()
            .flatMap({ _ in
                Just(()).eraseToAnyPublisher()
            })
            .handleEvents(receiveOutput: { _ in
                debugPrint("here")
            })
            .prefix(1)
            .eraseToAnyPublisher()
    }

    deinit {
        debugPrint("deinit")
    }
}
