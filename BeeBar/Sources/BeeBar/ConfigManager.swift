import Foundation

public struct BeeConfig: Codable, Sendable {
    public var endpoint: String
    public var token: String
    public var storageDir: String
    public var syncIntervalMinutes: Int
    public var lastSyncedAt: Double?

    public init(
        endpoint: String = "http://127.0.0.1:8787",
        token: String = "",
        storageDir: String = "",
        syncIntervalMinutes: Int = 5,
        lastSyncedAt: Double? = nil
    ) {
        self.endpoint = endpoint
        self.token = token
        self.storageDir = storageDir.isEmpty ? (FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Bee Exports").path) : storageDir
        self.syncIntervalMinutes = syncIntervalMinutes
        self.lastSyncedAt = lastSyncedAt
    }
}

public final class ConfigManager: Sendable {
    public static let shared = ConfigManager()

    private let configURL: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let beeDesktopDir = home.appendingPathComponent(".bee-desktop", isDirectory: true)
        if !FileManager.default.fileExists(atPath: beeDesktopDir.path) {
            try? FileManager.default.createDirectory(at: beeDesktopDir, withIntermediateDirectories: true)
        }
        self.configURL = beeDesktopDir.appendingPathComponent("config.json")
    }

    public func load() -> BeeConfig {
        guard FileManager.default.fileExists(atPath: configURL.path),
              let data = try? Data(contentsOf: configURL) else {
            return BeeConfig()
        }

        do {
            struct PartialConfig: Codable {
                var endpoint: String?
                var token: String?
                var storageDir: String?
                var syncIntervalMinutes: Int?
                var lastSyncedAt: Double?
            }
            let decoded = try JSONDecoder().decode(PartialConfig.self, from: data)
            let defaultStorage = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Bee Exports").path
            return BeeConfig(
                endpoint: decoded.endpoint ?? "http://127.0.0.1:8787",
                token: decoded.token ?? "",
                storageDir: decoded.storageDir ?? defaultStorage,
                syncIntervalMinutes: decoded.syncIntervalMinutes ?? 5,
                lastSyncedAt: decoded.lastSyncedAt
            )
        } catch {
            return BeeConfig()
        }
    }

    public func save(_ config: BeeConfig) {
        do {
            // Read existing JSON if possible to preserve other keys (like 'user' or 'sidebarVisibility')
            var existingDict: [String: Any] = [:]
            if let data = try? Data(contentsOf: configURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                existingDict = json
            }

            existingDict["endpoint"] = config.endpoint
            existingDict["token"] = config.token
            existingDict["storageDir"] = config.storageDir
            existingDict["syncIntervalMinutes"] = config.syncIntervalMinutes
            if let last = config.lastSyncedAt {
                existingDict["lastSyncedAt"] = last
            }

            let outData = try JSONSerialization.data(withJSONObject: existingDict, options: [.prettyPrinted])
            try outData.write(to: configURL, options: [.atomic])
        } catch {
            print("Failed to save config: \(error)")
        }
    }
}
