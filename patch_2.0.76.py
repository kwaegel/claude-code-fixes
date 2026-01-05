#!/usr/bin/env python3
"""
Surgical patch for Claude Code WSL detection.
Only patches the specific microsoft/wsl checks in the platform detection function.
"""

def patch_wsl_detection(input_file, output_file):
    with open(input_file, 'rb') as f:
        data = bytearray(f.read())

    # The specific pattern we're looking for in the WSL detection:
    # readFileSync("/proc/version"...includes("microsoft")||...includes("wsl")
    # We need to find this exact context and only replace those instances

    # Pattern: .includes("microsoft") in context of /proc/version
    pattern1 = b'.includes("microsoft")'
    replacement1 = b'.includes("micr0s0ft")'

    # Pattern: .includes("wsl") in context of /proc/version
    pattern2 = b'.includes("wsl")'
    replacement2 = b'.includes("ws1")'

    # We need to search for the context: readFileSync("/proc/version"
    context_marker = b'readFileSync("/proc/version"'

    changes_made = 0
    pos = 0

    while True:
        # Find the next occurrence of readFileSync("/proc/version"
        pos = data.find(context_marker, pos)
        if pos == -1:
            break

        # Look for patterns within 500 bytes after this marker
        search_end = min(pos + 500, len(data))
        search_region = pos

        # Find and replace "microsoft" within this context
        ms_pos = data.find(pattern1, pos, search_end)
        if ms_pos != -1:
            print(f"Found 'microsoft' at offset {hex(ms_pos)}")
            data[ms_pos:ms_pos+len(pattern1)] = replacement1
            changes_made += 1

        # Find and replace "wsl" within this context
        wsl_pos = data.find(pattern2, pos, search_end)
        if wsl_pos != -1:
            print(f"Found 'wsl' at offset {hex(wsl_pos)}")
            data[wsl_pos:wsl_pos+len(pattern2)] = replacement2
            changes_made += 1

        # Move past this occurrence
        pos = search_end

    print(f"\nTotal changes made: {changes_made}")

    with open(output_file, 'wb') as f:
        f.write(data)

    return changes_made

if __name__ == '__main__':
    changes = patch_wsl_detection('2.0.76', '2.0.76-patched')
    if changes > 0:
        print(f"\nSuccessfully created surgical patch with {changes} targeted changes")
    else:
        print("\nWarning: No changes were made - pattern not found!")
