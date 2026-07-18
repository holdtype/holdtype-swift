//
//  HoldTypeUITests.swift
//  HoldTypeUITests
//
//  Created by Eugene Potapenko on 6/20/26.
//

import XCTest

final class HoldTypeUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication.vibeTypeAutomation().launch()
        }
    }
}

extension XCUIApplication {
    static func vibeTypeAutomation() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["HOLDTYPE_AUTOMATION"] = "1"
        app.launchEnvironment["HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI"] = "skip"
        return app
    }
}
