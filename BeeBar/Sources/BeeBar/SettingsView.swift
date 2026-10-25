import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var store: BeeStore

    @State private var endpoint: String = ""
    @State private var token: String = ""
    @State private var storageDir: String = ""
    @State private var syncInterval: Int = 5
    @State private var geminiApiKey: String = ""
    @State private var isShowingToken: Bool = false
    @State private var isShowingGeminiKey: Bool = false
    @State private var testResultText: String? = nil
    @State private var isTesting: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
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

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Quick Preset Buttons
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Connection Preset")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            Button("Local Proxy (8787)") {
                                endpoint = "http://127.0.0.1:8787"
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("Public Cloud API") {
                                endpoint = "https://api.developer.bee.amazon.dev"
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    // Endpoint
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Endpoint")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("http://127.0.0.1:8787", text: $endpoint)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Token
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

                    // Storage Folder
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

                    // Gemini API Key
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Google Gemini API Key (Flash Lite)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Button("Paste") {
                                if let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !clip.isEmpty {
                                    self.geminiApiKey = clip
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
                            TextField("AIzaSy... (for 1-click Flash Lite summarization)", text: $geminiApiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("AIzaSy... (for 1-click Flash Lite summarization)", text: $geminiApiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        Text("Used when selecting 'Summarize with Gemini Flash Lite' on any conversation.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Sync Interval
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

                    // Test Connection
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
                .padding(.vertical, 4)
            }

            Divider()

            HStack {
                Button("Quit BeeBar") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Cancel") {
                    store.showingSettings = false
                }
                .buttonStyle(.borderless)

                Button("Save Settings") {
                    saveAndClose()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.amber)
            }
        }
        .padding(16)
        .frame(width: 380, height: 490)
        .onAppear {
            self.endpoint = store.config.endpoint
            self.token = store.config.token
            self.storageDir = store.config.storageDir
            self.syncInterval = store.config.syncIntervalMinutes
            self.geminiApiKey = store.config.geminiApiKey
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
        store.updateConfig(updated)
        store.showingSettings = false
    }
}

extension Color {
    static let amber = Color(red: 245/255, green: 158/255, blue: 11/255)
}
