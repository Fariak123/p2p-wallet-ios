//
//  ListViewModel.swift
//  p2p_wallet
//
//  Created by Giang Long Tran on 15.02.2023.
//

import Combine
import Foundation

/// List adapter status
enum ListStateStatus {
    /// Adapter is fetching new data
    case fetching
    
    /// Adapter is ready to fetch new data
    case ready
}

/// A structure that describe in general a list
struct ListState<Element> {
    var status: ListStateStatus = .ready
    var data: [Element] = []
    var fetchable: Bool = true
    var error: Error?
    
    init() {
        self.status = .ready
        self.data = []
        self.fetchable = true
        self.error = nil
    }
    
    init(data: [Element]) {
        self.status = .ready
        self.data = data
        self.fetchable = true
        self.error = nil
    }
    
    init(status: ListStateStatus, data: [Element], fetchable: Bool, error: Error?) {
        self.status = status
        self.data = data
        self.fetchable = fetchable
        self.error = error
    }
}

/// A class holder
final class AsyncList<Element> {
    typealias ID = KeyPath<Element, String>
    
    // MARK: - Variables
    
    /// Number of items that will be fetched by call ``fetch()``
    private let limit: Int
    
    /// Adapter current state
    @Published private(set) var state: ListState<Element>
    
    /// Iterator that help build a list
    private var sequence: AnyAsyncSequence<Element>
    
    private var iterator: AnyAsyncSequence<Element>.AsyncIterator
    
    /// Current fetching task
    private var currentTask: Task<Void, Error>?
    
    /// The id of item. Will be used to ensure unique id in list.
    private let id: ID?
    
    // MARK: - Initializing
    
    init(sequence: AnyAsyncSequence<Element>, id: ID? = nil, limit: Int = 20) {
        self.state = .init()
        self.sequence = sequence
        self.iterator = sequence.makeAsyncIterator()
        self.limit = limit
        self.id = id
    }
    
    // MARK: - Actions
    
    /// Cancel current task and reset data.
    func reset() {
        // Cancel current task
        currentTask?.cancel()
        currentTask = nil
        
        // Reset state
        state = .init()
        
        // Set new iterator
        iterator = sequence.makeAsyncIterator()
    }
    
    /// Fetch new data
    @discardableResult func fetch() -> Task<Void, Error>? {
        // Ensure only one task at current moment
        if let currentTask {
            return currentTask
        }
        
        // Ensure is fetchable
        guard state.fetchable else {
            return nil
        }
        
        // Create a new task
        currentTask = Task {
            state.status = .fetching
            state.error = nil
            
            // Preparing
            var n = limit
            var fetchedItems: [Element] = []
            
            // Fetching
            do {
                while n > 0, let item: Element = try await iterator.next() {
                    try Task.checkCancellation()
                    fetchedItems.append(item)
                    n -= 1
                }
                
                // Update fetchable
                state.fetchable = n == 0
            } catch {
                if !Task.isCancelled {
                    print(error)
                    state.error = error
                }
            }
            
            // Ensure unique in list
            if let id {
                fetchedItems = fetchedItems.filter { fetchedItem in
                    !state.data.contains {
                        $0[keyPath: id] == fetchedItem[keyPath: id]
                    }
                }
            }
            
            // Update data
            state.data = state.data + fetchedItems
            
            // Finish task
            currentTask = nil
            state.status = .ready
        }
        
        return currentTask
    }
    
    func listen<Target: ObservableObject>(target: Target, in storage: inout [AnyCancellable]) where Target.ObjectWillChangePublisher == ObservableObjectPublisher
    {
        $state
            .receive(on: RunLoop.main)
            .sink { [weak target] _ in
                target?.objectWillChange.send()
            }.store(in: &storage)
    }
}

extension AsyncList: Collection {
    typealias Index = Int

    // The upper and lower bounds of the collection, used in iterations
    var startIndex: Index {
        return state.data.startIndex
    }
    
    var endIndex: Index {
        return state.data.endIndex
    }

    // Required subscript, based on a dictionary index
    subscript(index: Index) -> Element {
        return state.data[index]
    }

    // Method that returns the next index when iterating
    func index(after i: Index) -> Index {
        return state.data.index(after: i)
    }
}
