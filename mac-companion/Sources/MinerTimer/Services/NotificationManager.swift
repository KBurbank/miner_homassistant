import Foundation
import AppKit
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    private let sound = NSSound(named: NSSound.Name("Glass"))
    private var hasPermission = false
    
    private init() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .alert]) { granted, error in
            if let error = error {
                Logger.shared.log("❌ Notification permission error: \(error.localizedDescription)")
                return
            }
            
            self.hasPermission = granted
            Logger.shared.log(granted ? "✅ Notification permission granted" : "❌ Notification permission denied")
        }
        
        // Verify sound loaded
        if sound == nil {
            Logger.shared.log("❌ Failed to load system sound")
        }
    }
    
    func playFiveMinuteWarning(remainingMinutes: Int) {
        // Play system sound
        if let sound = sound {
            sound.stop()  // Stop any previous playing
            sound.play()
            Logger.shared.log("Playing alert sound")
        } else {
            // Fallback to beep if sound failed to load
            NSSound.beep()
            Logger.shared.log("Using fallback beep sound")
        }
        
        // Show notification
        if hasPermission {
            let content = UNMutableNotificationContent()
            content.title = "Time Warning"
            content.body = "\(remainingMinutes) minutes of game time remaining"
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    Logger.shared.log("❌ Failed to show notification: \(error.localizedDescription)")
                }
            }
        }
        
        // Speak warning using system voice with actual remaining minutes
        let process = Process()
        process.launchPath = "/usr/bin/say"
        process.arguments = ["About \(remainingMinutes) minutes remain"]
        try? process.run()
    }
    
    func playOneMinuteWarning() {
        // Play system sound
        if let sound = sound {
            sound.stop()
            sound.play()
        }
        
        // Speak warning
        let process = Process()
        process.launchPath = "/usr/bin/say"
        process.arguments = ["One minute remains"]
        try? process.run()
    }
    
    func announceGamePaused() {
        let process = Process()
        process.launchPath = "/usr/bin/say"
        process.arguments = ["Minecraft is being paused"]
        try? process.run()
    }
    
    func announceGameResumed(remainingMinutes: Int) {
        Task { @MainActor in
            // Speak warning using system voice
            let process = Process()
            process.launchPath = "/usr/bin/say"
            process.arguments = ["Minecraft resumed with \(remainingMinutes) minutes remaining"]
            try? process.run()
            Logger.shared.log("Announcing game resumed with \(remainingMinutes) minutes")
        }
    }
} 