import Foundation

// MARK: - StorageError

/// Storage layer domain errors
enum StorageError: LocalizedError {
    case duplicateWord(String)
    case recordNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .duplicateWord(let word):
            return "Word '\(word)' already exists in the repository"
        case .recordNotFound(let id):
            return "Record with id '\(id)' not found"
        }
    }
}
