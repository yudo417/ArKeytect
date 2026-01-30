import SwiftUI
import AppKit
import GameController

/// メニューバー左クリックでオン/オフするコントローラー機能の状態（永続化）
final class ControllerEnabledState: ObservableObject {
    static let shared = ControllerEnabledState()
    private let key = "ControllerEnabled"
    
    @Published var isControllerEnabled: Bool {
        didSet { UserDefaults.standard.set(isControllerEnabled, forKey: key) }
    }
    
    private init() {
        self.isControllerEnabled = UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }
}

/// App が持つ ControllerMonitor をメニューから開く設定ウィンドウで共有するための保持用
enum StoredControllerMonitor {
    static weak var instance: ControllerMonitor?
}

@main
struct ProControlerForMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var controllerHandler = ControllerMonitor()
    
    init() {
        ProControllerHIDInterceptor.initializeEarly()
        GCController.shouldMonitorBackgroundEvents = true
        requestAccessibilityPermission()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storeControllerMonitor(controllerHandler))
        }
        .defaultSize(CGSize(width: 1000, height: 700))
    }
    
    private func storeControllerMonitor(_ m: ControllerMonitor) -> ControllerMonitor {
        StoredControllerMonitor.instance = m
        return m
    }
    
    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var infoWindow: NSWindow?
    private var isOpeningSettings = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        updateStatusItemIcon()
        button.action = #selector(menuBarClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    private func updateStatusItemIcon() {
        let enabled = ControllerEnabledState.shared.isControllerEnabled
        let name = enabled ? "gamecontroller.fill" : "gamecontroller"
        if let image = NSImage(systemSymbolName: name, accessibilityDescription: "ProController") {
            image.isTemplate = true
            statusItem?.button?.image = image
        } else {
            statusItem?.button?.title = "🎮"
        }
    }

    func applicationWillTerminate(_ notification: Notification) {

    }
    
    @objc func menuBarClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            rightMenuClicked()
        } else if event.type == .leftMouseUp {
            ControllerEnabledState.shared.isControllerEnabled.toggle()
            updateStatusItemIcon()
        }
    }

    @objc func rightMenuClicked() {
        let menu = NSMenu()
        
        // 「このアプリについて」
        let aboutItem = NSMenuItem(
            title: "このアプリについて",
            action: #selector(openinfo),
            keyEquivalent: ""
        )
        if let aboutImage = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About") {
            aboutImage.isTemplate = true
            let resizedImage = aboutImage.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 22, weight: .regular))
            aboutItem.image = resizedImage
        }
        menu.addItem(aboutItem)
        
        // セパレーター
        menu.addItem(NSMenuItem.separator())

        // 設定（構築）
        let settingsItem = NSMenuItem(
            title: "構築",
            action: #selector(opensettings),
            keyEquivalent: ","
        )
        if let settingsImage = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings") {
            settingsImage.isTemplate = true
            let resizedImage = settingsImage.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 22, weight: .regular))
            settingsItem.image = resizedImage
        }
        menu.addItem(settingsItem)
        
        // セパレーター
        menu.addItem(NSMenuItem.separator())
        
        // 終了
        let quitItem = NSMenuItem(
            title: "終了",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        if let quitImage = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Quit") {
            quitImage.isTemplate = true
            let resizedImage = quitImage.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 22, weight: .regular))
            quitItem.image = resizedImage
        }
        menu.addItem(quitItem)

        statusItem?.popUpMenu(menu)
    }

    //MARK: MenubarMenu

    @objc func openinfo() {
        NSApp.activate(ignoringOtherApps: true)
        showInfoWindow()
    }

    @objc func opensettings() {
        NSApp.activate(ignoringOtherApps: true)
        showSettingsWindow()
    }
    
    private func showSettingsWindow() {
        if let existing = self.settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            if existing.isMiniaturized { existing.deminiaturize(nil) }
            return
        }
        if isOpeningSettings { return }
        isOpeningSettings = true
        defer { isOpeningSettings = false }

        let monitor = StoredControllerMonitor.instance ?? ControllerMonitor()
        if StoredControllerMonitor.instance == nil {
            StoredControllerMonitor.instance = monitor
        }
        let content = ContentView().environmentObject(monitor)
        let hosting = NSHostingController(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.settingsWindow = window
        window.title = "Settings"
        window.contentViewController = hosting
        window.setContentSize(NSSize(width: 1000, height: 700))
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        window.delegate = self
    }

    private func showInfoWindow() {
        if let existing = self.infoWindow {
            existing.makeKeyAndOrderFront(nil)
            if existing.isMiniaturized { existing.deminiaturize(nil) }
            return
        }

        let hosting = NSHostingController(rootView: AppInfoView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        self.infoWindow = window
        window.title = "このアプリについて"
        window.contentViewController = hosting
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        window.delegate = self
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        if window == settingsWindow {
            settingsWindow = nil
        } else if window == infoWindow {
            infoWindow = nil
        }
    }
}
