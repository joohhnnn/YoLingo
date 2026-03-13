import XCTest
import Combine
@testable import YoLingo

final class SettingsServiceTests: XCTestCase {

    private var service: SettingsService!
    private var eventBus: EventBus!
    private var receivedEvents: [AppEvent] = []
    private let testKeychainService = "com.yolingo.test.settings"

    override func setUp() {
        super.setUp()
        eventBus = EventBus()
        let defaults = UserDefaults(suiteName: "com.yolingo.test")!
        defaults.removePersistentDomain(forName: "com.yolingo.test")
        service = SettingsService(
            eventBus: eventBus,
            defaults: defaults,
            keychainService: testKeychainService
        )
        receivedEvents = []
        eventBus.publisher
            .sink { [weak self] event in
                self?.receivedEvents.append(event)
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables.removeAll()
        try? KeychainHelper.delete(service: testKeychainService, account: "openai")
        try? KeychainHelper.delete(service: testKeychainService, account: "gemini")
        service = nil
        super.tearDown()
    }

    func testAppLanguageDefault() {
        XCTAssertEqual(service.appLanguage, "zh-Hans")
    }

    func testSetAppLanguage() {
        service.setAppLanguage("zh-Hant")
        XCTAssertEqual(service.appLanguage, "zh-Hant")
    }

    func testSetAppLanguageEmitsEvent() {
        service.setAppLanguage("zh-Hant")
        XCTAssertEqual(receivedEvents.count, 1)
        if case .settingsChanged(.appLanguage) = receivedEvents.first! {
            // OK
        } else {
            XCTFail("Expected .settingsChanged(.appLanguage)")
        }
    }

    func testFloatingCardPositionDefault() {
        XCTAssertEqual(service.floatingCardPosition, .bottomRight)
    }

    func testSetFloatingCardPosition() {
        service.setFloatingCardPosition(.topLeft)
        XCTAssertEqual(service.floatingCardPosition, .topLeft)
    }

    func testFloatingCardOpacityDefault() {
        XCTAssertEqual(service.floatingCardOpacity, 0.85, accuracy: 0.001)
    }

    func testSetFloatingCardOpacity() {
        service.setFloatingCardOpacity(0.5)
        XCTAssertEqual(service.floatingCardOpacity, 0.5, accuracy: 0.001)
    }

    func testAIProviderDefault() {
        XCTAssertEqual(service.aiProvider, "openai")
    }

    func testSetAIProvider() {
        service.setAIProvider("gemini")
        XCTAssertEqual(service.aiProvider, "gemini")
    }

    func testSetAndGetAPIKey() throws {
        try service.setAPIKey("sk-test-123", for: "openai")
        let key = service.getAPIKey(for: "openai")
        XCTAssertEqual(key, "sk-test-123")
    }

    func testGetAPIKeyReturnsNilWhenNotSet() {
        let key = service.getAPIKey(for: "openai")
        XCTAssertNil(key)
    }

    func testSetAPIKeyEmitsEvent() throws {
        try service.setAPIKey("sk-test", for: "openai")
        XCTAssertTrue(receivedEvents.contains { event in
            if case .settingsChanged(.apiKey) = event { return true }
            return false
        })
    }

    func testAppVersionReturnsString() {
        let version = service.appVersion
        XCTAssertFalse(version.isEmpty)
    }
}
