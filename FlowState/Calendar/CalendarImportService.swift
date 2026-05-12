import Foundation
import EventKit
import SwiftData

@MainActor
enum CalendarImportService {
    enum ImportError: Error {
        case denied
        case failure(String)
    }

    struct ImportSummary {
        let inserted: Int
        let updated: Int
        let deleted: Int
    }

    /// Imports / refreshes / prunes events for the next 14 days against EventKit.
    /// Idempotent on `externalIdentifier`. Safe to call repeatedly — it
    /// upserts existing rows and removes any local rows whose source event
    /// is no longer in the 14-day window.
    ///
    /// User customizations are preserved across refresh:
    ///   - `userOverrideEnergy` & `energyRaw` (when overridden)
    ///   - `displaySlotRaw` (the user's manual time-of-day choice)
    ///
    /// When a row's `title` changes and the user hasn't manually picked an
    /// energy, `energyRaw` is cleared and the classifier re-runs in the
    /// background (heuristic baseline + best-effort AI).
    @discardableResult
    static func importNext14Days(into context: ModelContext) async throws -> ImportSummary {
        let store = EKEventStore()
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = (try? await store.requestFullAccessToEvents()) ?? false
        } else {
            granted = await withCheckedContinuation { continuation in
                store.requestAccess(to: .event) { ok, _ in
                    continuation.resume(returning: ok)
                }
            }
        }
        guard granted else { throw ImportError.denied }

        let now = Date()
        guard let end = Calendar.current.date(byAdding: .day, value: 14, to: now) else {
            return ImportSummary(inserted: 0, updated: 0, deleted: 0)
        }
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        // Build an index of existing rows for O(1) lookup by source identifier.
        let descriptor = FetchDescriptor<ImportedEvent>()
        let existing = (try? context.fetch(descriptor)) ?? []
        var byID: [String: ImportedEvent] = [:]
        byID.reserveCapacity(existing.count)
        for e in existing { byID[e.externalIdentifier] = e }

        var seenIDs: Set<String> = []
        seenIDs.reserveCapacity(events.count)

        var newlyInserted: [ImportedEvent] = []
        var retitled: [ImportedEvent] = []
        var updatedCount = 0

        for event in events {
            guard let extID = event.eventIdentifier, !extID.isEmpty else {
                // Some calendar sources (rare) return events without an
                // identifier — we can't dedupe those, so skip them.
                continue
            }
            seenIDs.insert(extID)

            let newTitle = event.title ?? "(No title)"
            let newCal = event.calendar?.title

            if let model = byID[extID] {
                let titleChanged = model.title != newTitle
                let anyChange =
                    titleChanged ||
                    model.startDate != event.startDate ||
                    model.endDate != event.endDate ||
                    model.calendarTitle != newCal

                if anyChange {
                    model.title = newTitle
                    model.startDate = event.startDate
                    model.endDate = event.endDate
                    model.calendarTitle = newCal
                    updatedCount += 1

                    if titleChanged && !model.userOverrideEnergy {
                        // Drop the stale heuristic so the classifier rebuilds it.
                        model.energyRaw = nil
                        retitled.append(model)
                    }
                }
            } else {
                let model = ImportedEvent(
                    externalIdentifier: extID,
                    title: newTitle,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    calendarTitle: newCal
                )
                context.insert(model)
                newlyInserted.append(model)
            }
        }

        // Prune: rows whose source event has vanished from the 14-day window.
        var deletedCount = 0
        for row in existing where !seenIDs.contains(row.externalIdentifier) {
            context.delete(row)
            deletedCount += 1
        }

        context.saveAndSync()

        // Fire-and-forget energy classification for new + retitled events.
        // Caller doesn't await — heuristic fallback ensures UI is never empty.
        let needsClassify = newlyInserted + retitled
        if !needsClassify.isEmpty {
            _Concurrency.Task { @MainActor in
                await EventEnergyClassifier.classify(events: needsClassify, in: context)
            }
        }

        return ImportSummary(
            inserted: newlyInserted.count,
            updated: updatedCount,
            deleted: deletedCount
        )
    }
}
