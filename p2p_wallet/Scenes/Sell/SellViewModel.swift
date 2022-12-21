import Combine
import Foundation
import Combine
import Resolver
import RxSwift
import KeyAppUI
import SolanaSwift

enum SellViewModelInputError: Error, Equatable {
    case balanceEmpty(baseCurrencyCode: String)
    case amountIsTooSmall(minBaseAmount: Double?, baseCurrencyCode: String)
    case insufficientFunds(baseCurrencyCode: String)
    case exceedsProviderLimit(maxBaseProviderAmount: Double?, baseCurrencyCode: String)
    
    var recomendation: String {
        switch self {
        case .balanceEmpty(let baseCurrencyCode):
            return L10n.thereIsNoInYourWalletToSell(baseCurrencyCode)
        case .amountIsTooSmall(let minBaseAmount, let baseCurrencyCode):
            return L10n.theMinimumAmountIs(minBaseAmount.toString(), baseCurrencyCode)
        case .insufficientFunds(let baseCurrencyCode):
            return L10n.notEnought(baseCurrencyCode)
        case .exceedsProviderLimit(let maxBaseProviderAmount, let baseCurrencyCode):
            return L10n.theMaximumAmountIs(maxBaseProviderAmount.toString(), baseCurrencyCode)
        }
    }
    
    var isBalanceEmpty: Bool {
        switch self {
        case .balanceEmpty:
            return true
        default:
            return false
        }
    }
}

@MainActor
class SellViewModel: BaseViewModel, ObservableObject {

    // MARK: - Dependencies

    @Injected private var walletRepository: WalletsRepository
    @Injected private var dataService: any SellDataService
    @Injected private var actionService: any SellActionService

    // MARK: -

    private let disposeBag = DisposeBag()
    private let navigation: PassthroughSubject<SellNavigation?, Never>

    // MARK: -

    private var minBaseAmount: Double?
    /// Maximum value to sell from sell provider
    private var maxBaseProviderAmount: Double?
    private let baseAmountTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    // MARK: - Properties

    @Published var baseCurrencyCode: String = "SOL"
    @Published var baseAmount: Double?
    /// Maximum amount user can sell (balance)
    @Published var maxBaseAmount: Double?
    @Published var isEnteringBaseAmount: Bool = true
    @Published var quoteCurrencyCode: String = Fiat.usd.code
    @Published var quoteAmount: Double?
    @Published var isEnteringQuoteAmount: Bool = false
    @Published var exchangeRate: Double = 0
    @Published var fee: Double = 0
    @Published var status: SellDataServiceStatus = .initialized
    @Published var inputError: SellViewModelInputError?

    init(navigation: PassthroughSubject<SellNavigation?, Never>) {
        self.navigation = navigation
        super.init()

        warmUp()

        bind()
    }

    private func bind() {
        // enter base amount
        Publishers.CombineLatest($baseAmount, $exchangeRate)
            .filter { [weak self] _ in
                self?.isEnteringBaseAmount == true
            }
            .map { baseAmount, exchangeRate in
                guard let baseAmount else {return nil}
                return baseAmount * exchangeRate
            }
            .assign(to: \.quoteAmount, on: self)
            .store(in: &subscriptions)

        // enter quote amount
        Publishers.CombineLatest($quoteAmount, $exchangeRate)
            .filter { [weak self] _ in
                self?.isEnteringQuoteAmount == true
            }
            .map { quoteAmount, exchangeRate in
                guard let quoteAmount, exchangeRate != 0 else { return nil }
                return quoteAmount / exchangeRate
            }
            .assign(to: \.baseAmount, on: self)
            .store(in: &subscriptions)
        
        // bind status publisher to status property
        dataService.statusPublisher
            .receive(on: RunLoop.main)
            .assign(to: \.status, on: self)
            .store(in: &subscriptions)

        // bind dataService.data to viewModel's data
        let dataPublisher = dataService.statusPublisher
            .compactMap({ [weak self] status in
                switch status {
                case .ready:
                    return (self?.dataService.currency, self?.dataService.fiat)
                default:
                    return nil
                }
            })
            .receive(on: RunLoop.main)
            .share()
        
        dataPublisher
            .sink(receiveValue: { [weak self] currency, fiat in
                guard let self = self else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.baseAmount = currency?.minSellAmount ?? 0
                    self.quoteCurrencyCode = fiat?.code ?? "USD"
                    self.maxBaseProviderAmount = currency?.maxSellAmount ?? 0
                    self.minBaseAmount = currency?.minSellAmount ?? 0
                    self.baseCurrencyCode = "SOL"
                }
            })
            .store(in: &subscriptions)

