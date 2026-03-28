import SwiftUI
import Charts

struct WebsiteDetailMetricsSections: View {
    let viewModel: WebsiteDetailViewModel

    var body: some View {
        Group {
            locationSection
            techSection
            if !viewModel.languages.isEmpty || !viewModel.screens.isEmpty {
                languageScreenSection
            }
            if !viewModel.events.isEmpty {
                eventsSection
            }
        }
    }

    // MARK: - Location Section

    var locationSection: some View {
        VStack(spacing: 16) {
            if !viewModel.countries.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: String(localized: "website.countries"), icon: "globe.europe.africa.fill")

                        ForEach(viewModel.countries.prefix(8)) { country in
                            HStack {
                                Text(countryFlag(country.name))
                                    .font(.title3)
                                Text(countryName(country.name))
                                    .font(.subheadline)
                                Spacer()

                                let total = viewModel.countries.reduce(0) { $0 + $1.value }
                                let percentage = total > 0 ? Double(country.value) / Double(total) * 100 : 0

                                Text(String(format: "%.1f%%", percentage))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 50, alignment: .trailing)

                                Text(country.value.formatted())
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(width: 60, alignment: .trailing)
                            }

                            if country.id != viewModel.countries.prefix(8).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: 16) {
                if !viewModel.regions.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: String(localized: "website.regions"), icon: "map.fill")

                            ForEach(viewModel.regions.prefix(5)) { region in
                                HStack {
                                    Text(region.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(region.value.formatted())
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                }

                if !viewModel.cities.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: String(localized: "website.cities"), icon: "building.2.fill")

                            ForEach(viewModel.cities.prefix(5)) { city in
                                HStack {
                                    Text(city.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(city.value.formatted())
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tech Section

    var techSection: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                if !viewModel.devices.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: String(localized: "website.devices"), icon: "iphone")

                            Chart(viewModel.devices, id: \.id) { item in
                                SectorMark(
                                    angle: .value("Anzahl", item.value),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 2
                                )
                                .foregroundStyle(deviceColor(item.name))
                                .cornerRadius(4)
                            }
                            .frame(height: 120)

                            ForEach(viewModel.devices) { item in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(deviceColor(item.name))
                                        .frame(width: 8, height: 8)
                                    Text(deviceName(item.name))
                                        .font(.caption)
                                    Spacer()
                                    Text(item.value.formatted())
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                }

                if !viewModel.browsers.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: String(localized: "website.browsers"), icon: "globe")

                            Chart(viewModel.browsers.prefix(5), id: \.id) { item in
                                SectorMark(
                                    angle: .value("Anzahl", item.value),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 2
                                )
                                .foregroundStyle(browserColor(item.name))
                                .cornerRadius(4)
                            }
                            .frame(height: 120)

                            ForEach(viewModel.browsers.prefix(5)) { item in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(browserColor(item.name))
                                        .frame(width: 8, height: 8)
                                    Text(item.name.capitalized)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(item.value.formatted())
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                }
            }

            if !viewModel.operatingSystems.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: String(localized: "website.os"), icon: "desktopcomputer")

                        ForEach(viewModel.operatingSystems.prefix(6)) { item in
                            HStack {
                                Image(systemName: osIcon(item.name))
                                    .frame(width: 20)
                                    .foregroundStyle(.secondary)
                                Text(item.name)
                                    .font(.subheadline)
                                Spacer()
                                Text(item.value.formatted())
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Language & Screen Section

    var languageScreenSection: some View {
        HStack(alignment: .top, spacing: 16) {
            if !viewModel.languages.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: String(localized: "website.languages"), icon: "character.bubble.fill")

                        ForEach(viewModel.languages.prefix(5)) { language in
                            HStack {
                                Text(languageFlag(language.name))
                                Text(languageName(language.name))
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text(language.value.formatted())
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
            }

            if !viewModel.screens.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: String(localized: "website.screens"), icon: "rectangle.dashed")

                        ForEach(viewModel.screens.prefix(5)) { screen in
                            HStack {
                                Image(systemName: screenIcon(screen.name))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(screen.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text(screen.value.formatted())
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Events Section

    var eventsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Events", icon: "bell.fill")

                ForEach(viewModel.events.prefix(8)) { item in
                    HStack {
                        Text(item.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Text(item.value.formatted())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 4)

                    if item.id != viewModel.events.prefix(8).last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func countryFlag(_ code: String) -> String {
        let base: UInt32 = 127397
        var flag = ""
        for scalar in code.uppercased().unicodeScalars {
            if let unicode = UnicodeScalar(base + scalar.value) {
                flag.append(String(unicode))
            }
        }
        return flag.isEmpty ? "🌍" : flag
    }

    private func countryName(_ code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    private func deviceName(_ name: String) -> String {
        switch name.lowercased() {
        case "desktop": return String(localized: "device.desktop")
        case "mobile": return String(localized: "device.mobile")
        case "tablet": return String(localized: "device.tablet")
        default: return name
        }
    }

    private func osIcon(_ name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("windows") { return "pc" }
        if lowercased.contains("mac") || lowercased.contains("os x") { return "desktopcomputer" }
        if lowercased.contains("ios") || lowercased.contains("iphone") { return "iphone" }
        if lowercased.contains("android") { return "candybarphone" }
        if lowercased.contains("linux") { return "terminal" }
        if lowercased.contains("chrome") { return "globe" }
        return "desktopcomputer"
    }

    private func languageFlag(_ code: String) -> String {
        let languageToCountry: [String: String] = [
            "de": "DE", "en": "GB", "fr": "FR", "es": "ES", "it": "IT",
            "pt": "PT", "nl": "NL", "pl": "PL", "ru": "RU", "ja": "JP",
            "zh": "CN", "ko": "KR", "ar": "SA", "tr": "TR", "sv": "SE"
        ]

        let langCode = String(code.prefix(2)).lowercased()
        if let countryCode = languageToCountry[langCode] {
            return countryFlag(countryCode)
        }
        return "🌐"
    }

    private func languageName(_ code: String) -> String {
        let locale = Locale.current
        let langCode = String(code.prefix(2))
        return locale.localizedString(forLanguageCode: langCode) ?? code
    }

    private func screenIcon(_ size: String) -> String {
        let parts = size.split(separator: "x")
        if let width = parts.first, let w = Int(width) {
            if w < 768 { return "iphone" }
            if w < 1024 { return "ipad" }
            return "desktopcomputer"
        }
        return "rectangle"
    }

    private func deviceColor(_ name: String) -> Color {
        switch name.lowercased() {
        case "desktop", "laptop": return .blue
        case "mobile": return .green
        case "tablet": return .orange
        default: return .purple
        }
    }

    private func browserColor(_ name: String) -> Color {
        let lowercased = name.lowercased()
        if lowercased.contains("chrome") { return .yellow }
        if lowercased.contains("safari") || lowercased.contains("ios") { return .blue }
        if lowercased.contains("firefox") { return .orange }
        if lowercased.contains("edge") { return .cyan }
        if lowercased.contains("samsung") { return .purple }
        if lowercased.contains("opera") { return .red }
        return .gray
    }
}
