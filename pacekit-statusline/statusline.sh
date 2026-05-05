#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# ANSI Color Codes — aligned with Design System dark-mode semantic tokens
# success: oklch(0.7 0.17 145)  → xterm 114 (light sea green)
# warning: oklch(0.82 0.16 70)  → xterm 221 (light goldenrod)
# danger:  oklch(0.7 0.19 28)   → xterm 210 (light coral)
BOLD=$'\033[1m'
SUCCESS=$'\033[38;5;114m'
WARNING=$'\033[38;5;221m'
DANGER=$'\033[38;5;210m'
CRITICAL=$'\033[38;5;177m'
DIM=$'\033[2m'
# Dim variants — darker xterm colors for empty bar segments (avoids DIM attribute)
SUCCESS_DIM=$'\033[38;5;65m'
WARNING_DIM=$'\033[38;5;136m'
DANGER_DIM=$'\033[38;5;131m'
CRITICAL_DIM=$'\033[38;5;97m'
FG_DIM=$'\033[38;5;244m'
FG_LIGHT=$'\033[38;5;252m'
RESET=$'\033[0m'

# Extract fields
MODEL_DISPLAY=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
MODEL_DISPLAY=$(echo "$MODEL_DISPLAY" | sed -E 's/ *\([^)]*\) *$//')
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
CTX_PERCENT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# Rate limits (Max/Pro, absent before first API response)
FIVE_H_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
SEVEN_D_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
SEVEN_D_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Branch — always from git (source of truth)
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir // empty')
BRANCH=$(git -C "$CURRENT_DIR" branch --show-current 2>/dev/null)
[ -z "$BRANCH" ] && BRANCH=$(echo "$input" | jq -r '.worktree.branch // empty')

