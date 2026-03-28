import SwiftUI

// MARK: - Compare Hero Card

struct CompareHeroCard: View {
    let label: String
    let icon: String
    let value1: Int
    let value2: Int
    var isSelected: Bool = false
    var isPercentage: Bool = false
    var invertBetter: Bool = false

    private var difference: Int {
        value1 - value2
    }

    private var percentChange: Double {
        guard value2 > 0 else { return value1 > 0 ? 100 : 0 }
        return Double(difference) / Double(value2) * 100
    }

    private var isBetter: Bool {
        invertBetter ? difference < 0 : difference > 0
    }

    private var iconColor: Color {
        let pageviews = String(localized: "metrics.pageviews")
        let visitors = String(localized: "metrics.visitors")
        let visits = String(localized: "metrics.visits")
        let bounceRate = String(localized: "metrics.bounceRate")

        switch label {
        case pageviews: return .blue
        case visitors: return .purple
        case visits: return .orange
        case bounceRate: return .red
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(iconColor)
                }
            }

            // Periode A Wert
            HStack(spacing: 4) {
                Circle()
                    .fill(.blue)
                    .frame(width: 6, height: 6)
                Text(isPercentage ? "\(value1)%" : value1.formatted())
                    .font(.title3)
                    .fontWeight(.bold)
            }

            // Periode B Wert
            HStack(spacing: 4) {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
                Text(isPercentage ? "\(value2)%" : value2.formatted())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if difference != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: isBetter ? "arrow.up" : "arrow.down")
                        Text(String(format: "%.0f%%", abs(percentChange)))
                    }
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isBetter ? .green : .red)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? iconColor.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? iconColor : .clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
