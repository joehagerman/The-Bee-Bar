import Foundation

public struct BeeConversationItem: Identifiable, Codable, Sendable {
    public let id: String
    public let title: String
    public let created_at: AnyTimestamp?
    public let duration_ms: Double?
    public let summarySnippet: String?
    public let utteranceCount: Int?
    public let tags: [String]?
    public let keywords: [String]?
    public let location: String?

    public var formattedDuration: String? {
        guard let ms = duration_ms, ms > 0 else { return nil }
        let totalSeconds = Int(ms / 1000)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        if mins == 0 { return "\(secs)s" }
        return "\(mins)m \(secs)s"
    }

    public var createdDate: Date? {
        guard let ts = created_at else { return nil }
        return ts.toDate()
    }

    public var relativeDateString: String {
        guard let date = createdDate else { return "Unknown date" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let now = Date()
        let diff = now.timeIntervalSince(date)
        if diff < 60 {
            return "Just now"
        } else if diff < 86400 * 3 {
            return formatter.localizedString(for: date, relativeTo: now)
        } else {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            return df.string(from: date)
        }
    }

    public func markdownPath(storageDir: String) -> String {
        return (storageDir as NSString).appendingPathComponent("conversations/\(id).md")
    }

    public func jsonPath(storageDir: String) -> String {
        return (storageDir as NSString).appendingPathComponent("conversations/\(id).json")
    }

    public func transcriptTextPath(storageDir: String) -> String {
        return (storageDir as NSString).appendingPathComponent("transcripts/\(id)_transcript.txt")
    }

    public func transcriptMarkdownPath(storageDir: String) -> String {
        return (storageDir as NSString).appendingPathComponent("transcripts/\(id)_transcript.md")
    }
}

public enum AnyTimestamp: Codable, Sendable {
    case double(Double)
    case int(Int)
    case string(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else {
            self = .double(0)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .double(let d): try container.encode(d)
        case .int(let i): try container.encode(i)
        case .string(let s): try container.encode(s)
        }
    }

    public func toDate() -> Date? {
        switch self {
        case .double(let d):
            return Date(timeIntervalSince1970: d > 1_000_000_000_000 ? d / 1000 : d)
        case .int(let i):
            let d = Double(i)
            return Date(timeIntervalSince1970: d > 1_000_000_000_000 ? d / 1000 : d)
        case .string(let s):
            if let num = Double(s) {
                return Date(timeIntervalSince1970: num > 1_000_000_000_000 ? num / 1000 : num)
            }
            let isoFormatter = ISO8601DateFormatter()
            return isoFormatter.date(from: s)
        }
    }
}

public struct BeeMetadata: Codable, Sendable {
    public var lastSyncedAt: Double?
    public var conversations: [BeeConversationItem]?
}
