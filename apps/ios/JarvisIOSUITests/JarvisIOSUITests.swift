import XCTest

final class JarvisIOSUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testReadyScenarioCanToggleIntoRecording() {
        let app = launchApp(scenario: "ready")

        XCTAssertTrue(app.staticTexts["Capture System Ready"].waitForExistence(timeout: 2))

        app.buttons["primary-capture-button"].tap()
        XCTAssertTrue(app.staticTexts["Listening For Input"].waitForExistence(timeout: 2))

        app.buttons["primary-capture-button"].tap()
        XCTAssertTrue(app.staticTexts["Capture System Ready"].waitForExistence(timeout: 2))
    }

    func testPermissionScenarioRendersMicrophoneCallToAction() {
        let app = launchApp(scenario: "permission-needed")

        XCTAssertTrue(app.staticTexts["Microphone Access Required"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["primary-capture-button"].exists)
        XCTAssertTrue(app.staticTexts["Microphone denied"].exists)
    }

    func testErrorScenarioRendersFaultState() {
        let app = launchApp(scenario: "error")

        XCTAssertTrue(app.staticTexts["Capture Fault Detected"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Audio engine unavailable in the test fixture."].exists)
    }

    @discardableResult
    private func launchApp(scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launchEnvironment["JARVIS_CAPTURE_SCENARIO"] = scenario
        app.launch()
        return app
    }
}
