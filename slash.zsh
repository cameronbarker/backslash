# backslash-terminal zsh plugin
#
# Source this file from .zshrc:
#   source /path/to/backslash-terminal/slash.zsh

: ${SLASH_COMMANDS_FILE:="$HOME/.config/backslash-terminal/commands.yaml"}
: ${SLASH_PROJECT_COMMANDS_FILE:=".slash-commands.yaml"}
: ${SLASH_FZF_HEIGHT:=80%}
: ${SLASH_FZF_PREVIEW:=right:45%:wrap}
: ${SLASH_DIM_COMMAND_LINE:=1}
: ${SLASH_RUN_LINE_COLOR:=244}

_slash_project_commands_file() {
  local dir="$PWD"
  local marker="$SLASH_PROJECT_COMMANDS_FILE"

  while [[ -n "$dir" ]]; do
    if [[ -f "$dir/$marker" ]]; then
      print -r -- "$dir/$marker"
      return 0
    fi

    [[ "$dir" == "$HOME" || "$dir" == "/" ]] && break
    dir="${dir:h}"
  done

  return 1
}

_slash_trim_yaml_value() {
  emulate -L zsh
  setopt extendedglob
  local value="$1"

  value="${value##[[:space:]]#}"
  value="${value%%[[:space:]]#}"

  if [[ "$value" == \"*\" && "$value" == *\" ]]; then
    value="${value[2,-2]}"
  elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
    value="${value[2,-2]}"
  fi

  print -r -- "$value"
}

_slash_strip_yaml_comment() {
  emulate -L zsh
  local line="$1"

  [[ "$line" == *"#"* ]] || {
    print -r -- "$line"
    return 0
  }

  local i char quote=""
  for (( i = 1; i <= ${#line}; i++ )); do
    char="${line[i]}"

    if [[ -n "$quote" ]]; then
      [[ "$char" == "$quote" ]] && quote=""
      continue
    fi

    if [[ "$char" == \" || "$char" == \' ]]; then
      quote="$char"
      continue
    fi

    if [[ "$char" == "#" ]]; then
      if (( i == 1 )) || [[ "${line[i-1]}" == [[:space:]] ]]; then
        print -r -- "${line[1,i-1]}"
        return 0
      fi
    fi
  done

  print -r -- "$line"
}

_slash_emit_yaml_command() {
  emulate -L zsh
  local source="$1"
  local name="$2"
  local description="$3"
  local command="$4"
  local flags="$5"

  [[ -n "$name" && -n "$description" && -n "$command" ]] || return 0
  print -r -- "$source	$name	$description	$command	$flags"
}

_slash_emit_file_commands() {
  emulate -L zsh
  setopt extendedglob
  local file="$1"
  local source="$2"
  local line
  local name description command flags
  local in_commands=0 in_flags=0 value

  [[ -f "$file" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(_slash_strip_yaml_comment "$line")"
    [[ -z "${line//[[:space:]]/}" ]] && continue

    if [[ "$line" == commands: ]]; then
      in_commands=1
      in_flags=0
      continue
    fi

    (( in_commands )) || continue

    if [[ "$line" == [[:space:]]##-[[:space:]]##name:* ]]; then
      _slash_emit_yaml_command "$source" "$name" "$description" "$command" "$flags"

      value="${line#*name:}"
      name="$(_slash_trim_yaml_value "$value")"
      description=""
      command=""
      flags=""
      in_flags=0
      continue
    fi

    [[ -n "$name" ]] || continue

    if [[ "$line" == [[:space:]]##description:* ]]; then
      value="${line#*description:}"
      description="$(_slash_trim_yaml_value "$value")"
      in_flags=0
      continue
    fi

    if [[ "$line" == [[:space:]]##command:* ]]; then
      value="${line#*command:}"
      command="$(_slash_trim_yaml_value "$value")"
      in_flags=0
      continue
    fi

    if [[ "$line" == [[:space:]]##flags:* ]]; then
      value="${line#*flags:}"
      flags="$(_slash_trim_yaml_value "$value")"
      flags="${flags#\[}"
      flags="${flags%\]}"
      flags="${flags//[[:space:]]/}"
      in_flags=1
      continue
    fi

    if (( in_flags )) && [[ "$line" == [[:space:]]##-[[:space:]]##* ]]; then
      value="${line#*-}"
      value="$(_slash_trim_yaml_value "$value")"
      if [[ -n "$value" ]]; then
        [[ -n "$flags" ]] && flags="${flags},"
        flags="${flags}${value}"
      fi
      continue
    fi
  done < "$file"

  _slash_emit_yaml_command "$source" "$name" "$description" "$command" "$flags"
}

_slash_commands() {
  local project_file

  if project_file="$(_slash_project_commands_file 2>/dev/null)"; then
    _slash_emit_file_commands "$project_file" "project"
  fi

  _slash_emit_file_commands "$SLASH_COMMANDS_FILE" "global"
}

_slash_contains_value() {
  emulate -L zsh
  local needle="$1"
  shift
  local value

  for value in "$@"; do
    [[ "$value" == "$needle" ]] && return 0
  done

  return 1
}

_slash_placeholders() {
  emulate -L zsh
  unsetopt bashrematch ksharrays
  local command="$1"
  local rest="$command"
  local placeholder
  local -a seen

  while [[ "$rest" =~ '\{([A-Za-z_][A-Za-z0-9_]*)\}' ]]; do
    placeholder="$match[1]"

    if ! _slash_contains_value "$placeholder" "${seen[@]}"; then
      seen+=("$placeholder")
      print -r -- "$placeholder"
    fi

    rest="${rest#*$MATCH}"
  done
}

_slash_command_hints() {
  local command="$1"
  local flags="$2"
  local -a hints placeholders
  local placeholder_output

  placeholder_output="$(_slash_placeholders "$command")"
  if [[ -n "$placeholder_output" ]]; then
    placeholders=("${(@f)placeholder_output}")
  else
    placeholders=()
  fi

  if (( ${#placeholders} > 0 )); then
    local placeholder
    local -a braced

    for placeholder in "${placeholders[@]}"; do
      braced+=("{$placeholder}")
    done

    hints+=("args:${(j:,:)braced}")
  fi

  if _slash_flags_include_confirm "$flags"; then
    hints+=("confirm")
  fi

  print -r -- "${(j:,:)hints}"
}

_slash_palette_rows() {
  local row source name description command flags hints

  while IFS= read -r row || [[ -n "$row" ]]; do
    source="$(_slash_field "$row" 1)"
    name="$(_slash_field "$row" 2)"
    description="$(_slash_field "$row" 3)"
    command="$(_slash_field "$row" 4)"
    flags="$(_slash_field "$row" 5)"
    hints="$(_slash_command_hints "$command" "$flags")"

    print -r -- "$source	$name	$description	$command	$flags	$hints"
  done
}

_slash_pick_command() {
  if ! command -v fzf >/dev/null 2>&1; then
    print -u2 -- "backslash-terminal: fzf is required for the slash palette"
    return 127
  fi

  _slash_commands | _slash_palette_rows | fzf \
    --prompt="/ " \
    --height="$SLASH_FZF_HEIGHT" \
    --layout=reverse \
    --delimiter=$'\t' \
    --with-nth=2 \
    --nth=2,3,4,6 \
    --preview='printf "%s\n\n%s\n\ncommand:\n%s\n\nsource: %s\nflags: %s\nhints: %s\n" {2} {3} {4} {1} {5} {6}' \
    --preview-window="$SLASH_FZF_PREVIEW"
}

_slash_field() {
  local row="$1"
  local index="$2"
  local rest="$row"
  local i

  for (( i = 1; i < index; i++ )); do
    if [[ "$rest" == *$'\t'* ]]; then
      rest="${rest#*$'\t'}"
    else
      print -r -- ""
      return 0
    fi
  done

  if [[ "$rest" == *$'\t'* ]]; then
    print -r -- "${rest%%$'\t'*}"
  else
    print -r -- "$rest"
  fi
}

_slash_flags_include_confirm() {
  local flags="$1"
  [[ ",${flags}," == *,confirm,* ]]
}

_slash_confirm_command() {
  local name="$1"
  local command="$2"
  local reply

  print -u2 -n -- "Run slash command '$name'? $command [y/N] "
  read -r reply
  [[ "$reply" == "y" || "$reply" == "Y" ]]
}

_slash_resolve_placeholders() {
  local command="$1"
  local placeholder answer
  local -a placeholders
  local placeholder_output

  placeholder_output="$(_slash_placeholders "$command")"
  if [[ -n "$placeholder_output" ]]; then
    placeholders=("${(@f)placeholder_output}")
  else
    placeholders=()
  fi

  for placeholder in "${placeholders[@]}"; do
    print -u2 -n -- "$placeholder: "
    read -r answer

    [[ -n "$answer" ]] || return 1

    command="${command//\{$placeholder\}/$answer}"
  done

  print -r -- "$command"
}

_slash_selected_command() {
  local row="$1"
  local name command flags

  name="$(_slash_field "$row" 2)"
  command="$(_slash_field "$row" 4)"
  flags="$(_slash_field "$row" 5)"

  [[ -n "$command" ]] || return 1

  command="$(_slash_resolve_placeholders "$command")" || return 1

  if _slash_flags_include_confirm "$flags"; then
    _slash_confirm_command "$name" "$command" || return 1
  fi

  print -r -- "$command"
}

_slash_run_line_color() {
  emulate -L zsh
  setopt extendedglob
  local color="$SLASH_RUN_LINE_COLOR"

  [[ "$color" == [A-Za-z0-9]## ]] || color="244"
  print -r -- "$color"
}

_slash_dim_command_line() {
  emulate -L zsh
  local color

  [[ "$SLASH_DIM_COMMAND_LINE" == "0" ]] && return 0

  color="$(_slash_run_line_color)"
  region_highlight=("0 ${#BUFFER} fg=$color")
}

_slash_widget() {
  local row command
  local slash_status

  if [[ -n "$BUFFER" ]]; then
    zle self-insert
    return
  fi

  row="$(_slash_pick_command)" || {
    slash_status=$?
    if (( slash_status == 127 )); then
      zle -M "backslash-terminal: fzf is required for the slash palette"
    fi

    zle redisplay
    return
  }

  command="$(_slash_selected_command "$row")" || {
    zle redisplay
    return
  }

  BUFFER="$command"
  CURSOR=${#BUFFER}
  _slash_dim_command_line
  zle accept-line
}

if [[ -o zle ]]; then
  zle -N slash-widget _slash_widget
  bindkey '/' slash-widget
fi
