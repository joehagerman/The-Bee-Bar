import Foundation
import AppKit
import Combine

@MainActor
public class BeeStore: ObservableObject {
    public static let shared = BeeStore()

    @Published public var config: BeeConfig
    @Published public var conversations: [BeeConversationItem] = []
    @Published public var isSyncing: Bool = false
    @Published public var syncMessage: String = ""
    @Published public var syncProgress: Double = 0.0
    @Published public var isConnected: Bool = false
    @Published public var connectionDetails: String = "Connecting..."
    @Published public var lastSyncTimeText: String = "Never"
    @Published public var showingSettings: Bool = false

    private var syncEngine: BeeSyncEngine
    private var syncTimer: Timer?

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

    public func updateConfig(_ newConfig: BeeConfig) {
        self.config = newConfig
        ConfigManager.shared.save(newConfig)
        Task {
            await syncEngine.updateConfig(newConfig)
            setupTimer()
            await checkConnection()
        }
    }

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
                let d = Date(timeIntervalSince1970: last / 1000)
                let df = DateFormatter()
                df.timeStyle = .short
                df.dateStyle = .none
                self.lastSyncTimeText = df.string(from: d)
            }
        } catch {
            print("Failed to decode metadata: \(error)")
        }
    }

    public func checkConnection() async {
        let result = await syncEngine.testConnection()
        self.isConnected = result.success
        self.connectionDetails = result.message
    }

    public func performSync() async {
        guard !isSyncing else { return }
        self.isSyncing = true
        self.syncProgress = 0.0
        self.syncMessage = "Starting sync..."

        do {
            _ = try await syncEngine.sync { [weak self] message, progress in
                Task { @MainActor in
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

    public func openFolderInFinder() {
        let url = URL(fileURLWithPath: config.storageDir)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        NSWorkspace.shared.open(url)
    }

    public func openFile(atPath path: String) {
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        } else {
            // Open parent dir if file missing
            openFolderInFinder()
        }
    }

    public func revealInFinder(atPath path: String) {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            openFolderInFinder()
        }
    }

    private func setupTimer() {
        syncTimer?.invalidate()
        let mins = max(1, config.syncIntervalMinutes)
        syncTimer = Timer.scheduledTimer(withTimeInterval: Double(mins * 60), repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performSync()
            }
        }
    }
}
