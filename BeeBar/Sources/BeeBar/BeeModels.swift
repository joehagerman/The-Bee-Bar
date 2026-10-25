//
//  BeeModels.swift
//  BeeBar
//
//  Core data models representing Bee conversations, flexible timestamp decoding,
//  and the local metadata index (`metadata.json`).
//

import Foundation

// MARK: - Conversation Item Model

/// Represents a single synced Bee conversation record and provides computed
/// formatting and file path helpers.
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

    // MARK: - Formatted Display Properties

    /// Human-readable duration string (e.g. `"12m 34s"` or `"45s"`).
    public var formattedDuration: String? {
        guard let ms = duration_ms, ms > 0 else { return nil }
        let totalSeconds = Int(ms / 1000)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        if mins == 0 { return "\(secs)s" }
        return "\(mins)m \(secs)s"
    }

    /// Conversation start/creation date parsed from `created_at`.
    public var createdDate: Date? {
        created_at?.toDate()
    }

    /// Relative date string for recent conversations (within 3 days) or medium date/time string for older records.
    public var relativeDateString: String {
        guard let date = createdDate else { return "Unknown date" }
        let now = Date()
        let diff = now.timeIntervalSince(date)
        if diff < 60 {
            return "Just now"
        } else if diff < 86400 * 3 {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: now)
        } else {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            return df.string(from: date)
        }
    }

    // MARK: - Local Export File Paths

    /// Path to the exported Markdown summary file (`conversations/<id>.md`).
    public func markdownPath(storageDir: String) -> String {
        (storageDir as NSString).appendingPathComponent("conversations/\(id).md")
    }

    /// Path to the raw Bee API JSON record (`conversations/<id>.json`).
    public func jsonPath(storageDir: String) -> String {
        (storageDir as NSString).appendingPathComponent("conversations/\(id).json")
    }

    /// Path to the saved Gemini executive brief (`conversations/<id>_gemini_brief.md`).
    public func geminiBriefPath(storageDir: String) -> String {
        (storageDir as NSString).appendingPathComponent("conversations/\(id)_gemini_brief.md")
    }

    /// Path to the plain-text verbatim transcript (`transcripts/<id>_transcript.txt`).
    public func transcriptTextPath(storageDir: String) -> String {
        (storageDir as NSString).appendingPathComponent("transcripts/\(id)_transcript.txt")
    }

    /// Path to the Markdown verbatim transcript (`transcripts/<id>_transcript.md`).
    public func transcriptMarkdownPath(storageDir: String) -> String {
        (storageDir as NSString).appendingPathComponent("transcripts/\(id)_transcript.md")
    }
}

// MARK: - Polymorphic Timestamp Codable

/// Decodes timestamps that may arrive as epoch milliseconds/seconds (`Double` or `Int`)
/// or ISO-8601 strings (`String`).
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

    /// Converts the underlying timestamp representation into a Foundation `Date`.
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

// MARK: - Local Metadata Index

/// Represents the root structure of `<storageDir>/metadata.json`.
public struct BeeMetadata: Codable, Sendable {
    public var lastSyncedAt: Double?
    public var conversations: [BeeConversationItem]?
}
