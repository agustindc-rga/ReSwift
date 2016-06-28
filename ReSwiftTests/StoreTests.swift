//
//  StoreTests.swift
//  ReSwift
//
//  Created by Benjamin Encz on 11/27/15.
//  Copyright © 2015 DigiTales. All rights reserved.
//

import XCTest
@testable import ReSwift

class StoreTests: XCTestCase {

    func testInit() {
        // Dispatches an Init action when it doesn't receive an initial state

        let reducer = MockReducer()
        let _ = Store<CounterState>(reducer: reducer, state: nil)

        XCTAssert(reducer.calledWithAction[0] is ReSwiftInit)
    }

    func testDeinit() {
        // Deinitializes when no reference is held

        var deInitCount = 0

        autoreleasepool {
            let reducer = TestReducer()
            let _ = DeInitStore(
                reducer: reducer,
                state: TestAppState(),
                deInitAction: { deInitCount += 1 })
        }

        XCTAssertEqual(deInitCount, 1)
    }

}


class StoreSubscribeTest: XCTestCase {

    typealias TestSubscriber = TestStoreSubscriber<TestAppState>

    var store: Store<TestAppState>!
    var reducer: TestReducer!

    override func setUp() {
        super.setUp()
        reducer = TestReducer()
        store = Store(reducer: reducer, state: TestAppState())
    }

    func testStrongCapture() {
        // It does not strongly capture an observer

        store = Store(reducer: reducer, state: TestAppState())
        var subscriber: TestSubscriber? = TestSubscriber()

        store.subscribe(subscriber!)
        XCTAssertEqual(store.subscriptions.flatMap({ $0.subscriber }).count, 1)

        subscriber = nil
        XCTAssertEqual(store.subscriptions.flatMap({ $0.subscriber }).count, 0)
    }

    func testRemoveSubscribers() {
        // it removes deferenced subscribers before notifying state changes

        store = Store(reducer: reducer, state: TestAppState())
        var subscriber1: TestSubscriber? = TestSubscriber()
        var subscriber2: TestSubscriber? = TestSubscriber()

        store.subscribe(subscriber1!)
        store.subscribe(subscriber2!)
        store.dispatch(SetValueAction(3))
        XCTAssertEqual(store.subscriptions.count, 2)
        XCTAssertEqual(subscriber1?.receivedStates.last?.testValue, 3)
        XCTAssertEqual(subscriber2?.receivedStates.last?.testValue, 3)

        subscriber1 = nil
        store.dispatch(SetValueAction(5))
        XCTAssertEqual(store.subscriptions.count, 1)
        XCTAssertEqual(subscriber2?.receivedStates.last?.testValue, 5)

        subscriber2 = nil
        store.dispatch(SetValueAction(8))
        XCTAssertEqual(store.subscriptions.count, 0)
    }

    func testDispatchInitialValue() {
        // it dispatches initial value upon subscription
        store = Store(reducer: reducer, state: TestAppState())
        let subscriber = TestSubscriber()

        store.subscribe(subscriber)
        store.dispatch(SetValueAction(3))

        XCTAssertEqual(subscriber.receivedStates.last?.testValue, 3)
    }

    func testAllowDispatchWithinObserver() {
        // it allows dispatching from within an observer
        store = Store(reducer: reducer, state: TestAppState())
        let subscriber = DispatchingSubscriber(store: store)

        store.subscribe(subscriber)
        store.dispatch(SetValueAction(2))

        XCTAssertEqual(store.state.testValue, 5)
    }

    func testDontDispatchToUnsubscribers() {
        // it does not dispatch value after subscriber unsubscribes
        store = Store(reducer: reducer, state: TestAppState())
        let subscriber = TestSubscriber()

        store.dispatch(SetValueAction(5))
        store.subscribe(subscriber)
        store.dispatch(SetValueAction(10))

        store.unsubscribe(subscriber)
        // Following value is missed due to not being subscribed:
        store.dispatch(SetValueAction(15))
        store.dispatch(SetValueAction(25))

        store.subscribe(subscriber)

        store.dispatch(SetValueAction(20))

        XCTAssertEqual(subscriber.receivedStates.count, 4)
        XCTAssertEqual(subscriber.receivedStates[subscriber.receivedStates.count - 4].testValue, 5)
        XCTAssertEqual(subscriber.receivedStates[subscriber.receivedStates.count - 3].testValue, 10)
        XCTAssertEqual(subscriber.receivedStates[subscriber.receivedStates.count - 2].testValue, 25)
        XCTAssertEqual(subscriber.receivedStates[subscriber.receivedStates.count - 1].testValue, 20)
    }

