# YoLingo - 命令行构建和运行
# 用法:
#   make build    → 编译项目
#   make run      → 编译并运行
#   make app      → 打包为 .app bundle
#   make clean    → 清理构建产物

APP_NAME = YoLingo
BUILD_DIR = .build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
BINARY = $(BUILD_DIR)/debug/$(APP_NAME)
INFO_PLIST = YoLingo/Resources/Info.plist
ENTITLEMENTS = YoLingo/Resources/YoLingo.entitlements

.PHONY: build run app clean

# 编译（swift build）
build:
	@echo "🔨 编译 $(APP_NAME)..."
	swift build
	@echo "✅ 编译完成"

# 打包为 .app bundle（macOS 权限需要 .app 格式）
app: build
	@echo "📦 打包 $(APP_NAME).app..."
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp $(BINARY) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	@cp $(INFO_PLIST) $(APP_BUNDLE)/Contents/Info.plist
	@# 代码签名（使用 "YoLingo Dev" 自签名证书，权限在重编译后不会失效）
	@codesign --force --sign "YoLingo Dev" \
		--entitlements $(ENTITLEMENTS) \
		$(APP_BUNDLE)
	@echo "✅ 打包完成: $(APP_BUNDLE)"

# 编译 + 打包 + 运行
run: app
	@echo "🚀 启动 $(APP_NAME)..."
	@open $(APP_BUNDLE)

# 清理
clean:
	@echo "🧹 清理构建产物..."
	swift package clean
	rm -rf $(APP_BUNDLE)
	@echo "✅ 清理完成"