# Worktree / checkout name — basename of the git worktree root (exact, no prefix stripping).
# Subdir = relative path from worktree root to cwd (empty when at root).
WORKTREE_ROOT=$(git -C "$CURRENT_DIR" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$WORKTREE_ROOT" ]; then
    WORKTREE_NAME=$(basename "$WORKTREE_ROOT")
    if [ "$CURRENT_DIR" != "$WORKTREE_ROOT" ]; then
        SUBDIR="${CURRENT_DIR#$WORKTREE_ROOT/}"
    else
        SUBDIR=""
    fi
else
    WORKTREE_NAME=$(basename "$CURRENT_DIR" 2>/dev/null)
    SUBDIR=""
fi

# Format context window size in M/K
format_k() {
    local num=$1
    if [ $num -ge 1000000 ]; then
        printf "%dM" $((num / 1000000))
    elif [ $num -ge 100000 ]; then
        printf "%dK" $((num / 1000))
    elif [ $num -ge 1000 ]; then
        printf "%dK" $(( (num + 500) / 1000 ))
    else
        echo "$num"
    fi
}
CTX_WINDOW_K=$(format_k $CONTEXT_SIZE)

# Build a colored bar for a given percentage.
# Fills with ▮ (narrow vertical rectangle), pads with dim-color ▮.
# Args: $1=pct, $2=ANSI fg color code, $3=width (default 5), $4=dim color
EMPTY_COLOR=$'\033[38;5;240m'
build_bar() {
    local pct=$1
    local color=$2
    local width=${3:-5}
    local dim_color=${4:-$EMPTY_COLOR}
    local filled=$(( (pct * width + 50) / 100 ))
    [ $filled -gt $width ] && filled=$width
    [ $filled -lt 0 ] && filled=0
    local empty=$((width - filled))
    local bar=""
    local i
    for ((i=0; i<filled; i++)); do bar+="${color}▮"; done
    local pad=""
    for ((i=0; i<empty; i++)); do pad+="${dim_color}▮"; done
    printf "%s%s%s" "$bar" "$pad" "$RESET"
}

# Threshold coloring for context (not a time window)
threshold_color() {
    local pct=$1
    if [ $pct -ge 60 ]; then echo "$CRITICAL"
    elif [ $pct -ge 50 ]; then echo "$DANGER"
    elif [ $pct -ge 40 ]; then echo "$WARNING"
    else echo "$SUCCESS"
    fi
}
threshold_color_dim() {
    local pct=$1
    if [ $pct -ge 60 ]; then echo "$CRITICAL_DIM"
    elif [ $pct -ge 50 ]; then echo "$DANGER_DIM"
    elif [ $pct -ge 40 ]; then echo "$WARNING_DIM"
    else echo "$SUCCESS_DIM"
    fi
}

# Velocity coloring — compare usage% to elapsed% of the window.
# Args: $1=usage pct, $2=seconds remaining, $3=window total seconds
# Rules (consistent at all elapsed values — no "too early to tell" grace):
#   Ratio-based pace: (usage/elapsed - 1) * 100 = % over pace
#   > 10  -> critical (violet)
#   >= 0  -> danger (red)
#   > -10 -> warning (yellow)
#   <= -10 -> success (green)
# Echoes "COLOR PACE" (e.g. "\033[...m 15")
velocity_info() {
    local usage=$1
    local remaining=$2
    local total=$3
    if [ -z "$remaining" ] || [ -z "$total" ]; then echo "$SUCCESS 0"; return; fi
    local elapsed=$((total - remaining))
    [ $elapsed -lt 0 ] && elapsed=0
    local elapsed_pct=$(( elapsed * 100 / total ))
    [ $elapsed_pct -lt 1 ] && elapsed_pct=1
    local pace=$(( (usage * 100 / elapsed_pct) - 100 ))
    local color
    if [ $pace -gt 10 ]; then color="$CRITICAL"
    elif [ $pace -ge 0 ]; then color="$DANGER"
    elif [ $pace -gt -10 ]; then color="$WARNING"
    else color="$SUCCESS"
    fi
    echo "$color $pace"
}
velocity_info_dim() {
    local usage=$1
    local remaining=$2
    local total=$3
    if [ -z "$remaining" ] || [ -z "$total" ]; then echo "$SUCCESS_DIM"; return; fi
    local elapsed=$((total - remaining))
    [ $elapsed -lt 0 ] && elapsed=0
    local elapsed_pct=$(( elapsed * 100 / total ))
    [ $elapsed_pct -lt 1 ] && elapsed_pct=1
    local pace=$(( (usage * 100 / elapsed_pct) - 100 ))
    if [ $pace -gt 10 ]; then echo "$CRITICAL_DIM"
    elif [ $pace -ge 0 ]; then echo "$DANGER_DIM"
    elif [ $pace -gt -10 ]; then echo "$WARNING_DIM"
    else echo "$SUCCESS_DIM"
    fi
}

# Reset countdown — short form "3h 21m" for <24h windows
format_reset_short() {
    local epoch=$1
    [ -z "$epoch" ] && return
    local now=$(date +%s)
    local diff=$((epoch - now))
    [ $diff -lt 0 ] && echo "now" && return
    local hours=$((diff / 3600))
    local mins=$(( (diff % 3600) / 60 ))
    if [ $hours -eq 0 ] && [ $mins -eq 0 ]; then printf "<1m"
    elif [ $hours -eq 0 ]; then printf "%dm" $mins
    elif [ $mins -eq 0 ]; then printf "%dh" $hours
    else printf "%dh%dm" $hours $mins
    fi
}

# Reset countdown — long form "2d 01h" for multi-day windows
format_reset_long() {
    local epoch=$1
    [ -z "$epoch" ] && return
    local now=$(date +%s)
    local diff=$((epoch - now))
    [ $diff -lt 0 ] && echo "now" && return
    local days=$((diff / 86400))
    local hours=$(( (diff % 86400) / 3600 ))
    local mins=$(( (diff % 3600) / 60 ))
    if [ $days -eq 0 ] && [ $hours -eq 0 ] && [ $mins -eq 0 ]; then printf "<1m"
    elif [ $days -eq 0 ] && [ $hours -eq 0 ]; then printf "%dm" $mins
    elif [ $days -eq 0 ] && [ $mins -eq 0 ]; then printf "%dh" $hours
    elif [ $days -eq 0 ]; then printf "%dh%dm" $hours $mins
    elif [ $hours -eq 0 ]; then printf "%dd" $days
    else printf "%dd%dh" $days $hours
    fi
}

# Seconds-until-reset helper for velocity calc
secs_until() {
    local epoch=$1
    [ -z "$epoch" ] && { echo ""; return; }
    local now=$(date +%s)
    local diff=$((epoch - now))
    [ $diff -lt 0 ] && diff=0
    echo $diff
}

# Single line: context | 5h rate | 7d rate | model + branch
CTX_COLOR=$(threshold_color $CTX_PERCENT)
CTX_COLOR_DIM=$(threshold_color_dim $CTX_PERCENT)
CTX_BAR=$(build_bar $CTX_PERCENT "$CTX_COLOR" 5 "$CTX_COLOR_DIM")
FIVE_H_TOTAL=$((5 * 3600))
SEVEN_D_TOTAL=$((7 * 86400))

CTX_SEG="${CTX_BAR} ${BOLD}${CTX_COLOR}${CTX_PERCENT}%${RESET} / ${BOLD}${FG_LIGHT}${CTX_WINDOW_K} ${MODEL_DISPLAY}${RESET}"
[ -n "$WORKTREE_NAME" ] && CTX_SEG+=" ${FG_DIM}·${RESET} ${FG_LIGHT}⑂ ${WORKTREE_NAME}${RESET}"
[ -n "$SUBDIR" ] && CTX_SEG+="${FG_DIM}/${SUBDIR}${RESET}"
# Hide branch when it duplicates the worktree name
[ -n "$BRANCH" ] && [ "$BRANCH" != "$WORKTREE_NAME" ] && CTX_SEG+=" ${FG_LIGHT}⎇ ${BRANCH}${RESET}"

LINE1="${CTX_SEG}"

# Line 2 — only rendered when both rate-limit windows are present (Pro/Max plans).
# On non-Pro/Max plans these fields are absent, and we hide the line entirely
# rather than showing a placeholder.
if [ -n "$FIVE_H_PCT" ] && [ -n "$SEVEN_D_PCT" ]; then
    FIVE_H_INT=$(printf '%.0f' "$FIVE_H_PCT")
    FIVE_REMAIN=$(secs_until "$FIVE_H_RESET")
    read FIVE_COLOR FIVE_PACE <<< "$(velocity_info $FIVE_H_INT "$FIVE_REMAIN" $FIVE_H_TOTAL)"
    FIVE_COLOR_DIM=$(velocity_info_dim $FIVE_H_INT "$FIVE_REMAIN" $FIVE_H_TOTAL)
    FIVE_BAR=$(build_bar $FIVE_H_INT "$FIVE_COLOR" 5 "$FIVE_COLOR_DIM")
    FIVE_RESET_TEXT=$(format_reset_short "$FIVE_H_RESET")
    FIVE_PACE_SIGN=$([ $FIVE_PACE -ge 0 ] && echo "+" || echo "")
    FIVE_SEG="${FIVE_BAR} ${FIVE_COLOR_DIM}${FIVE_H_INT}%${RESET} (${BOLD}${FIVE_COLOR}${FIVE_PACE_SIGN}${FIVE_PACE}%${RESET}) ${FG_LIGHT}${FIVE_RESET_TEXT:-}${RESET} ${FG_DIM}/${RESET} ${FG_LIGHT}5h${RESET}"

    SEVEN_D_INT=$(printf '%.0f' "$SEVEN_D_PCT")
    SEVEN_REMAIN=$(secs_until "$SEVEN_D_RESET")
    read SEVEN_COLOR SEVEN_PACE <<< "$(velocity_info $SEVEN_D_INT "$SEVEN_REMAIN" $SEVEN_D_TOTAL)"
    SEVEN_COLOR_DIM=$(velocity_info_dim $SEVEN_D_INT "$SEVEN_REMAIN" $SEVEN_D_TOTAL)
    SEVEN_BAR=$(build_bar $SEVEN_D_INT "$SEVEN_COLOR" 5 "$SEVEN_COLOR_DIM")
    SEVEN_RESET_TEXT=$(format_reset_long "$SEVEN_D_RESET")
    SEVEN_PACE_SIGN=$([ $SEVEN_PACE -ge 0 ] && echo "+" || echo "")
    SEVEN_SEG="${SEVEN_BAR} ${SEVEN_COLOR_DIM}${SEVEN_D_INT}%${RESET} (${BOLD}${SEVEN_COLOR}${SEVEN_PACE_SIGN}${SEVEN_PACE}%${RESET}) ${FG_LIGHT}${SEVEN_RESET_TEXT:-}${RESET} ${FG_DIM}/${RESET} ${FG_LIGHT}7d${RESET}"

    LINE2="${FIVE_SEG} ${FG_DIM}·${RESET} ${SEVEN_SEG}"
    printf "%b\n%b\n" "$LINE1" "$LINE2"
else
    printf "%b\n" "$LINE1"
fi
