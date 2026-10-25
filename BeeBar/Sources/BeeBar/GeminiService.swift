import Foundation

public actor GeminiService {
    public static let shared = GeminiService()

    private init() {}

    public func summarize(text: String, apiKey: String) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw NSError(domain: "Gemini", code: 1, userInfo: [NSLocalizedDescriptionKey: "Gemini API key is required."])
        }

        // Use gemini-2.5-flash or gemini-1.5-flash
        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(key)"
        guard let url = URL(string: urlStr) else {
            throw NSError(domain: "Gemini", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini endpoint URL."])
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
                "maxOutputTokens": 1024
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Gemini", code: 3, userInfo: [NSLocalizedDescriptionKey: "No HTTP response from Gemini."])
        }

        guard httpResponse.statusCode == 200 else {
            let errString = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "Gemini", code: 4, userInfo: [NSLocalizedDescriptionKey: "Gemini API error (\(httpResponse.statusCode)): \(errString)"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let generatedText = firstPart["text"] as? String else {
            throw NSError(domain: "Gemini", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Gemini response payload."])
        }

        return generatedText
    }
}
