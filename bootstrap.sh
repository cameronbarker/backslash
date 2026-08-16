#!/usr/bin/env bash
set -euo pipefail

repo_raw_url="${BACKSLASH_RAW_URL:-https://raw.githubusercontent.com/cameronbarker/backslash/main}"
config_dir="${BACKSLASH_CONFIG_DIR:-$HOME/.config/backslash-terminal}"
zshrc="${BACKSLASH_ZSHRC:-$HOME/.zshrc}"
source_line="source $config_dir/slash.zsh"

mkdir -p "$config_dir"

curl -fsSL "$repo_raw_url/slash.zsh" -o "$config_dir/slash.zsh"
curl -fsSL "$repo_raw_url/commands.example.yaml" -o "$config_dir/commands.example.yaml"

if [[ ! -f "$config_dir/commands.yaml" ]]; then
  cp "$config_dir/commands.example.yaml" "$config_dir/commands.yaml"
fi

touch "$zshrc"
if ! grep -Fxq "$source_line" "$zshrc"; then
  {
    printf '\n'
    printf '%s\n' "$source_line"
  } >> "$zshrc"
fi

printf 'backslash-terminal installed in %s\n' "$config_dir"
printf 'Open a new zsh session or run: %s\n' "$source_line"
