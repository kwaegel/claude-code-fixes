# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository provides a surgical binary patch for Claude Code CLI version 2.0.76 to bypass WSL2 detection that prevents sandboxing. It's a workaround for [upstream issue #10567](https://github.com/anthropics/claude-code/issues/10567).

## Development Workflow

All operations are managed through the Justfile:

```bash
# Complete workflow: download, patch, verify
just all

# Individual steps
just download    # Download original binary from GCS bucket
just patch       # Apply WSL detection patch
just verify      # Verify patched binary
just hash        # Show SHA256 hashes
just info        # Show binary status

# Cleanup
just clean              # Remove all generated files
just clean-patched      # Remove only patched binary
just clean-original     # Remove only original binary
```

## Architecture

### Binary Distribution Source
- Downloads from official GCS bucket: `https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases`
- Automatically detects platform: `linux-x64`, `linux-x64-musl`, `linux-arm64`, `linux-arm64-musl`
- Verifies download integrity using manifest checksums

### Patch Mechanism
The patch (`patch_2.0.76.py`) performs context-aware binary modification:
1. Locates `readFileSync("/proc/version"` markers in the binary
2. Within 500-byte windows, replaces:
   - `.includes("microsoft")` → `.includes("micr0s0ft")`
   - `.includes("wsl")` → `.includes("ws1")`
3. Makes exactly 10 byte changes (6 locations, some strings appear twice)
4. Preserves all other functionality by maintaining string lengths

**Important**: This is surgical - it only modifies WSL2 platform detection, not SSL certificates, MIME types, npm packages, or other "microsoft" strings in the binary.

### Verification Layers
Three-layer verification ensures patch correctness:

1. **Byte-level**: `binary_diff_2.0.76.txt` specifies exact offsets and byte changes
   - Format: `<offset> <original_byte> <new_byte>`
   - Offsets are hex addresses in the binary

2. **SHA256**: `2.0.76-patched.sha256` contains expected hash of correctly patched binary
   - Hash: `296071f49d3882fc7d2f1688f95478f25781f4eae8398cdb722ab5eeef237408`

3. **String verification**: Confirms patch strings appear in binary using `strings` command

### Version-Specific Files
All patch artifacts are versioned:
- `patch_2.0.76.py` - Patch script for version 2.0.76
- `binary_diff_2.0.76.txt` - Expected changes for 2.0.76
- `2.0.76-patched.sha256` - Checksum for patched 2.0.76

To support a new version, create corresponding versioned files and update the `VERSION` variable in the Justfile.

## Platform Support

**Target**: Linux/WSL2 only (the patch exists specifically for WSL2 environments)

**Requirements**:
- `python3` - Runs the patch script
- `curl` - Downloads binaries from GCS
- `jq` - Parses manifest JSON
- `xxd` - Byte-level verification
- `sha256sum` - Checksum verification
- `just` - Command runner

## Important Notes

### Binary Offset Convention
The byte offsets in `binary_diff_2.0.76.txt` are actual file offsets (0-indexed). If verification fails but SHA256 passes, check if offsets need adjustment - they were historically off by 1 in some tools.

### Future Patching
If you need to create a patch for a new version:
1. Download the new binary version
2. Locate the WSL detection code (search for `/proc/version` reads)
3. Find all instances of `includes("microsoft")` and `includes("wsl")` in that context
4. Update `patch_X.Y.Z.py` with the new patterns/offsets
5. Generate new `binary_diff_X.Y.Z.txt` with actual byte changes
6. Calculate and save SHA256 checksum to `X.Y.Z-patched.sha256`
7. Update `VERSION` in Justfile

### Python Script Dependencies
The patch script currently uses only Python stdlib. If dependencies are ever needed, use uv [script mode](https://docs.astral.sh/uv/guides/scripts/#using-a-shebang-to-create-an-executable-file) as noted in README.md.
