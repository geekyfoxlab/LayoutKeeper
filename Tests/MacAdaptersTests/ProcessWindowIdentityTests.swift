// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 LayoutKeeper contributors
import XCTest
import Darwin
import SpaceProbe
@testable import MacAdapters
final class ProcessWindowIdentityTests: XCTestCase {
    func testKernelStartTimeIsAvailableAndStable() throws {
        let first=try XCTUnwrap(ProcessStartTime.read(pid:getpid()))
        XCTAssertEqual(first,ProcessStartTime.read(pid:getpid()))
        XCTAssertEqual(first.timeIntervalSince1970,SPProcessStartTime(getpid()),accuracy:0.000001)
        XCTAssertEqual(SPProcessStartTime(Int32.max),0)
        XCTAssertLessThanOrEqual(first,Date())
        XCTAssertNil(ProcessStartTime.read(pid:Int32.max))
    }
    func testOnlyVerifiedSingleMainWindowGetsFallback() {
        XCTAssertEqual(AXWindows.untitledMainIdentifier(windowID:12,mainID:12,candidateIDs:[12]),"single-main-window")
        XCTAssertNil(AXWindows.untitledMainIdentifier(windowID:12,mainID:nil,candidateIDs:[12]))
        XCTAssertNil(AXWindows.untitledMainIdentifier(windowID:12,mainID:13,candidateIDs:[12]))
        XCTAssertNil(AXWindows.untitledMainIdentifier(windowID:12,mainID:12,candidateIDs:[12,13]))
        XCTAssertNil(AXWindows.untitledMainIdentifier(windowID:12,mainID:12,candidateIDs:[]))
    }
}
