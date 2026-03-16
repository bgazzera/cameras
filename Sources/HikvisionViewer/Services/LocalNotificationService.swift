import Foundation
import UserNotifications

struct LocalNotificationService {
    func requestAuthorizationIfNeeded() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return
        }
    }

    func notifyDoorbellRinging() async {
        let content = UNMutableNotificationContent()
        content.title = "Portero"
        content.body = "Someone is ringing the doorbell. Switching to the Portero stream."
        content.sound = .default

        let request = UNNotificationRequest(identifier: "hikvisionViewer.portero.ringing", content: content, trigger: nil)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            return
        }
    }
}