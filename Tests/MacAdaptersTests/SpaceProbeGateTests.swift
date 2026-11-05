// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 LayoutKeeper contributors
import XCTest
import SpaceProbe

final class SpaceProbeGateTests: XCTestCase {
    func testNativeSelectorAcceptsUnchangedEmptyFieldsForVerifiedWindow() {
        XCTAssertEqual(SPWindowSelectorMatches("" as CFString,"" as CFString,"" as CFString,"" as CFString),1)
    }
    func testNativeSelectorPreservesTitleAndDocumentChecks() {
        XCTAssertEqual(SPWindowSelectorMatches("" as CFString,"标题" as CFString,"" as CFString,"标题" as CFString),1)
        XCTAssertEqual(SPWindowSelectorMatches("file:///a" as CFString,"" as CFString,"file:///a" as CFString,"" as CFString),1)
        XCTAssertEqual(SPWindowSelectorMatches("file:///a" as CFString,"标题" as CFString,"file:///b" as CFString,"标题" as CFString),0)
        XCTAssertEqual(SPWindowSelectorMatches("" as CFString,"" as CFString,"" as CFString,"新标题" as CFString),0)
        XCTAssertEqual(SPWindowSelectorMatches("" as CFString,"旧标题" as CFString,"" as CFString,"新标题" as CFString),0)
    }
    func testNativeSelectorRejectsMissingValues() {
        let empty="" as CFString
        XCTAssertEqual(SPWindowSelectorMatches(nil,empty,empty,empty),0)
        XCTAssertEqual(SPWindowSelectorMatches(empty,nil,empty,empty),0)
        XCTAssertEqual(SPWindowSelectorMatches(empty,empty,nil,empty),0)
        XCTAssertEqual(SPWindowSelectorMatches(empty,empty,empty,nil),0)
    }
    func testNativeGateMatchesProbeAndOSMajor() {
        var s=SPCrossSpaceSymbols(); SPProbeCrossSpaceSymbols(&s)
        let all=s.skyLightLoaded != 0 && s.moveOperationClass != 0 && s.moveOperationABI != 0 && s.membershipRead != 0 && s.managedDisplaySpaces != 0 && s.mainConnection != 0
        let modern=ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26
        XCTAssertEqual(SPControlledBridgeAvailable(),(all && modern) ? 1 : 0)
        if !modern { XCTAssertEqual(SPControlledBridgeAvailable(),0) }
    }
    func testMissingAXElementRejectsBeforePermissionOrWindowServerCalls() {
        var detail=[CChar](repeating:0,count:256)
        let result=SPDispatchVerifiedWindow(nil,0,0,0,"","","",0,0,"","",&detail,detail.count)
        XCTAssertEqual(result,-1);XCTAssertTrue(String(cString:detail).contains("Missing AX element"))
    }
}
