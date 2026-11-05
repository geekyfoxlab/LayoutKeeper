// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 LayoutKeeper contributors
import Foundation

/// 只缓存已确认的窗口身份，不更新保存的桌面、位置或标题，也不写入布局文件。
public struct SavedWindowBindings {
    private var records: [String:MonitorLayoutRecord]=[:]
    public init() {}
    public mutating func bind(_ saved: MonitorLayoutRecord,snapshot: Snapshot,displayToken: String) -> MonitorLayoutRecord {
        let key=saved.monitor.key
        var previous=records[key]
        func withoutRuntime(_ windows: [SavedWindow]) -> [SavedWindow] {
            windows.map { var w=$0;w.runtime=nil;return w }
        }
        if previous?.savedAt != saved.savedAt || previous.map({withoutRuntime($0.profile.windows) != withoutRuntime(saved.profile.windows)}) == true { previous=nil }
        var bound=saved
        for i in bound.profile.windows.indices {
            let window=saved.profile.windows[i]
            if let old=previous?.profile.windows[i].runtime,
               snapshot.windows.contains(where:{old.matches($0) && $0.selector.bundleID==window.selector.bundleID}) {
                bound.profile.windows[i].runtime=old
                continue
            }
            let match=WindowMatcher.match(window,displayToken:displayToken,snapshot:snapshot,
                                          savedOfApp:saved.profile.windows.filter{$0.selector.bundleID==window.selector.bundleID}.count)
            let certain: Set<MatchKind>=[.document,.title,.identifier,.browserTitle,.browserProfile,.onlyWindow]
            guard match.verdict == .unique,certain.contains(match.kind),let live=match.chosen,live.processStartedAt != nil else {
                // 暂时读不到不等于关闭；旧身份仍须在恢复时通过进程生命周期检查。
                bound.profile.windows[i].runtime=previous?.profile.windows[i].runtime
                continue
            }
            bound.profile.windows[i].runtime=RuntimeWindowIdentity(token:live.token,processStartedAt:live.processStartedAt)
        }
        let counts=Dictionary(grouping:bound.profile.windows.compactMap(\.runtime),by:\.token).mapValues(\.count)
        for i in bound.profile.windows.indices {
            if let token=bound.profile.windows[i].runtime?.token,counts[token] != 1 { bound.profile.windows[i].runtime=nil }
        }
        records[key]=bound
        return bound
    }
}
