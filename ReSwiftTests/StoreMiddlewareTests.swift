//
//  StoreMiddlewareTests.swift
//  ReSwift
//
//  Created by Benji Encz on 12/24/15.
//  Copyright © 2015 Benjamin Encz. All rights reserved.
//

import XCTest
@testable import ReSwift

let firstMiddleware: Middleware = { dispatch, getState in
    return { next in
        return { action in

            if var action = action as? SetValueStringAction {
                action.value = action.value + " First Middleware"
                return next(action)
            } else {
                return next(action)
            }
        }
    }
}

let secondMiddleware: Middleware = { dispatch, getState in
    return { next in
        return { action in

            if var action = action as? SetValueStringAction {
                action.value = action.value + " Second Middleware"
                return next(action)
            } else {
                return next(action)
            }
        }
    }
}

let dispatchingMiddleware: Middleware = { dispatch, getState in
    return { next in
        return { action in

            if var action = action as? SetValueAction {
                _ = dispatch?(SetValueStringAction("\(action.value)"))

                return "Converted Action Successfully"
            }

            return next(action)
        }
    }
}

let stateAccessingMiddleware: Middleware = { dispatch, getState in
    return { next in
        return { action in

            let appState = getState() as? TestStringAppState,
                stringAction = action as? SetValueStringAction

            // avoid endless recursion by checking if we've dispatched exactly this action
            if appState?.testValue == "OK" && stringAction?.value != "Not OK" {
                // dispatch a new action
                _ = dispatch?(SetValueStringAction("Not OK"))

                // and swallow the current one
                return next(StandardAction(type: "No-Op-Action"))
            }

            return next(action)
        }
    }
}

// swiftlint:disable function_body_length
class StoreMiddlewareTest: XCTestCase {

    func testDecorateDispatch() {
        // it can decorate dispatch function
        let reducer = TestValueStringReducer()
        let store = Store<TestStringAppState>(reducer: reducer,
            state: TestStringAppState(),
            middleware: [firstMiddleware, secondMiddleware])

        let subscriber = TestStoreSubscriber<TestStringAppState>()
        #if swift(>=3)
            store.subscribe(subscriber: subscriber)
        #else
            store.subscribe(subscriber)
        #endif

        let action = SetValueStringAction("OK")
        #if swift(>=3)
            store.dispatch(action: action)
        #else
            store.dispatch(action)
        #endif

        XCTAssertEqual(store.state.testValue, "OK First Middleware Second Middleware")
    }

    func testCanDispatch() {
        // it can dispatch actions
        let reducer = TestValueStringReducer()
        let store = Store<TestStringAppState>(reducer: reducer,
            state: TestStringAppState(),
            middleware: [firstMiddleware, secondMiddleware, dispatchingMiddleware])

        let subscriber = TestStoreSubscriber<TestStringAppState>()
        #if swift(>=3)
            store.subscribe(subscriber: subscriber)
        #else
            store.subscribe(subscriber)
        #endif

        let action = SetValueAction(10)
        #if swift(>=3)
            store.dispatch(action: action)
        #else
            store.dispatch(action)
        #endif

        XCTAssertEqual(store.state.testValue, "10 First Middleware Second Middleware")
    }

    func testCanChangeReturnValue() {
        // it can change the return value of the dispatch function
        let reducer = TestValueStringReducer()
        let store = Store<TestStringAppState>(reducer: reducer,
            state: TestStringAppState(),
            middleware: [firstMiddleware, secondMiddleware, dispatchingMiddleware])

        let action = SetValueAction(10)
        #if swift(>=3)
            let returnValue = store.dispatch(action: action) as? String
        #else
            let returnValue = store.dispatch(action) as? String
        #endif

        XCTAssertEqual(returnValue, "Converted Action Successfully")
    }

    func testMiddlewareCanAccessState() {
        // it middleware can access the store's state
        let reducer = TestValueStringReducer()
        var state = TestStringAppState()
        state.testValue = "OK"

        let store = Store<TestStringAppState>(reducer: reducer, state: state,
            middleware: [stateAccessingMiddleware])

        #if swift(>=3)
            store.dispatch(action: SetValueStringAction("Action That Won't Go Through"))
        #else
            store.dispatch(SetValueStringAction("Action That Won't Go Through"))
        #endif

        XCTAssertEqual(store.state.testValue, "Not OK")
    }
}
