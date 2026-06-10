import SwiftUI

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Image(systemName: icon)
                .foregroundStyle(.secondary)
        }
    }
}

struct DateRangeChip: View {
    let title: String
    let isSelected: Bool
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
            }
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.primary : .clear)
            .foregroundColor(isSelected ? Color(.systemBackground) : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? .clear : .secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct HeroStatCard: View {
    let value: String
    let label: String
    let change: Double?
    let icon: String
    let color: Color
    var isLive: Bool = false
    var invertChangeColor: Bool = false
    var showChevron: Bool = false
    var isSelected: Bool = false

    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)

                Spacer()

                if isLive {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(.green.opacity(0.5), lineWidth: 2)
                                .scaleEffect(isAnimating ? 2 : 1)
                                .opacity(isAnimating ? 0 : 1)
                        )
                        .onAppear {
                            withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) {
                                isAnimating = true
                            }
                        }
                } else if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .contentTransition(.numericText())

            HStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let change = change, change != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
                        Text(String(format: "%.0f%%", abs(change)))
                    }
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(changeColor(change))
                }
            }
        }
        .padding()
        .background(isSelected ? color.opacity(0.15) : Color(.secondarySystemGroupedBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? color : .clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func changeColor(_ change: Double) -> Color {
        if invertChangeColor {
            return change > 0 ? .red : .green
        }
        return change > 0 ? .green : .red
    }
}

struct HeroStatCardWithLink<Destination: View>: View {
    let value: String
    let label: String
    let change: Double?
    let icon: String
    let color: Color
    var isSelected: Bool = false
    let onTap: () -> Void
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: icon)
                            .foregroundStyle(color)
                        Spacer()
                    }

                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())

                    HStack(spacing: 4) {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let change = change, change != 0 {
                            HStack(spacing: 2) {
                                Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
                                Text(String(format: "%.0f%%", abs(change)))
                            }
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(change > 0 ? .green : .red)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? color.opacity(0.15) : Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? color : .clear, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            // Link-Button oben rechts
            NavigationLink(destination: destination) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(color, color.opacity(0.2))
            }
            .padding(8)
        }
    }
}

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    var isDashed: Bool = false
    var isPoint: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if isPoint {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            } else if isDashed {
                Rectangle()
                    .stroke(color, style: StrokeStyle(lineWidth: 2, dash: [4, 2]))
                    .frame(width: 16, height: 2)
            } else {
                Rectangle()
                    .fill(color)
                    .frame(width: 16, height: 2)
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct CustomDateRangePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        String(localized: "button.back"),
                        selection: $startDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )

                    DatePicker(
                        String(localized: "button.next"),
                        selection: $endDate,
                        in: startDate...Date(),
                        displayedComponents: .date
                    )
                }

                Section {
                    Button {
                        onApply()
                    } label: {
                        HStack {
                            Spacer()
                            Text(String(localized: "button.done"))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "daterange.custom"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Chart Loading Skeleton

/// Dezenter Platzhalter für den Detail-Graphen, solange noch keine Chart-Daten
/// (weder aus Cache noch vom Netzwerk) vorliegen. Verhindert die leere Stelle,
/// die zuvor wie ein „Hängen" der Graph-Generierung wirkte.
struct ChartLoadingSkeleton: View {
    @State private var pulse = false

    // Feste Pseudo-Höhen für eine ruhige, gleichmäßige Balken-Silhouette.
    private let barHeights: [CGFloat] = [0.35, 0.55, 0.4, 0.7, 0.5, 0.85, 0.6, 0.45, 0.75, 0.5, 0.65, 0.4]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                // Header-Platzhalter
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .frame(width: 18, height: 18)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .frame(width: 90, height: 16)
                    Spacer()
                }

                // Balken-Silhouette
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(barHeights.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.tertiarySystemGroupedBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 180 * barHeights[i])
                    }
                }
                .frame(height: 180, alignment: .bottom)
            }
            .opacity(pulse ? 0.45 : 0.9)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
        }
    }
}
