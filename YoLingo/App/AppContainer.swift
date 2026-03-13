import Foundation

// MARK: - AppContainer

/// 依赖注入容器
/// 集中创建和管理所有 Service 和 ViewModel 实例
/// 避免依赖到处飞，也方便测试时替换 mock
final class AppContainer {

    let eventBus: EventBus

    init(eventBus: EventBus = EventBus()) {
        self.eventBus = eventBus
    }

    // MARK: - Services (lazy，用到时才创建)

    lazy var settingsService: SettingsServiceProtocol = SettingsService(eventBus: eventBus)

    /// Config 依赖 settingsService，因此也必须是 lazy
    lazy var config: Config = Config(settings: settingsService)

    lazy var captureService: CaptureServiceProtocol = CaptureService(
        accessibilityCapturer: AccessibilityCapturer(),
        ocrCapturer: OCRCapturer(captureSize: config.ocrCaptureSize),
        eventBus: eventBus
    )

    lazy var dictionaryService: DictionaryServiceProtocol = FreeDictionaryService()

    lazy var aiService: AIServiceProtocol = OpenAIService(settingsService: settingsService)

    lazy var srsScheduler: SRSSchedulerProtocol = SM2Scheduler()

    lazy var repository: WordRepositoryProtocol = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("YoLingo")
        try? FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true
        )
        let dbPath = appSupport
            .appendingPathComponent(config.databaseFileName).path
        // Fatal on failure: app cannot function without storage
        return try! SQLiteWordRepository(databasePath: dbPath)
    }()

    // MARK: - ViewModel Factories
    // 每次调用创建新实例（ViewModel 生命周期跟随 View）

    @MainActor
    func makeCaptureOverlayVM() -> CaptureOverlayViewModel {
        CaptureOverlayViewModel(
            captureService: captureService,
            eventBus: eventBus
        )
    }

    @MainActor
    func makeFloatingCardVM() -> FloatingCardViewModel {
        FloatingCardViewModel(
            repository: repository,
            scheduler: srsScheduler,
            eventBus: eventBus
        )
    }

    @MainActor
    func makeCapturePopoverVM() -> CapturePopoverViewModel {
        CapturePopoverViewModel(
            dictionaryService: dictionaryService,
            aiService: aiService,
            repository: repository,
            eventBus: eventBus
        )
    }

    @MainActor
    func makeReviewVM() -> ReviewViewModel {
        ReviewViewModel(
            repository: repository,
            scheduler: srsScheduler,
            dictionaryService: dictionaryService,
            eventBus: eventBus
        )
    }

    @MainActor
    func makeSettingsVM() -> SettingsViewModel {
        SettingsViewModel(
            settingsService: settingsService,
            repository: repository,
            config: config,
            eventBus: eventBus
        )
    }
}
