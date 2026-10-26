//
//  SettingsView.swift
//  BeeBar
//
//  SwiftUI preferences view allowing users to configure the Bee API endpoint,
//  Bearer token, local exports folder, number of menu bar recordings to show,
//  Google Gemini API key, dynamic Gemini model version, custom Gemini pre-prompt,
//  and background sync frequency.
//

import SwiftUI
import AppKit

/// Preference tabs.
enum SettingsTab: String, CaseIterable, Identifiable {
    case connection = "Connection & Proxy"
    case general = "Sync & Menu"
    case gemini = "Gemini AI"

    var id: String { rawValue }
}

/// Preferences window content view.
struct SettingsView: View {
    @ObservedObject var store: BeeStore
    var onClose: (() -> Void)? = nil

    // MARK: - State

    @State private var selectedTab: SettingsTab = .connection

    // Bee Connection State
    @State private var endpoint: String = ""
    @State private var token: String = ""
    @State private var isShowingToken: Bool = false
    @State private var testResultText: String? = nil
    @State private var isTesting: Bool = false
    @State private var copiedCommandBanner: String? = nil

    // Sync & Menu State
    @State private var storageDir: String = ""
    @State private var syncInterval: Int = 5
    @State private var maxItemsToShow: Int = 15

    // Gemini State
    @State private var geminiApiKey: String = ""
    @State private var geminiModel: String = BeeConfig.defaultGeminiModel
    @State private var geminiPrompt: String = BeeConfig.defaultGeminiPrompt
    @State private var availableModels: [GeminiModelInfo] = []
    @State private var isLoadingModels: Bool = false
    @State private var modelLoadStatus: String? = nil
    @State private var isShowingGeminiKey: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header with Tab Selector
            headerBar
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            // Active Tab Content inside dynamic ScrollView
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    switch selectedTab {
                    case .connection:
                        connectionTabContent
                    case .general:
                        syncAndMenuTabContent
                    case .gemini:
                        geminiTabContent
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer Bar with Actions
            footerBar
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .frame(minWidth: 500, idealWidth: 540, maxWidth: .infinity, minHeight: 520, idealHeight: 600, maxHeight: .infinity)
        .onAppear(perform: populateInitialValues)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        VStack(spacing: 12) {
            HStack {
                Text("The Bee Bar Settings")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Button("Done") {
                    saveAndClose()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.amber)
                .controlSize(.small)
            }

            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Tab 1: Connection & Proxy Content

    private var connectionTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Connection Presets
            VStack(alignment: .leading, spacing: 6) {
                Text("Connection Mode")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 10) {
                    Button(action: {
                        endpoint = BeeConfig.defaultEndpoint
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: endpoint.contains("8787") ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(endpoint.contains("8787") ? Color.amber : .secondary)
                            Text("Local Proxy (8787)")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button(action: {
                        endpoint = BeeConfig.publicCloudEndpoint
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: endpoint.contains("developer.bee.amazon.dev") ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(endpoint.contains("developer.bee.amazon.dev") ? Color.amber : .secondary)
                            Text("Public Cloud API")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }

            // Endpoint URL Input
            VStack(alignment: .leading, spacing: 4) {
                Text("API Endpoint URL")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                TextField(BeeConfig.defaultEndpoint, text: $endpoint)
                    .textFieldStyle(.roundedBorder)
            }

            // Bearer Token Input
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Bearer Token ($BEE_TOKEN)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

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
                    TextField("Leave blank if using Local Proxy", text: $token)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("Leave blank if using Local Proxy", text: $token)
                        .textFieldStyle(.roundedBorder)
                }

                Text("Local Proxy mode automatically manages authentication. Token is only needed for Public Cloud API.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Test Connection Button & Status
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Button(action: testConnection) {
                        if isTesting {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Testing Connection...")
                            }
                        } else {
                            Text("Verify Connection (GET /v1/me)")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(isTesting)

                    Spacer()
                }

                if let res = testResultText {
                    Text(res)
                        .font(.callout)
                        .foregroundColor(res.contains("Connected") ? .green : .red)
                        .padding(.vertical, 2)
                }
            }

            Divider()

            // Step-by-Step Proxy Setup Guide
            proxyStepByStepGuideCard
        }
    }

    // MARK: - Proxy Setup Guide Card

    private var proxyStepByStepGuideCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(Color.amber)
                Text("How to Set Up the Local Proxy Server")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                if let banner = copiedCommandBanner {
                    Text(banner)
                        .font(.caption)
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            }

            Text("The Bee local proxy (`bee proxy`) runs locally on your Mac at port 8787. It automatically signs all requests without requiring you to copy and paste API tokens.")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                // Step 1
                VStack(alignment: .leading, spacing: 3) {
                    Text("1. Install the Bee CLI (if needed)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    HStack {
                        Text("npm install -g @bee-computer/cli")
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(4)
                        Spacer()
                        copyButton(for: "npm install -g @bee-computer/cli")
                    }
                }

                // Step 2
                VStack(alignment: .leading, spacing: 3) {
                    Text("2. Sign in with QR Code")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    HStack {
                        Text("bee login --qr")
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(4)
                        Spacer()
                        copyButton(for: "bee login --qr")
                    }
                    Text("Run this in Terminal, open your Bee mobile app, go to Settings, and scan the terminal QR code.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Step 3
                VStack(alignment: .leading, spacing: 3) {
                    Text("3. Start the Local Proxy")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    HStack {
                        Text("bee proxy")
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(4)
                        Spacer()
                        copyButton(for: "bee proxy")
                    }
                    Text("The proxy will start on http://127.0.0.1:8787. Keep this Terminal tab open.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Step 4
                VStack(alignment: .leading, spacing: 3) {
                    Text("4. Select 'Local Proxy (8787)' Above")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Click the 'Local Proxy (8787)' button above. Leave the Bearer Token empty.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Step 5
                VStack(alignment: .leading, spacing: 3) {
                    Text("5. Click 'Verify Connection'")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Click the verify button to confirm The Bee Bar connects to your device profile.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private func copyButton(for command: String) -> some View {
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
            withAnimation {
                copiedCommandBanner = "Copied command!"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    if self.copiedCommandBanner == "Copied command!" {
                        self.copiedCommandBanner = nil
                    }
                }
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                Text("Copy")
            }
            .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: - Tab 2: Sync & Menu Content

    private var syncAndMenuTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Number of Recordings in Menu
            VStack(alignment: .leading, spacing: 6) {
                Text("Menu Bar Recordings Display")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Picker("Recordings to Show in Menu:", selection: $maxItemsToShow) {
                    Text("5 recordings").tag(5)
                    Text("10 recordings").tag(10)
                    Text("15 recordings (Default)").tag(15)
                    Text("20 recordings").tag(20)
                    Text("25 recordings").tag(25)
                    Text("50 recordings").tag(50)
                    Text("All recordings (100)").tag(100)
                }
                .pickerStyle(.menu)

                Text("Sets how many recent Bee conversation recordings appear in the macOS menu bar dropdown.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Storage Folder
            VStack(alignment: .leading, spacing: 6) {
                Text("Exports Storage Folder")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack {
                    TextField("~/Documents/Bee Exports", text: $storageDir)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button("Browse...") {
                        chooseFolder()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button("Finder") {
                        let path = (storageDir as NSString).expandingTildeInPath
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                Text("Where Markdown (.md) and raw JSON records are downloaded and stored.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Background Sync Frequency
            VStack(alignment: .leading, spacing: 6) {
                Text("Background Sync Schedule")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Picker("Sync Frequency:", selection: $syncInterval) {
                    Text("Every 1 minute").tag(1)
                    Text("Every 5 minutes (Recommended)").tag(5)
                    Text("Every 15 minutes").tag(15)
                    Text("Daily (Every 24 hours)").tag(1440)
                    Text("Weekly").tag(10080)
                    Text("Manual Only (Disabled)").tag(0)
                }
                .pickerStyle(.menu)

                Text("The Bee Bar automatically polls for new Bee conversations and updates timestamps in the background.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Tab 3: Gemini AI Content

    private var geminiTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // API Key
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Google Gemini API Key")
                        .font(.subheadline)
                        .fontWeight(.semibold)

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

                Text("Obtain an API key from Google AI Studio (aistudio.google.com).")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Model Selection
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Gemini Model Version")
                        .font(.subheadline)
                        .fontWeight(.semibold)

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
                }
            }

            Divider()

            // Pre-Prompt Configuration
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Pre-Prompt / System Instructions")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button("Reset to Default") {
                        geminiPrompt = BeeConfig.defaultGeminiPrompt
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundColor(Color.amber)
                }

                Text("This prompt is sent to Google Gemini immediately before the conversation transcript. Customize the structure, tone, or formatting of the executive brief.")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                TextEditor(text: $geminiPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 130, idealHeight: 150)
                    .padding(4)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack {
            Button("Quit The Bee Bar") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

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
            .controlSize(.regular)
        }
    }

    // MARK: - Actions & Helpers

    private func populateInitialValues() {
        self.endpoint = store.config.endpoint
        self.token = store.config.token
        self.storageDir = store.config.storageDir
        self.syncInterval = store.config.syncIntervalMinutes
        self.maxItemsToShow = store.config.maxItemsToShow
        self.geminiApiKey = store.config.geminiApiKey
        self.geminiModel = store.config.geminiModel
        self.geminiPrompt = store.config.geminiPrompt
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
            syncIntervalMinutes: syncInterval,
            maxItemsToShow: maxItemsToShow
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
        updated.maxItemsToShow = maxItemsToShow
        updated.geminiApiKey = geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.geminiModel = geminiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.geminiPrompt = geminiPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        store.updateConfig(updated)
        store.showingSettings = false
        onClose?()
    }
}

// MARK: - Brand Accent Color

extension Color {
    static let amber = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
}
