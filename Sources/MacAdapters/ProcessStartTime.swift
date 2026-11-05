// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 LayoutKeeper contributors
import Foundation
import Darwin

/// 使用内核启动时间区分 PID 的不同生命周期；不依赖 NSRunningApplication 的可选缓存。
enum ProcessStartTime {
    static func read(pid: pid_t) -> Date? {
        var info=proc_bsdinfo()
        let size=MemoryLayout<proc_bsdinfo>.size
        guard proc_pidinfo(pid,PROC_PIDTBSDINFO,0,&info,Int32(size)) == size,
              info.pbi_pid == UInt32(pid),info.pbi_start_tvsec > 0 else { return nil }
        return Date(timeIntervalSince1970:Double(info.pbi_start_tvsec)+Double(info.pbi_start_tvusec)/1_000_000)
    }
}