        // Open pendings in case there are pending txs
        dataPublisher
            .withLatestFrom(dataService.transactionsPublisher)
            .map { $0.filter { $0.status == .waitingForDeposit }}
            .removeDuplicates()
            .sink(receiveValue: { [weak self] transactions in
                guard let self = self, let fiat = self.dataService.fiat else { return }
                self.navigation.send(.showPending(transactions: transactions, fiat: fiat))
            })
            .store(in: &subscriptions)

        maxBaseAmount = walletRepository.nativeWallet?.amount
        walletRepository.dataDidChange
            .subscribe(onNext: { [weak self] val in
                guard let self = self else { return }
                self.maxBaseAmount = self.walletRepository.nativeWallet?.amount
                if self.walletRepository.nativeWallet?.amount == 0 {
                    self.inputError = .balanceEmpty(baseCurrencyCode: self.baseCurrencyCode)
                }
            })
            .disposed(by: disposeBag)

        Publishers.Merge(
            $baseAmount,
            baseAmountTimer.withLatestFrom($baseAmount)
        )
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .withLatestFrom(Publishers.CombineLatest3(
                $baseCurrencyCode, $quoteCurrencyCode, $baseAmount.compactMap { $0 }
            ))
            .filter { [unowned self] _ in self.status.isReady && self.isEnteringBaseAmount && (self.inputError == nil || self.inputError?.isBalanceEmpty == false) }
            .handleEvents(receiveOutput: { [unowned self] amount in
                self.inputError = nil
                self.checkError(amount: amount.2)
            })
            .map { [unowned self] base, quote, amount -> AnyPublisher<SellActionServiceQuote?, Never> in
                self.calculateFee(
                    amount: amount,
                    baseCurrencyCode: base,
                    quoteCurrencyCode: quote
                )
                    .map(Optional.init)
                    .replaceError(with: nil)
                    .eraseToAnyPublisher()
            }
            .subscribe(on: DispatchQueue.global())
            .receive(on: DispatchQueue.main)
            // Getting only last request
            .switchToLatest()
            .sink(receiveValue: { [unowned self] val in
                guard let val else {
                    if self.isEnteringBaseAmount {
                        self.quoteAmount = 0
                    } else {
                        self.baseAmount = 0
                    }
                    return
                }
                self.fee = val.feeAmount + val.extraFeeAmount
                self.quoteAmount = val.quoteCurrencyAmount
                self.exchangeRate = val.baseCurrencyPrice
            })
            .store(in: &subscriptions)
    }

    func warmUp() {
        Task { [unowned self] in
            await dataService.update()
        }
    }

    private func checkError(amount: Double) {
        if amount < minBaseAmount {
            inputError = .amountIsTooSmall(minBaseAmount: minBaseAmount, baseCurrencyCode: baseCurrencyCode)
        } else if amount > (maxBaseAmount ?? 0) {
            inputError = .insufficientFunds(baseCurrencyCode: baseCurrencyCode)
        } else if amount > maxBaseProviderAmount {
            inputError = .exceedsProviderLimit(maxBaseProviderAmount: maxBaseProviderAmount, baseCurrencyCode: baseCurrencyCode)
        }
    }

    private func calculateFee(
        amount: Double,
        baseCurrencyCode: String,
        quoteCurrencyCode: String
    ) -> AnyPublisher<SellActionServiceQuote, Error> {
        Deferred {
            Future { promise in
                Task { [unowned self] in
                    do {
                        let result = try await self.actionService.sellQuote(
                            baseCurrencyCode: baseCurrencyCode.lowercased(),
                            quoteCurrencyCode: quoteCurrencyCode.lowercased(),
                            baseCurrencyAmount: amount.rounded(decimals: 2),
                            extraFeePercentage: 0
                        )
                        promise(.success(result))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }
        }.eraseToAnyPublisher()
    }

    // MARK: - Actions

    func sell() {
        guard let userId = dataService.userId, let fiat = dataService.fiat else { return }
        try? openProviderWebView(
            quoteCurrencyCode: fiat.code,
            baseCurrencyAmount: baseAmount ?? 0,
            externalTransactionId: userId
        )
    }

    func goToSwap() {
        navigation.send(.swap)
    }

    func sellAll() {
        baseAmount = walletRepository.nativeWallet?.amount ?? 0
    }

    func openProviderWebView(
        quoteCurrencyCode: String,
        baseCurrencyAmount: Double,
        externalTransactionId: String
    ) throws {
        let url = try actionService.createSellURL(
            quoteCurrencyCode: quoteCurrencyCode,
            baseCurrencyAmount: baseCurrencyAmount,
            externalTransactionId: externalTransactionId
        )
        navigation.send(.webPage(url: url))
    }
}

extension SellViewModel {
    enum _Error: Error {
        case invalidAmount
    }
}
