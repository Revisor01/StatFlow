import SwiftUI

/// Vermerke einer Website — datierte Notizen, die erklären, warum der Verlauf
/// an einer Stelle ausschlägt („Newsletter raus", „Beitrag im Gemeindebrief").
///
/// Umami führt sie ab Version 3.4. Auf älteren Servern erscheint statt der
/// Liste ein Hinweis, weil die Adresse dort nicht existiert.
struct AnnotationsView: View {
    let website: Website
    let dateRange: DateRange

    @StateObject private var viewModel: AnnotationsViewModel
    @State private var editorSubject: AnnotationEditorSubject?
    @State private var pendingDeletion: UmamiAnnotation?

    init(website: Website, dateRange: DateRange) {
        self.website = website
        self.dateRange = dateRange
        _viewModel = StateObject(wrappedValue: AnnotationsViewModel(websiteId: website.id))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading && viewModel.annotations.isEmpty {
                    ProgressView()
                        .padding(40)
                } else if viewModel.isSupported == false {
                    ContentUnavailableView(
                        String(localized: "annotations.unsupported"),
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text(String(localized: "annotations.unsupported.description"))
                    )
                } else if viewModel.annotations.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        String(localized: "annotations.empty"),
                        systemImage: "text.badge.plus",
                        description: Text(String(localized: "annotations.empty.description"))
                    )
                } else {
                    annotationList
                }

                if let error = viewModel.error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "annotations.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isSupported != false {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorSubject = .new
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "annotations.add"))
                }
            }
        }
        .sheet(item: $editorSubject) { subject in
            AnnotationEditorView(subject: subject, dateRange: dateRange, viewModel: viewModel)
        }
        .confirmationDialog(
            String(localized: "annotations.delete.confirm"),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "button.delete"), role: .destructive) {
                if let annotation = pendingDeletion {
                    Task { await viewModel.delete(annotation) }
                }
                pendingDeletion = nil
            }
            Button(String(localized: "button.cancel"), role: .cancel) {
                pendingDeletion = nil
            }
        }
        .task {
            await viewModel.load(dateRange: dateRange)
        }
    }

    @ViewBuilder
    private var annotationList: some View {
        ForEach(viewModel.annotations) { annotation in
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: "bookmark.fill")
                            .font(.subheadline)
                            .foregroundStyle(.teal)

                        Text(Self.dateText(for: annotation))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }

                    Text(annotation.note)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    editorSubject = .existing(annotation)
                }
            }
            .padding(.horizontal)
            .contextMenu {
                Button {
                    editorSubject = .existing(annotation)
                } label: {
                    Label(String(localized: "annotations.edit"), systemImage: "pencil")
                }
                Button(role: .destructive) {
                    pendingDeletion = annotation
                } label: {
                    Label(String(localized: "button.delete"), systemImage: "trash")
                }
            }
        }
    }

    /// Ganztägige Vermerke zeigen nur das Datum — die gespeicherte Uhrzeit ist
    /// dort ohne Bedeutung und würde eine Genauigkeit vortäuschen.
    static func dateText(for annotation: UmamiAnnotation) -> String {
        annotation.allDay
            ? annotation.date.formatted(date: .abbreviated, time: .omitted)
            : annotation.date.formatted(date: .abbreviated, time: .shortened)
    }
}

/// Was der Editor gerade bearbeitet — ein neuer oder ein bestehender Vermerk.
enum AnnotationEditorSubject: Identifiable {
    case new
    case existing(UmamiAnnotation)

    var id: String {
        switch self {
        case .new: return "new"
        case .existing(let annotation): return annotation.id
        }
    }
}

/// Eingabe für einen Vermerk. Dieselbe Maske für Anlegen und Ändern, weil sich
/// beides nur darin unterscheidet, womit die Felder starten.
struct AnnotationEditorView: View {
    let subject: AnnotationEditorSubject
    let dateRange: DateRange
    @ObservedObject var viewModel: AnnotationsViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var note: String
    @State private var date: Date
    @State private var allDay: Bool

    init(subject: AnnotationEditorSubject, dateRange: DateRange, viewModel: AnnotationsViewModel) {
        self.subject = subject
        self.dateRange = dateRange
        self.viewModel = viewModel

        switch subject {
        case .new:
            _note = State(initialValue: "")
            _date = State(initialValue: Date())
            _allDay = State(initialValue: true)
        case .existing(let annotation):
            _note = State(initialValue: annotation.note)
            _date = State(initialValue: annotation.date)
            _allDay = State(initialValue: annotation.allDay)
        }
    }

    /// Der Server lehnt leere Notizen und mehr als 500 Zeichen mit HTTP 400 ab —
    /// deshalb hier schon prüfen, statt den Fehler erst zurückzubekommen.
    private var isValid: Bool {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= UmamiAnnotation.noteLimit
    }

    private var remaining: Int {
        UmamiAnnotation.noteLimit - note.trimmingCharacters(in: .whitespacesAndNewlines).count
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
                    .lineLimit(3...8)
                } header: {
                    Text("annotations.note")
                } footer: {
                    // Erst gegen Ende einblenden; vorher ist die Zahl nur Lärm.
                    if remaining <= 100 {
                        Text(String(format: String(localized: "annotations.note.remaining"), remaining))
                            .foregroundStyle(remaining < 0 ? .red : .secondary)
                    }
                }

                Section {
                    Toggle(String(localized: "annotations.allday"), isOn: $allDay)
                    DatePicker(
                        String(localized: "annotations.date"),
                        selection: $date,
                        displayedComponents: allDay ? [.date] : [.date, .hourAndMinute]
                    )
                } footer: {
                    Text("annotations.date.description")
                }

                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(String(localized: subject.isNew ? "annotations.add" : "annotations.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "button.save")) {
                        Task { await save() }
                    }
                    .disabled(!isValid || viewModel.isSaving)
                }
            }
            .interactiveDismissDisabled(viewModel.isSaving)
        }
    }

    private func save() async {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let succeeded: Bool

        switch subject {
        case .new:
            succeeded = await viewModel.create(
                date: date,
                note: trimmed,
                allDay: allDay,
                dateRange: dateRange
            )
        case .existing(let annotation):
            succeeded = await viewModel.update(
                annotation,
                date: date,
                note: trimmed,
                allDay: allDay
            )
        }

        // Nur schließen, wenn es geklappt hat — sonst wäre die Eingabe weg und
        // die Fehlermeldung ohne Bezug.
        if succeeded { dismiss() }
    }
}

private extension AnnotationEditorSubject {
    var isNew: Bool {
        if case .new = self { return true }
        return false
    }
}
