// YoLingo/UI/Settings/SettingsView.swift
import SwiftUI

// MARK: - SettingsView

/// 偏好设置单页表单
struct SettingsView: View {

    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            generalSection
            aiSection
            floatingCardSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 480)
        .onAppear {
            Task { await viewModel.loadAboutInfo() }
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section(Localizer.string("general_title")) {
            Picker(Localizer.string("language_label"), selection: $viewModel.appLanguage) {
                Text(Localizer.string("language_zh_hans")).tag("zh-Hans")
                Text(Localizer.string("language_zh_hant")).tag("zh-Hant")
            }

            Toggle(Localizer.string("launch_at_login"), isOn: $viewModel.launchAtLogin)
        }
    }

    // MARK: - AI Section

    private var aiSection: some View {
        Section {
            Picker(Localizer.string("ai_provider"), selection: $viewModel.aiProvider) {
                Text("OpenAI").tag("openai")
                Text("Gemini").tag("gemini")
            }

            HStack {
                SecureField(
                    Localizer.string("api_key_placeholder"),
                    text: $viewModel.apiKeyInput
                )
                .onSubmit { viewModel.saveAPIKey() }

                Button(Localizer.string("validate_button")) {
                    viewModel.saveAPIKey()
                    Task { await viewModel.validateAPIKey() }
                }

                validationIndicator
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        } header: {
            Text(Localizer.string("ai_title"))
        } footer: {
            Text(Localizer.string("keychain_note"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var validationIndicator: some View {
        Group {
            switch viewModel.validationState {
            case .idle:
                EmptyView()
            case .validating:
                ProgressView()
                    .controlSize(.small)
            case .valid:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .invalid:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Floating Card Section

    private var floatingCardSection: some View {
        Section(Localizer.string("card_title")) {
            HStack {
                Text(Localizer.string("card_position"))
                Spacer()
                positionPicker
            }

            HStack {
                Text(Localizer.string("card_opacity"))
                Slider(
                    value: $viewModel.floatingCardOpacity,
                    in: 0.3...1.0,
                    step: 0.05
                )
                Text("\(Int(viewModel.floatingCardOpacity * 100))%")
                    .frame(width: 40, alignment: .trailing)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }

    private var positionPicker: some View {
        HStack(spacing: 4) {
            ForEach(FloatingCardPosition.allCases, id: \.self) { position in
                PositionButton(
                    position: position,
                    isSelected: viewModel.floatingCardPosition == position
                ) {
                    viewModel.floatingCardPosition = position
                }
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section(Localizer.string("about_title")) {
            LabeledContent(Localizer.string("about_version")) {
                Text(viewModel.appVersion)
                    .foregroundColor(.secondary)
            }

            LabeledContent(Localizer.string("about_database")) {
                Text(aboutDatabaseText)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var aboutDatabaseText: String {
        let sizeKB = viewModel.databaseSize / 1024
        let sizeStr = sizeKB > 0 ? "\(sizeKB) KB" : "0 KB"
        return "\(sizeStr) · \(viewModel.wordCount) \(Localizer.string("about_words"))"
    }
}

// MARK: - PositionButton

/// 四角位置选择的小方块按钮
private struct PositionButton: View {
    let position: FloatingCardPosition
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.5), lineWidth: isSelected ? 2 : 1)
                    .frame(width: 28, height: 28)
                    .background(
                        isSelected ? Color.accentColor.opacity(0.1) : Color.clear
                    )

                Circle()
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .offset(dotOffset)
            }
        }
        .buttonStyle(.plain)
    }

    private var dotOffset: CGSize {
        switch position {
        case .topLeft:     return CGSize(width: -6, height: -6)
        case .topRight:    return CGSize(width: 6, height: -6)
        case .bottomLeft:  return CGSize(width: -6, height: 6)
        case .bottomRight: return CGSize(width: 6, height: 6)
        }
    }
}
