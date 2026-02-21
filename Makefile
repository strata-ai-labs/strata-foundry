BRIDGE_DIR = strata-foundry-bridge
DYLIB = libstrata_foundry_bridge.dylib
FRAMEWORKS_DIR = StrataFoundry/Frameworks

.PHONY: bridge bridge-release install test clean dev

# Build Rust bridge (debug)
bridge:
	cd $(BRIDGE_DIR) && cargo build

# Build Rust bridge (release, universal binary)
bridge-release:
	cd $(BRIDGE_DIR) && cargo build --release --target aarch64-apple-darwin
	cd $(BRIDGE_DIR) && cargo build --release --target x86_64-apple-darwin
	lipo -create \
		$(BRIDGE_DIR)/target/aarch64-apple-darwin/release/$(DYLIB) \
		$(BRIDGE_DIR)/target/x86_64-apple-darwin/release/$(DYLIB) \
		-output $(BRIDGE_DIR)/target/release/$(DYLIB)

# Copy dylib into Xcode project
install: bridge
	mkdir -p $(FRAMEWORKS_DIR)
	cp $(BRIDGE_DIR)/target/debug/$(DYLIB) $(FRAMEWORKS_DIR)/

install-release: bridge-release
	mkdir -p $(FRAMEWORKS_DIR)
	cp $(BRIDGE_DIR)/target/release/$(DYLIB) $(FRAMEWORKS_DIR)/

# Run Rust tests
test:
	cd $(BRIDGE_DIR) && cargo test

# Clean Rust build artifacts
clean:
	cd $(BRIDGE_DIR) && cargo clean

# Dev workflow: build Rust + open Xcode
dev: install
	open StrataFoundry/StrataFoundry.xcodeproj
