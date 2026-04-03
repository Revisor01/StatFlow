import SwiftUI

// MARK: - Login Provider (UI-specific)

enum LoginProvider: CaseIterable {
    case umami
    case plausible

    var displayName: String {
        switch self {
        case .umami: return "Umami"
        case .plausible: return "Plausible"
        }
    }

    var icon: String {
        switch self {
        case .umami: return "chart.bar.xaxis"
        case .plausible: return "chart.line.uptrend.xyaxis"
        }
    }

    var color: Color {
        switch self {
        case .umami: return .blue
        case .plausible: return .indigo
        }
    }

    var description: String {
        switch self {
        case .umami: return String(localized: "login.umami.description")
        case .plausible: return String(localized: "login.plausible.description")
        }
    }

    var cloudURL: String {
        switch self {
        case .umami: return "https://cloud.umami.is"
        case .plausible: return "https://plausible.io"
        }
    }

    var websiteURL: String {
        switch self {
        case .umami: return "https://umami.is"
        case .plausible: return "https://plausible.io"
        }
    }
}

// MARK: - Server Type

enum ServerType: CaseIterable {
    case cloud
    case selfHosted

    var displayName: String {
        switch self {
        case .cloud: return String(localized: "login.cloud.title")
        case .selfHosted: return String(localized: "login.selfhosted.title")
        }
    }

    var icon: String {
        switch self {
        case .cloud: return "cloud.fill"
        case .selfHosted: return "server.rack"
        }
    }

    var description: String {
        switch self {
        case .cloud: return String(localized: "login.cloud.description")
        case .selfHosted: return String(localized: "login.selfhosted.description")
        }
    }
}

// MARK: - Login View

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()

    @State private var step: LoginStep = .provider
    @State private var selectedProvider: LoginProvider = .umami
    @State private var serverType: ServerType = .cloud
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var apiKey = ""
    @State private var accountName = ""

    @FocusState private var focusedField: Field?

    enum LoginStep {
        case provider
        case credentials
    }

    enum Field {
        case serverURL, username, password, apiKey, accountName
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    headerSection

                    switch step {
                    case .provider:
                        providerSelectionSection
                    case .credentials:
                        credentialsSection
                    }

                    if let error = viewModel.errorMessage {
                        errorView(error)
                    }
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step == .credentials {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            withAnimation {
                                step = .provider
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("button.back")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image("AppIcon1")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)

            Text(String(localized: "app.name"))
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(step == .provider ? "login.subtitle.choose" : "login.subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    // MARK: - Provider Selection

    private var providerSelectionSection: some View {
        VStack(spacing: 20) {
            ForEach(LoginProvider.allCases, id: \.self) { provider in
                ProviderCard(
                    provider: provider,
                    isSelected: selectedProvider == provider
                ) {
                    selectedProvider = provider
                    serverURL = provider.cloudURL
                }
            }

            // Server Type Selector
            VStack(alignment: .leading, spacing: 12) {
                Text("login.serverType")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                HStack(spacing: 12) {
                    ForEach(ServerType.allCases, id: \.self) { type in
                        ServerTypeButton(
                            type: type,
                            isSelected: serverType == type,
                            providerColor: selectedProvider.color
                        ) {
                            withAnimation(.spring(duration: 0.3)) {
                                serverType = type
                                if type == .cloud {
                                    serverURL = selectedProvider.cloudURL
                                } else {
                                    serverURL = ""
                                }
                            }
                        }
                    }
                }
            }

            // Continue Button
            Button {
                withAnimation {
                    step = .credentials
                }
            } label: {
                HStack(spacing: 12) {
                    Text("button.next")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right.circle.fill")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(selectedProvider.color)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Credentials Section

    private var credentialsSection: some View {
        VStack(spacing: 20) {
            // Provider Badge
            HStack(spacing: 12) {
                Image(systemName: selectedProvider.icon)
                    .font(.title2)
                    .foregroundStyle(selectedProvider.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedProvider.displayName)
                        .font(.headline)
                    Text(serverType == .cloud ? selectedProvider.cloudURL : String(localized: "login.selfhosted.title"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Server URL (only for self-hosted)
            if serverType == .selfHosted {
                GlassTextField(
                    icon: "server.rack",
                    placeholder: String(localized: "login.server.placeholder"),
                    text: $serverURL
                )
                .focused($focusedField, equals: .serverURL)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()
            }

            // Credentials
            if selectedProvider == .umami {
                umamiCredentialsFields
            } else {
                plausibleCredentialsFields
            }

            // Login Button
            loginButton
        }
    }

    private var umamiCredentialsFields: some View {
        VStack(spacing: 16) {
            GlassTextField(
                icon: "person.fill",
                placeholder: String(localized: "login.username"),
                text: $username
            )
            .focused($focusedField, equals: .username)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            GlassTextField(
                icon: "lock.fill",
                placeholder: String(localized: "login.password"),
                text: $password,
                isSecure: true
            )
            .focused($focusedField, equals: .password)

            // Optional account name
            accountNameField
        }
    }

    private var plausibleCredentialsFields: some View {
        VStack(spacing: 16) {
            GlassTextField(
                icon: "key.fill",
                placeholder: String(localized: "login.apiKey.placeholder"),
                text: $apiKey,
                isSecure: true
            )
            .focused($focusedField, equals: .apiKey)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            // API Key Help
            Link(destination: URL(string: "\(serverURL)/settings")!) {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                    Text("login.apiKey.help")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            // Optional account name
            accountNameField
        }
    }

    private var accountNameField: some View {
        GlassTextField(
            icon: "tag.fill",
            placeholder: String(localized: "login.accountName.placeholder"),
            text: $accountName
        )
        .focused($focusedField, equals: .accountName)
    }

    private var loginButton: some View {
        Button {
            Task {
                if selectedProvider == .umami {
                    await viewModel.login(
                        serverURL: serverURL,
                        username: username,
                        password: password,
                        accountName: accountName
                    )
                } else {
                    await viewModel.loginWithPlausible(
                        serverURL: serverURL,
                        apiKey: apiKey,
                        accountName: accountName
                    )
                }
            }
        } label: {
            HStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("login.button")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right.circle.fill")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selectedProvider.color)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(viewModel.isLoading || !isFormValid)
        .opacity(isFormValid ? 1 : 0.6)
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
        }
        .font(.subheadline)
        .foregroundColor(.red)
        .padding()
        .frame(maxWidth: .infinity)
        .background(.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var isFormValid: Bool {
        let hasValidServer = serverType == .cloud || !serverURL.isEmpty

        if selectedProvider == .umami {
            return hasValidServer && !username.isEmpty && !password.isEmpty
        } else {
            return hasValidServer && !apiKey.isEmpty
        }
    }
}

// MARK: - Provider Card

struct ProviderCard: View {
    let provider: LoginProvider
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(provider.color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: provider.icon)
                        .font(.title2)
                        .foregroundStyle(provider.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(provider.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? provider.color : .secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? provider.color : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Server Type Button

struct ServerTypeButton: View {
    let type: ServerType
    let isSelected: Bool
    let providerColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? providerColor.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
                        .frame(width: 50, height: 50)

                    Image(systemName: type.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? providerColor : .secondary)
                }

                VStack(spacing: 2) {
                    Text(type.displayName)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? .primary : .secondary)

                    Text(type.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? providerColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass TextField

struct GlassTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    LoginView()
}
