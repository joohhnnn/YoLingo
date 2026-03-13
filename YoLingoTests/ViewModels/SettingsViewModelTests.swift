// YoLingoTests/ViewModels/SettingsViewModelTests.swift
import XCTest
import Combine
@testable import YoLingo

// MARK: - MockSettingsService

final class MockSettingsService: SettingsServiceProtocol {
    private let eventBus: EventBus
    private var _appLanguage = "zh-Hans"
    private var _launchAtLogin = false
    private var _aiProvider = "openai"
    private var _position: FloatingCardPosition = .bottomRight
    private var _opacity: Double = 0.85
    private var keys: [String: String] = [:]

    init(eventBus: EventBus) { self.eventBus = eventBus }

    var appLanguage: String { _appLanguage }
    func setAppLanguage(_ lang: String) { _appLanguage = lang; eventBus.emit(.settingsChanged(.appLanguage)) }

    var launchAtLogin: Bool { _launchAtLogin }
    func setLaunchAtLogin(_ enabled: Bool) { _launchAtLogin = enabled; eventBus.emit(.settingsChanged(.launchAtLogin)) }

    var aiProvider: String { _aiProvider }
    func setAIProvider(_ provider: String) { _aiProvider = provider; eventBus.emit(.settingsChanged(.aiProvider)) }

    func getAPIKey(for provider: String) -> String? { keys[provider] }
    func setAPIKey(_ key: String, for provider: String) throws { keys[provider] = key; eventBus.emit(.settingsChanged(.apiKey)) }

    var floatingCardPosition: FloatingCardPosition { _position }
    func setFloatingCardPosition(_ pos: FloatingCardPosition) { _position = pos; eventBus.emit(.settingsChanged(.floatingCardPosition)) }

    var floatingCardOpacity: Double { _opacity }
    func setFloatingCardOpacity(_ opacity: Double) { _opacity = opacity; eventBus.emit(.settingsChanged(.floatingCardOpacity)) }

    var appVersion: String { "1.0.0-test" }
}

// MARK: - SettingsViewModelTests

@MainActor
final class SettingsViewModelTests: XCTestCase {

    private var mockSettings: MockSettingsService!
    private var mockRepo: MockWordRepository!
    private var eventBus: EventBus!
    private var vm: SettingsViewModel!
    private var receivedEvents: [AppEvent] = []
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        eventBus = EventBus()
        mockSettings = MockSettingsService(eventBus: eventBus)
        mockRepo = MockWordRepository()
        vm = SettingsViewModel(
            settingsService: mockSettings,
            repository: mockRepo,
            config: Config(settings: mockSettings),
            eventBus: eventBus
        )
        receivedEvents = []
        eventBus.publisher
            .sink { [weak self] event in self?.receivedEvents.append(event) }
            .store(in: &cancellables)
    }

    override func tearDown() {
        cancellables.removeAll()
        vm = nil
        super.tearDown()
    }

    func testLanguageChangeCallsService() {
        vm.appLanguage = "zh-Hant"
        let exp = expectation(description: "propagate")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(mockSettings.appLanguage, "zh-Hant")
    }

    func testPositionChangeCallsService() {
        vm.floatingCardPosition = .topLeft
        let exp = expectation(description: "propagate")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(mockSettings.floatingCardPosition, .topLeft)
    }

    func testOpacityChangeCallsService() {
        vm.floatingCardOpacity = 0.5
        let exp = expectation(description: "propagate")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(mockSettings.floatingCardOpacity, 0.5, accuracy: 0.001)
    }

    func testProviderChangeEmitsEvent() {
        vm.aiProvider = "gemini"
        let exp = expectation(description: "propagate")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1)
        XCTAssertTrue(receivedEvents.contains { event in
            if case .settingsChanged(.aiProvider) = event { return true }
            return false
        })
    }

    func testSaveAPIKeyCallsService() {
        vm.apiKeyInput = "sk-test-new-key"
        vm.saveAPIKey()
        XCTAssertEqual(mockSettings.getAPIKey(for: "openai"), "sk-test-new-key")
    }
}
