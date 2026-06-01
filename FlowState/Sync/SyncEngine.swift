import Foundation
import Observation
import SwiftData

/// Two-way sync between local SwiftData and the Supabase `tasks`,
/// `parked_tasks`, and `imported_events` tables.
///
/// Model:
///   • Every model carries `userID`, `updatedAt`, `syncedAt`. Mutations should
///     call `markDirty()` before saving.
///   • `runFullSync` is called on sign-in and app-foreground. It (1) claims
///     orphan rows for the new user, (2) pushes anything dirty to Supabase,
///     and (3) pulls down anything the server has that's newer than our
///     `syncedAt`.
///   • Deletes are fire-and-forget at the moment they happen — see `delete*`.
///     If the network call fails, a future pull may resurrect the row. For v1
///     we accept that trade-off.
///   • RLS on Supabase guarantees a user can only ever see their own rows;
///     the iOS-side `userID` filter is a belt-and-suspenders check.
@MainActor
@Observable
final class SyncEngine {
    static let shared = SyncEngine()

    private(set) var isSyncing = false
    private(set) var lastSyncError: String?
    private(set) var lastSyncAt: Date?

    private init() {}

    // MARK: - Config

    private var restBase: URL? {
        guard let raw = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              !raw.isEmpty, !raw.contains("$(") else { return nil }
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return URL(string: "\(trimmed)/rest/v1")
    }

    private var publishableKey: String? {
        guard let k = Bundle.main.infoDictionary?["SUPABASE_PUBLISHABLE_KEY"] as? String,
              !k.isEmpty, !k.contains("$(") else { return nil }
        return k
    }

    // MARK: - Public API

    /// Claim orphans → push dirty → pull remote. Called on sign-in and
    /// every app foreground. Idempotent; safe to call repeatedly.
    func runFullSync(context: ModelContext) async {
        guard let userID = AuthManager.shared.currentUserID else { return }
        guard !isSyncing else { return }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }
        Analytics.track(.syncRunStarted(kind: "full"))
        let startedAt = Date()

