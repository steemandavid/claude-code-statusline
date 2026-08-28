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

# Detect backend
is_zai=false
is_anthropic=false
if [ -n "${ANTHROPIC_BASE_URL:-}" ]; then
    is_zai=true
else
    is_anthropic=true
fi

# Build usage info based on backend
glm_info=""
anthropic_info=""

if [ "$is_zai" = true ]; then
    # z.ai / GLM backend — read GLM usage cache
    cache_file="$HOME/.glm-plan-usage-cache.json"
    update_script="$HOME/.claude/update-glm-usage-cache.mjs"

    if [ -f "$cache_file" ]; then
        mcp_used=$(jq -r '.mcp_used // 0' "$cache_file" 2>/dev/null)
        mcp_total=$(jq -r '.mcp_total // 1000' "$cache_file" 2>/dev/null)
        token_5h=$(jq -r '.token_percent_5h // 0' "$cache_file" 2>/dev/null)
        token_weekly=$(jq -r '.token_percent_weekly // 0' "$cache_file" 2>/dev/null)
        # Fallback for old cache format
        if [ "$token_5h" -eq 0 ] 2>/dev/null && [ "$token_weekly" -eq 0 ] 2>/dev/null; then
            token_weekly=$(jq -r '.token_percent // 0' "$cache_file" 2>/dev/null)
        fi

        if [ "$mcp_used" -gt 0 ] 2>/dev/null || [ "$token_weekly" -gt 0 ] 2>/dev/null; then
            mcp_percent=$((mcp_used * 100 / mcp_total))
            glm_parts=()
            [ "$mcp_percent" -gt 0 ] 2>/dev/null && glm_parts+=("MCP ${mcp_percent}%")
            if [ "$token_5h" -gt 0 ] 2>/dev/null || [ "$token_weekly" -gt 0 ] 2>/dev/null; then
                glm_parts+=("Tok ${token_5h}%/${token_weekly}%")
            fi
            [ ${#glm_parts[@]} -gt 0 ] && glm_info=$(IFS='| '; echo "${glm_parts[*]}")
        fi

        # Trigger background refresh if cache is stale (older than 5 minutes)
        if [ -x "$update_script" ]; then
            if [ -z "$(find "$cache_file" -mmin -5 2>/dev/null)" ]; then
                nohup node "$update_script" >/dev/null 2>&1 &
            fi
        fi
    fi
else
    # Anthropic Pro/Max backend — live rate limits from the statusline JSON
    # (Claude Code v2.1.x: rate_limits.five_hour / rate_limits.seven_day,
    # populated for Claude.ai subscribers after the first API response).
    if [ -n "$(echo "$input" | jq -r '.rate_limits // empty')" ]; then
        a_token_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // 0')
        a_token_weekly=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // 0')
        anthropic_info="Tok ${a_token_5h}%/${a_token_weekly}%"
    fi

    # Fallback: show raw session tokens if no Anthropic cache
    if [ -z "$anthropic_info" ]; then
        total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0' 2>/dev/null)
        total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0' 2>/dev/null)
        total_tokens=$(( ${total_in:-0} + ${total_out:-0} ))

        if [ "$total_tokens" -gt 0 ] 2>/dev/null; then
            if [ "$total_tokens" -ge 1000 ]; then
                token_str=$(awk "BEGIN {printf \"%.1fk\", $total_tokens/1000}")
            else
                token_str="${total_tokens}"
            fi
            anthropic_info="Tok: ${token_str}"
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

# Add GLM usage if on z.ai backend
if [ -n "$glm_info" ]; then
    status_line="${status_line} | \033[01;36mGLM: ${glm_info}\033[00m"
fi

# Add Anthropic usage if on Anthropic backend
if [ -n "$anthropic_info" ]; then
    status_line="${status_line} | \033[01;36m${anthropic_info}\033[00m"
fi

# Add user@host:path at the end (truncated if needed)
status_line="${status_line} | \033[01;32m${user}@${hostname}\033[00m:\033[01;34m${cwd}\033[00m"

printf '%b' "$status_line"
