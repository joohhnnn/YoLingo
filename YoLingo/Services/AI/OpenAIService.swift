import Foundation

// MARK: - OpenAIService

/// 通过 OpenAI API 实现 AI 功能
/// 以后可以写 GeminiService: AIServiceProtocol 替换
final class OpenAIService: AIServiceProtocol {

    private let settingsService: SettingsServiceProtocol
    private let model: String
    private let session: URLSession

    /// API Key — 每次调用时从 SettingsService 动态读取，确保配置变更立即生效
    private var apiKey: String {
        settingsService.getAPIKey(for: settingsService.aiProvider) ?? ""
    }

    init(
        settingsService: SettingsServiceProtocol,
        model: String = "gpt-4o-mini",  // 便宜够用
        session: URLSession = .shared
    ) {
        self.settingsService = settingsService
        self.model = model
        self.session = session
    }

    func generateExampleSentences(for word: String, count: Int) async throws -> [String] {
        guard !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }

        let prompt = """
        Generate \(count) natural English example sentences using the word "\(word)".
        Each sentence should demonstrate a different usage or context.
        Return only the sentences, one per line, without numbering or bullet points.
        """

        let response = try await callChatCompletion(prompt: prompt)

        // 按行分割，过滤空行
        let sentences = response
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Array(sentences.prefix(count))
    }

    // MARK: - Private

    private func callChatCompletion(prompt: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 200
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIServiceError.apiError
        }

        // 解析 OpenAI 响应
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String

        guard let result = content else {
            throw AIServiceError.invalidResponse
        }

        return result
    }
}

// MARK: - AIServiceError

enum AIServiceError: Error, LocalizedError {
    case missingAPIKey
    case apiError
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:   return "未配置 AI API Key"
        case .apiError:        return "AI API 请求失败"
        case .invalidResponse: return "AI 返回了无效的响应"
        }
    }
}
