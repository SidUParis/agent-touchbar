CC = clang
CFLAGS = -O2 -Wall
OBJC_FLAGS = -fobjc-arc -framework AppKit -framework Carbon -framework ApplicationServices

APP_NAME = AgentTouchBar
BUNDLE = build/$(APP_NAME).app

all: bundle tb-ask

$(APP_NAME): main.m
	$(CC) $(CFLAGS) $(OBJC_FLAGS) main.m -o $(APP_NAME)

bundle: $(APP_NAME)
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	cp packaging/Info.plist $(BUNDLE)/Contents/
	cp $(APP_NAME) $(BUNDLE)/Contents/MacOS/
	codesign --force --sign - $(BUNDLE) 2>/dev/null || true
	@echo "Built $(BUNDLE)"

tb-ask: tb-ask.c
	$(CC) $(CFLAGS) tb-ask.c -o tb-ask

clean:
	rm -rf $(APP_NAME) tb-ask build

install: all
	mkdir -p $(HOME)/Applications $(HOME)/.local/bin
	rm -rf $(HOME)/Applications/$(APP_NAME).app
	cp -R $(BUNDLE) $(HOME)/Applications/
	cp tb-ask $(HOME)/.local/bin/tb-ask
	@echo "Installed $(APP_NAME).app to $(HOME)/Applications and tb-ask to $(HOME)/.local/bin"

.PHONY: all bundle clean install
