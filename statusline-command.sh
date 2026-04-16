#!/bin/sh
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.id // ""')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# Get just the last component of the path, replacing home with ~
home="$HOME"
if [ "$cwd" = "$home" ]; then
  folder="~"
else
  case "$cwd" in
    "$home"/*)
      rel="${cwd#$home/}"
      folder=$(basename "$rel")
      ;;
    *)
      folder=$(basename "$cwd")
      ;;
  esac
fi

# Get git branch if inside a git repo (skip locks to avoid blocking)
git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
if [ -n "$git_branch" ]; then
  location="$folder ($git_branch)"
else
  location="$folder"
fi

# Build context string with k-token counts
# used_tokens = used_percentage * context_window_size / 100
if [ -n "$used" ] && [ -n "$ctx_size" ]; then
  used_k=$(awk "BEGIN {printf \"%.0f\", $used * $ctx_size / 100 / 1000}")
  max_k=$(awk "BEGIN {printf \"%.0f\", $ctx_size / 1000}")
  ctx_str="$(printf '%.0f' "$used")% (${used_k}k/${max_k}k)"
elif [ -n "$used" ]; then
  ctx_str="$(printf '%.0f' "$used")%"
else
  ctx_str=""
fi

# Build rate limit string
five_h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_h_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
if [ -n "$five_h" ] && [ -n "$seven_d" ]; then
  reset_str=""
  if [ -n "$five_h_reset" ]; then
    now=$(date +%s)
    diff=$((five_h_reset - now))
    if [ "$diff" -gt 0 ]; then
      hrs=$((diff / 3600))
      mins=$(((diff % 3600) / 60))
      reset_at=$(date -r "$five_h_reset" "+%I:%M%p" 2>/dev/null | sed 's/^0//')
      reset_str=$(printf " resets in %dh%02dm (%s)" "$hrs" "$mins" "$reset_at")
    fi
  fi
  rate_str="5h: $(printf '%.0f' "$five_h")%${reset_str} [7d: $(printf '%.0f' "$seven_d")%]"
else
  rate_str=""
fi

if [ -n "$rate_str" ]; then
  printf "\033[32m %s\033[0m | %s | %s | %s" "$location" "$model" "$ctx_str" "$rate_str"
else
  printf "\033[32m %s\033[0m | %s | %s" "$location" "$model" "$ctx_str"
fi
