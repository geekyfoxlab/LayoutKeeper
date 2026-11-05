// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 LayoutKeeper contributors
import XCTest
@testable import LayoutCore
final class UntitledWindowTests: XCTestCase {
    func testLegacySelectorDecodesWithoutIdentifier() throws {
        let data=Data(#"{"bundleID":"fixture.app","title":"old"}"#.utf8)
        let selector=try JSONDecoder().decode(WindowSelector.self,from:data)
        XCTAssertNil(selector.identifier); XCTAssertTrue(selector.usable)
    }
    func testUntitledMainWindowCanBeCapturedAndPlanned() throws {
        let demo=DemoBackend(); var snapshot=demo.state
        snapshot.windows[0].selector=WindowSelector(bundleID:"fixture.app",title:"",identifier:"single-main-window")
        snapshot.windows[0].processStartedAt=Date(timeIntervalSince1970:10)
        let (record,_)=try ExternalLayoutCapture.capture(monitor:.builtInOnly,displayToken:"simulated-panel",snapshot:snapshot)
        XCTAssertEqual(record.profile.windows.count,1); XCTAssertNil(record.profile.windows[0].runtime)
        let decoded=try JSONDecoder().decode(MonitorLayoutRecord.self,from:JSONEncoder().encode(record))
        XCTAssertEqual(decoded.profile.windows[0].selector.identifier,"single-main-window")
        snapshot.windows[0].frame=Rect(200,200,400,300)
        let plan=try QuickRestorePlanner.plan(record:decoded,monitor:.builtInOnly,displayToken:"simulated-panel",snapshot:snapshot,allowCrossSpace:true)
        XCTAssertEqual(plan.items[0].matchKind,.identifier); XCTAssertEqual(plan.items[0].state,.ready)
        XCTAssertTrue(QuickRestorePlanner.autoEligible(plan.items[0]))
    }
    func testIdentifierMismatchDoesNotGuessAnotherWindow() {
        let demo=DemoBackend(); var snapshot=demo.state
        snapshot.windows[0].selector=WindowSelector(bundleID:"fixture.app",title:"Different")
        let saved=SavedWindow(selector:WindowSelector(bundleID:"fixture.app",title:"",identifier:"single-main-window"),displayRole:.builtIn,desktopLabel:"A",normalizedFrame:Rect(0,0,0.5,0.5),desktopIndex:1)
        let match=WindowMatcher.match(saved,displayToken:"simulated-panel",snapshot:snapshot,savedOfApp:1)
        XCTAssertEqual(match.verdict,.needsConfirmation); XCTAssertNil(match.chosen)
    }
}
