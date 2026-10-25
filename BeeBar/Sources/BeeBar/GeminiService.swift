import Foundation

public struct GeminiModelInfo: Codable, Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String // e.g. "models/gemini-2.5-flash"
    public let displayName: String?
    public let description: String?
    public let supportedGenerationMethods: [String]?

    public var shortId: String {
        name.replacingOccurrences(of: "models/", with: "")
    }

    public var readableName: String {
        if let d = displayName, !d.isEmpty { return "\(d) (\(shortId))" }
        return shortId
    }
}

public actor GeminiService {
    public static let shared = GeminiService()

    private init() {}

    /// Fetches all models available to the provided API key from Google Generative Language API
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

        // Filter to models that support text generation (generateContent)
        let contentModels = allModels.filter { model in
            if let methods = model.supportedGenerationMethods {
                return methods.contains("generateContent")
            }
            return model.shortId.contains("gemini")
        }

        // Sort intelligently: prefer gemini-2.5, gemini-2.0, gemini-1.5, flash, pro
        return contentModels.sorted { a, b in
            let aName = a.shortId.lowercased()
            let bName = b.shortId.lowercased()
            return aName > bName
        }
    }

    /// Generates an executive brief using the specified model
    public func summarize(text: String, apiKey: String, model: String = "gemini-2.5-flash") async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw NSError(domain: "Gemini", code: 3, userInfo: [NSLocalizedDescriptionKey: "Gemini API key is required."])
        }

        var cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanModel.hasPrefix("models/") {
            cleanModel = String(cleanModel.dropFirst(7))
        }
        if cleanModel.isEmpty {
            cleanModel = "gemini-2.5-flash"
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
        \(text.prefix(60000))
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
                "maxOutputTokens": 8192
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 35

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
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let generatedText = firstPart["text"] as? String else {
            throw NSError(domain: "Gemini", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Gemini response payload."])
        }

        return generatedText
    }
}
