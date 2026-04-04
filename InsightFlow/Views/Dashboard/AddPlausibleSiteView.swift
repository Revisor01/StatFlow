import os
import SwiftUI

struct AddPlausibleSiteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var domain = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    let onSiteAdded: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("addSite.domain.placeholder", text: $domain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("addSite.domain.header")
                } footer: {
                    Text("addSite.domain.footer")
                }

                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("addSite.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("button.add") {
                        addSite()
                    }
                    .disabled(domain.isEmpty || isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }

    private func addSite() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await PlausibleAPI.shared.addSite(domain: domain)
                await MainActor.run {
                    onSiteAdded()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    AddPlausibleSiteView {
        Logger.ui.debug("Site added")
    }
}
