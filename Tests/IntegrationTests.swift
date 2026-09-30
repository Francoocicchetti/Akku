import Foundation
import AppKit
import Darwin

@main
struct IntegrationTests {
    static func main() throws {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            checks += 1
            guard condition() else { fputs("FAIL: \(name)\n", stderr); exit(1) }
        }
        let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/TestStorage-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = LocalStore(directory: dir)
        let home = SavedHome(latitude: 0.0, longitude: 0.0, accuracy: 20)
        check(store.write(home, name: "home.json"), "Location writes locally")
        check(store.write(home, name: "home.json") && store.physicalWrites == 1 && store.skippedWrites == 1, "Unchanged JSON does not rewrite the file")
        let loaded = store.read("home.json", as: SavedHome.self)
        check(loaded?.latitude == 0 && loaded?.accuracy == 20, "Saved home round-trip")
        let attributes = try FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent("home.json").path)
        check((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600, "Private location file permissions")
        check(store.remove("home.json"), "User can forget home")
        check(store.read("home.json", as: SavedHome.self) == nil, "Forgotten home absent")
        try Data("bad json".utf8).write(to: dir.appendingPathComponent("broken.json"))
        check(store.read("broken.json", as: SavedHome.self) == nil, "Corruption is handled safely")
        func processTicks() -> UInt64 {
            var info = proc_taskinfo()
            _ = withUnsafeMutablePointer(to: &info) { proc_pidinfo(getpid(), PROC_PIDTASKINFO, 0, $0, Int32(MemoryLayout<proc_taskinfo>.size)) }
            return info.pti_total_user + info.pti_total_system
        }
        func resourceSeconds() -> Double {
            var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
            return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
        }
        let beforeTicks = processTicks(), beforeSeconds = resourceSeconds()
        let began = ProcessInfo.processInfo.systemUptime
        var calculation = 1.0
        while ProcessInfo.processInfo.systemUptime - began < 0.25 { calculation = sin(calculation) + 0.42 }
        let measured = CPUClock.seconds(ticks: processTicks() - beforeTicks)
        let reference = resourceSeconds() - beforeSeconds
        check(measured > 0 && abs(measured - reference) < 0.03, "CPU clock conversion matches independent getrusage on this chip")
        check(calculation.isFinite, "Controlled CPU workload completed")
        let monitor = NativeAppMonitor()
        check(monitor.cpuReads == 0, "Background enumeration does not probe every process CPU")
        monitor.refresh()
        check(monitor.cpuReads == 0, "Repeated background refresh still avoids CPU probes")
        monitor.cpuMonitoringEnabled = true; monitor.refresh()
        check(monitor.cpuReads == monitor.apps.count, "CPU probing only on demand")
        monitor.cpuMonitoringEnabled = false
        let reads = monitor.cpuReads; monitor.refresh()
        check(monitor.cpuReads == reads && monitor.apps.allSatisfy { $0.cpu == nil }, "Hiding CPU view stops probes and clears stale readings")
        check(!monitor.apps.isEmpty, "Native running-app enumeration returns real apps")
        check(!monitor.apps.contains { $0.bundleID == "com.apple.loginwindow" || $0.bundleID == "com.apple.dock" }, "System services excluded from quit UI")
        check(!monitor.apps.contains { $0.application.bundleURL?.path.contains(".app/Contents/") == true }, "Nested helpers aren't presented as standalone apps")
        for app in monitor.apps where app.canQuit {
            check(app.bundleID != "com.apple.finder" && app.bundleID != "com.batterytrip.mac", "Protected apps cannot be quit")
            check(!(app.application.bundleURL?.path.hasPrefix("/System/Library/") ?? true), "No core system services can be quit")
        }
        let battery = BatterySnapshot.read()
        if let percent = battery.percent { check((0...100).contains(percent), "Native battery percent is valid") }
        let hardware = HardwareProfile.read(hasBattery: battery.percent != nil)
        check(!hardware.identifier.isEmpty && !hardware.chip.isEmpty, "Actual hardware detected")
        print("PASS: \(checks) local storage, privacy, native app and hardware integration checks")
        print("Hardware: \(hardware.name) / \(hardware.chip)")
        print("Real user-facing apps detected: \(monitor.apps.count)")
    }
}
