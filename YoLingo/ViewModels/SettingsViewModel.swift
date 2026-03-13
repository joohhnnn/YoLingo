// YoLingo/ViewModels/SettingsViewModel.swift
import Combine
import Foundation

// MARK: - SettingsViewModel

/// 设置界面的 ViewModel
/// 桥接 SettingsService 和 SettingsView
@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published State

    @Published var appLanguage: String
    @Published var launchAtLogin: Bool
    @Published var aiProvider: String
    @Published var apiKeyInput: String = ""
    @Published var floatingCardPosition: FloatingCardPosition
    @Published var floatingCardOpacity: Double

    // API Key validation
    @Published var validationState: ValidationState = .idle
    @Published var errorMessage: String?

    // About
    @Published var appVersion: String = ""
    @Published var wordCount: Int = 0
    @Published var databaseSize: Int64 = 0

    // MARK: - Dependencies

    private let settingsService: SettingsServiceProtocol
    private let repository: WordRepositoryProtocol
    private let config: Config
    private let eventBus: EventBus
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        settingsService: SettingsServiceProtocol,
        repository: WordRepositoryProtocol,
        config: Config,
        eventBus: EventBus
    ) {
        self.settingsService = settingsService
        self.repository = repository
        self.config = config
        self.eventBus = eventBus

        // Initialize from current settings
        self.appLanguage = settingsService.appLanguage
        self.launchAtLogin = settingsService.launchAtLogin
        self.aiProvider = settingsService.aiProvider
        self.floatingCardPosition = settingsService.floatingCardPosition
        self.floatingCardOpacity = settingsService.floatingCardOpacity
        self.appVersion = settingsService.appVersion

        // Load stored API key for current provider
        if let key = settingsService.getAPIKey(for: aiProvider) {
            apiKeyInput = key
        }

        setupBindings()
    }

    // MARK: - Actions

    /// 验证当前 API Key
    func validateAPIKey() async {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            errorMessage = "请输入 API Key"
            return
        }

        validationState = .validating

        do {
            let isValid = try await performValidation(key: key, provider: aiProvider)
            validationState = isValid ? .valid : .invalid
            if !isValid {
                errorMessage = "API Key 无效"
            }
        } catch {
            validationState = .error
            errorMessage = "网络连接失败"
        }
    }

    /// 保存 API Key
    func saveAPIKey() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        do {
            try settingsService.setAPIKey(key, for: aiProvider)
            validationState = .idle
        } catch {
            errorMessage = "无法保存 API Key: \(error.localizedDescription)"
        }
    }

    /// 加载关于信息
    func loadAboutInfo() async {
        wordCount = ((try? await repository.fetchAll())?.count) ?? 0
        let dbPath = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first?.appendingPathComponent("YoLingo")
            .appendingPathComponent(config.databaseFileName).path ?? ""
        let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath)
        databaseSize = (attrs?[.size] as? Int64) ?? 0
    }

    // MARK: - Private

    private func setupBindings() {
        $appLanguage
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] lang in
                self?.settingsService.setAppLanguage(lang)
            }
            .store(in: &cancellables)

        $launchAtLogin
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] enabled in
                self?.settingsService.setLaunchAtLogin(enabled)
            }
            .store(in: &cancellables)

        $aiProvider
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] provider in
                guard let self else { return }
                self.settingsService.setAIProvider(provider)
                self.apiKeyInput = self.settingsService.getAPIKey(for: provider) ?? ""
                self.validationState = .idle
            }
            .store(in: &cancellables)

        $floatingCardPosition
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] pos in
                self?.settingsService.setFloatingCardPosition(pos)
            }
            .store(in: &cancellables)

        $floatingCardOpacity
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] opacity in
                self?.settingsService.setFloatingCardOpacity(opacity)
            }
            .store(in: &cancellables)
    }

    private func performValidation(key: String, provider: String) async throws -> Bool {
        let request: URLRequest
        if provider == "gemini" {
            var url = URLComponents(string: "https://generativelanguage.googleapis.com/v1/models")!
            url.queryItems = [URLQueryItem(name: "key", value: key)]
            request = URLRequest(url: url.url!)
        } else {
            var req = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request = req
        }

        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as? HTTPURLResponse
        return httpResponse?.statusCode == 200
    }
}

// MARK: - ValidationState

enum ValidationState {
    case idle
    case validating
    case valid
    case invalid
    case error
}
