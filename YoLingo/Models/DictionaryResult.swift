import Foundation

// MARK: - DictionaryResult

/// 词典查询结果
struct DictionaryResult {
    let word: String
    let phonetic: String?
    let definitions: [DefinitionEntry]
}

// MARK: - DefinitionEntry

struct DefinitionEntry {
    let partOfSpeech: String    // 词性: noun, verb, adjective...
    let meaning: String
}