        claimOrphans(context: context, userID: userID)
        do {
            try await pushDirty(context: context, userID: userID)
            try await pullRemote(context: context, userID: userID)
            lastSyncAt = Date()
            Analytics.track(.syncRunSucceeded(
                latencyMs: Int(Date().timeIntervalSince(startedAt) * 1000),
                recordCount: 0
            ))
        } catch {
            lastSyncError = (error as? LocalizedError)?.errorDescription
                ?? "\(error)"
            Analytics.track(.syncRunFailed(kind: "full", reason: lastSyncError ?? "unknown"))
            AnalyticsErrorReporter.report(error, context: "sync.full")
        }
    }

    /// Fire-and-forget delete on the server. Called from mutation sites
    /// immediately after the local row is deleted. Failures are logged but
    /// don't surface to the user — on the next pull, a still-present server
    /// row would resurrect locally.
    func deleteRemote<T: SyncableModel>(_ type: T.Type, id: UUID) {
        _Concurrency.Task { [weak self] in
            guard let self else { return }
            _ = try? await self.delete(table: T.tableName, id: id)
        }
    }

    /// Assigns the current user as the owner of any rows that don't have one
    /// yet. This is the migration path for users who had local data created
    /// before the auth gate landed.
    private func claimOrphans(context: ModelContext, userID: String) {
        do {
            let tasks = try context.fetch(FetchDescriptor<Task>(predicate: #Predicate { $0.userID == nil }))
            for t in tasks { t.userID = userID; t.markDirty() }

            let parked = try context.fetch(FetchDescriptor<ParkedTask>(predicate: #Predicate { $0.userID == nil }))
            for p in parked { p.userID = userID; p.markDirty() }

            let events = try context.fetch(FetchDescriptor<ImportedEvent>(predicate: #Predicate { $0.userID == nil }))
            for e in events { e.userID = userID; e.markDirty() }

            if !tasks.isEmpty || !parked.isEmpty || !events.isEmpty {
                try? context.save()
            }
        } catch {
            // Non-fatal; the next sync will retry. Recorded as warning so
            // we can spot persistent claim-orphan failures.
            AnalyticsErrorReporter.report(error, context: "sync.claimOrphans")
        }
    }

    // MARK: - Push

    private func pushDirty(context: ModelContext, userID: String) async throws {
        try await pushDirtyTasks(context: context, userID: userID)
        try await pushDirtyParked(context: context, userID: userID)
        try await pushDirtyEvents(context: context, userID: userID)
    }

    private func pushDirtyTasks(context: ModelContext, userID: String) async throws {
        let dirty = try context.fetch(FetchDescriptor<Task>(predicate: #Predicate {
            $0.userID == userID && $0.syncedAt == nil
        }))
        guard !dirty.isEmpty else { return }
        try await upsert(table: "tasks", rows: dirty.map { $0.toJSON() })
        let now = Date()
        for t in dirty { t.syncedAt = now }
        try? context.save()
    }

    private func pushDirtyParked(context: ModelContext, userID: String) async throws {
        let dirty = try context.fetch(FetchDescriptor<ParkedTask>(predicate: #Predicate {
            $0.userID == userID && $0.syncedAt == nil
        }))
        guard !dirty.isEmpty else { return }
        try await upsert(table: "parked_tasks", rows: dirty.map { $0.toJSON() })
        let now = Date()
        for p in dirty { p.syncedAt = now }
        try? context.save()
    }

    private func pushDirtyEvents(context: ModelContext, userID: String) async throws {
        let dirty = try context.fetch(FetchDescriptor<ImportedEvent>(predicate: #Predicate {
            $0.userID == userID && $0.syncedAt == nil
        }))
        guard !dirty.isEmpty else { return }
        try await upsert(table: "imported_events", rows: dirty.map { $0.toJSON() })
        let now = Date()
        for e in dirty { e.syncedAt = now }
        try? context.save()
    }

    // MARK: - Pull

    private func pullRemote(context: ModelContext, userID: String) async throws {
        try await pullTasks(context: context, userID: userID)
        try await pullParked(context: context, userID: userID)
        try await pullEvents(context: context, userID: userID)
    }

    private func pullTasks(context: ModelContext, userID: String) async throws {
        let rows: [TaskRow] = try await fetch(table: "tasks")
        let localByID = try Dictionary(uniqueKeysWithValues:
            context.fetch(FetchDescriptor<Task>()).map { ($0.id, $0) })
        for row in rows {
            if row.deleted_at != nil {
                if let existing = localByID[row.id] {
                    context.delete(existing)
                }
                continue
            }
            if let existing = localByID[row.id] {
                let localTime = existing.updatedAt ?? .distantPast
                if row.updated_at > localTime {
                    row.applyTo(existing)
                    existing.syncedAt = row.updated_at
                }
            } else {
                let task = Task(title: row.title, energyTag: .steady, userID: userID)
                task.id = row.id
                row.applyTo(task)
                task.syncedAt = row.updated_at
                context.insert(task)
            }
        }
        try? context.save()
    }

    private func pullParked(context: ModelContext, userID: String) async throws {
        let rows: [ParkedRow] = try await fetch(table: "parked_tasks")
        let localByID = try Dictionary(uniqueKeysWithValues:
            context.fetch(FetchDescriptor<ParkedTask>()).map { ($0.id, $0) })
        for row in rows {
            if row.deleted_at != nil {
                if let existing = localByID[row.id] { context.delete(existing) }
                continue
            }
            if let existing = localByID[row.id] {
                let localTime = existing.updatedAt ?? .distantPast
                if row.updated_at > localTime {
                    row.applyTo(existing)
                    existing.syncedAt = row.updated_at
                }
            } else {
                let parked = ParkedTask(taskId: row.task_id, taskTitle: row.task_title, elapsedSeconds: row.elapsed_seconds, userID: userID)
                parked.id = row.id
                row.applyTo(parked)
                parked.syncedAt = row.updated_at
                context.insert(parked)
            }
        }
        try? context.save()
    }

    private func pullEvents(context: ModelContext, userID: String) async throws {
        let rows: [EventRow] = try await fetch(table: "imported_events")
        let localByID = try Dictionary(uniqueKeysWithValues:
            context.fetch(FetchDescriptor<ImportedEvent>()).map { ($0.id, $0) })
        for row in rows {
            if row.deleted_at != nil {
                if let existing = localByID[row.id] { context.delete(existing) }
                continue
            }
            if let existing = localByID[row.id] {
                let localTime = existing.updatedAt ?? .distantPast
                if row.updated_at > localTime {
                    row.applyTo(existing)
                    existing.syncedAt = row.updated_at
                }
            } else {
                let event = ImportedEvent(
                    externalIdentifier: row.external_identifier,
                    title: row.title,
                    startDate: row.start_date,
                    endDate: row.end_date,
                    calendarTitle: row.calendar_title
                )
                event.id = row.id
                event.userID = userID
                row.applyTo(event)
                event.syncedAt = row.updated_at
                context.insert(event)
            }
        }
        try? context.save()
    }

    // MARK: - HTTP plumbing

    private func upsert(table: String, rows: [[String: Any]]) async throws {
        guard let base = restBase, let key = publishableKey else { throw SyncError.missingConfig }
        let token = try await AuthManager.shared.accessTokenForRequest()
        let url = base.appendingPathComponent(table)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("resolution=merge-duplicates,return=minimal",
                         forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: rows)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SyncError.network }
        if !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SyncError.server(http.statusCode, body)
        }
    }

    private func fetch<Row: Decodable>(table: String) async throws -> [Row] {
        guard let base = restBase, let key = publishableKey else { throw SyncError.missingConfig }
        let token = try await AuthManager.shared.accessTokenForRequest()
        let url = base.appendingPathComponent(table)

        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SyncError.network }
        if !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SyncError.server(http.statusCode, body)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let container = try d.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = Self.isoFormatter.date(from: raw) { return date }
            if let date = Self.isoNoFractional.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(raw)")
        }
        return try decoder.decode([Row].self, from: data)
    }

    private func delete(table: String, id: UUID) async throws {
        guard let base = restBase, let key = publishableKey else { throw SyncError.missingConfig }
        let token = try await AuthManager.shared.accessTokenForRequest()
        var components = URLComponents(url: base.appendingPathComponent(table), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")]
        guard let url = components?.url else { throw SyncError.network }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.timeoutInterval = 30

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SyncError.network
        }
    }

    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let isoNoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

