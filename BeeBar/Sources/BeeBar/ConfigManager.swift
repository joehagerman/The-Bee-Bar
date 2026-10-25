//
//  ConfigManager.swift
//  BeeBar
//
//  Manages reading and writing user configuration to `~/.bee-desktop/config.json`.
//  Preserves external keys in `config.json` that may be used by companion CLI or desktop tools.
//

import Foundation

// MARK: - Configuration Model

/// User preferences and API settings for BeeBar.
public struct BeeConfig: Codable, Sendable {
    public static let defaultEndpoint = "http://127.0.0.1:8787"
    public static let publicCloudEndpoint = "https://api.developer.bee.amazon.dev"
    public static let defaultGeminiModel = "gemini-2.5-flash"

    public var endpoint: String
    public var token: String
    public var storageDir: String
    public var syncIntervalMinutes: Int
    public var lastSyncedAt: Double?
    public var geminiApiKey: String
    public var geminiModel: String

    /// Default exports directory (`~/Documents/Bee Exports`).
    public static var defaultStorageDirectory: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Bee Exports")
            .path
    }

    public init(
        endpoint: String = BeeConfig.defaultEndpoint,
        token: String = "",
        storageDir: String = "",
        syncIntervalMinutes: Int = 5,
        lastSyncedAt: Double? = nil,
        geminiApiKey: String = "",
        geminiModel: String = BeeConfig.defaultGeminiModel
    ) {
        self.endpoint = endpoint.isEmpty ? BeeConfig.defaultEndpoint : endpoint
        self.token = token
        self.storageDir = storageDir.isEmpty ? BeeConfig.defaultStorageDirectory : storageDir
        self.syncIntervalMinutes = syncIntervalMinutes
        self.lastSyncedAt = lastSyncedAt
        self.geminiApiKey = geminiApiKey
        self.geminiModel = geminiModel.isEmpty ? BeeConfig.defaultGeminiModel : geminiModel
    }
}

// MARK: - Configuration Persistence Manager

/// Thread-safe manager responsible for loading and saving `BeeConfig` at `~/.bee-desktop/config.json`.
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

    /// Loads `BeeConfig` from disk, falling back to sensible defaults for any missing fields.
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
                var geminiApiKey: String?
                var geminiModel: String?
            }

            let decoded = try JSONDecoder().decode(PartialConfig.self, from: data)
            return BeeConfig(
                endpoint: decoded.endpoint ?? BeeConfig.defaultEndpoint,
                token: decoded.token ?? "",
                storageDir: decoded.storageDir ?? BeeConfig.defaultStorageDirectory,
                syncIntervalMinutes: decoded.syncIntervalMinutes ?? 5,
                lastSyncedAt: decoded.lastSyncedAt,
                geminiApiKey: decoded.geminiApiKey ?? ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? "",
                geminiModel: decoded.geminiModel ?? BeeConfig.defaultGeminiModel
            )
        } catch {
            return BeeConfig()
        }
    }

    /// Saves `BeeConfig` to `~/.bee-desktop/config.json`, merging into existing JSON so companion tool keys remain intact.
    public func save(_ config: BeeConfig) {
        do {
            var existingDict: [String: Any] = [:]
            if let data = try? Data(contentsOf: configURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                existingDict = json
            }

            existingDict["endpoint"] = config.endpoint
            existingDict["token"] = config.token
            existingDict["storageDir"] = config.storageDir
            existingDict["syncIntervalMinutes"] = config.syncIntervalMinutes
            existingDict["geminiApiKey"] = config.geminiApiKey
            existingDict["geminiModel"] = config.geminiModel
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
