import AppKit
import Darwin

struct PerformanceSample: Codable {
    let date: Date
    let seconds: Double
    let cpuPercentOneCore: Double
    let residentMiB: Double
    let visibility: String
}
struct PerformanceMonitor {
    private var previous: (uptime: Double, cpu: Double, visible: Bool)?
    private(set) var samples: [PerformanceSample] = []
    mutating func sample() {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return }
        let cpu = Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
        let uptime = ProcessInfo.processInfo.systemUptime
        let visible = NSApplication.shared.windows.contains { $0.isVisible && $0.occlusionState.contains(.visible) }
        guard let previous else { self.previous = (uptime, cpu, visible); return }
        let delta = uptime - previous.uptime
        guard delta >= 15 else { return }
        defer { self.previous = (uptime, cpu, visible) }
        guard delta <= 95, cpu >= previous.cpu else { return }
        var info = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.size
        let read = withUnsafeMutablePointer(to: &info) { proc_pidinfo(getpid(), PROC_PIDTASKINFO, 0, $0, Int32(size)) }
        guard read == size else { return }
        let value = PerformanceSample(date: Date(), seconds: delta, cpuPercentOneCore: (cpu - previous.cpu) / delta * 100,
                                      residentMiB: Double(info.pti_resident_size) / 1048576,
                                      visibility: visible == previous.visible ? (visible ? "visible-at-both-readings" : "hidden-at-both-readings") : "visibility-changed")
        samples = Array((samples + [value]).suffix(200))
    }
    var averageCPU: Double? {
        let total = samples.reduce(0) { $0 + $1.seconds }
        return total > 0 ? samples.reduce(0) { $0 + $1.cpuPercentOneCore * $1.seconds } / total : nil
    }
}
