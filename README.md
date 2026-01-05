# Claude Code WSL2 Patch

This repository contains a surgical patch for Claude Code binary `2.0.76` that bypasses the WSL2 detection which prevents sandboxing from being enabled.

> **Note:** This is a workaround for [upstream issue #10567](https://github.com/anthropics/claude-code/issues/10567). Use at your own risk.

## Quick Start

### Prerequisites

- Linux/WSL2 (this patch is specifically for WSL2 environments)
- `just` command runner ([install just](https://github.com/casey/just))
- `python3`
- `curl`, `xxd`, `sha256sum`, `jq`

### Usage

Run the complete workflow:

```bash
just all
```

This will:
1. Download the original Claude Code CLI binary (v2.0.76) from the official GCS distribution
2. Verify the download with SHA256 checksum from the manifest
3. Apply the WSL detection patch
4. Verify the patched binary against the expected changes

### Individual Commands

```bash
# Show all available commands
just

# Download the original binary
just download

# Apply the patch (downloads if needed)
just patch

# Verify the patched binary
just verify

# Show binary hashes
just hash

# Show information about binaries
just info

# Clean up generated files
just clean
just clean-original    # Remove only original binary
just clean-patched     # Remove only patched binary
```

## What This Patch Does

The patch modifies the WSL2 platform detection logic to prevent Claude Code from detecting it's running on WSL2. This allows the sandbox feature to work properly on WSL2 systems.

**Download Source**: The Justfile downloads binaries from the official Claude Code GCS bucket (same source as the official installer), automatically detects your architecture (x64/arm64) and C library (glibc/musl), and verifies the download with SHA256 checksums.

**Changes made:**
- `includes("microsoft")` → `includes("micr0s0ft")`
- `includes("wsl")` → `includes("ws1")`

Only 6 specific bytes are changed in targeted locations within the `/proc/version` detection code.

## Verification

The `just verify` command performs multiple checks:
1. **Byte-level verification**: Checks each byte change listed in `binary_diff_2.0.76.txt`
2. **SHA256 checksum**: Verifies the overall hash against `2.0.76-patched.sha256`
3. **String verification**: Confirms the patch strings appear in the binary

Example output:
```
✓ Offset 063260A0: 6F -> 30 (verified)
✓ Offset 063260A2: 6F -> 30 (verified)
✓ Offset 063260C5: 6C -> 31 (verified)
...
✓ All byte changes verified successfully!

Verifying SHA256 checksum...
✓ SHA256 checksum verified!

Additional verification with strings command:
  micr0s0ft occurrences: 4
  ws1 occurrences: 2
```

## Using the Patched Binary

After running `just all`, use the patched binary:

```bash
# Run directly
./2.0.76-patched

# Or create a symlink
ln -sf $(pwd)/2.0.76-patched ~/bin/claude-code
```

## Files

- `patch_2.0.76.py` - Python script that applies the patch
- `binary_diff_2.0.76.txt` - Expected byte changes for verification
- `2.0.76-patched.sha256` - SHA256 checksum of the correctly patched binary
- `PATCH_NOTES.txt` - Detailed technical documentation
- `Justfile` - Automation script for the workflow

## Why This Patch Exists

Claude Code explicitly detects WSL2 and disables sandboxing, even though the sandboxing primitives (bwrap, bubblewrap, socat) work fine on WSL2. This patch is a workaround for [upstream issue #10567](https://github.com/anthropics/claude-code/issues/10567) until Anthropic removes the check or provides official WSL2 support.

## Caveats

- This is an unofficial workaround, not an official fix
- Will need to be reapplied after Claude Code updates
- Use at your own risk
- Please follow [issue #10567](https://github.com/anthropics/claude-code/issues/10567) for official updates and resolution

## Future work
The Python patch script should be updated to use uv [script mode](https://docs.astral.sh/uv/guides/scripts/#using-a-shebang-to-create-an-executable-file) if we ever need to add dependencies.

## License

See [LICENSE](LICENSE) file.
