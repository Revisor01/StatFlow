import SwiftUI

struct PagesView: View {
    let website: Website

    @StateObject private var viewModel: PagesViewModel
    @State private var selectedDateRange: DateRange = .thisWeek

    init(website: Website) {
        self.website = website
        _viewModel = StateObject(wrappedValue: PagesViewModel(websiteId: website.id))
    }

    var body: some View {
        List {
            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                }
            } else {
                pagesSection
            }
        }
        .navigationTitle(String(localized: "pages.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(DateRange.allCases, id: \.preset) { range in
                        Button {
                            selectedDateRange = range
                        } label: {
                            if selectedDateRange.preset == range.preset {
                                Label(range.displayName, systemImage: "checkmark")
                            } else {
                                Text(range.displayName)
                            }
                        }
                    }
                } label: {
                    Text(selectedDateRange.displayName)
                        .font(.subheadline)
                }
            }
        }
        .task {
            await viewModel.loadData(dateRange: selectedDateRange)
        }
        .onChange(of: selectedDateRange) { _, newValue in
            Task {
                await viewModel.loadData(dateRange: newValue)
            }
        }
    }

    private var pagesSection: some View {
        Section {
            if viewModel.combinedPages.isEmpty {
                ContentUnavailableView(
                    String(localized: "pages.empty"),
                    systemImage: "doc.text",
                    description: Text(String(localized: "pages.empty.description"))
                )
            } else {
                ForEach(viewModel.combinedPages) { page in
                    PageRow(page: page, baseURL: website.domain ?? website.name)
                }
            }
        } header: {
            HStack {
                Text(String(localized: "pages.visited"))
                Spacer()
                Text("\(viewModel.combinedPages.count) " + String(localized: "pages.count"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text(String(localized: "pages.showFullUrl"))
        }
    }
}

struct PageRow: View {
    let page: CombinedPage
    let baseURL: String

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                // Titel oben
                Text(page.title.isEmpty ? String(localized: "website.noTitle") : page.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                // Vollständige URL darunter
                Text(fullURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(page.views.formatted())
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
    }

    private var fullURL: String {
        let cleanDomain = baseURL.replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        return cleanDomain + page.path
    }
}

// Kombinierte Seite mit Titel und Pfad
struct CombinedPage: Identifiable {
    let id: String
    let title: String
    let path: String
    let views: Int

    init(title: String, path: String, views: Int) {
        self.id = "\(title)-\(path)"
        self.title = title
        self.path = path
        self.views = views
    }
}

#Preview {
    NavigationStack {
        PagesView(
            website: Website(
                id: "1",
                name: "Test Website",
                domain: "kirche-wesselburen.de",
                shareId: nil,
            teamId: nil,
                resetAt: nil,
                createdAt: nil
            )
        )
    }
}
