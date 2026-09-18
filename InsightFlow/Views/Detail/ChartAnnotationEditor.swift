import SwiftUI

/// Hüllentyp, damit sich ein Datum als `item` an ein Sheet binden lässt.
struct AnnotationDraft: Identifiable {
    let date: Date
    var id: Date { date }

    init(_ date: Date) {
        self.date = date
    }
}

/// Vermerk für einen im Diagramm gewählten Zeitpunkt anlegen.
///
/// Bewusst schmaler als die Eingabe in der Vermerke-Liste: Datum und Uhrzeit
/// stehen bereits fest — sie kommen aus dem angetippten Punkt. Zu ändern bleibt
/// nur die Notiz, und ob der Vermerk für den ganzen Tag gilt.
struct ChartAnnotationEditor: View {
    let websiteId: String
    let date: Date
    let allDay: Bool
    var onCreated: (UmamiAnnotation) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var note = ""
    @State private var isAllDay: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        websiteId: String,
        date: Date,
        allDay: Bool,
        onCreated: @escaping (UmamiAnnotation) -> Void
    ) {
        self.websiteId = websiteId
        self.date = date
        self.allDay = allDay
        self.onCreated = onCreated
        _isAllDay = State(initialValue: allDay)
    }

    /// Der Server lehnt leere Notizen und mehr als 500 Zeichen mit HTTP 400 ab.
    private var isValid: Bool {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= UmamiAnnotation.noteLimit
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        String(localized: "annotations.note.placeholder"),
                        text: $note,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                } header: {
                    Text("annotations.note")
                } footer: {
                    Text(isAllDay
                         ? date.formatted(date: .long, time: .omitted)
                         : date.formatted(date: .long, time: .shortened))
                }

                Section {
                    Toggle(String(localized: "annotations.allday"), isOn: $isAllDay)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(String(localized: "annotations.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "button.save")) {
                        Task { await save() }
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let created = try await UmamiAPI.shared.createAnnotation(
                websiteId: websiteId,
                date: date,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                allDay: isAllDay
            )
            onCreated(created)
            dismiss()
        } catch APIError.unauthorized {
            // Häufigster Fall: Leserecht genügt fürs Anzeigen, nicht fürs Anlegen.
            errorMessage = String(localized: "annotations.error.readonly")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
