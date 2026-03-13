import Foundation
import GRDB

// MARK: - WordEntryRecord

/// GRDB record type that bridges WordEntry (Models, zero dependencies) and the database.
/// Handles all type conversions: UUID ↔ String, Date ↔ Double, [String] ↔ JSON, enums ↔ String.
struct WordEntryRecord: Codable, FetchableRecord, PersistableRecord {

    static let databaseTableName = "word_entries"

    var id: String
    var word: String
    var definition: String
    var phonetic: String?
    var exampleSentences: String
    var sourceApp: String
    var capturedAt: Double
    var learningState: String
    var srsNextReviewDate: Double
    var srsInterval: Double
    var srsEaseFactor: Double
    var srsRepetitions: Int

    // MARK: - CodingKeys (camelCase → snake_case column mapping)

    enum CodingKeys: String, CodingKey {
        case id, word, definition, phonetic
        case exampleSentences = "example_sentences"
        case sourceApp = "source_app"
        case capturedAt = "captured_at"
        case learningState = "learning_state"
        case srsNextReviewDate = "srs_next_review_date"
        case srsInterval = "srs_interval"
        case srsEaseFactor = "srs_ease_factor"
        case srsRepetitions = "srs_repetitions"
    }

    // MARK: - Column References (for type-safe queries)

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let word = Column(CodingKeys.word)
        static let capturedAt = Column(CodingKeys.capturedAt)
        static let srsNextReviewDate = Column(CodingKeys.srsNextReviewDate)
    }

    // MARK: - WordEntry → Record

    init(from entry: WordEntry) {
        self.id = entry.id.uuidString
        self.word = entry.word
        self.definition = entry.definition
        self.phonetic = entry.phonetic

        // Encode [String] as JSON
        let jsonData = (try? JSONEncoder().encode(entry.exampleSentences)) ?? Data()
        self.exampleSentences = String(data: jsonData, encoding: .utf8) ?? "[]"

        self.sourceApp = entry.sourceApp
        self.capturedAt = entry.capturedAt.timeIntervalSinceReferenceDate
        self.learningState = entry.learningState.rawValue
        self.srsNextReviewDate = entry.srsData.nextReviewDate.timeIntervalSinceReferenceDate
        self.srsInterval = entry.srsData.interval
        self.srsEaseFactor = entry.srsData.easeFactor
        self.srsRepetitions = entry.srsData.repetitions
    }

    // MARK: - Record → WordEntry

    func toWordEntry() -> WordEntry {
        let sentences: [String]
        if let data = exampleSentences.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            sentences = decoded
        } else {
            sentences = []
        }

        return WordEntry(
            id: UUID(uuidString: id) ?? {
                NSLog("[WordEntryRecord] ⚠️ Corrupt UUID string '%@', generating new UUID", id)
                return UUID()
            }(),
            word: word,
            definition: definition,
            phonetic: phonetic,
            exampleSentences: sentences,
            sourceApp: sourceApp,
            capturedAt: Date(timeIntervalSinceReferenceDate: capturedAt),
            learningState: LearningState(rawValue: learningState) ?? .new,
            srsData: SRSData(
                nextReviewDate: Date(timeIntervalSinceReferenceDate: srsNextReviewDate),
                interval: srsInterval,
                easeFactor: srsEaseFactor,
                repetitions: srsRepetitions
            )
        )
    }
}
