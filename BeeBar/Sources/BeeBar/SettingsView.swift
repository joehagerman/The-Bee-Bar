//
//  SettingsView.swift
//  BeeBar
//
//  SwiftUI preferences view allowing users to configure the Bee API endpoint,
//  Bearer token, local exports folder, Google Gemini API key, dynamic Gemini model
//  version, and background sync frequency.
//

import SwiftUI
import AppKit

/// Preferences window content view.
struct SettingsView: View {
    @ObservedObject var store: BeeStore
    var onClose: (() -> Void)? = nil

    // MARK: - Form State

    @State private var endpoint: String = ""
    @State private var token: String = ""
    @State private var storageDir: String = ""
    @State private var syncInterval: Int = 5
    @State private var geminiApiKey: String = ""
    @State private var geminiModel: String = BeeConfig.defaultGeminiModel
    @State private var availableModels: [GeminiModelInfo] = []
    @State private var isLoadingModels: Bool = false
    @State private var modelLoadStatus: String? = nil
    @State private var isShowingToken: Bool = false
    @State private var isShowingGeminiKey: Bool = false
    @State private var testResultText: String? = nil
    @State private var isTesting: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    connectionPresetSection
                    endpointSection
                    bearerTokenSection
                    storageDirectorySection
                    geminiConfigurationSection
                    syncFrequencySection
                    connectionTestSection
                }
                .padding(.vertical, 4)
            }

            Divider()
            footerBar
        }
        .padding(16)
        .frame(width: 380, height: 490)
        .onAppear(perform: populateInitialValues)
    }

    // MARK: - Subviews

    private var headerBar: some View {
        HStack {
            Text("BeeBar Settings")
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
            Button("Done") {
                saveAndClose()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(Color.amber)
        }
        .padding(.bottom, 4)
    }

    private var connectionPresetSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Connection Preset")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Button("Local Proxy (8787)") {
                    endpoint = BeeConfig.defaultEndpoint
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Public Cloud API") {
                    endpoint = BeeConfig.publicCloudEndpoint
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var endpointSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("API Endpoint")
                .font(.subheadline)
                .fontWeight(.medium)
            TextField(BeeConfig.defaultEndpoint, text: $endpoint)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var bearerTokenSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Bearer Token")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button("Paste") {
                    if let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !clip.isEmpty {
                        self.token = clip
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundColor(.accentColor)

                Button(isShowingToken ? "Hide" : "Show") {
                    isShowingToken.toggle()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundColor(Color.amber)
            }

            if isShowingToken {
                TextField("Paste token if using public endpoint", text: $token)
                    .textFieldStyle(.roundedBorder)
            } else {
                SecureField("Leave empty if using local proxy", text: $token)
                    .textFieldStyle(.roundedBorder)
            }
            Text("Proxy mode automatically handles auth without token.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var storageDirectorySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Exports Folder")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                TextField("~/Documents/Bee Exports", text: $storageDir)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Button("Browse...") {
                    chooseFolder()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var geminiConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Google Gemini API Key")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button("Paste") {
                    if let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !clip.isEmpty {
                        self.geminiApiKey = clip
                        fetchModels()
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundColor(.accentColor)

                Button(isShowingGeminiKey ? "Hide" : "Show") {
                    isShowingGeminiKey.toggle()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundColor(Color.amber)
            }

            if isShowingGeminiKey {
                TextField("Paste key (AIzaSy...)", text: $geminiApiKey)
                    .textFieldStyle(.roundedBorder)
            } else {
                SecureField("Paste key (AIzaSy...)", text: $geminiApiKey)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Text("Gemini Model Version")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if isLoadingModels {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Fetch Models") {
                        fetchModels()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.top, 4)

            Picker("", selection: $geminiModel) {
                if availableModels.isEmpty {
                    Text("Gemini 2.5 Flash (Default)").tag("gemini-2.5-flash")
                    Text("Gemini 2.5 Pro").tag("gemini-2.5-pro")
                    Text("Gemini 2.0 Flash").tag("gemini-2.0-flash")
                    Text("Gemini 2.0 Flash Lite").tag("gemini-2.0-flash-lite")
                    Text("Gemini 1.5 Flash").tag("gemini-1.5-flash")
                    Text("Gemini 1.5 Pro").tag("gemini-1.5-pro")
                } else {
                    ForEach(availableModels) { m in
                        Text(m.readableName).tag(m.shortId)
                    }
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            if let status = modelLoadStatus {
                Text(status)
                    .font(.caption2)
                    .foregroundColor(status.contains("Loaded") ? .secondary : .orange)
            } else {
                Text("Click 'Fetch Models' to load all available versions for your key.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var syncFrequencySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Background Sync Frequency")
                .font(.subheadline)
                .fontWeight(.medium)

            Picker("", selection: $syncInterval) {
                Text("Every 1 minute").tag(1)
                Text("Every 5 minutes (Recommended)").tag(5)
                Text("Every 15 minutes").tag(15)
                Text("Daily (Every 24 hours)").tag(1440)
                Text("Weekly").tag(10080)
                Text("Manual Only").tag(0)
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private var connectionTestSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button(action: testConnection) {
                    if isTesting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Verify Connection (GET /v1/me)")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isTesting)

                Spacer()
            }

            if let res = testResultText {
                Text(res)
                    .font(.caption)
                    .foregroundColor(res.contains("Connected") ? .green : .red)
            }
        }
    }

    private var footerBar: some View {
        HStack {
            Button("Quit BeeBar") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            Button("Cancel") {
                store.showingSettings = false
                onClose?()
            }
            .buttonStyle(.borderless)

            Button("Save Settings") {
                saveAndClose()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.amber)
        }
    }

    // MARK: - Actions & Helpers

    private func populateInitialValues() {
        self.endpoint = store.config.endpoint
        self.token = store.config.token
        self.storageDir = store.config.storageDir
        self.syncInterval = store.config.syncIntervalMinutes
        self.geminiApiKey = store.config.geminiApiKey
        self.geminiModel = store.config.geminiModel
        if !self.geminiApiKey.isEmpty {
            fetchModels()
        }
    }

    private func fetchModels() {
        let key = geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            modelLoadStatus = "Enter an API key first."
            return
        }
        isLoadingModels = true
        modelLoadStatus = "Querying available models..."
        Task {
            do {
                let models = try await GeminiService.shared.fetchAvailableModels(apiKey: key)
                await MainActor.run {
                    self.isLoadingModels = false
                    self.availableModels = models
                    if !models.isEmpty {
                        self.modelLoadStatus = "Loaded \(models.count) generation models from Google API"
                        if !models.contains(where: { $0.shortId == self.geminiModel }),
                           let first = models.first {
                            self.geminiModel = first.shortId
                        }
                    } else {
                        self.modelLoadStatus = "No text models returned. Using default."
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoadingModels = false
                    self.modelLoadStatus = "Could not list models: \(error.localizedDescription)"
                }
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose Export Folder"
        if panel.runModal() == .OK, let url = panel.url {
            self.storageDir = url.path
        }
    }

    private func testConnection() {
        isTesting = true
        testResultText = nil

        let testCfg = BeeConfig(
            endpoint: endpoint,
            token: token,
            storageDir: storageDir,
            syncIntervalMinutes: syncInterval
        )
        let engine = BeeSyncEngine(config: testCfg)

        Task {
            let res = await engine.testConnection()
            await MainActor.run {
                self.isTesting = false
                self.testResultText = res.success ? "✅ \(res.message)" : "❌ \(res.message)"
            }
        }
    }

    private func saveAndClose() {
        var updated = store.config
        updated.endpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.storageDir = storageDir.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.syncIntervalMinutes = syncInterval
        updated.geminiApiKey = geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.geminiModel = geminiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        store.updateConfig(updated)
        store.showingSettings = false
        onClose?()
    }
}

// MARK: - Brand Accent Color

extension Color {
    static let amber = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
}
