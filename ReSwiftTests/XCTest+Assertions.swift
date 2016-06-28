//
//  Assertions
//  Copyright © 2015 mohamede1945. All rights reserved.
//  https://github.com/mohamede1945/AssertionsTestingExample
//

import Foundation
import XCTest
@testable import ReSwift

private let noReturnFailureWaitTime = 0.1


public extension XCTestCase {

    /**
     Expects an `fatalError` to be called.
     If `fatalError` not called, the test case will fail.

     - parameter expectedMessage: The expected message to be asserted to the one passed to the
     `fatalError`. If nil, then ignored.
     - parameter file:            The file name that called the method.
     - parameter line:            The line number that called the method.
     - parameter testCase:        The test case to be executed that expected to fire the assertion
     method.
     */
    public func expectFatalError(expectedMessage: String? = nil, file: StaticString = #file,
                                 line: UInt = #line, testCase: () -> Void) {
        #if swift(>=3)
            expectAssertionNoReturnFunction(functionName: "fatalError", file: file, line: line,
                                            function: { (caller) -> Void in
                Assertions.fatalErrorClosure = { caller($0.0) }
            }, expectedMessage: expectedMessage, testCase: testCase) { _ in
                Assertions.fatalErrorClosure = Assertions.swiftFatalErrorClosure
            }
        #else
            expectAssertionNoReturnFunction("fatalError", file: file, line: line, function: {
                (caller) -> Void in

                Assertions.fatalErrorClosure = { message, _, _ in
                    caller(message)
                }

            }, expectedMessage: expectedMessage, testCase: testCase) { _ in
                Assertions.fatalErrorClosure = Assertions.swiftFatalErrorClosure
            }
        #endif
    }

    // MARK:- Private Methods

    // swiftlint:disable function_parameter_count
    private func expectAssertionNoReturnFunction(
        functionName: String,
        file: StaticString,
        line: UInt,
        function: (caller: (String) -> Void) -> Void,
        expectedMessage: String? = nil,
        testCase: () -> Void,
        cleanUp: () -> ()) {

        #if swift(>=3)
            let asyncExpectation = expectation(withDescription: functionName + "-Expectation")
        #else
            let asyncExpectation = expectationWithDescription(functionName + "-Expectation")
        #endif
        var assertionMessage: String? = nil

        function { (message) -> Void in
            assertionMessage = message
            asyncExpectation.fulfill()
        }

        // act, perform on separate thead because a call to function runs forever
        #if swift(>=3)
            DispatchQueue.global(attributes: .qosUserInitiated).async(execute: testCase)

            waitForExpectations(withTimeout: noReturnFailureWaitTime) { _ in
                defer { cleanUp() }
                guard let assertionMessage = assertionMessage else {
                    XCTFail(functionName + " is expected to be called.", file: file, line: line)
                    return
                }
                if let expectedMessage = expectedMessage {
                    XCTAssertEqual(assertionMessage, expectedMessage, functionName +
                        " called with incorrect message.", file: file, line: line)
                }
            }
        #else
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), testCase)

            waitForExpectationsWithTimeout(noReturnFailureWaitTime) { _ in
                defer { cleanUp() }
                guard let assertionMessage = assertionMessage else {
                    XCTFail(functionName + " is expected to be called.", file: file, line: line)
                    return
                }
                if let expectedMessage = expectedMessage {
                    XCTAssertEqual(assertionMessage, expectedMessage, functionName +
                        " called with incorrect message.", file: file, line: line)
                }
            }
        #endif
    }
    // swiftlint:enable function_parameter_count
}
