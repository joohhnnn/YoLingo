import XCTest
@testable import YoLingo

final class SM2SchedulerTests: XCTestCase {

    private var scheduler: SM2Scheduler!

    override func setUp() {
        super.setUp()
        scheduler = SM2Scheduler()
    }

    // MARK: - Schedule Tests

    func testForgotResetsRepetitions() {
        let entry = makeEntry(repetitions: 3, interval: 86400)
        let result = scheduler.schedule(entry, feedback: .forgot)

        XCTAssertEqual(result.repetitions, 0, "Forgot should reset repetitions to 0")
        XCTAssertLessThan(result.interval, 86400, "Forgot should shorten interval")
    }

    func testGoodIncreasesRepetitions() {
        let entry = makeEntry(repetitions: 0, interval: 0)
        let result = scheduler.schedule(entry, feedback: .good)

        XCTAssertEqual(result.repetitions, 1, "Good should increment repetitions")
        XCTAssertGreaterThan(result.interval, 0, "Good should set a positive interval")
    }

    func testEasyIncreasesEaseFactor() {
        let entry = makeEntry(easeFactor: 2.5)
        let result = scheduler.schedule(entry, feedback: .easy)

        XCTAssertGreaterThan(result.easeFactor, 2.5, "Easy should increase ease factor")
    }

    func testHardDecreasesEaseFactor() {
        let entry = makeEntry(easeFactor: 2.5)
        let result = scheduler.schedule(entry, feedback: .hard)

        XCTAssertLessThan(result.easeFactor, 2.5, "Hard should decrease ease factor")
    }

    func testEaseFactorNeverBelowMinimum() {
        var entry = makeEntry(easeFactor: 1.3)
        // 多次 forgot 不应低于 1.3
        for _ in 0..<10 {
            let result = scheduler.schedule(entry, feedback: .forgot)
            XCTAssertGreaterThanOrEqual(result.easeFactor, 1.3)
            entry.srsData = result
        }
    }

    func testNextReviewDateIsInFuture() {
        let entry = makeEntry()
        let result = scheduler.schedule(entry, feedback: .good)

        XCTAssertGreaterThan(result.nextReviewDate, Date(), "Next review should be in the future")
    }

    // MARK: - getDueWords Tests

    func testGetDueWordsFiltersCorrectly() {
        let now = Date()
        let pastDue = makeEntry(nextReviewDate: now.addingTimeInterval(-3600))
        let notDue = makeEntry(nextReviewDate: now.addingTimeInterval(3600))
        var mastered = makeEntry(nextReviewDate: now.addingTimeInterval(-3600))
        mastered.learningState = .mastered

        let dueWords = scheduler.getDueWords(from: [pastDue, notDue, mastered], on: now)

        XCTAssertEqual(dueWords.count, 1, "Only past-due non-mastered words should be returned")
        XCTAssertEqual(dueWords.first?.id, pastDue.id)
    }

    // MARK: - Helpers

    private func makeEntry(
        repetitions: Int = 0,
        interval: TimeInterval = 0,
        easeFactor: Double = 2.5,
        nextReviewDate: Date = Date()
    ) -> WordEntry {
        WordEntry(
            word: "test",
            definition: "a procedure to test something",
            learningState: .learning,
            srsData: SRSData(
                nextReviewDate: nextReviewDate,
                interval: interval,
                easeFactor: easeFactor,
                repetitions: repetitions
            )
        )
    }
}
