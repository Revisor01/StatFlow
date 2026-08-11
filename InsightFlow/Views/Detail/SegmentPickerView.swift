import SwiftUI
import os

/// Auswahl von Umami-v3-Segmenten und -Cohorts plus den erweiterten
/// Filteroptionen (`match`, `excludeBounce`).
///
/// Segmente gibt es ausschließlich bei Umami ab v3 — bei einem
/// Plausible-Konto zeigt die Ansicht deshalb nur einen erklärenden Hinweis
/// statt einer leeren, scheinbar kaputten Liste.
struct SegmentPickerView: View {
    let website: Website

    @StateObject private var viewModel: SegmentPickerViewModel
    @Environment(\.dismiss) private var dismiss

    /// Segmente/Cohorts sind eine Umami-v3-Funktion — Plausible kennt sie nicht.
    private var isPlausible: Bool {
        AnalyticsManager.shared.providerType == .plausible
    }

    init(website: Website) {
        self.website = website
        _viewModel = StateObject(wrappedValue: SegmentPickerViewModel(websiteId: website.id))
    }

    var body: some View {
        NavigationStack {
            Group {
                if isPlausible {
                    unsupportedProviderView
                } else {
                    content
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "segments.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "button.done")) {
                        Task {
                            await viewModel.applySelection()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(isPlausible)
                }
            }
        }
    }

    // MARK: - Inhalt

    @ViewBuilder
    private var content: some View {
        List {
            filterSection

            if viewModel.isLoading && viewModel.segments.isEmpty && viewModel.cohorts.isEmpty {
                loadingSection
            } else if let errorMessage = viewModel.errorMessage {
                errorSection(errorMessage)
            } else if viewModel.segments.isEmpty && viewModel.cohorts.isEmpty {
                emptySection
            } else {
                segmentSection
                cohortSection
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(String(localized: "segments.search.prompt"))
        )
        .task {
            await viewModel.loadIfNeeded()
        }
        .task(id: viewModel.searchText) {
            await viewModel.searchTextChanged()
        }
        .refreshable {
            await viewModel.reload()
        }
    }

    // MARK: - Filteroptionen

    private var filterSection: some View {
        Section {
            Picker(
                String(localized: "filters.match.title"),
                selection: $viewModel.filterMatch
            ) {
                Text(String(localized: "filters.match.all")).tag(UmamiFilterMatch.all)
                Text(String(localized: "filters.match.any")).tag(UmamiFilterMatch.any)
            }
            .pickerStyle(.segmented)

            Toggle(isOn: $viewModel.excludeBounce) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "filters.excludeBounce"))
                    Text(String(localized: "filters.excludeBounce.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(String(localized: "filters.title"))
        } footer: {
            Text(String(localized: viewModel.filterMatch == .all
                        ? "filters.match.all.description"
                        : "filters.match.any.description"))
        }
    }

    // MARK: - Segmente & Cohorts

    private var segmentSection: some View {
        Section {
            selectionRow(
                title: String(localized: "segments.none"),
                subtitle: nil,
                isSelected: viewModel.selectedSegmentId == nil
            ) {
                viewModel.selectedSegmentId = nil
            }

            ForEach(viewModel.segments) { segment in
                selectionRow(
                    title: segment.name,
                    subtitle: nil,
                    isSelected: viewModel.selectedSegmentId == segment.id
                ) {
                    viewModel.selectedSegmentId = segment.id
                }
            }
        } header: {
            Text(String(localized: "segments.section.segments"))
        } footer: {
            if viewModel.segments.isEmpty {
                Text(String(localized: "segments.section.segments.empty"))
            }
        }
    }

    private var cohortSection: some View {
        Section {
            selectionRow(
                title: String(localized: "segments.cohorts.none"),
                subtitle: nil,
                isSelected: viewModel.selectedCohortId == nil
            ) {
                viewModel.selectedCohortId = nil
            }

            ForEach(viewModel.cohorts) { cohort in
                selectionRow(
                    title: cohort.name,
                    subtitle: nil,
                    isSelected: viewModel.selectedCohortId == cohort.id
                ) {
                    viewModel.selectedCohortId = cohort.id
                }
            }
        } header: {
            Text(String(localized: "segments.section.cohorts"))
        } footer: {
            if viewModel.cohorts.isEmpty {
                Text(String(localized: "segments.section.cohorts.empty"))
            }
        }
    }

    private func selectionRow(
        title: String,
        subtitle: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                        .fontWeight(isSelected ? .semibold : .regular)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                    .opacity(isSelected ? 1 : 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Zustände

    private var loadingSection: some View {
        Section {
            HStack {
                Spacer()
                ProgressView(String(localized: "segments.loading"))
                    .padding(.vertical, 24)
                Spacer()
            }
        }
        .listRowBackground(Color.clear)
    }

    private var emptySection: some View {
        Section {
            ContentUnavailableView(
                viewModel.searchText.isEmpty
                    ? String(localized: "segments.empty")
                    : String(localized: "segments.empty.search"),
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text(String(localized: viewModel.searchText.isEmpty
                                         ? "segments.empty.description"
                                         : "segments.empty.search.description"))
            )
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
    }

    private func errorSection(_ message: String) -> some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)

                Text(String(localized: "segments.error"))
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(String(localized: "segments.retry")) {
                    Task { await viewModel.reload() }
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .listRowBackground(Color.clear)
    }

    private var unsupportedProviderView: some View {
        ContentUnavailableView(
            String(localized: "segments.unsupported"),
            systemImage: "chart.line.uptrend.xyaxis",
            description: Text(String(localized: "segments.unsupported.description"))
        )
    }
}

// MARK: - ViewModel

@MainActor
final class SegmentPickerViewModel: ObservableObject {
    let websiteId: String

    @Published var segments: [UmamiSegment] = []
    @Published var cohorts: [UmamiSegment] = []
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var selectedSegmentId: String?
    @Published var selectedCohortId: String?
    @Published var filterMatch: UmamiFilterMatch = .all
    @Published var excludeBounce: Bool = false

    private let api: UmamiAPI
    private var hasLoadedInitialState = false

    init(websiteId: String, api: UmamiAPI = .shared) {
        self.websiteId = websiteId
        self.api = api
    }

    /// Erstbefüllung: aktuellen Filterzustand aus der API übernehmen und Listen laden.
    func loadIfNeeded() async {
        guard !hasLoadedInitialState else { return }
        hasLoadedInitialState = true

        selectedSegmentId = await api.activeSegmentId
        selectedCohortId = await api.activeCohortId
        filterMatch = await api.filterMatch ?? .all
        excludeBounce = await api.excludeBounce

        await load(search: nil)
    }

    /// Erneutes Laden mit dem aktuell eingegebenen Suchbegriff.
    func reload() async {
        await load(search: searchText)
    }

    /// Debounce für `.searchable` — verhindert einen Request pro Tastendruck.
    func searchTextChanged() async {
        guard hasLoadedInitialState else { return }
        do {
            try await Task.sleep(for: .milliseconds(300))
        } catch {
            return // abgebrochen, weil weitergetippt wurde
        }
        await load(search: searchText)
    }

    private func load(search: String?) async {
        let trimmed = search?.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = (trimmed?.isEmpty ?? true) ? nil : trimmed

        isLoading = true
        errorMessage = nil

        do {
            async let segmentsTask = api.getSegments(websiteId: websiteId, type: .segment, search: query)
            async let cohortsTask = api.getCohorts(websiteId: websiteId, search: query)

            let (loadedSegments, loadedCohorts) = try await (segmentsTask, cohortsTask)

            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            segments = loadedSegments
            cohorts = loadedCohorts
        } catch is CancellationError {
            // Nutzer hat weitergetippt — kein Fehlerzustand.
        } catch {
            Logger.api.error("SegmentPicker load failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            segments = []
            cohorts = []
        }

        isLoading = false
    }

    /// Auswahl an die API übergeben, damit alle folgenden Abfragen sie nutzen.
    func applySelection() async {
        await api.setSegment(selectedSegmentId)
        await api.setCohort(selectedCohortId)
        await api.setFilterMatch(filterMatch)
        await api.setExcludeBounce(excludeBounce)
    }
}

#Preview {
    SegmentPickerView(
        website: Website(
            id: "1",
            name: "Test",
            domain: "test.de",
            shareId: nil,
            teamId: nil,
            resetAt: nil,
            createdAt: nil
        )
    )
}
