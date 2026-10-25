import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure app runs as menu bar accessory (no dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Create NSPopover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 530)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuView(store: BeeStore.shared))

        // Create NSStatusItem in the system menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🐝"
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Monitor clicks outside popover
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let self = self, self.popover.isShown {
                self.closePopover(sender: nil)
            }
        }
    }

    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let currentEvent = NSApp.currentEvent else { return }

        // Right-click or Control-click opens context menu
        if currentEvent.type == .rightMouseUp || currentEvent.modifierFlags.contains(.control) {
            showContextMenu()
            return
        }

        togglePopover(sender: sender)
    }

    func togglePopover(sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender: sender)
        } else {
            showPopover(sender: sender)
        }
    }

    func showPopover(sender: AnyObject?) {
        if let button = statusItem.button {
            // Refresh local data when opening
            BeeStore.shared.loadLocalData()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func closePopover(sender: AnyObject?) {
        popover.performClose(sender)
    }

    func showContextMenu() {
        let menu = NSMenu()

        let syncItem = NSMenuItem(title: "Sync Records Now", action: #selector(menuSyncNow), keyEquivalent: "s")
        syncItem.target = self
        menu.addItem(syncItem)

        let finderItem = NSMenuItem(title: "Open Bee Exports in Finder", action: #selector(menuOpenFinder), keyEquivalent: "f")
        finderItem.target = self
        menu.addItem(finderItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Preferences...", action: #selector(menuOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit BeeBar", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // Reset so regular clicks continue to toggle popover
    }

    @objc func menuSyncNow() {
        Task {
            await BeeStore.shared.performSync()
        }
    }

    @objc func menuOpenFinder() {
        BeeStore.shared.openFolderInFinder()
    }

    @objc func menuOpenSettings() {
        BeeStore.shared.showingSettings = true
        showPopover(sender: nil)
    }

    @objc func menuQuit() {
        NSApp.terminate(nil)
    }
}
