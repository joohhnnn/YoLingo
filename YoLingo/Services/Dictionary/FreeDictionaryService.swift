import Foundation

// MARK: - FreeDictionaryService

/// 使用 Free Dictionary API 实现词典查询
/// API: https://dictionaryapi.dev/
final class FreeDictionaryService: DictionaryServiceProtocol {

    private let baseURL = "https://api.dictionaryapi.dev/api/v2/entries/en"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func lookup(_ word: String) async throws -> DictionaryResult {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty,
              let url = URL(string: "\(baseURL)/\(trimmed)") else {
            throw DictionaryError.invalidWord
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DictionaryError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            throw DictionaryError.wordNotFound
        }

        return try parseResponse(data, word: trimmed)
    }

    // MARK: - Private

    private func parseResponse(_ data: Data, word: String) throws -> DictionaryResult {
        let entries = try JSONDecoder().decode([APIEntry].self, from: data)

        guard let first = entries.first else {
            throw DictionaryError.wordNotFound
        }

        let definitions = first.meanings.flatMap { meaning in
            meaning.definitions.prefix(2).map { def in
                DefinitionEntry(
                    partOfSpeech: meaning.partOfSpeech,
                    meaning: def.definition
                )
            }
        }

        return DictionaryResult(
            word: first.word,
            phonetic: first.phonetic ?? first.phonetics.first(where: { $0.text != nil })?.text,
            definitions: definitions
        )
    }
}

// MARK: - API Response Models (private)

private struct APIEntry: Decodable {
    let word: String
    let phonetic: String?
    let phonetics: [APIPhonetic]
    let meanings: [APIMeaning]
}

private struct APIPhonetic: Decodable {
    let text: String?
    let audio: String?
}

private struct APIMeaning: Decodable {
    let partOfSpeech: String
    let definitions: [APIDefinition]
}

private struct APIDefinition: Decodable {
    let definition: String
}

// MARK: - DictionaryError

enum DictionaryError: Error, LocalizedError {
    case invalidWord
    case wordNotFound
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidWord:   return "无效的单词"
        case .wordNotFound:  return "未找到该单词"
        case .networkError:  return "网络请求失败"
        }
    }
}