    func testIgnoreIdenticalSubscribers() {
        // it ignores identical subscribers
        store = Store(reducer: reducer, state: TestAppState())
        let subscriber = TestSubscriber()

        store.subscribe(subscriber)
        store.subscribe(subscriber)

        XCTAssertEqual(store.subscriptions.count, 1)
    }

    func testIgnoreIdenticalSubstateSubscribers() {
        // it ignores identical subscribers that provide substate selectors
        store = Store(reducer: reducer, state: TestAppState())
        let subscriber = TestSubscriber()

        store.subscribe(subscriber) { $0 }
        store.subscribe(subscriber) { $0 }

        XCTAssertEqual(store.subscriptions.count, 1)
    }

}



class StoreDispatchTest: XCTestCase {

    typealias TestSubscriber = TestStoreSubscriber<TestAppState>
    typealias CallbackSubscriber = CallbackStoreSubscriber<TestAppState>

    var store: Store<TestAppState>!
    var reducer: TestReducer!

    override func setUp() {
        super.setUp()
        reducer = TestReducer()
        store = Store(reducer: reducer, state: TestAppState())
    }

    func testReturnsDispatchedAction() {
        // it returns the dispatched action
        let action = SetValueAction(10)
        let returnValue = store.dispatch(action)

        XCTAssertEqual((returnValue as? SetValueAction)?.value, action.value)
    }

    func testThrowsExceptionWhenReducersDispatch() {
        // it throws an exception when a reducer dispatches an action
        // Expectation lives in the `DispatchingReducer` class
        let reducer = DispatchingReducer()
        store = Store(reducer: reducer, state: TestAppState())
        reducer.store = store
        store.dispatch(SetValueAction(10))
    }

    func testAcceptsActionCreators() {
        // it accepts action creators
        store.dispatch(SetValueAction(5))

        let doubleValueActionCreator: Store<TestAppState>.ActionCreator = { state, store in
            return SetValueAction(state.testValue! * 2)
        }

        store.dispatch(doubleValueActionCreator)

        XCTAssertEqual(store.state.testValue, 10)
    }

    func testAcceptsAsyncActionCreators() {
        let expectation = expectationWithDescription("It accepts async action creators")

        let asyncActionCreator: Store<TestAppState>.AsyncActionCreator = { _, _, callback in
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                // Provide the callback with an action creator
                callback { state, store in
                    return SetValueAction(5)
                }
            }
        }

        let subscriber = CallbackSubscriber { [unowned self] state in
            if self.store.state.testValue != nil {
                XCTAssertEqual(self.store.state.testValue, 5)
                expectation.fulfill()
            }
        }
        store.subscribe(subscriber)

        store.dispatch(asyncActionCreator)
        waitForExpectationsWithTimeout(1) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
        }
    }

    func testCallsCalbackOnce() {
        let expectation = expectationWithDescription(
            "It calls the callback once state update from async action is complete")

        let asyncActionCreator: Store<TestAppState>.AsyncActionCreator = { _, _, callback in
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                // Provide the callback with an action creator
                callback { state, store in
                    return SetValueAction(5)
                }
            }
        }

        store.dispatch(asyncActionCreator) { newState in
            XCTAssertEqual(self.store.state.testValue, 5)
            if newState.testValue == 5 {
                expectation.fulfill()
            }
        }

        waitForExpectationsWithTimeout(1) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
        }
    }
}

// Used for deinitialization test
class DeInitStore<State: StateType>: Store<State> {
    var deInitAction: (() -> Void)?

    deinit {
        deInitAction?()
    }

    required convenience init(
        reducer: AnyReducer,
        state: State?,
        deInitAction: () -> Void) {
            self.init(reducer: reducer, state: state, middleware: [])
            self.deInitAction = deInitAction
    }

    required init(reducer: AnyReducer, state: State?, middleware: [Middleware]) {
        super.init(reducer: reducer, state: state, middleware: middleware)
    }
}

// Needs to be class so that shared reference can be modified to inject store
class DispatchingReducer: XCTestCase, Reducer {
    var store: Store<TestAppState>? = nil

    func handleAction(action: Action, state: TestAppState?) -> TestAppState {
        expectFatalError {
            self.store?.dispatch(SetValueAction(20))
        }
        return state ?? TestAppState()
    }
}
