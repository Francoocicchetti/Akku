import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = BatteryModel()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.setAccessibilityLabel("Akku")
        if let logo = BrandAssets.logo.copy() as? NSImage {
            logo.size = NSSize(width: 20, height: 20); statusItem.button?.image = logo
        }
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        statusItem.button?.toolTip = "Akku"
        model.onUpdate = { [weak self] in self?.updateStatus() }
        updateStatus()
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 480, height: min(740, max(460, (NSScreen.main?.visibleFrame.height ?? 800) - 70)))
        popover.contentViewController = NSHostingController(rootView: RootView(model: model, openWindow: { [weak self] in self?.showWindow() }, isPopover: true))
        model.alerts.onOpen = { [weak self] in self?.showWindow() }
        let event = NSAppleEventManager.shared().currentAppleEvent
        let launchedAtLogin = event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !launchedAtLogin { showWindow() }
        // An ad-hoc development update can invalidate a prior OS consent.
        // Request again only in a user-opened foreground launch; never silently at login.
        if !launchedAtLogin && !model.showWelcome && model.location.enabled && model.location.authorization == .notDetermined {
            DispatchQueue.main.async { [weak self] in self?.model.location.requestPermission() }
        }
    }

    private func updateStatus() {
        let title = " " + (model.snapshot.percent.map { "\(Int($0.rounded()))%" } ?? "—")
        if statusItem?.button?.title != title { statusItem?.button?.title = title }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            model.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func showWindow() {
        popover?.performClose(nil)
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 780), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            w.title = "Akku"
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.backgroundColor = NSColor(red: 0.035, green: 0.055, blue: 0.045, alpha: 1)
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.delegate = self
            // Keep traffic lights above the app header instead of overlapping its controls.
            w.contentView = NSHostingView(rootView: RootView(model: model, openWindow: {}, isPopover: false).padding(.top, 24).background(Palette.background))
            w.contentMinSize = NSSize(width: 380, height: 484)
            w.setContentSize(NSSize(width: 660, height: min(800, max(484, (NSScreen.main?.visibleFrame.height ?? 850) - 60))))
            w.center()
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationWillTerminate(_ notification: Notification) { model.restoreOnExit() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct AkkuMain {
    static func main() {
        if CommandLine.arguments.contains("--diagnostics") {
            let battery = BatterySnapshot.read()
            let hardware = HardwareProfile.read(hasBattery: battery.percent != nil)
            let monitor = NativeAppMonitor()
            let report: [String: Any] = ["model": hardware.name, "identifier": hardware.identifier, "chip": hardware.chip, "recognized": hardware.supported,
                "logoLoaded": BrandAssets.logo.isValid, "battery": battery.percent.map { $0 as Any } ?? NSNull(), "connected": battery.connected,
                "apps": monitor.apps.map { ["name": $0.name, "bundleID": $0.bundleID, "pid": Int($0.id)] }]
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), let text = String(data: data, encoding: .utf8) { print(text) }
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
