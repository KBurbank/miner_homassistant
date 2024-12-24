import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    func showTimeExpiredNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Time Expired"
        content.body = "Minecraft has been suspended"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
} 