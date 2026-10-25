//
//  GeminiService.swift
//  BeeBar
//
//  Actor interfacing with the Google Generative Language API (v1beta) to dynamically
//  discover available Gemini models for the user's API key and generate structured
//  executive briefs from conversation transcripts.
//

import Foundation

// MARK: - Gemini Model Metadata

/// Metadata describing an available model returned by `GET /v1beta/models`.
public struct GeminiModelInfo: Codable, Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String // e.g. "models/gemini-2.5-flash"
    public let displayName: String?
    public let description: String?
    public let supportedGenerationMethods: [String]?

    /// Model identifier stripped of the `"models/"` prefix.
    public var shortId: String {
        name.replacingOccurrences(of: "models/", with: "")
    }

    /// Human-friendly label combining `displayName` and `shortId` for UI pickers.
    public var readableName: String {
        if let d = displayName, !d.isEmpty { return "\(d) (\(shortId))" }
        return shortId
    }
}

// MARK: - Gemini API Client Actor

/// Thread-safe client for listing Gemini models and summarizing transcripts.
public actor GeminiService {
    public static let shared = GeminiService()

    /// Maximum characters of source transcript sent in a single summarization prompt.
    private let maxTranscriptCharacters = 60_000

    /// Maximum output tokens (set high so thinking/reasoning tokens on Gemini 2.5/3.8/4
    /// models never truncate the visible executive summary output).
    private let maxOutputTokens = 8_192

    private init() {}

    // MARK: - Model Discovery

    /// Fetches all text-generation models available to the provided API key from the Google Generative Language API.
    public func fetchAvailableModels(apiKey: String) async throws -> [GeminiModelInfo] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return [] }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(key)") else {
            throw NSError(domain: "Gemini", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid models endpoint URL."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errString = String(data: data, encoding: .utf8) ?? "HTTP \(status)"
            throw NSError(domain: "Gemini", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to list models (\(status)): \(errString)"])
        }

        struct ListModelsResponse: Codable {
            let models: [GeminiModelInfo]?
        }

        let decoded = try JSONDecoder().decode(ListModelsResponse.self, from: data)
        let allModels = decoded.models ?? []

        // Filter to models supporting content generation
        let contentModels = allModels.filter { model in
            if let methods = model.supportedGenerationMethods {
                return methods.contains("generateContent")
            }
            return model.shortId.contains("gemini")
        }

        // Sort newer model families first
        return contentModels.sorted { a, b in
            a.shortId.lowercased() > b.shortId.lowercased()
        }
    }

    // MARK: - Transcript Summarization

    /// Generates a structured executive brief from a conversation transcript using the specified Gemini model.
    public func summarize(
        text: String,
        apiKey: String,
        model: String = BeeConfig.defaultGeminiModel
    ) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw NSError(domain: "Gemini", code: 3, userInfo: [NSLocalizedDescriptionKey: "Gemini API key is required."])
        }

        var cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanModel.hasPrefix("models/") {
            cleanModel = String(cleanModel.dropFirst(7))
        }
        if cleanModel.isEmpty {
            cleanModel = BeeConfig.defaultGeminiModel
        }

        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/\(cleanModel):generateContent?key=\(key)"
        guard let url = URL(string: urlStr) else {
            throw NSError(domain: "Gemini", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini endpoint URL for model \(cleanModel)."])
        }

        let prompt = """
        You are an elite executive intelligence assistant. Summarize the following audio transcript / conversation into a crisp, high-impact executive brief:

        ### 📋 Executive Takeaway
        (2 sentences maximum)

        ### 💡 Strategic Highlights & Key Decisions
        - (3-4 bullet points)

        ### ✅ Action Items & Follow-ups
        - [ ] (Clear actionable tasks with owners if identified)

        CONVERSATION / TRANSCRIPT:
        \(text.prefix(maxTranscriptCharacters))
        """

        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "maxOutputTokens": maxOutputTokens
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 45

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Gemini", code: 5, userInfo: [NSLocalizedDescriptionKey: "No HTTP response from Gemini."])
        }

        guard httpResponse.statusCode == 200 else {
            let errString = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "Gemini", code: 6, userInfo: [NSLocalizedDescriptionKey: "Gemini API error (\(httpResponse.statusCode)): \(errString)"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw NSError(domain: "Gemini", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Gemini response payload."])
        }

        // Concatenate all non-thought text parts in the candidate response
        let combinedText = parts.compactMap { part -> String? in
            if let isThought = part["thought"] as? Bool, isThought {
                return nil
            }
            return part["text"] as? String
        }.joined(separator: "\n")

        guard !combinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "Gemini", code: 8, userInfo: [NSLocalizedDescriptionKey: "Gemini returned an empty summary."])
        }

        return combinedText
    }
}
