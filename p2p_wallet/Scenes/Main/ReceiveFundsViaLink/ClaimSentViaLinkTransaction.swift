import Foundation
import SolanaSwift
import Send
import Resolver
import FeeRelayerSwift

struct ClaimSentViaLinkTransaction: RawTransactionType {
    // MARK: - Nested type
    
    enum FakeTransactionErrorType: String, CaseIterable, Identifiable {
        case noError
        case networkError
        case otherError
        var id: Self { self }
    }
    
    // MARK: - Properties

    let claimableTokenInfo: ClaimableTokenInfo
    let token: Token
    let destinationWallet: Wallet
    let tokenAmount: Double
    
    let payingFeeWallet: Wallet? = nil
    let feeAmount: FeeAmount = .zero
    let isFakeTransaction: Bool
    let fakeTransactionErrorType: FakeTransactionErrorType
    
    var mainDescription: String {
        "Claim-sent-via-link"
    }
    
    var amountInFiat: Double? {
        Resolver.resolve(PricesServiceType.self).currentPrice(mint: token.address)?.value * tokenAmount
    }
    
    func createRequest() async throws -> String {
        // fake transaction for debugging
        if isFakeTransaction {
            // fake delay api call 1s
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            // simulate error if needed
            switch fakeTransactionErrorType {
            case .noError:
                break
            case .otherError:
                throw SolanaError.unknown
            case .networkError:
                throw NSError(domain: "Network error", code: NSURLErrorNetworkConnectionLost)
            }
            
            return .fakeTransactionSignature(id: UUID().uuidString)
        }
        
        // get receiver
        guard let receiver = Resolver.resolve(UserWalletManager.self).wallet?.account.publicKey
        else {
            throw SolanaError.unauthorized
        }
        
        // get services
        let sendViaLinkDataService = Resolver.resolve(SendViaLinkDataService.self)
        let contextManager = Resolver.resolve(RelayContextManager.self)
        let solanaAPIClient = Resolver.resolve(SolanaAPIClient.self)
        
        guard let context = contextManager.currentContext else {
            throw FeeRelayerError.relayInfoMissing
        }
        
        // prepare transaction, get recent blockchash
        var (preparedTransaction, recentBlockhash) = try await(
            sendViaLinkDataService.claim(
                token: claimableTokenInfo,
                receiver: receiver,
                feePayer: context.feePayerAddress
            ),
            solanaAPIClient.getRecentBlockhash()
        )
        
        preparedTransaction.transaction.recentBlockhash = recentBlockhash
        
        // get feePayer's signature
        let feePayerSignature = try await Resolver.resolve(RelayService.self)
            .signRelayTransaction(
                preparedTransaction,
                config: FeeRelayerConfiguration(
                    operationType: .sendViaLink, // TODO: - Received via link?
                    currency: claimableTokenInfo.mintAddress,
                    autoPayback: false
                )
            )
        
        // sign transaction by user
        try preparedTransaction.transaction.sign(signers: [claimableTokenInfo.keypair])
        
        // add feePayer's signature
        try preparedTransaction.transaction.addSignature(
            .init(
                signature: Data(Base58.decode(feePayerSignature)),
                publicKey: context.feePayerAddress
            )
        )
        
        // serialize transaction
        let serializedTransaction = try preparedTransaction.transaction.serialize().base64EncodedString()
        
        // send to solanaBlockchain
        return try await solanaAPIClient.sendTransaction(transaction: serializedTransaction, configs: RequestConfiguration(encoding: "base64")!)
    }
}
