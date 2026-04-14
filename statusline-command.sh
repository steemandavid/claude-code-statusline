#!/bin/bash
input=$(cat)

# Get basic session info
user=$(whoami)
hostname=$(hostname -s)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // "'"$(pwd)"'"')
# Show only top-level directory name
cwd="/$(basename "$cwd")"

# Get model display name
model=$(echo "$input" | jq -r '.model.display_name // ""')

# Get context window info
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Try to get GLM Coding Plan usage
glm_info=""
cache_file="$HOME/.glm-plan-usage-cache.json"
update_script="$HOME/.claude/update-glm-usage-cache.mjs"

# Check for cached usage data
if [ -f "$cache_file" ]; then
    mcp_used=$(jq -r '.mcp_used // 0' "$cache_file" 2>/dev/null)
    mcp_total=$(jq -r '.mcp_total // 1000' "$cache_file" 2>/dev/null)
    token_percent=$(jq -r '.token_percent // 0' "$cache_file" 2>/dev/null)

    if [ "$mcp_used" -gt 0 ] 2>/dev/null || [ "$token_percent" -gt 0 ] 2>/dev/null; then
        mcp_percent=$((mcp_used * 100 / mcp_total))
        glm_parts=()
        [ "$mcp_percent" -gt 0 ] 2>/dev/null && glm_parts+=("MCP ${mcp_percent}%")
        [ "$token_percent" -gt 0 ] 2>/dev/null && glm_parts+=("Tok ${token_percent}%")
        [ ${#glm_parts[@]} -gt 0 ] && glm_info=$(IFS='| '; echo "${glm_parts[*]}")
    fi

    # Trigger background refresh if cache is stale (older than 5 minutes)
    # Only runs when ANTHROPIC_BASE_URL is set (z.ai backend)
    if [ -n "${ANTHROPIC_BASE_URL:-}" ] && [ -x "$update_script" ]; then
        if [ -z "$(find "$cache_file" -mmin -5 2>/dev/null)" ]; then
            nohup node "$update_script" >/dev/null 2>&1 &
        fi
    fi
fi

# Build status line components — info first, path last
status_line=""

# Add model if available
if [ -n "$model" ]; then
    status_line="${status_line}\033[01;33m${model}\033[00m"
fi

# Add context window usage if available
if [ -n "$used" ]; then
    status_line="${status_line} | \033[01;35mCont: ${used}%\033[00m"
fi

# Add GLM usage if available (z.ai backend)
if [ -n "$glm_info" ]; then
    status_line="${status_line} | \033[01;36mGLM: ${glm_info}\033[00m"
fi

# Add session token usage
# Anthropic Pro: show live session tokens; z.ai: show token percentage from GLM cache
if [ -z "${ANTHROPIC_BASE_URL:-}" ] && [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
    total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0' 2>/dev/null)
    total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0' 2>/dev/null)
    total_tokens=$(( ${total_in:-0} + ${total_out:-0} ))

    if [ "$total_tokens" -gt 0 ] 2>/dev/null; then
        if [ "$total_tokens" -ge 1000 ]; then
            token_str=$(awk "BEGIN {printf \"%.1fk\", $total_tokens/1000}")
        else
            token_str="${total_tokens}"
        fi
        status_line="${status_line} | \033[01;33mTok: ${token_str}\033[00m"
    fi
fi

# Add user@host:path at the end (truncated if needed)
status_line="${status_line} | \033[01;32m${user}@${hostname}\033[00m:\033[01;34m${cwd}\033[00m"

printf '%b' "$status_line"
