# Justfile for Claude Code binary patching automation

VERSION := "2.0.76"
ORIGINAL_BIN := VERSION
PATCHED_BIN := VERSION + "-patched"
PATCH_SCRIPT := "patch_" + VERSION + ".py"
BINARY_DIFF := "binary_diff_" + VERSION + ".txt"
PATCHED_CHECKSUM := VERSION + "-patched.sha256"

# Official Claude Code distribution (GCS bucket)
GCS_BUCKET := "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

# Default recipe - show available commands
default:
    @just --list

# Download the original Claude Code CLI binary
download:
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -f "{{ORIGINAL_BIN}}" ]; then
        echo "Binary {{ORIGINAL_BIN}} already exists. Run 'just clean' first if you want to re-download."
        exit 0
    fi

    echo "Downloading Claude Code CLI version {{VERSION}} from official GCS bucket..."

    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64) arch="x64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) echo "Error: Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
    esac

    # Check for musl on Linux
    if [ -f /lib/libc.musl-x86_64.so.1 ] || [ -f /lib/libc.musl-aarch64.so.1 ] || ldd /bin/ls 2>&1 | grep -q musl; then
        platform="linux-${arch}-musl"
    else
        platform="linux-${arch}"
    fi

    echo "Detected platform: $platform"

    # Download manifest to get checksum
    echo "Downloading manifest..."
    manifest_url="{{GCS_BUCKET}}/{{VERSION}}/manifest.json"

    # Extract checksum using jq
    checksum=$(curl -fsSL "$manifest_url" | jq -r ".platforms[\"$platform\"].checksum")

    if [ -z "$checksum" ] || [ "$checksum" = "null" ]; then
        echo "Error: Could not find checksum for platform $platform in manifest"
        exit 1
    fi

    echo "Expected checksum: $checksum"

    # Download the binary
    binary_url="{{GCS_BUCKET}}/{{VERSION}}/$platform/claude"
    echo "Downloading from: $binary_url"
    curl -fsSL -o "{{ORIGINAL_BIN}}" "$binary_url"

    # Verify checksum
    actual=$(sha256sum "{{ORIGINAL_BIN}}" | cut -d' ' -f1)

    if [ "$actual" != "$checksum" ]; then
        echo "Error: Checksum verification failed!"
        echo "Expected: $checksum"
        echo "Got:      $actual"
        rm -f "{{ORIGINAL_BIN}}"
        exit 1
    fi

    echo "✓ Checksum verified"

    # Make executable
    chmod +x "{{ORIGINAL_BIN}}"

    echo "✓ Successfully downloaded {{ORIGINAL_BIN}}"
    echo "  File size: $(du -h {{ORIGINAL_BIN}} | cut -f1)"
    echo "  SHA256: $actual"

# Apply the WSL detection patch
patch: download
    #!/usr/bin/env bash
    set -euo pipefail

    if [ ! -f "{{ORIGINAL_BIN}}" ]; then
        echo "Error: Original binary {{ORIGINAL_BIN}} not found. Run 'just download' first."
        exit 1
    fi

    if [ -f "{{PATCHED_BIN}}" ]; then
        echo "Patched binary {{PATCHED_BIN}} already exists. Run 'just clean-patched' first if you want to re-patch."
        exit 0
    fi

    echo "Applying WSL detection patch..."
    python3 "{{PATCH_SCRIPT}}"

    # Make patched binary executable
    chmod +x "{{PATCHED_BIN}}"

    echo "Patch applied successfully!"

# Verify the patched binary against the binary diff file
verify:
    #!/usr/bin/env bash
    set -euo pipefail

    if [ ! -f "{{PATCHED_BIN}}" ]; then
        echo "Error: Patched binary {{PATCHED_BIN}} not found. Run 'just patch' first."
        exit 1
    fi

    echo "Verifying patched binary..."
    echo ""

    # Parse the binary_diff file and verify each byte change
    failed=0
    checked=0

    while IFS=' ' read -r offset orig_byte new_byte; do
        # Skip empty lines
        [ -z "$offset" ] && continue

        # Convert hex offset to decimal (removing 0x prefix if present)
        offset_dec=$((16#${offset#0x}))

        # Read the byte at the offset from the patched binary
        actual_byte=$(xxd -s $offset_dec -l 1 -p "{{PATCHED_BIN}}")

        checked=$((checked + 1))

        if [ "$actual_byte" = "$new_byte" ]; then
            echo "✓ Offset $offset: $orig_byte -> $new_byte (verified)"
        else
            echo "✗ Offset $offset: Expected $new_byte, got $actual_byte"
            failed=$((failed + 1))
        fi
    done < "{{BINARY_DIFF}}"

    echo ""
    echo "Verification complete: $checked checks performed"

    if [ $failed -ne 0 ]; then
        echo "✗ Byte-level verification failed: $failed mismatches found"
        exit 1
    fi

    echo "✓ All byte changes verified successfully!"
    echo ""

    # Verify SHA256 checksum of patched binary
    echo "Verifying SHA256 checksum..."
    if sha256sum -c "{{PATCHED_CHECKSUM}}" 2>/dev/null; then
        echo "✓ SHA256 checksum verified!"
    else
        echo "✗ SHA256 checksum verification failed!"
        echo "Expected checksum from {{PATCHED_CHECKSUM}}:"
        cat "{{PATCHED_CHECKSUM}}"
        echo "Actual checksum:"
        sha256sum "{{PATCHED_BIN}}"
        exit 1
    fi

# Full workflow: download, patch, and verify
all: download patch verify
    @echo ""
    @echo "==================================="
    @echo "All steps completed successfully!"
    @echo "==================================="
    @echo ""
    @echo "The patched binary is ready: {{PATCHED_BIN}}"
    @echo ""
    @echo "Use of this binary is left as an exercise to the reader"

# Clean patched binary only
clean-patched:
    rm -f "{{PATCHED_BIN}}"
    @echo "Removed patched binary"

# Clean original binary only
clean-original:
    rm -f "{{ORIGINAL_BIN}}"
    @echo "Removed original binary"

# Clean all generated files
clean: clean-patched clean-original
    @echo "Cleaned all generated files"
