import SwiftUI

// MARK: - GlossaryTerm

struct GlossaryTerm: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: LocalizedStringKey
    let description: LocalizedStringKey
}

// MARK: - Helper Views

private struct GlossaryTermRow: View {
    let term: GlossaryTerm

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: term.icon)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(term.color)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(term.title)
                    .font(.headline)

                Text(term.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - AnalyticsGlossaryView

struct AnalyticsGlossaryView: View {

    private let terms: [GlossaryTerm] = [
        GlossaryTerm(
            icon: "eye",
            color: .blue,
            title: "glossary.term.pageviews.title",
            description: "glossary.term.pageviews.desc"
        ),
        GlossaryTerm(
            icon: "person.2",
            color: .indigo,
            title: "glossary.term.visits.title",
            description: "glossary.term.visits.desc"
        ),
        GlossaryTerm(
            icon: "person",
            color: .purple,
            title: "glossary.term.visitors.title",
            description: "glossary.term.visitors.desc"
        ),
        GlossaryTerm(
            icon: "arrow.uturn.left",
            color: .red,
            title: "glossary.term.bounce-rate.title",
            description: "glossary.term.bounce-rate.desc"
        ),
        GlossaryTerm(
            icon: "clock",
            color: .orange,
            title: "glossary.term.session-duration.title",
            description: "glossary.term.session-duration.desc"
        ),
        GlossaryTerm(
            icon: "link",
            color: .teal,
            title: "glossary.term.referrer.title",
            description: "glossary.term.referrer.desc"
        ),
        GlossaryTerm(
            icon: "tag",
            color: .green,
            title: "glossary.term.utm.title",
            description: "glossary.term.utm.desc"
        ),
        GlossaryTerm(
            icon: "arrow.left.arrow.right",
            color: .cyan,
            title: "glossary.term.entry-exit.title",
            description: "glossary.term.entry-exit.desc"
        ),
        GlossaryTerm(
            icon: "cursorarrow.rays",
            color: .pink,
            title: "glossary.term.events.title",
            description: "glossary.term.events.desc"
        ),
        GlossaryTerm(
            icon: "target",
            color: .mint,
            title: "glossary.term.goals.title",
            description: "glossary.term.goals.desc"
        ),
        GlossaryTerm(
            icon: "percent",
            color: .yellow,
            title: "glossary.term.conversion-rate.title",
            description: "glossary.term.conversion-rate.desc"
        ),
        GlossaryTerm(
            icon: "arrow.down.to.line",
            color: .brown,
            title: "glossary.term.funnels.title",
            description: "glossary.term.funnels.desc"
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("glossary.intro")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(terms) { term in
                    GlossaryTermRow(term: term)
                }
            }
            .padding(16)
        }
        .navigationTitle("glossary.title")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AnalyticsGlossaryView()
    }
}
