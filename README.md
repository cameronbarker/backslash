# backslash-terminal

A zsh slash-command palette for your terminal, powered by `fzf`.

Press `/` on an empty zsh prompt to open a searchable list of commands. Pick one, answer any argument prompts, and the command is submitted to zsh. If the prompt already contains text, `/` behaves normally, so paths like `cd /usr/local` still work.

Selected slash commands dim the submitted command line before their output. The command still runs normally:

```text
$ echo hello
hello
```

## Features

- zsh-native `/` key binding through ZLE
- `fzf` command palette
- global and project-local command files
- YAML command definitions
- `global` / `project` source labels in the picker
- named argument prompts with `{placeholder}` syntax
- optional confirmation for risky commands
- dimmed selected command line before command output
- no GPT, network service, daemon, or terminal wrapper

## Requirements

- zsh
- fzf

Install `fzf` with Homebrew:

```sh
brew install fzf
```

## Installation

Source the plugin from your `.zshrc`:

```sh
source /path/to/backslash-terminal/slash.zsh
```

Open a new zsh session after editing `.zshrc`.

## Quick Start

Create a global command file:

```sh
mkdir -p ~/.config/backslash-terminal
cp /path/to/backslash-terminal/commands.example.yaml ~/.config/backslash-terminal/commands.yaml
```

Then press `/` on an empty prompt.

The picker shows each command's source, name, description, and hints. The preview window shows the shell command that will run.

## Command Files

Commands are loaded from two places:

1. Global commands: `${SLASH_COMMANDS_FILE:-$HOME/.config/backslash-terminal/commands.yaml}`
2. Project commands: the nearest `.slash-commands.yaml` found by walking upward from the current directory

Project commands appear before global commands. Duplicate names are allowed and appear as separate choices.

Add project-local commands by creating `.slash-commands.yaml` in a project directory:

```yaml
commands:
  - name: hello
    description: Print a project-local test message
    command: echo "hello from this project"

  - name: shell-source
    description: Print the current shell source
    command: echo "SHELL=$SHELL; process=$(ps -p $$ -o comm=); zsh=${ZSH_VERSION:-not-zsh}; bash=${BASH_VERSION:-not-bash}"
```

These commands are available from that directory and its child directories.

Command files use a small dependency-free YAML subset:

```yaml
commands:
  - name: status
    description: Show git status
    command: git status

  - name: clean
    description: Remove build output
    command: rm -rf dist
    flags:
      - confirm
```

Blank lines and comments are ignored. The `flags` field is optional.

The parser supports one top-level `commands:` list, command entries with `name`, `description`, and `command`, plus optional `flags`. Flags may be written as a block list or an inline list:

```yaml
commands:
  - name: clean
    description: Remove build output
    command: rm -rf dist
    flags: [confirm]
```

## Arguments

Use `{name}` placeholders in a command to prompt for values before execution:

```yaml
commands:
  - name: checkout
    description: Check out a git branch
    command: git checkout {branch}

  - name: compare
    description: Compare two git refs
    command: git diff {base}..{head}
```

Repeated placeholders prompt once and reuse the same value:

```yaml
commands:
  - name: copy
    description: Copy a branch
    command: git branch {branch}-copy {branch}
```

If any placeholder answer is empty, the command is cancelled and you return to the prompt. Literal braces are not supported yet; any token shaped like `{name}` is treated as a prompt.

## Safety

Commands run immediately after selection. Mark commands that deserve a second look with the `confirm` flag:

```yaml
commands:
  - name: clean
    description: Remove build output
    command: rm -rf dist
    flags:
      - confirm
```

Confirmed commands run only when you type `y` or `Y`.

For commands with both placeholders and `confirm`, argument prompts happen first. The confirmation prompt shows the resolved command.

## Configuration

- `SLASH_COMMANDS_FILE`: global command file path
- `SLASH_PROJECT_COMMANDS_FILE`: project-local filename, default `.slash-commands.yaml`
- `SLASH_FZF_HEIGHT`: picker height, default `40%`
- `SLASH_FZF_PREVIEW`: preview window setting, default `down:4:wrap`
- `SLASH_DIM_COMMAND_LINE`: dim the selected command line before command output, default `1`
- `SLASH_RUN_LINE_COLOR`: zsh highlight color for the selected command line, default `244`

Example:

```sh
export SLASH_COMMANDS_FILE="$HOME/.slash-commands.yaml"
export SLASH_FZF_HEIGHT="60%"
export SLASH_DIM_COMMAND_LINE=0
source /path/to/backslash-terminal/slash.zsh
```

## Testing

Run the test suite:

```sh
zsh test/run
```

The tests cover command loading, source labels, picker hints, placeholders, confirmation, and widget behavior.

## Current Limitations

- zsh only
- requires `fzf`
- command files must use the documented YAML subset
- full YAML features like anchors, multiline strings, nested objects, and multi-document files are not supported
- placeholder values are inserted as typed
- literal brace escaping is not supported
- there is no installer yet; source the plugin manually
