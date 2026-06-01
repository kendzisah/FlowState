import Foundation
import UIKit

extension AppStore {
    /// Weak reference to the live AppStore so non-View code (sync engine,
    /// ModelContext extensions) can request a widget snapshot refresh without
    /// having to thread the store through every call. Set in
    /// `FlowStateApp` immediately after the store is constructed.
    nonisolated(unsafe) static weak var activeInstanceForWidgetRefresh: AppStore?

    /// Builds the trait dict we send to `Analytics.identify`. Centralised
    /// here so identify callers (AuthManager, RootView restore, etc.) stay
    /// consistent and so adding a new persisted profile field only requires
    /// one site change.
    func analyticsTraits() -> [String: Any] {
        var traits: [String: Any] = [
            "entitled": entitled,
            "theme_mode": themeMode.rawValue,
            "notifications_enabled": notificationsEnabled,
            "calendar_imported": calendarImported,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
            "device_model": UIDevice.current.model,
            "os_version": UIDevice.current.systemVersion,
        ]
        if let v = marketingOptIn { traits["marketing_optin"] = v }
        if let v = primaryNeed { traits["primary_need"] = v.rawValue }
        if let v = neurodivergenceSelfId { traits["neurodivergence_id"] = v.rawValue }
        if let e = userEmail, !e.isEmpty { traits["auth_method"] = "email" }
        else if appleUserIdentifier != nil { traits["auth_method"] = "apple" }
        return traits
    }
}
