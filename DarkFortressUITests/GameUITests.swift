import XCTest

final class GameUITests: XCTestCase {
    @MainActor
    func testSceneInterruptionPausesGame() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--seed", "14"]
        app.launch()
        let pause = app.buttons["pauseToggle"]
        XCTAssertTrue(pause.waitForExistence(timeout: 10))
        XCTAssertEqual(pause.label, "Pause")
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
        app.activate()
        XCTAssertTrue(app.staticTexts["Paused"].waitForExistence(timeout: 5))
        XCTAssertEqual(pause.label, "Play")
        let frozenHealth = app.staticTexts["playerHealth"].label
        Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(app.staticTexts["playerHealth"].label, frozenHealth)
        pause.tap()
        XCTAssertEqual(pause.label, "Pause")
        XCTAssertFalse(app.staticTexts["Paused"].exists)
    }

    @MainActor
    func testPortraitPauseDeathAndNewGame() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--seed", "14"]
        app.launch()
        let pause = app.buttons["pauseToggle"]
        XCTAssertTrue(pause.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(app.frame.height, app.frame.width)
        pause.tap()
        XCTAssertEqual(pause.label, "Play")
        XCTAssertTrue(app.staticTexts["Paused"].exists)
        XCTAssertGreaterThan(pause.frame.minX, app.buttons["zoomToggle"].frame.minX)
        let frozenHealth = app.staticTexts["playerHealth"].label
        Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(app.staticTexts["playerHealth"].label, frozenHealth)
        let pausedShot = XCTAttachment(screenshot: app.screenshot())
        pausedShot.name = "Portrait world and play toggle"
        pausedShot.lifetime = .keepAlways
        add(pausedShot)
        pause.tap()
        XCTAssertEqual(pause.label, "Pause")
        XCTAssertTrue(app.staticTexts["You died"].waitForExistence(timeout: 65))
        XCTAssertEqual(app.staticTexts["playerHealth"].label, "Health, 0")
        let deathShot = XCTAttachment(screenshot: app.screenshot())
        deathShot.name = "You died"
        deathShot.lifetime = .keepAlways
        add(deathShot)
        app.buttons["newGame"].tap()
        XCTAssertFalse(app.staticTexts["You died"].exists)
        XCTAssertEqual(app.staticTexts["playerHealth"].label, "Health, 30")
        XCTAssertEqual(pause.label, "Pause")
    }
}
