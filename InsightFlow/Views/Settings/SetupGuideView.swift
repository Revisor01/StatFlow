import SwiftUI

// MARK: - Helper Views

private struct GuideSectionHeader: View {
    let icon: String
    let color: Color
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(.title2)
                .bold()
        }
    }
}

private struct GuideStep: View {
    let number: Int
    let color: Color
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct CodeBlock: View {
    let code: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .padding(12)
        }
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - SetupGuideView

struct SetupGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Intro
                Text("setupGuide.intro")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()
                    .padding(.vertical, 4)

                // MARK: Umami Section
                GuideSectionHeader(
                    icon: "chart.bar.xaxis",
                    color: .orange,
                    title: "setupGuide.umami.title"
                )

                VStack(alignment: .leading, spacing: 16) {
                    GuideStep(
                        number: 1,
                        color: .orange,
                        title: "setupGuide.umami.step1.title",
                        description: "setupGuide.umami.step1.desc"
                    )

                    GuideStep(
                        number: 2,
                        color: .orange,
                        title: "setupGuide.umami.step2.title",
                        description: "setupGuide.umami.step2.desc"
                    )

                    GuideStep(
                        number: 3,
                        color: .orange,
                        title: "setupGuide.umami.step3.title",
                        description: "setupGuide.umami.step3.desc"
                    )

                    CodeBlock(code: """
<script defer
  src="https://your-umami.example/script.js"
  data-website-id="YOUR-WEBSITE-ID">
</script>
""")

                    GuideStep(
                        number: 4,
                        color: .orange,
                        title: "setupGuide.umami.step4.title",
                        description: "setupGuide.umami.step4.desc"
                    )
                }

                Divider()
                    .padding(.vertical, 8)

                // MARK: Plausible Section
                GuideSectionHeader(
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue,
                    title: "setupGuide.plausible.title"
                )

                VStack(alignment: .leading, spacing: 16) {
                    GuideStep(
                        number: 1,
                        color: .blue,
                        title: "setupGuide.plausible.step1.title",
                        description: "setupGuide.plausible.step1.desc"
                    )

                    GuideStep(
                        number: 2,
                        color: .blue,
                        title: "setupGuide.plausible.step2.title",
                        description: "setupGuide.plausible.step2.desc"
                    )

                    GuideStep(
                        number: 3,
                        color: .blue,
                        title: "setupGuide.plausible.step3.title",
                        description: "setupGuide.plausible.step3.desc"
                    )

                    CodeBlock(code: """
<script defer
  data-domain="yourdomain.com"
  src="https://your-plausible.example/js/script.js">
</script>
""")

                    GuideStep(
                        number: 4,
                        color: .blue,
                        title: "setupGuide.plausible.step4.title",
                        description: "setupGuide.plausible.step4.desc"
                    )
                }

                Divider()
                    .padding(.vertical, 8)

                // MARK: Goals Section
                GuideSectionHeader(
                    icon: "target",
                    color: .purple,
                    title: "setupGuide.goals.title"
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("setupGuide.goals.umami.subtitle")
                        .font(.headline)
                        .foregroundStyle(.purple)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(
                            [
                                (LocalizedStringKey("setupGuide.goals.umami.step1"), 1),
                                (LocalizedStringKey("setupGuide.goals.umami.step2"), 2),
                                (LocalizedStringKey("setupGuide.goals.umami.step3"), 3),
                                (LocalizedStringKey("setupGuide.goals.umami.step4"), 4)
                            ],
                            id: \.1
                        ) { step in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(.purple)
                                    .padding(.top, 6)
                                Text(step.0)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    Text("setupGuide.goals.plausible.subtitle")
                        .font(.headline)
                        .foregroundStyle(.purple)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(
                            [
                                (LocalizedStringKey("setupGuide.goals.plausible.step1"), 1),
                                (LocalizedStringKey("setupGuide.goals.plausible.step2"), 2),
                                (LocalizedStringKey("setupGuide.goals.plausible.step3"), 3),
                                (LocalizedStringKey("setupGuide.goals.plausible.step4"), 4)
                            ],
                            id: \.1
                        ) { step in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(.purple)
                                    .padding(.top, 6)
                                Text(step.0)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                Divider()
                    .padding(.vertical, 8)

                // MARK: Verify Section
                GuideSectionHeader(
                    icon: "checkmark.circle",
                    color: .green,
                    title: "setupGuide.verify.title"
                )

                VStack(alignment: .leading, spacing: 16) {
                    GuideStep(
                        number: 1,
                        color: .green,
                        title: "setupGuide.verify.step1.title",
                        description: "setupGuide.verify.step1.desc"
                    )

                    GuideStep(
                        number: 2,
                        color: .green,
                        title: "setupGuide.verify.step2.title",
                        description: "setupGuide.verify.step2.desc"
                    )

                    GuideStep(
                        number: 3,
                        color: .green,
                        title: "setupGuide.verify.step3.title",
                        description: "setupGuide.verify.step3.desc"
                    )

                    GuideStep(
                        number: 4,
                        color: .green,
                        title: "setupGuide.verify.step4.title",
                        description: "setupGuide.verify.step4.desc"
                    )
                }
            }
            .padding()
        }
        .navigationTitle(String(localized: "setupGuide.title"))
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        SetupGuideView()
    }
}
