//
//  LocalNotificationService.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 10/03/26.
//

import Foundation
import UserNotifications
import UIKit

final class LocalNotificationService {
    static let shared = LocalNotificationService()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if granted {
                print("✅ [Notifications] Permission granted")
            } else {
                print("⚠️ [Notifications] Permission denied: \(error?.localizedDescription ?? "")")
            }
        }
        // Show banners even when app is in foreground
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    /// Call this from any WS message handler when payload has a `notification` key
    func fire(title: String, body: String, sound: UNNotificationSound = .defaultCritical) {
        let content        = UNMutableNotificationContent()
        content.title      = title
        content.body       = body
        content.sound      = sound

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content:    content,
            trigger:    nil        // nil = fire immediately
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("❌ [Notifications] Failed: \(error.localizedDescription)") }
        }
        // Also trigger haptic for in-app feel
        HapticManager.shared.trigger(.warning)
    }
}

// Allows banners to show while app is foregrounded
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    private override init() {}

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
