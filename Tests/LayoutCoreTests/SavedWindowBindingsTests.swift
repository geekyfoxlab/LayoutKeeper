// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 LayoutKeeper contributors
import XCTest
@testable import LayoutCore

final class SavedWindowBindingsTests: XCTestCase {
    func fixture() -> (MonitorLayoutRecord,Snapshot) {
        let selector=WindowSelector(bundleID:"com.google.Chrome",title:"Page A - Google Chrome")
        let w=ObservedWindow(token:"10:20",selector:selector,frame:Rect(0,0,1000,700),spaceIDs:[2],processStartedAt:Date(timeIntervalSince1970:100))
        let s=Snapshot(session:UUID(),topology:"internal",displays:[Display(token:"panel",name:"Panel",role:.builtIn,visible:Rect(0,0,1000,700))],spaces:[Space(id:1,displayToken:"panel"),Space(id:2,displayToken:"panel")],windows:[w])
        let saved=SavedWindow(selector:selector,displayRole:.builtIn,desktopLabel:"Work",normalizedFrame:Rect(0,0,1,1),desktopIndex:2)
        return (MonitorLayoutRecord(monitor:.builtInOnly,savedAt:Date(timeIntervalSince1970:200),profile:Profile(location:"Internal",windows:[saved])),s)
    }
    func testTitleChangeAcrossDisplaySwitchRestoresOriginalSavedDesktop() throws {
        let (record,initial)=fixture();var cache=SavedWindowBindings()
        _=cache.bind(record,snapshot:initial,displayToken:"panel")
        var current=initial;current.windows[0].selector.title="Page B - Google Chrome";current.windows[0].spaceIDs=[1]
        let withoutBinding=try QuickRestorePlanner.plan(record:record,monitor:.builtInOnly,displayToken:"panel",snapshot:current,allowCrossSpace:true)
        XCTAssertFalse(QuickRestorePlanner.autoEligible(withoutBinding.items[0]))
        let bound=cache.bind(record,snapshot:current,displayToken:"panel")
        let preview=try QuickRestorePlanner.plan(record:bound,monitor:.builtInOnly,displayToken:"panel",snapshot:current,allowCrossSpace:true)
        XCTAssertEqual(preview.items[0].matchKind,.runtime)
        let plan=QuickRestorePlanner.executionPlan(preview,autoOnly:true,fresh:current).plan
        let backend=Simulation(snapshot:current)
        let result=ManualRestorer.execute(plan,windows:backend,spaces:backend,approved:true,persist:{_ in})
        XCTAssertEqual(result.results.first?.outcome,.verified)
        XCTAssertEqual(backend.state.windows[0].spaceIDs,[2])
        XCTAssertNil(record.profile.windows[0].runtime)
        XCTAssertEqual(bound.profile.windows[0].normalizedFrame,record.profile.windows[0].normalizedFrame)
        XCTAssertEqual(bound.profile.windows[0].selector,record.profile.windows[0].selector)
    }
    func testResavedLayoutInvalidatesOldBinding() {
        let (record,initial)=fixture();var cache=SavedWindowBindings()
        _=cache.bind(record,snapshot:initial,displayToken:"panel")
        var newer=record;newer.savedAt.addTimeInterval(1)
        var s=initial;s.windows[0].selector.title="Other page"
        XCTAssertNil(cache.bind(newer,snapshot:s,displayToken:"panel").profile.windows[0].runtime)
    }
    func testRestartCannotReuseBindingForChangedContent() throws {
        let (record,initial)=fixture();var cache=SavedWindowBindings()
        _=cache.bind(record,snapshot:initial,displayToken:"panel")
        var s=initial;s.windows[0].processStartedAt=Date(timeIntervalSince1970:300);s.windows[0].selector.title="Other page";s.windows[0].spaceIDs=[1]
        let bound=cache.bind(record,snapshot:s,displayToken:"panel")
        let p=try QuickRestorePlanner.plan(record:bound,monitor:.builtInOnly,displayToken:"panel",snapshot:s,allowCrossSpace:true)
        XCTAssertFalse(try XCTUnwrap(bound.profile.windows[0].runtime).matches(s.windows[0]))
        XCTAssertNotEqual(p.items[0].matchKind,.runtime)
        XCTAssertFalse(QuickRestorePlanner.autoEligible(p.items[0]))
        XCTAssertTrue(QuickRestorePlanner.executionPlan(p,autoOnly:true,fresh:s).plan.entries.isEmpty)
    }
    func testTwoWindowsKeepSeparateIdentitiesAfterBothTitlesChange() {
        var (record,s)=fixture();record.profile.windows[0].selector.bundleID="fixture.editor";s.windows[0].selector.bundleID="fixture.editor"
        var second=record.profile.windows[0];second.selector.title="Second";record.profile.windows.append(second)
        var live=s.windows[0];live.token="10:21";live.selector=second.selector;s.windows.append(live)
        var cache=SavedWindowBindings();_=cache.bind(record,snapshot:s,displayToken:"panel")
        s.windows[0].selector.title="Renamed first";s.windows[1].selector.title="Renamed second"
        let bound=cache.bind(record,snapshot:s,displayToken:"panel")
        XCTAssertEqual(bound.profile.windows.compactMap{$0.runtime?.token},["10:20","10:21"])
    }
    func testOneLiveWindowCannotBindTwoSavedEntries() {
        var (record,s)=fixture();record.profile.windows.append(record.profile.windows[0])
        var cache=SavedWindowBindings()
        XCTAssertTrue(cache.bind(record,snapshot:s,displayToken:"panel").profile.windows.allSatisfy{$0.runtime==nil})
    }
    func testTemporaryOmissionPreservesBindingAcrossRepeatedTitleChanges() {
        let (record,initial)=fixture();var cache=SavedWindowBindings()
        _=cache.bind(record,snapshot:initial,displayToken:"panel")
        var missing=initial;missing.windows=[]
        _=cache.bind(record,snapshot:missing,displayToken:"panel")
        for index in 1...4 {
            var s=initial;s.windows[0].selector.title="New page \(index)";s.windows[0].spaceIDs=[index % 2 == 0 ? 1 : 2]
            let bound=cache.bind(record,snapshot:s,displayToken:"panel")
            XCTAssertTrue(bound.profile.windows[0].runtime?.matches(s.windows[0]) == true)
            XCTAssertEqual(bound.profile.windows[0].desktopIndex,2)
        }
    }
    func testLayoutReplacementWithSameDateInvalidatesBindings() {
        let (record,s)=fixture();var cache=SavedWindowBindings()
        _=cache.bind(record,snapshot:s,displayToken:"panel")
        var replaced=record;replaced.profile.windows[0].selector.title="Different saved window"
        XCTAssertNil(cache.bind(replaced,snapshot:s,displayToken:"panel").profile.windows[0].runtime)
    }
    func testUnknownProcessLifetimeDoesNotCreateBinding() {
        var (record,s)=fixture();s.windows[0].processStartedAt=nil
        var cache=SavedWindowBindings()
        XCTAssertNil(cache.bind(record,snapshot:s,displayToken:"panel").profile.windows[0].runtime)
    }
    func testSameTokenInDifferentAppCannotUseOldBinding() throws {
        let (record,initial)=fixture();var cache=SavedWindowBindings()
        _=cache.bind(record,snapshot:initial,displayToken:"panel")
        var s=initial;s.windows[0].selector.bundleID="fixture.other"
        let bound=cache.bind(record,snapshot:s,displayToken:"panel")
        let p=try QuickRestorePlanner.plan(record:bound,monitor:.builtInOnly,displayToken:"panel",snapshot:s,allowCrossSpace:true)
        XCTAssertNil(p.items[0].chosenToken)
        XCTAssertFalse(QuickRestorePlanner.autoEligible(p.items[0]))
    }
}
