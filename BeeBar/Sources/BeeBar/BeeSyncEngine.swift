//
//  BeeSyncEngine.swift
//  BeeBar
//
//  Background actor responsible for communicating with the Bee API (local proxy or cloud),
//  downloading conversation records and utterances, formatting Markdown and plain-text
//  exports, aligning file creation/modification timestamps with conversation times,
//  and rebuilding the local `metadata.json` index.
//

import Foundation

// MARK: - Connection Test Result

/// Result of verifying connectivity against the Bee API `/v1/me` endpoint.
public struct TestConnectionResult: Sendable {
    public let success: Bool
    public let message: String

    public init(success: Bool, message: String) {
        self.success = success
        self.message = message
    }
}

// MARK: - Synchronization Actor

/// Actor that performs network requests and file export generation off the main thread.
public actor BeeSyncEngine {
    private var config: BeeConfig

    public init(config: BeeConfig) {
        self.config = config
    }

    /// Updates the engine's active configuration.
    public func updateConfig(_ newConfig: BeeConfig) {
        self.config = newConfig
    }

    // MARK: - Connection Verification

    /// Verifies API reachability and authentication via `GET /v1/me`.
    public func testConnection() async -> TestConnectionResult {
        guard let url = URL(string: "\(cleanEndpoint())/v1/me") else {
            return TestConnectionResult(success: false, message: "Invalid endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        if !config.token.isEmpty {
            request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return TestConnectionResult(success: false, message: "No HTTP response")
            }

            if httpResponse.statusCode == 200 {
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let user = json?["user"] as? [String: Any] ?? json
                let name = (user?["name"] as? String)
                    ?? (user?["first_name"] as? String)
                    ?? (user?["email"] as? String)
                    ?? "Bee User"
                return TestConnectionResult(success: true, message: "Connected: \(name)")
            } else {
                let errStr = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                return TestConnectionResult(success: false, message: "Status \(httpResponse.statusCode): \(errStr)")
            }
        } catch {
            return TestConnectionResult(success: false, message: error.localizedDescription)
        }
    }

    // MARK: - Synchronization Pipeline

    /// Fetches conversations from the Bee API, caches new or incomplete records locally,
    /// writes `.json`, `.md`, and `.txt` exports with conversation-matched file dates,
    /// and updates `metadata.json`.
    ///
    /// - Parameter onProgress: Callback reporting human-readable status and progress (`0.0...1.0`).
    /// - Returns: Count of newly downloaded or updated conversations.
    public func sync(onProgress: @Sendable (String, Double) -> Void) async throws -> Int {
        ensureDirectories()
        onProgress("Checking Bee API connection...", 0.05)

        guard let url = URL(string: "\(cleanEndpoint())/v1/conversations") else {
            throw NSError(domain: "BeeBar", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid API endpoint"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        if !config.token.isEmpty {
            request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NSError(domain: "BeeBar", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch conversations (HTTP \(status))"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "BeeBar", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
        }

        let convList = (json["conversations"] as? [[String: Any]]) ?? []
        let total = convList.count
        onProgress("Found \(total) recent conversations. Updating local cache...", 0.15)

        var newOrUpdatedCount = 0
        let fm = FileManager.default

        for (idx, item) in convList.enumerated() {
            guard let id = item["id"] as? String ?? (item["id"] as? Int).map(String.init) else { continue }
            let safeId = id.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
            let jsonPath = (config.storageDir as NSString).appendingPathComponent("conversations/\(safeId).json")
            let mdPath = (config.storageDir as NSString).appendingPathComponent("conversations/\(safeId).md")
            let txtPath = (config.storageDir as NSString).appendingPathComponent("transcripts/\(safeId)_transcript.txt")
            let mdTranscriptPath = (config.storageDir as NSString).appendingPathComponent("transcripts/\(safeId)_transcript.md")

            var fullConv: [String: Any] = item

            let jsonSize = (try? fm.attributesOfItem(atPath: jsonPath)[.size] as? Int) ?? 0
            let fileExists = fm.fileExists(atPath: jsonPath) && jsonSize > 10

            if fileExists {
                // Regenerate derived Markdown/Transcript files if missing
                if !fm.fileExists(atPath: txtPath) || !fm.fileExists(atPath: mdPath) {
                    if let cachedData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
                       let cachedJson = try? JSONSerialization.jsonObject(with: cachedData) as? [String: Any] {
                        fullConv = (cachedJson["conversation"] as? [String: Any]) ?? cachedJson
                    }
                } else {
                    continue
                }
            } else {
                let progress = 0.15 + (Double(idx) / Double(max(1, total))) * 0.75
                onProgress("Downloading transcript (\(idx + 1)/\(total))...", progress)
                if let detail = try? await fetchConversationDetail(id: id), !detail.isEmpty {
                    fullConv = detail
                    newOrUpdatedCount += 1
                }
            }

            // 1. Save Raw JSON
            if let serialized = try? JSONSerialization.data(withJSONObject: fullConv, options: [.prettyPrinted]) {
                try? serialized.write(to: URL(fileURLWithPath: jsonPath), options: [.atomic])
            }

            // 2. Save Markdown Summary
            let mdContent = formatConversationMarkdown(conv: fullConv, id: safeId)
            try? mdContent.write(to: URL(fileURLWithPath: mdPath), atomically: true, encoding: .utf8)

            // 3. Save Verbatim Transcripts (.txt and .md)
            let txtContent = formatPureTranscriptText(conv: fullConv, id: safeId)
            try? txtContent.write(to: URL(fileURLWithPath: txtPath), atomically: true, encoding: .utf8)

            let mdTrContent = formatPureTranscriptMarkdown(conv: fullConv, id: safeId)
            try? mdTrContent.write(to: URL(fileURLWithPath: mdTranscriptPath), atomically: true, encoding: .utf8)

            // 4. Stamp file creation & modification dates to match the actual conversation timestamp
            let convDate = parseTimestamp(fullConv["start_time"])
                ?? parseTimestamp(fullConv["created_at"])
                ?? parseTimestamp(fullConv["timestamp"])
                ?? Date()
            setFileDate(path: jsonPath, date: convDate)
            setFileDate(path: mdPath, date: convDate)
            setFileDate(path: txtPath, date: convDate)
            setFileDate(path: mdTranscriptPath, date: convDate)
        }

        onProgress("Saving metadata index...", 0.95)
        updateLocalMetadata()

        onProgress("Sync complete!", 1.0)
        return newOrUpdatedCount
    }

    // MARK: - API Networking Helpers

    /// Fetches the full conversation record (including transcriptions/utterances) for a given conversation ID.
    private func fetchConversationDetail(id: String) async throws -> [String: Any] {
        guard let url = URL(string: "\(cleanEndpoint())/v1/conversations/\(id)") else {
            throw NSError(domain: "BeeBar", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid detail URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        if !config.token.isEmpty {
            request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return (json["conversation"] as? [String: Any]) ?? json
        }
        return [:]
    }

    /// Normalizes the configured endpoint URL by removing any trailing slash.
    private func cleanEndpoint() -> String {
        var ep = config.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if ep.hasSuffix("/") { ep = String(ep.dropLast()) }
        return ep
    }

    // MARK: - Local Metadata Index Builder

    /// Scans `<storageDir>/conversations/*.json`, enforces file timestamps, classifies topics,
    /// and writes the sorted conversation index to `<storageDir>/metadata.json`.
    private func updateLocalMetadata() {
        let convDir = (config.storageDir as NSString).appendingPathComponent("conversations")
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: convDir) else { return }

        var items: [[String: Any]] = []

        for f in files where f.hasSuffix(".json") {
            let fullPath = (convDir as NSString).appendingPathComponent(f)
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: fullPath)),
                  let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            let c = (raw["conversation"] as? [String: Any]) ?? raw
            let safeId = f.replacingOccurrences(of: ".json", with: "")

            let title = (c["short_summary"] as? String) ?? (c["title"] as? String) ?? "Conversation \(safeId)"
            let createdAt = c["start_time"] ?? c["created_at"] ?? c["timestamp"]
            let summary = (c["summary"] as? String) ?? (c["short_summary"] as? String) ?? ""
            let snippet = String(summary.replacingOccurrences(of: "\n", with: " ").prefix(200))

            if let date = parseTimestamp(createdAt) {
                let mdPath = (convDir as NSString).appendingPathComponent("\(safeId).md")
                let transcriptsDir = (config.storageDir as NSString).appendingPathComponent("transcripts")
                let txtPath = (transcriptsDir as NSString).appendingPathComponent("\(safeId)_transcript.txt")
                let mdTrPath = (transcriptsDir as NSString).appendingPathComponent("\(safeId)_transcript.md")
                setFileDate(path: fullPath, date: date)
                setFileDate(path: mdPath, date: date)
                setFileDate(path: txtPath, date: date)
                setFileDate(path: mdTrPath, date: date)
            }

            let utterances = extractUtterances(c)
            let (tags, keywords) = classify(title: title, summary: summary)

            var dict: [String: Any] = [
                "id": safeId,
                "title": title,
                "summarySnippet": snippet,
                "utteranceCount": utterances.count,
                "tags": tags,
                "keywords": keywords
            ]
            if let ca = createdAt { dict["created_at"] = ca }
            if let dur = c["duration_ms"] as? Double { dict["duration_ms"] = dur }
            if let loc = (c["primary_location"] as? [String: Any])?["address"] as? String {
                dict["location"] = loc
            }

            items.append(dict)
        }

        // Sort newest conversations first
        items.sort { a, b in
            let aTime = parseTimestamp(a["created_at"])?.timeIntervalSince1970 ?? 0
            let bTime = parseTimestamp(b["created_at"])?.timeIntervalSince1970 ?? 0
            return aTime > bTime
        }

        let metaURL = URL(fileURLWithPath: (config.storageDir as NSString).appendingPathComponent("metadata.json"))
        var metaDict: [String: Any] = [:]
        if let existingData = try? Data(contentsOf: metaURL),
           let existing = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
            metaDict = existing
        }

        metaDict["lastSyncedAt"] = Date().timeIntervalSince1970 * 1000
        metaDict["conversations"] = items

        if let outData = try? JSONSerialization.data(withJSONObject: metaDict, options: [.prettyPrinted]) {
            try? outData.write(to: metaURL, options: [.atomic])
        }
    }

    // MARK: - Markdown & Transcript Formatting

    /// Extracts utterance dictionaries from either top-level `utterances` or nested `transcriptions`.
    private func extractUtterances(_ conv: [String: Any]) -> [[String: Any]] {
        if let direct = conv["utterances"] as? [[String: Any]], !direct.isEmpty {
            return direct
        }
        if let transcriptions = conv["transcriptions"] as? [[String: Any]] {
            var all: [[String: Any]] = []
            for t in transcriptions {
                if let u = t["utterances"] as? [[String: Any]] {
                    all.append(contentsOf: u)
                }
            }
            return all
        }
        return []
    }

    /// Formats a complete Markdown document containing frontmatter, executive summary, and audio transcript.
    private func formatConversationMarkdown(conv: [String: Any], id: String) -> String {
        let title = (conv["short_summary"] as? String) ?? (conv["title"] as? String) ?? "Conversation \(id)"
        let summary = (conv["summary"] as? String) ?? (conv["short_summary"] as? String) ?? "No summary available."
        let utterances = extractUtterances(conv)

        var md = """
        ---
        id: "\(id)"
        title: "\(title.replacingOccurrences(of: "\"", with: "\\\""))"
        type: conversation
        source: bee.computer
        ---

        # 💬 \(title)

        - **ID:** `\(id)`
        - **Utterances:** \(utterances.count)

        ## 📋 Executive Summary
        \(summary)

        """

        if !utterances.isEmpty {
            md += "\n## 🎙️ Audio Transcript\n\n"
            for u in utterances {
                let speaker = (u["speaker"] as? String) ?? "Speaker"
                let text = (u["text"] as? String) ?? ""
                md += "**\(speaker)**: \(text)\n\n"
            }
        }
        return md
    }

    /// Formats a clean plain-text verbatim transcript (`transcripts/<id>_transcript.txt`).
    private func formatPureTranscriptText(conv: [String: Any], id: String) -> String {
        let title = (conv["short_summary"] as? String) ?? (conv["title"] as? String) ?? "Conversation \(id)"
        let utterances = extractUtterances(conv)

        var out = "================================================================================\n"
        out += "TRANSCRIPT: \(title)\n"
        out += "ID: \(id)\n"
        out += "Total Utterances: \(utterances.count)\n"
        out += "================================================================================\n\n"

        if utterances.isEmpty {
            out += "[No verbatim utterances captured for this session]\n"
            return out
        }

        for u in utterances {
            let speaker = (u["speaker"] as? String) ?? "Unknown"
            let text = (u["text"] as? String) ?? ""
            out += "\(speaker): \(text)\n\n"
        }
        return out
    }

    /// Formats a Markdown verbatim transcript (`transcripts/<id>_transcript.md`).
    private func formatPureTranscriptMarkdown(conv: [String: Any], id: String) -> String {
        let title = (conv["short_summary"] as? String) ?? (conv["title"] as? String) ?? "Conversation \(id)"
        let utterances = extractUtterances(conv)

        var md = """
        ---
        id: "\(id)"
        title: "Transcript: \(title.replacingOccurrences(of: "\"", with: "\\\""))"
        type: transcript
        ---

        # 🎙️ Transcript: \(title)

        """

        for u in utterances {
            let speaker = (u["speaker"] as? String) ?? "Unknown"
            let text = (u["text"] as? String) ?? ""
            md += "> **\(speaker)**: \(text)\n\n"
        }
        return md
    }

    // MARK: - Automatic Topic Classification

    /// Assigns topical category tags and keywords based on conversation title and summary content.
    private func classify(title: String, summary: String) -> ([String], [String]) {
        let text = (title + " " + summary).lowercased()
        var tags: [String] = []
        var keywords: [String] = []

        if text.contains("data center") || text.contains("datacenter") || text.contains("hyperscaler") {
            tags.append("Data Centers"); keywords.append("Data Centers")
        }
        if text.contains("critical mineral") || text.contains("lithium") || text.contains("brine") {
            tags.append("Critical Minerals"); keywords.append("Critical Minerals")
        }
        if text.contains("nuclear") || text.contains("curio") || text.contains("reactor") {
            tags.append("Nuclear Energy"); keywords.append("Nuclear")
        }
        if text.contains("resilien") || text.contains("storm") || text.contains("outage") {
            tags.append("Grid Resilience"); keywords.append("Resilience")
        }
        if text.contains("grant") || text.contains("eecbg") || text.contains("contract") || text.contains("sow") {
            tags.append("Grants & Contracts"); keywords.append("Grants")
        }
        if text.contains("conference") || text.contains("panel") || text.contains("nasio") || text.contains("sseb") {
            tags.append("Conferences & Panels"); keywords.append("Conferences")
        }
        if text.contains("family") || text.contains("personal") || text.contains("son") || text.contains("school") {
            tags.append("Family & Personal"); keywords.append("Personal")
        }
        if text.contains("energy") || text.contains("utility") || text.contains("power") {
            if !tags.contains("Grid Resilience") && !tags.contains("Nuclear Energy") {
                tags.append("Energy & Infrastructure"); keywords.append("Energy")
            }
        }
        if tags.isEmpty { tags.append("General Work") }
        return (tags, keywords)
    }

    // MARK: - File System & Timestamp Utilities

    /// Ensures all required export subdirectories exist inside `config.storageDir`.
    private func ensureDirectories() {
        let fm = FileManager.default
        let dirs = ["conversations", "transcripts", "daily", "todos", "facts", "insights", "journals"]
        for d in dirs {
            let p = (config.storageDir as NSString).appendingPathComponent(d)
            if !fm.fileExists(atPath: p) {
                try? fm.createDirectory(atPath: p, withIntermediateDirectories: true)
            }
        }
    }

    /// Parses numeric epoch timestamps (seconds or milliseconds) or ISO-8601 date strings.
    private func parseTimestamp(_ raw: Any?) -> Date? {
        guard let raw = raw else { return nil }
        if let d = raw as? Double {
            return Date(timeIntervalSince1970: d > 1e11 ? d / 1000.0 : d)
        }
        if let i = raw as? Int {
            let d = Double(i)
            return Date(timeIntervalSince1970: d > 1e11 ? d / 1000.0 : d)
        }
        if let s = raw as? String {
            if let d = Double(s) {
                return Date(timeIntervalSince1970: d > 1e11 ? d / 1000.0 : d)
            }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: s) { return date }
            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: s)
        }
        return nil
    }

    /// Sets both the creation date and modification date of a file on disk to match the conversation time.
    private func setFileDate(path: String, date: Date) {
        try? FileManager.default.setAttributes([
            .creationDate: date,
            .modificationDate: date
        ], ofItemAtPath: path)
    }
}
