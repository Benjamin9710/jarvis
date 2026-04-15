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
    XCTAssertTrue(app.staticTexts["Kitchen lights turned on"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["Turn on the kitchen lights"].exists)
    XCTAssertTrue(app.buttons["replay-response-button"].exists)
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

  func testBackendFailureScenarioRendersTranscriptFault() {
    let app = launchApp(scenario: "ready", interactionScenario: "failure")

    XCTAssertTrue(app.staticTexts["Capture System Ready"].waitForExistence(timeout: 2))
    app.buttons["primary-capture-button"].tap()
    XCTAssertTrue(app.staticTexts["Listening For Input"].waitForExistence(timeout: 2))

    app.buttons["primary-capture-button"].tap()
    XCTAssertTrue(
      app.staticTexts["Jarvis could not process the latest voice interaction."].waitForExistence(
        timeout: 2)
    )
    XCTAssertTrue(app.staticTexts["Fault"].exists)
  }

  func testUnsupportedScenarioRendersJarvisFallbackResponse() {
    let app = launchApp(scenario: "ready", interactionScenario: "unsupported")

    XCTAssertTrue(app.staticTexts["Capture System Ready"].waitForExistence(timeout: 2))
    app.buttons["primary-capture-button"].tap()
    XCTAssertTrue(app.staticTexts["Listening For Input"].waitForExistence(timeout: 2))

    app.buttons["primary-capture-button"].tap()
    XCTAssertTrue(app.staticTexts["Command not available"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["I'm afraid I can't do that just yet."].exists)
  }

  @discardableResult
  private func launchApp(
    scenario: String,
    interactionScenario: String = "success"
  ) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments.append("-ui-testing")
    app.launchEnvironment["JARVIS_CAPTURE_SCENARIO"] = scenario
    app.launchEnvironment["JARVIS_INTERACTION_SCENARIO"] = interactionScenario
    app.launch()
    return app
  }
}
