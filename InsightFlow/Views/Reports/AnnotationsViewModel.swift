import Foundation
import os

/// Vermerke einer Website: datierte Notizen an der Zeitachse, die Umami ab
/// Version 3.4 führt.
///
/// Anders als die übrigen Auswertungen schreibt diese Ansicht auch — Anlegen,
/// Ändern und Löschen brauchen serverseitig das Änderungsrecht an der Website.
/// Ein Konto mit reinem Leserecht bekommt darauf HTTP 401; die Liste bleibt
/// trotzdem sichtbar.
@MainActor
class AnnotationsViewModel: ObservableObject {
    let websiteId: String

    @Published var annotations: [UmamiAnnotation] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?

    /// `nil`, solange nicht geprüft; `false` auf Servern vor Umami 3.4.
    @Published var isSupported: Bool?

    private var loadingTask: Task<Void, Never>?
    private let api: UmamiAPI

    init(websiteId: String, api: UmamiAPI = .shared) {
        self.websiteId = websiteId
        self.api = api
    }

    /// Lädt die Vermerke des Zeitraums, neueste zuerst.
    ///
    /// Der Zeitraum wird bewusst mitgegeben: Vermerke sollen zu dem passen, was
    /// die übrigen Auswertungen gerade zeigen.
    func load(dateRange: DateRange) async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            error = nil
            defer { if !Task.isCancelled { isLoading = false } }

            let supported = await api.supportsAnnotations(websiteId: websiteId)
            guard !Task.isCancelled else { return }
            isSupported = supported
            guard supported else {
                annotations = []
                return
            }

            do {
                let loaded = try await api.getAnnotations(websiteId: websiteId, dateRange: dateRange)
                guard !Task.isCancelled else { return }
                annotations = loaded.sorted { $0.date > $1.date }
            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("loadAnnotations: \(error.localizedDescription)")
                self.error = error.localizedDescription
            }
        }
        loadingTask = task
        await task.value
    }

    /// Legt einen Vermerk an und nimmt ihn sofort in die Liste auf.
    /// Gibt zurück, ob das geklappt hat — die Eingabe bleibt sonst offen.
    func create(date: Date, note: String, allDay: Bool, dateRange: DateRange) async -> Bool {
        await perform {
            let created = try await self.api.createAnnotation(
                websiteId: self.websiteId,
                date: date,
                note: note,
                allDay: allDay
            )
            // Nur einsortieren, wenn der Vermerk in den gezeigten Zeitraum fällt;
            // sonst stünde er in einer Liste, die ihn beim Neuladen verliert.
            let dates = dateRange.dates
            if created.date >= dates.start && created.date <= dates.end {
                self.annotations.append(created)
                self.annotations.sort { $0.date > $1.date }
            }
        }
    }

    func update(_ annotation: UmamiAnnotation, date: Date, note: String, allDay: Bool) async -> Bool {
        await perform {
            let updated = try await self.api.updateAnnotation(
                websiteId: self.websiteId,
                annotationId: annotation.id,
                date: date,
                note: note,
                allDay: allDay
            )
            if let index = self.annotations.firstIndex(where: { $0.id == annotation.id }) {
                self.annotations[index] = updated
                self.annotations.sort { $0.date > $1.date }
            }
        }
    }

    @discardableResult
    func delete(_ annotation: UmamiAnnotation) async -> Bool {
        await perform {
            try await self.api.deleteAnnotation(
                websiteId: self.websiteId,
                annotationId: annotation.id
            )
            self.annotations.removeAll { $0.id == annotation.id }
        }
    }

    /// Klammer um die drei schreibenden Wege: Zustand setzen, Fehler in eine
    /// lesbare Meldung übersetzen, Erfolg zurückmelden.
    private func perform(_ work: @escaping () async throws -> Void) async -> Bool {
        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            try await work()
            return true
        } catch APIError.unauthorized {
            // Der häufigste Fall: Leserecht genügt fürs Anzeigen, nicht fürs Ändern.
            error = String(localized: "annotations.error.readonly")
            return false
        } catch {
            Logger.ui.error("annotation write: \(error.localizedDescription)")
            self.error = error.localizedDescription
            return false
        }
    }
}
