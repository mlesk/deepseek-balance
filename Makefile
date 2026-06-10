.PHONY: build run clean debug dmg install

APP := .build/Deepseek-Balance.app
DMG := .build/Deepseek-Balance.dmg

build:
	bash scripts/build-app.sh

run: build
	open "$(APP)" || "$(APP)/Contents/MacOS/Deepseek-Balance"

dmg: build
	@echo "DMG ready: $(DMG)"

debug:
	/usr/bin/swift build -c debug
	.build/arm64-apple-macosx/debug/DeepseekBalance

clean:
	rm -rf .build

install: build
	cp -R "$(APP)" /Applications/

help:
	@echo "make build    — compile & create .app bundle + .dmg installer"
	@echo "make run      — build & launch the app"
	@echo "make dmg      — build & ensure .dmg exists"
	@echo "make debug    — build & run debug binary from terminal"
	@echo "make clean    — remove build artifacts"
	@echo "make install  — copy to /Applications"
