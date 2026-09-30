import AppKit
import Combine
import Darwin

enum CPUClock {
    static let nanosecondsPerTick: Double = {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return Double(timebase.numer) / Double(max(1, timebase.denom))
    }()
    static func seconds(ticks: UInt64) -> Double { Double(ticks) * nanosecondsPerTick / 1_000_000_000 }
}

struct RunningApp: Identifiable {
    let application: NSRunningApplication
    let cpu: Double?
    let foreground: Bool
    var id: pid_t { application.processIdentifier }
    var name: String { application.localizedName ?? application.bundleIdentifier ?? "Application" }
    var bundleID: String { application.bundleIdentifier ?? "" }
    var suggestedActivity: Activity? { AppCategory.suggestedActivity(bundleID: bundleID) }
    var canQuit: Bool {
        guard let path = application.bundleURL?.path else { return false }
        return bundleID != "com.apple.finder" && bundleID != "com.batterytrip.mac" && !path.hasPrefix("/System/Library/") && !path.contains(".app/Contents/") && application.processIdentifier != ProcessInfo.processInfo.processIdentifier
    }
}

final class NativeAppMonitor: ObservableObject {
    @Published private(set) var apps: [RunningApp] = []
    @Published private(set) var foregroundID: String?
    @Published private(set) var foregroundName: String?
    var cpuMonitoringEnabled = false {
        didSet { if !cpuMonitoringEnabled { cpuPrevious.removeAll() } }
    }
    private(set) var cpuReads = 0
    var onFocusChange: (() -> Void)?
    var onTerminate: ((NSRunningApplication) -> Void)?
    private var observation: NSKeyValueObservation?
    private var tokens: [NSObjectProtocol] = []
    private var cpuPrevious: [pid_t: (total: UInt64, time: TimeInterval, launched: Date?)] = [:]
    init() {
        observation = NSWorkspace.shared.observe(\.runningApplications, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.refresh() }
        }
        let center = NSWorkspace.shared.notificationCenter
        tokens.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in self?.refreshFocus(); self?.onFocusChange?() })
        tokens.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] notice in
            if let app = notice.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication { self?.onTerminate?(app) }
            self?.refresh()
        })
        refresh()
    }
    private func refreshFocus() {
        let front = NSWorkspace.shared.frontmostApplication
        let id = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front?.bundleIdentifier
        if foregroundID != id { foregroundID = id }
        let name = id == nil ? nil : front?.localizedName
        if foregroundName != name { foregroundName = name }
        let updated = apps.map { RunningApp(application: $0.application, cpu: $0.cpu, foreground: $0.id == front?.processIdentifier) }
        if zip(apps, updated).contains(where: { $0.foreground != $1.foreground }) { apps = updated }
    }
    func refresh() {
        let front = NSWorkspace.shared.frontmostApplication
        refreshFocus()
        let now = ProcessInfo.processInfo.systemUptime
        let running = NSWorkspace.shared.runningApplications.filter {
            guard let path = $0.bundleURL?.path, $0.bundleURL?.pathExtension == "app" else { return false }
            let systemService = path.hasPrefix("/System/Library/") && $0.bundleIdentifier != "com.apple.finder"
            return !$0.isTerminated && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && $0.bundleIdentifier != "com.batterytrip.mac" && $0.activationPolicy != .prohibited && !systemService && !path.contains(".app/Contents/")
        }
        let updated = running.map { app in
            let pid = app.processIdentifier
            var info = proc_taskinfo()
            let size = MemoryLayout<proc_taskinfo>.size
            let read: Int32
            if cpuMonitoringEnabled { read = withUnsafeMutablePointer(to: &info) { proc_pidinfo(pid, PROC_PIDTASKINFO, 0, $0, Int32(size)) }; cpuReads += 1 }
            else { read = 0 }
            var cpu: Double?
            if read == size {
                let total = info.pti_total_user + info.pti_total_system
                if let prev = cpuPrevious[pid], prev.launched == app.launchDate, now - prev.time >= 2, total >= prev.total {
                    cpu = CPUClock.seconds(ticks: total - prev.total) / (now - prev.time) * 100
                } else { cpu = apps.first { $0.id == pid }?.cpu }
                if cpuPrevious[pid] == nil || now - (cpuPrevious[pid]?.time ?? 0) >= 2 { cpuPrevious[pid] = (total, now, app.launchDate) }
            }
            return RunningApp(application: app, cpu: cpu, foreground: app.processIdentifier == front?.processIdentifier)
        }.sorted { a, b in
            if a.foreground != b.foreground { return a.foreground }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        if apps.count != updated.count || zip(apps, updated).contains(where: { $0.id != $1.id || $0.foreground != $1.foreground || $0.cpu != $1.cpu || $0.name != $1.name }) { apps = updated }
        let pids = Set(running.map(\.processIdentifier))
        cpuPrevious = cpuPrevious.filter { pids.contains($0.key) }
    }
    deinit { for token in tokens { NSWorkspace.shared.notificationCenter.removeObserver(token) } }
}
