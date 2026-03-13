// YoLingoTests/Services/KeychainHelperTests.swift
import XCTest
@testable import YoLingo

final class KeychainHelperTests: XCTestCase {

    private let testService = "com.yolingo.test"
    private let testAccount = "test-key"

    override func tearDown() {
        try? KeychainHelper.delete(service: testService, account: testAccount)
        super.tearDown()
    }

    func testSaveAndRead() throws {
        let data = "sk-test-key-12345".data(using: .utf8)!
        try KeychainHelper.save(service: testService, account: testAccount, data: data)

        let read = KeychainHelper.read(service: testService, account: testAccount)
        XCTAssertEqual(read, data)
    }

    func testReadNonExistent() {
        let read = KeychainHelper.read(service: testService, account: "nonexistent")
        XCTAssertNil(read)
    }

    func testUpdate() throws {
        let original = "original-key".data(using: .utf8)!
        let updated = "updated-key".data(using: .utf8)!

        try KeychainHelper.save(service: testService, account: testAccount, data: original)
        try KeychainHelper.update(service: testService, account: testAccount, data: updated)

        let read = KeychainHelper.read(service: testService, account: testAccount)
        XCTAssertEqual(read, updated)
    }

    func testDelete() throws {
        let data = "to-delete".data(using: .utf8)!
        try KeychainHelper.save(service: testService, account: testAccount, data: data)

        try KeychainHelper.delete(service: testService, account: testAccount)

        let read = KeychainHelper.read(service: testService, account: testAccount)
        XCTAssertNil(read)
    }

    func testSaveDuplicateUpdatesInstead() throws {
        let first = "first".data(using: .utf8)!
        let second = "second".data(using: .utf8)!

        try KeychainHelper.save(service: testService, account: testAccount, data: first)
        try KeychainHelper.save(service: testService, account: testAccount, data: second)

        let read = KeychainHelper.read(service: testService, account: testAccount)
        XCTAssertEqual(read, second)
    }
}
