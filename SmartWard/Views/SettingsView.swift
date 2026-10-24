import SwiftUI
import BYOKLLMKit
import Pipeline
import StrategistCore

struct SettingsView: View {
    @AppStorage("onboarding.completed") private var onboardingCompleted = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(LLMProvider.allCases) { provider in
                        ProviderKeyRow(provider: provider)
                    }
                } header: {
                    Text("API keys")
                } footer: {
                    Text("Keys are stored only in this device's Keychain. An OpenRouter key alone reaches Anthropic, OpenAI, xAI and open models.")
                }
                Section {
                    NavigationLink("Available models") { AvailableModelsView() }
                    NavigationLink("Usage & budget") { UsageView() }
                    NavigationLink("Export") { ExportView() }
                    NavigationLink("Backup & restore") { BackupView() }
                } footer: {
                    Text("Every model each provider you've keyed currently offers, as of when it was last checked. What your provider has cost, a daily cap for background work, and model fallback. Export your library as JSON, GraphML or Markdown, or back it up encrypted.")
                }
                ReadingSettingsSection()
                BackgroundRefreshSettingsSection()
                DigestSettingsSection()
                KnowledgeGraphSettingsSection()
                GitHubSettingsSection()
                ActionApprovalSettingsSection()
                VoiceSettingsSection()
                ReadAloudSettingsSection()
                VoiceNavigationSettingsSection()
                BriefingSettingsSection()
                SecuritySettingsSection()
                Section {
                    Button("Run setup again") { onboardingCompleted = false }
                } header: {
                    Text("Setup")
                } footer: {
                    Text("Re-runs the onboarding interview. Existing projects are kept; new links, sources and topics are merged in.")
                }
                if DeveloperSettings.isEnabled {
                    Section {
                        NavigationLink("Developer") { DeveloperView() }
                    } footer: {
                        Text("Sample library and latency check. Shown in Debug builds only.")
                    }
                }
                Section("About") {
                    LabeledContent("Version",
                                   value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ProviderKeyRow: View {
    let provider: LLMProvider
    /// Called after a key is saved or removed.
    var onChange: () -> Void = {}
    @State private var key = ""
    @State private var hasKey = false
    @State private var isVerifying = false
    @State private var verifyError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(provider.displayName)
                Spacer()
                if hasKey {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Key saved")
                }
            }
            SecureField(hasKey ? "Replace key" : "Paste key from \(provider.keyHint)", text: $key)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit(save)
            if let verifyError {
                Text(verifyError).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Button(action: save) {
                    if isVerifying {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Save")
                    }
                }
                .disabled(key.isEmpty || isVerifying)
                if hasKey {
                    Button("Remove", role: .destructive, action: remove)
                }
            }
            .buttonStyle(.borderless)
        }
        .onAppear { hasKey = LLMKeychainStore.shared.hasKey(for: provider) }
    }

    /// Verifies the key against the provider's own API (which doubles as
    /// fetching its available models) before saving. A clear rejection (401/
    /// 403) blocks the save; any other failure (unreachable, an unexpected
    /// response shape) still saves the key but says it couldn't be confirmed,
    /// since that's not necessarily a bad key.
    private func save() {
        let candidate = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return }
        verifyError = nil
        isVerifying = true
        Task {
            do {
                try await ProviderModelController.shared.verify(provider: provider, apiKey: candidate)
            } catch ProviderModelFetcher.FetchError.invalidKey {
                verifyError = "That key was rejected by \(provider.displayName)."
                isVerifying = false
                return
            } catch {
                verifyError = "Saved, but couldn't confirm it works yet: \(error.localizedDescription)"
            }
            LLMKeychainStore.shared.set(candidate, for: provider)
            if provider == .openrouter {
                // OpenRouter's catalog lives in ModelCatalogController and
                // refreshes by reading the key back out of the Keychain, so
                // this only works now that the key above is actually saved.
                await ModelCatalogController.shared.load(force: true)
            }
            key = ""
            hasKey = true
            isVerifying = false
            onChange()
        }
    }

    private func remove() {
        LLMKeychainStore.shared.delete(for: provider)
        hasKey = false
        onChange()
    }
}
