import Combine
import Send // FIXME: - Remove later

actor JupiterSwapStateMachine {
    // MARK: - Nested type
    
    /// The cache that handle currentTask and currentAction
    /// Must be actor to make sure that currentTask and currentAction are thread-safe
    private actor Cache {
        /// Current executing task
        fileprivate var currentTask: Task<JupiterSwapState, Never>?
        /// Save the current task
        fileprivate func saveCurrentTask(_ task: Task<JupiterSwapState, Never>?) {
            currentTask = task
        }
    }
    
    // MARK: - Properties

    private nonisolated let stateSubject: CurrentValueSubject<JupiterSwapState, Never>
    private nonisolated let cache = Cache()

    // MARK: - Public properties

    nonisolated var statePublisher: AnyPublisher<JupiterSwapState, Never> { stateSubject.eraseToAnyPublisher() }
    nonisolated var currentState: JupiterSwapState { stateSubject.value }

    nonisolated let services: JupiterSwapServices

    // MARK: - Initializer

    init(initialState: JupiterSwapState, services: JupiterSwapServices) {
        stateSubject = .init(initialState)
        self.services = services
    }
    
    // MARK: - Accept function

    @discardableResult
    nonisolated func accept(
        action newAction: JupiterSwapAction
    ) async -> JupiterSwapState {
        // assert if action should be performed
        // for example if data is not changed, perform action is not needed
        guard JupiterSwapBusinessLogic.shouldPerformAction(
            state: currentState,
            action: newAction
        ) else {
            print("JupiterSwapBusinessLogic.action: \(newAction.description) ignored")
            return currentState
        }
        
        // log
        print("JupiterSwapBusinessLogic.action: \(newAction.description) triggerred")
        
        // define if needs to cancel previous action
        let cancelPreviousAction: Bool
        switch newAction {
        case .updateUserWallets, .updateTokensPriceMap:
            cancelPreviousAction = false
        default:
            cancelPreviousAction = true
        }
        
        // cancel previous action if needed
        if cancelPreviousAction {
            await cache.currentTask?.cancel()
        }
        
        // create task to dispatch new action (can be immediately or after current action)
        let currentState = currentState
        let task = Task { [weak self] in
            guard let self else { return currentState}
            return await self.dispatch(action: newAction)
        }
        
        // save task to cache
        await cache.saveCurrentTask(task)
        
        // await it value
        return await task.value
    }
    
    // MARK: - Dispatching
    
    @discardableResult
    private func dispatch(action: JupiterSwapAction) async -> JupiterSwapState {
        // log
        print("JupiterSwapBusinessLogic.action: \(action.description) dispatched")
        
        // return the progress (loading state)
        if let progressState = JupiterSwapBusinessLogic.jupiterSwapProgressState(
            state: currentState, action: action
        ) {
            stateSubject.send(progressState)
        }
        
        // perform the action
        guard Task.isNotCancelled else {
            print("JupiterSwapBusinessLogic.action: \(action.description) cancelled")
            return currentState
        }
        let mainActionState = await JupiterSwapBusinessLogic.jupiterSwapBusinessLogic(
            state: currentState,
            action: action,
            services: services
        )

        // return the state
        guard Task.isNotCancelled else {
            print("JupiterSwapBusinessLogic.action: \(action.description) cancelled")
            return currentState
        }
        stateSubject.send(mainActionState)
        
        // Create transaction if needed
        guard Task.isNotCancelled else {
            print("JupiterSwapBusinessLogic.action: \(action.description) cancelled")
            return currentState
        }
        // Do not trigger stateSubject sending createTransactionState if it is not necessary
        guard currentState.status == .creatingSwapTransaction else {
            return currentState
        }
        let createTransactionState = await JupiterSwapBusinessLogic.createTransaction(
            state: currentState,
            services: services
        )
        
        guard Task.isNotCancelled else {
            print("JupiterSwapBusinessLogic.action: \(action.description) cancelled")
            return currentState
        }
        stateSubject.send(createTransactionState)
        
        print("JupiterSwapBusinessLogic.action: \(action.description) finished")
        
        // FIXME: - Optional part of action, refactor later
        guard Task.isNotCancelled else {
            return currentState
        }
        
        let updatePricesState = await JupiterSwapBusinessLogic.updatePrices(
            state: currentState,
            services: services
        )
        
        guard Task.isNotCancelled else {
            return currentState
        }
        stateSubject.send(updatePricesState)
        
        return currentState
    }
}
