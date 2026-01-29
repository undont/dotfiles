#!/usr/bin/env bash
# PreToolUse hook for Edit/Write operations
# Shows diff preview in Neovim and blocks until user approves/denies
# Exit 0 = allow tool to run, Exit 1 = block tool
set -euo pipefail

# Exit silently if NVIM_SOCKET not configured
[[ -z "${NVIM_SOCKET:-}" ]] && exit 0
[[ ! -S "$NVIM_SOCKET" ]] && exit 0

# Read hook data from stdin
hook_data=$(cat)

# Parse tool name and file path
tool_name=$(echo "$hook_data" | jq -r '.tool_name // empty' 2>/dev/null)
file_path=$(echo "$hook_data" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null)

# Only handle Edit/Write tools
if [[ "$tool_name" != "Edit" && "$tool_name" != "Write" ]]; then
    exit 0  # Allow other tools
fi

[[ -z "$file_path" ]] && exit 0

# Make path absolute
if [[ ! "$file_path" = /* ]]; then
    file_path="$(pwd)/$file_path"
fi

# Check if file exists and is git-tracked
if [[ ! -f "$file_path" ]] || ! git ls-files --error-unmatch "$file_path" &>/dev/null; then
    # New file or non-git file - allow without preview
    exit 0
fi

# Extract proposed content based on tool type
if [[ "$tool_name" == "Edit" ]]; then
    # Edit tool: extract old_string and new_string
    old_string=$(echo "$hook_data" | jq -r '.tool_input.old_string // empty' 2>/dev/null)
    new_string=$(echo "$hook_data" | jq -r '.tool_input.new_string // empty' 2>/dev/null)

    # Generate proposed file content by applying the edit
    current_content=$(cat "$file_path")

    # Simple string replacement for preview
    proposed_content=$(echo "$current_content" | sed "s|$(printf '%s' "$old_string" | sed 's/[[\.*^$/]/\\&/g')|$new_string|g")

elif [[ "$tool_name" == "Write" ]]; then
    # Write tool: extract full content
    proposed_content=$(echo "$hook_data" | jq -r '.tool_input.content // empty' 2>/dev/null)
else
    exit 0
fi

[[ -z "$proposed_content" ]] && exit 0

# Generate diff between current and proposed content
current_content=$(cat "$file_path")
diff_content=$(diff -u <(echo "$current_content") <(echo "$proposed_content") || true)

# Create approval response file
response_file=$(mktemp)
echo "pending" > "$response_file"

# Create JSON payload
json_payload=$(jq -n \
    --arg path "$file_path" \
    --arg diff "$diff_content" \
    --arg tool "$tool_name" \
    --arg response_file "$response_file" \
    '{path: $path, diff: $diff, tool: $tool, response_file: $response_file}')

# Escape for shell
escaped_json=$(printf '%s' "$json_payload" | sed "s/'/'\\\\''/g")

# Send to Neovim plugin and request approval
nvim --server "$NVIM_SOCKET" --remote-expr \
    "luaeval('require(\"claude-diff\").request_approval(vim.fn.json_decode([[$escaped_json]]))')" \
    2>/dev/null || exit 1

# Wait for user decision (timeout after 5 minutes)
timeout=3000  # 300 seconds = 3000 * 0.1s
elapsed=0
while [[ $elapsed -lt $timeout ]]; do
    response=$(cat "$response_file" 2>/dev/null || echo "pending")

    if [[ "$response" == "approved" ]]; then
        rm -f "$response_file"
        # Clear Claude alert on approval (if script exists)
        [[ -x ~/dotfiles/scripts/hooks/wrappers/claude-alert-clear.sh ]] && \
            ~/dotfiles/scripts/hooks/wrappers/claude-alert-clear.sh 2>/dev/null || true

        # Output JSON to allow the tool
        jq -n '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "allow"
            }
        }'
        exit 0
    elif [[ "$response" == "denied" ]]; then
        rm -f "$response_file"
        # Clear Claude alert on denial (if script exists)
        [[ -x ~/dotfiles/scripts/hooks/wrappers/claude-alert-clear.sh ]] && \
            ~/dotfiles/scripts/hooks/wrappers/claude-alert-clear.sh 2>/dev/null || true

        # Output JSON to deny the tool
        jq -n '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "deny"
            }
        }'
        exit 0
    fi

    sleep 0.1
    elapsed=$((elapsed + 1))
done

# Timeout - deny by default
rm -f "$response_file"
# Clear Claude alert on timeout (if script exists)
[[ -x ~/dotfiles/scripts/hooks/wrappers/claude-alert-clear.sh ]] && \
    ~/dotfiles/scripts/hooks/wrappers/claude-alert-clear.sh 2>/dev/null || true

# Output JSON to deny on timeout
jq -n '{
    hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny"
    }
}'
exit 0
