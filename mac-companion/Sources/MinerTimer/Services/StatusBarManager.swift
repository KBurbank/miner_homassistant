import Foundation
import AppKit
import SwiftUI

@MainActor
class StatusBarManager: NSObject {
    private var statusItem: NSStatusItem!
    private var monitor: ProcessMonitor
    private var timer: Timer?
    
    init(monitor: ProcessMonitor) {
        self.monitor = monitor
        super.init()
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Use unicode timer emoji for all versions
            button.title = "⏱"
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        // Time played
        let timePlayedItem = NSMenuItem(title: "Time played: 0 min", action: nil, keyEquivalent: "")
        menu.addItem(timePlayedItem)
        
        // Time limit
        let timeLimitItem = NSMenuItem(title: "Time limit: 0 min", action: nil, keyEquivalent: "")
        menu.addItem(timeLimitItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add time options
        let addTimeItem = NSMenuItem(title: "Add Time", action: nil, keyEquivalent: "")
        let addTimeSubmenu = NSMenu()
        
        // Add different time increments
        [15, 30, 60].forEach { minutes in
            let item = NSMenuItem(
                title: "+\(minutes) minutes",
                action: #selector(addTime(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.isEnabled = true
            addTimeSubmenu.addItem(item)
        }
        
        addTimeItem.submenu = addTimeSubmenu
        menu.addItem(addTimeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add Quit option
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        
        // Update menu periodically
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMenu()
            }
        }
    }
    
    private func updateMenu() {
        guard let menu = statusItem.menu else { return }
        
        // Update time played
        if let timePlayedItem = menu.item(at: 0) {
            timePlayedItem.title = "Time played: \(Int(monitor.playedTime)) min"
        }
        
        // Update time limit
        if let timeLimitItem = menu.item(at: 1) {
            timeLimitItem.title = "Time limit: \(Int(monitor.currentLimit)) min"
        }
    }
    
    @objc private func addTime(_ sender: NSMenuItem) {
        // Extract the number from "+XX minutes"
        if let minutes = Double(sender.title.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) {
            Logger.shared.log("Adding \(minutes) minutes to time limit")
            monitor.addTime(minutes)  // We'll add this method to ProcessMonitor
        }
    }
    
    @objc private func resetTime() {
        monitor.resetTime()
    }
} 