//
//  BeeStore.swift
//  BeeBar
//
//  Central @MainActor state container coordinating configuration, local metadata indexing,
//  background synchronization scheduling, and Finder file system operations.
//

import Foundation
import AppKit
import Combine

/// Observable application state store for BeeBar.
@MainActor
public final class BeeStore: ObservableObject {
    public static let shared = BeeStore()

    // MARK: - Published State

    @Published public var config: BeeConfig
    @Published public var conversations: [BeeConversationItem] = []
    @Published public var isSyncing: Bool = false
    @Published public var syncMessage: String = ""
    @Published public var syncProgress: Double = 0.0
    @Published public var isConnected: Bool = false
    @Published public var connectionDetails: String = "Connecting..."
    @Published public var lastSyncTimeText: String = "Never"
    @Published public var showingSettings: Bool = false

    // MARK: - Private Properties

    private let syncEngine: BeeSyncEngine
    private var syncTimer: Timer?

    // MARK: - Initialization

    private init() {
        let loadedConfig = ConfigManager.shared.load()
        self.config = loadedConfig
        self.syncEngine = BeeSyncEngine(config: loadedConfig)

        loadLocalData()
        setupTimer()

        Task {
            await checkConnection()
            await performSync()
        }
    }

    // MARK: - Configuration & Local Cache

    /// Updates the active configuration, persists it to disk, and restarts the background sync schedule.
    public func updateConfig(_ newConfig: BeeConfig) {
        self.config = newConfig
        ConfigManager.shared.save(newConfig)
        setupTimer()
        loadLocalData()

        Task {
            await syncEngine.updateConfig(newConfig)
            await checkConnection()
        }
    }

    /// Reads `<storageDir>/metadata.json` and updates the in-memory `conversations` array.
    public func loadLocalData() {
        let metaPath = (config.storageDir as NSString).appendingPathComponent("metadata.json")
        guard FileManager.default.fileExists(atPath: metaPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: metaPath)) else {
            return
        }

        do {
            let meta = try JSONDecoder().decode(BeeMetadata.self, from: data)
            if let list = meta.conversations {
                self.conversations = list
            }
            if let last = meta.lastSyncedAt {
                let date = Date(timeIntervalSince1970: last / 1000)
                self.lastSyncTimeText = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
            }
        } catch {
            print("Failed to decode metadata.json: \(error)")
        }
    }

    // MARK: - Synchronization & Connectivity

    /// Checks connectivity against the configured Bee API endpoint (`GET /v1/me`).
    public func checkConnection() async {
        let result = await syncEngine.testConnection()
        self.isConnected = result.success
        self.connectionDetails = result.message
    }

    /// Runs an incremental sync against the Bee API and refreshes local conversation data.
    public func performSync() async {
        guard !isSyncing else { return }
        self.isSyncing = true
        self.syncProgress = 0.0
        self.syncMessage = "Starting sync..."

        do {
            _ = try await syncEngine.sync { [weak self] message, progress in
                Task { @MainActor [weak self] in
                    self?.syncMessage = message
                    self?.syncProgress = progress
                }
            }

            self.loadLocalData()
            self.lastSyncTimeText = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
            self.syncMessage = "Synced successfully"
            self.isSyncing = false
            self.isConnected = true
        } catch {
            self.syncMessage = "Sync failed: \(error.localizedDescription)"
            self.isSyncing = false
        }
    }

    // MARK: - Finder & Workspace Operations

    /// Opens the configured exports folder in macOS Finder, creating it first if needed.
    public func openFolderInFinder() {
        let url = URL(fileURLWithPath: config.storageDir)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        NSWorkspace.shared.open(url)
    }

    /// Opens a specific exported file in its default macOS application, or falls back to opening the exports directory.
    public func openFile(atPath path: String) {
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        } else {
            openFolderInFinder()
        }
    }

    /// Highlights and selects a specific file in macOS Finder.
    public func revealInFinder(atPath path: String) {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            openFolderInFinder()
        }
    }

    // MARK: - Background Timer Scheduling

    /// Configures the recurring background sync timer based on `config.syncIntervalMinutes`.
    /// Passing `0` ("Manual Only") disables automatic background syncing.
    private func setupTimer() {
        syncTimer?.invalidate()
        syncTimer = nil

        let mins = config.syncIntervalMinutes
        guard mins > 0 else { return }

        syncTimer = Timer.scheduledTimer(
            timeInterval: Double(mins * 60),
            target: self,
            selector: #selector(handleSyncTimerTick(_:)),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func handleSyncTimerTick(_ timer: Timer) {
        Task {
            await performSync()
        }
    }
}
