//
//  BaseVM.swift
//  p2p_wallet
//
//  Created by Chung Tran on 11/12/20.
//

import Foundation
import RxSwift
import RxCocoa

class BaseVM<T: Hashable> {
    let disposeBag = DisposeBag()
    var requestDisposable: Disposable?
    var data: T
    let state = BehaviorRelay<FetcherState<T>>(value: .initializing)
    
    init(initialData: T) {
        data = initialData
        bind()
    }
    
    func bind() {}
    
    func reload() {
        if !shouldReload() {return}
        requestDisposable?.dispose()
        state.accept(.loading)
        requestDisposable = request
            .subscribe(onSuccess: {newData in
                self.handleNewData(newData)
            }, onFailure: {error in
                self.handleError(error)
            })
    }
    
    func shouldReload() -> Bool {
        state.value != .loading
    }
    
    var request: Single<T> { Single<T>.just(data).delay(.seconds(2), scheduler: MainScheduler.instance) // delay for simulating loading
    }
    
    func handleNewData(_ newData: T) {
        data = newData
        state.accept(.loaded(data))
    }
    
    func handleError(_ error: Error) {
        state.accept(.error(error))
    }
    
    var dataDidChange: Observable<Void> {
        state.distinctUntilChanged().map {_ in ()}
    }
    
    var dataObservable: Observable<T?> {
        state
            .map { state -> T? in
                switch state {
                case .loaded:
                    return self.data
                default:
                    return nil
                }
            }
    }
}
