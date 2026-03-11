import Foundation
import UserNotifications

/// Manages macOS user notifications for drift and conflict alerts.
///
/// Uses `UNUserNotificationCenter` to request authorization and deliver
/// notifications when sync drift is detected. Notification identifiers are
/// stable so repeated alerts replace previous ones rather than spamming.
final class NotificationService: NotificationServiceProtocol, @unchecked Sendable {

    /// The notification center used for scheduling notifications.
    private let center: UNUserNotificationCenter

    /// A closure that returns whether notifications are currently enabled in preferences.
    private let isEnabled: @Sendable () -> Bool

    /// Stable notification identifiers for replacement behavior.
    private enum NotificationID {
        static let localDrift = "cc.carpio.ChezmoiSyncMonitor.localDrift"
        static let remoteDrift = "cc.carpio.ChezmoiSyncMonitor.remoteDrift"
        static let conflict = "cc.carpio.ChezmoiSyncMonitor.conflict"
    }

    /// The notification category identifier for drift alerts.
    private static let driftCategory = "DRIFT_ALERT"

    /// Creates a new NotificationService.
    /// - Parameters:
    ///   - center: The notification center to use. Defaults to `.current()`.
    ///   - isEnabled: A closure returning whether notifications are enabled in preferences.
    init(
        center: UNUserNotificationCenter = .current(),
        isEnabled: @escaping @Sendable () -> Bool
    ) {
        self.center = center
        self.isEnabled = isEnabled
    } // End of init(center:isEnabled:)

    /// Requests notification authorization from the user.
    /// - Returns: `true` if authorization was granted.
    /// - Throws: If the authorization request fails.
    func requestAuthorization() async throws -> Bool {
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted
    } // End of func requestAuthorization()

    /// Sends notifications summarizing detected drift based on the current snapshot.
    ///
    /// Delivers up to three distinct notifications (local drift, remote drift, conflict),
    /// each with a stable identifier so repeated calls replace previous alerts.
    /// Only sends if notifications are enabled in preferences and relevant counts are > 0.
    /// - Parameter snapshot: The current sync snapshot.
    func notifyDrift(snapshot: SyncSnapshot) async {
        guard isEnabled() else { return }

        let localCount = snapshot.localDriftCount
        let remoteCount = snapshot.remoteDriftCount
        let conflictCount = snapshot.conflictCount

        // If everything is clean, remove any pending drift notifications
        let allIDs = [NotificationID.localDrift, NotificationID.remoteDrift, NotificationID.conflict]
        if localCount == 0 && remoteCount == 0 && conflictCount == 0 {
            center.removeDeliveredNotifications(withIdentifiers: allIDs)
            center.removePendingNotificationRequests(withIdentifiers: allIDs)
            return
        }

        // Local drift notification
        if localCount > 0 {
            let content = UNMutableNotificationContent()
            content.title = Strings.notifications.localChangesTitle
            content.body = Strings.notifications.localChangesBody(localCount)
            content.categoryIdentifier = NotificationService.driftCategory
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: NotificationID.localDrift,
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        } else {
            center.removeDeliveredNotifications(withIdentifiers: [NotificationID.localDrift])
        } // End of local drift notification block

        // Remote drift notification
        if remoteCount > 0 {
            let content = UNMutableNotificationContent()
            content.title = Strings.notifications.remoteChangesTitle
            content.body = Strings.notifications.remoteChangesBody(remoteCount)
            content.categoryIdentifier = NotificationService.driftCategory
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: NotificationID.remoteDrift,
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        } else {
            center.removeDeliveredNotifications(withIdentifiers: [NotificationID.remoteDrift])
        } // End of remote drift notification block

        // Conflict notification
        if conflictCount > 0 {
            let content = UNMutableNotificationContent()
            content.title = Strings.notifications.conflictsTitle
            content.body = Strings.notifications.conflictsBody(conflictCount)
            content.categoryIdentifier = NotificationService.driftCategory
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: NotificationID.conflict,
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        } else {
            center.removeDeliveredNotifications(withIdentifiers: [NotificationID.conflict])
        } // End of conflict notification block
    } // End of func notifyDrift(snapshot:)
} // End of class NotificationService
