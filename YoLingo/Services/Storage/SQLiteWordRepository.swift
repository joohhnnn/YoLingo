import Foundation
import GRDB

// MARK: - SQLiteWordRepository

/// GRDB-backed word repository
/// Uses DatabaseQueue for serialized read/write access to SQLite
final class SQLiteWordRepository: WordRepositoryProtocol {

    private let dbQueue: DatabaseQueue

    /// File-backed database for production use
    init(databasePath: String) throws {
        self.dbQueue = try DatabaseQueue(path: databasePath)
        try Self.runMigrations(on: dbQueue)
    }

    /// In-memory database for testing
    init() throws {
        self.dbQueue = try DatabaseQueue()
        try Self.runMigrations(on: dbQueue)
    }

    // MARK: - WordRepositoryProtocol

    func save(_ entry: WordEntry) async throws {
        let record = WordEntryRecord(from: entry)
        do {
            try await dbQueue.write { db in
                try record.insert(db)
            }
        } catch let error as DatabaseError where error.extendedResultCode == .SQLITE_CONSTRAINT_UNIQUE {
            throw StorageError.duplicateWord(entry.word)
        }
    }

    func update(_ entry: WordEntry) async throws {
        let record = WordEntryRecord(from: entry)
        do {
            try await dbQueue.write { db in
                try record.update(db)
            }
        } catch is PersistenceError {
            // GRDB throws PersistenceError.recordNotFound when no row matches
            throw StorageError.recordNotFound(entry.id)
        }
    }

    func delete(_ id: UUID) async throws {
        try await dbQueue.write { db in
            _ = try WordEntryRecord.deleteOne(db, key: id.uuidString)
        }
    }

    func fetchAll() async throws -> [WordEntry] {
        try await dbQueue.read { db in
            let records = try WordEntryRecord
                .order(WordEntryRecord.Columns.capturedAt.desc)
                .fetchAll(db)
            return records.map { $0.toWordEntry() }
        }
    }

    func fetch(where predicate: @Sendable (WordEntry) -> Bool) async throws -> [WordEntry] {
        // Swift closure cannot translate to SQL; fetch all then filter in memory
        let all = try await fetchAll()
        return all.filter(predicate)
    }

    func find(byWord word: String) async throws -> WordEntry? {
        try await dbQueue.read { db in
            // COLLATE NOCASE on the word column handles case-insensitive comparison
            let record = try WordEntryRecord
                .filter(WordEntryRecord.Columns.word == word)
                .fetchOne(db)
            return record?.toWordEntry()
        }
    }

    // MARK: - Migrations

    private static func runMigrations(on dbQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_create_word_entries") { db in
            try db.create(table: "word_entries") { t in
                t.primaryKey("id", .text)
                t.column("word", .text).notNull().collate(.nocase)
                t.column("definition", .text).notNull()
                t.column("phonetic", .text)
                t.column("example_sentences", .text).notNull()
                t.column("source_app", .text).notNull()
                t.column("captured_at", .double).notNull()
                t.column("learning_state", .text).notNull().defaults(to: "new")
                t.column("srs_next_review_date", .double).notNull()
                t.column("srs_interval", .double).notNull().defaults(to: 0)
                t.column("srs_ease_factor", .double).notNull().defaults(to: 2.5)
                t.column("srs_repetitions", .integer).notNull().defaults(to: 0)
            }

            try db.create(
                index: "idx_word",
                on: "word_entries",
                columns: ["word"],
                unique: true
            )

            try db.create(
                index: "idx_next_review",
                on: "word_entries",
                columns: ["srs_next_review_date"]
            )
        }

        try migrator.migrate(dbQueue)
    }
}
