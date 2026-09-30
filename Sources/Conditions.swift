import AppKit
import CoreGraphics
import IOKit
import IOKit.ps

final class ConditionsMonitor {
    private var lastCPURead = Date.distantPast
    private var previousCPU: host_cpu_load_info?
    private var highIntervals = 0
    private(set) var heavy = false
    func read(apps: [RunningApp], lowPower: Bool, sharing: Bool) -> UsageContext {
        if Date().timeIntervalSince(lastCPURead) >= 30 {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count) }
        }
        mach_port_deallocate(mach_task_self_, host)
        if result == KERN_SUCCESS && Date().timeIntervalSince(lastCPURead) >= 15 {
            lastCPURead = Date()
            if let prior = previousCPU {
                let current = [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3]
                let old = [prior.cpu_ticks.0, prior.cpu_ticks.1, prior.cpu_ticks.2, prior.cpu_ticks.3]
                let delta = zip(current, old).map { Double($0 &- $1) }
                let total = delta.reduce(0, +)
                let utilization = total > 0 ? (total - delta[2]) / total : 0
                highIntervals = utilization > 0.6 ? highIntervals + 1 : 0
            }
            previousCPU = info
        }
        }
        heavy = highIntervals >= 2 || ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical
        var displays = [CGDirectDisplayID](repeating: 0, count: 32)
        var displayCount: UInt32 = 0
        let valid = CGGetActiveDisplayList(32, &displays, &displayCount) == .success
        let external = valid ? displays.prefix(Int(displayCount)).filter { CGDisplayIsBuiltin($0) == 0 }.count : 0
        let ids = apps.filter { $0.application.activationPolicy == .regular && $0.bundleID != "com.apple.finder" }.map(\.bundleID)
        return UsageContext(externalDisplays: external, lowPower: lowPower, heavyLoad: heavy, screenSharing: sharing, apps: Array(Set(ids)).sorted())
    }
    static var lidClosed: Bool? {
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard root != 0 else { return nil }; defer { IOObjectRelease(root) }
        return IORegistryEntryCreateCFProperty(root, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool
    }
    static var adapter: String? {
        guard let details = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any], let watts = details["Watts"] as? NSNumber, watts.doubleValue > 0 else { return nil }
        return "\(watts.intValue)W"
    }
}
