import Foundation

public struct TestConnectionResult: Sendable {
    public let success: Bool
    public let message: String

    public init(success: Bool, message: String) {
        self.success = success
        self.message = message
    }
}

public actor BeeSyncEngine {
    private var config: BeeConfig

    public init(config: BeeConfig) {
        self.config = config
    }

    public func updateConfig(_ newConfig: BeeConfig) {
        self.config = newConfig
    }

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
                let name = (user?["name"] as? String) ?? (user?["email"] as? String) ?? "Bee User"
                return TestConnectionResult(success: true, message: "Connected: \(name)")
            } else {
                let errStr = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                return TestConnectionResult(success: false, message: "Status \(httpResponse.statusCode): \(errStr)")
            }
        } catch {
            return TestConnectionResult(success: false, message: error.localizedDescription)
        }
    }

    public func sync(onProgress: @Sendable (String, Double) -> Void) async throws -> Int {
        ensureDirectories()
        onProgress("Checking Bee API connection...", 0.05)

        // 1. Fetch conversations list
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

            let fileExists = fm.fileExists(atPath: jsonPath) && (try? fm.attributesOfItem(atPath: jsonPath)[.size] as? Int ?? 0) ?? 0 > 10

            if fileExists {
                // Check if transcripts are missing
                if !fm.fileExists(atPath: txtPath) || !fm.fileExists(atPath: mdPath) {
                    if let cachedData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
                       let cachedJson = try? JSONSerialization.jsonObject(with: cachedData) as? [String: Any] {
                        fullConv = (cachedJson["conversation"] as? [String: Any]) ?? cachedJson
                    }
                } else {
                    continue // Already fully synced locally!
                }
            } else {
                // Fetch detail
                onProgress("Downloading transcript (\(idx + 1)/\(total))...", 0.15 + (Double(idx) / Double(max(1, total))) * 0.75)
                if let detail = try? await fetchConversationDetail(id: id) {
                    fullConv = detail
                    newOrUpdatedCount += 1
                }
            }

            // Save JSON
            if let serialized = try? JSONSerialization.data(withJSONObject: fullConv, options: [.prettyPrinted]) {
                try? serialized.write(to: URL(fileURLWithPath: jsonPath), options: [.atomic])
            }

            // Save Markdown Summary
            let mdContent = formatConversationMarkdown(conv: fullConv, id: safeId)
            try? mdContent.write(to: URL(fileURLWithPath: mdPath), atomically: true, encoding: .utf8)

            // Save Verbatim Transcript .txt and .md
            let txtContent = formatPureTranscriptText(conv: fullConv, id: safeId)
            try? txtContent.write(to: URL(fileURLWithPath: txtPath), atomically: true, encoding: .utf8)

            let mdTrContent = formatPureTranscriptMarkdown(conv: fullConv, id: safeId)
            try? mdTrContent.write(to: URL(fileURLWithPath: mdTranscriptPath), atomically: true, encoding: .utf8)
        }

        // Rebuild or update metadata.json
        onProgress("Saving metadata index...", 0.95)
        updateLocalMetadata()

        onProgress("Sync complete!", 1.0)
        return newOrUpdatedCount
    }

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

    private func cleanEndpoint() -> String {
        var ep = config.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if ep.hasSuffix("/") { ep = String(ep.dropLast()) }
        return ep
    }

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

        // Sort items by created_at descending
        items.sort { a, b in
            let aTime = (a["created_at"] as? Double) ?? Double((a["created_at"] as? Int) ?? 0)
            let bTime = (b["created_at"] as? Double) ?? Double((b["created_at"] as? Int) ?? 0)
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
}
