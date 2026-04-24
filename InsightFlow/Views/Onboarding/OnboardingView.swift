import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "chart.bar.fill",
            iconColor: .blue,
            title: String(localized: "onboarding.welcome.title"),
            description: String(localized: "onboarding.welcome.subtitle"),
            details: [
                OnboardingDetail(icon: "chart.bar.xaxis", color: .blue, title: "Umami", text: String(localized: "onboarding.welcome.umami")),
                OnboardingDetail(icon: "chart.line.uptrend.xyaxis", color: .indigo, title: "Plausible", text: String(localized: "onboarding.welcome.plausible")),
                OnboardingDetail(icon: "arrow.triangle.branch", color: .green, title: String(localized: "onboarding.welcome.both"), text: String(localized: "onboarding.welcome.both.text"))
            ]
        ),
        OnboardingPage(
            icon: "person.2.fill",
            iconColor: .purple,
            title: String(localized: "onboarding.metrics.title"),
            description: String(localized: "onboarding.metrics.subtitle"),
            details: [
                OnboardingDetail(icon: "person.fill", color: .purple, title: String(localized: "metrics.visitors"), text: String(localized: "onboarding.metrics.visitors")),
                OnboardingDetail(icon: "eye.fill", color: .blue, title: String(localized: "metrics.pageviews"), text: String(localized: "onboarding.metrics.pageviews")),
                OnboardingDetail(icon: "arrow.triangle.swap", color: .orange, title: String(localized: "metrics.visits"), text: String(localized: "onboarding.metrics.bounces"))
            ]
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            iconColor: .green,
            title: String(localized: "onboarding.realtime.title"),
            description: String(localized: "onboarding.realtime.subtitle"),
            details: [
                OnboardingDetail(icon: "antenna.radiowaves.left.and.right", color: .green, title: String(localized: "onboarding.realtime.live"), text: String(localized: "onboarding.realtime.live")),
                OnboardingDetail(icon: "eye.fill", color: .blue, title: String(localized: "onboarding.realtime.activity"), text: String(localized: "onboarding.realtime.activity")),
                OnboardingDetail(icon: "point.topleft.down.to.point.bottomright.curvepath", color: .orange, title: String(localized: "onboarding.realtime.journeys"), text: String(localized: "onboarding.realtime.journeys"))
            ]
        ),
        OnboardingPage(
            icon: "slider.horizontal.3",
            iconColor: .indigo,
            title: String(localized: "onboarding.features.title"),
            description: String(localized: "onboarding.features.subtitle"),
            details: [
                OnboardingDetail(icon: "target", color: .orange, title: String(localized: "onboarding.features.events"), text: String(localized: "onboarding.features.events.text")),
                OnboardingDetail(icon: "arrow.left.arrow.right", color: .blue, title: String(localized: "onboarding.features.compare"), text: String(localized: "onboarding.features.compare.text")),
                OnboardingDetail(icon: "line.3.horizontal.decrease", color: .indigo, title: String(localized: "onboarding.features.filter"), text: String(localized: "onboarding.features.filter.text"))
            ]
        ),
        OnboardingPage(
            icon: "bell.fill",
            iconColor: .orange,
            title: String(localized: "onboarding.notifications.title"),
            description: String(localized: "onboarding.notifications.subtitle"),
            details: [
                OnboardingDetail(icon: "bell.badge", color: .blue, title: String(localized: "onboarding.notifications.daily"), text: String(localized: "onboarding.notifications.daily")),
                OnboardingDetail(icon: "calendar", color: .green, title: String(localized: "onboarding.notifications.weekly"), text: String(localized: "onboarding.notifications.weekly")),
                OnboardingDetail(icon: "clock", color: .purple, title: String(localized: "onboarding.notifications.custom"), text: String(localized: "onboarding.notifications.custom"))
            ]
        )
    ]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page Content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Bottom Section
                VStack(spacing: 20) {
                    // Page Indicator
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.spring(duration: 0.3), value: currentPage)
                        }
                    }

                    // Buttons
                    HStack(spacing: 16) {
                        if currentPage > 0 {
                            Button {
                                withAnimation {
                                    currentPage -= 1
                                }
                            } label: {
                                Text(String(localized: "button.back"))
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }

                        Button {
                            if currentPage < pages.count - 1 {
                                withAnimation {
                                    currentPage += 1
                                }
                            } else {
                                // Fertig
                                UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                                isPresented = false
                            }
                        } label: {
                            Text(currentPage < pages.count - 1 ? String(localized: "button.next") : String(localized: "button.start"))
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    // Skip Button
                    if currentPage < pages.count - 1 {
                        Button {
                            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                            isPresented = false
                        } label: {
                            Text(String(localized: "button.skip"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let details: [OnboardingDetail]
}

struct OnboardingDetail {
    let icon: String
    let color: Color
    let title: String
    let text: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 50))
                .foregroundStyle(page.iconColor)
                .padding(24)
                .background(page.iconColor.opacity(0.15))
                .clipShape(Circle())

            // Title
            Text(page.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // Description
            Text(page.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            // Details
            if !page.details.isEmpty {
                VStack(spacing: 10) {
                    ForEach(Array(page.details.enumerated()), id: \.offset) { _, detail in
                        OnboardingDetailRowCompact(detail: detail)
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

struct OnboardingDetailRowCompact: View {
    let detail: OnboardingDetail

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: detail.icon)
                .font(.body)
                .foregroundStyle(detail.color)
                .frame(width: 28, height: 28)
                .background(detail.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(detail.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(detail.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