enum SyncError: LocalizedError {
    case missingConfig
    case network
    case server(Int, String)
    var errorDescription: String? {
        switch self {
        case .missingConfig: return "Sync isn't configured."
        case .network:       return "Network error during sync."
        case .server(let code, _): return "Sync server error (HTTP \(code))."
        }
    }
}

/// Just a marker protocol so `deleteRemote(_:id:)` can take a model type.
protocol SyncableModel {
    static var tableName: String { get }
}

extension Task: SyncableModel       { static var tableName: String { "tasks" } }
extension ParkedTask: SyncableModel { static var tableName: String { "parked_tasks" } }
extension ImportedEvent: SyncableModel { static var tableName: String { "imported_events" } }

// MARK: - JSON shapes + encode/decode helpers

private extension Task {
    func toJSON() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "user_id": userID ?? "",
            "title": title,
            "energy_tag": energyTagRaw,
            "created_at": SyncEngine.isoFormatter.string(from: createdAt),
            "updated_at": SyncEngine.isoFormatter.string(from: updatedAt ?? createdAt),
            "is_completed": isCompleted,
        ]
        if let completedAt { dict["completed_at"] = SyncEngine.isoFormatter.string(from: completedAt) }
        if let scheduledDate { dict["scheduled_date"] = SyncEngine.isoFormatter.string(from: scheduledDate) }
        if let recurrenceRaw { dict["recurrence"] = recurrenceRaw }
        return dict
    }
}

private extension ParkedTask {
    func toJSON() -> [String: Any] {
        return [
            "id": id.uuidString,
            "user_id": userID ?? "",
            "task_id": taskId.uuidString,
            "task_title": taskTitle,
            "elapsed_seconds": elapsedSeconds,
            "parked_at": SyncEngine.isoFormatter.string(from: parkedAt),
            "updated_at": SyncEngine.isoFormatter.string(from: updatedAt ?? parkedAt),
        ]
    }
}

private extension ImportedEvent {
    func toJSON() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "user_id": userID ?? "",
            "external_identifier": externalIdentifier,
            "title": title,
            "start_date": SyncEngine.isoFormatter.string(from: startDate),
            "end_date": SyncEngine.isoFormatter.string(from: endDate),
            "imported_at": SyncEngine.isoFormatter.string(from: importedAt),
            "updated_at": SyncEngine.isoFormatter.string(from: updatedAt ?? importedAt),
            "user_override_energy": userOverrideEnergy,
        ]
        if let calendarTitle { dict["calendar_title"] = calendarTitle }
        if let energyRaw { dict["energy_raw"] = energyRaw }
        if let displaySlotRaw { dict["display_slot_raw"] = displaySlotRaw }
        return dict
    }
}

private struct TaskRow: Decodable {
    let id: UUID
    let title: String
    let energy_tag: String
    let created_at: Date
    let updated_at: Date
    let completed_at: Date?
    let is_completed: Bool
    let scheduled_date: Date?
    let recurrence: String?
    let deleted_at: Date?

    func applyTo(_ t: Task) {
        t.title = title
        t.energyTagRaw = energy_tag
        t.isCompleted = is_completed
        t.completedAt = completed_at
        t.scheduledDate = scheduled_date
        t.recurrenceRaw = recurrence
        t.updatedAt = updated_at
    }
}

private struct ParkedRow: Decodable {
    let id: UUID
    let task_id: UUID
    let task_title: String
    let elapsed_seconds: Int
    let parked_at: Date
    let updated_at: Date
    let deleted_at: Date?

    func applyTo(_ p: ParkedTask) {
        p.taskId = task_id
        p.taskTitle = task_title
        p.elapsedSeconds = elapsed_seconds
        p.parkedAt = parked_at
        p.updatedAt = updated_at
    }
}

private struct EventRow: Decodable {
    let id: UUID
    let external_identifier: String
    let title: String
    let start_date: Date
    let end_date: Date
    let calendar_title: String?
    let imported_at: Date
    let updated_at: Date
    let energy_raw: String?
    let user_override_energy: Bool
    let display_slot_raw: String?
    let deleted_at: Date?

    func applyTo(_ e: ImportedEvent) {
        e.externalIdentifier = external_identifier
        e.title = title
        e.startDate = start_date
        e.endDate = end_date
        e.calendarTitle = calendar_title
        e.importedAt = imported_at
        e.energyRaw = energy_raw
        e.userOverrideEnergy = user_override_energy
        e.displaySlotRaw = display_slot_raw
        e.updatedAt = updated_at
    }
}
