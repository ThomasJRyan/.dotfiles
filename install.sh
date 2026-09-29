#!/usr/bin/env bash

set -Eeuo pipefail

DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DRY_RUN=0
ASSUME_YES=0
BACKUP_ROOT="${HOME}/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

usage() {
  cat <<'EOF'
Usage: ./install.sh [--dry-run] [--yes]

Interactively link the selected configurations into their standard locations.
Existing files are moved to a timestamped backup before they are replaced.

Options:
  --dry-run  Show intended changes without modifying files.
  --yes      Select every app and approve replacement prompts (backups are still made).
  -h, --help Show this help.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --yes) ASSUME_YES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; usage >&2; exit 2 ;;
  esac
done

say() { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }

ask_yes_no() {
  local prompt="$1" answer
  if (( ASSUME_YES )); then return 0; fi
  while true; do
    read -r -p "$prompt [y/N] " answer || return 1
    case "$answer" in
      y|Y|yes|YES) return 0 ;;
      n|N|no|NO|'') return 1 ;;
      *) printf 'Please answer y or n.\n' ;;
    esac
  done
}

choose_app() {
  local name="$1" default="$2" answer
  if (( ASSUME_YES )); then [[ "$default" == y ]]; return; fi
  while true; do
    read -r -p "Configure $name? [y/n] (default $default): " answer || return 1
    answer="${answer:-$default}"
    case "$answer" in
      y|Y|yes|YES) return 0 ;;
      n|N|no|NO) return 1 ;;
      *) printf 'Please answer y or n.\n' ;;
    esac
  done
}

run() {
  if (( DRY_RUN )); then
    printf '    [dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

backup_path() {
  local target="$1" backup="$BACKUP_ROOT$1"
  if (( DRY_RUN )); then
    info "Would preserve existing path at $backup"
  else
    mkdir -p -- "$(dirname -- "$backup")"
    mv -- "$target" "$backup"
    info "Preserved existing path at $backup"
  fi
}

link_path() {
  local source="$1" target="$2" replace="$3" parent
  parent="$(dirname -- "$target")"
  if [[ ! -e "$source" ]]; then
    info "Source missing, skipping: $source"
    return 0
  fi

  if [[ -L "$target" ]]; then
    local current
    current="$(readlink -- "$target")"
    if [[ "$current" == "$source" ]]; then
      info "Already linked: $target"
      return 0
    fi
    info "Existing symlink: $target -> $current"
    if ! ask_yes_no "Replace this symlink?"; then
      info "Left unchanged: $target"
      return 0
    fi
    backup_path "$target"
  elif [[ -e "$target" ]]; then
    info "Existing $(if [[ -d "$target" ]]; then printf directory; else printf file; fi): $target"
    if (( ! replace )); then
      info "This path is not a managed config target; leaving it unchanged."
      return 0
    fi
    if ! ask_yes_no "Move it to backup and link the dotfiles version?"; then
      info "Left unchanged: $target"
      return 0
    fi
    backup_path "$target"
  fi

  run mkdir -p -- "$parent"
  run ln -s -- "$source" "$target"
}

check_tool() {
  local name="$1" command_name="$2"
  if command -v "$command_name" >/dev/null 2>&1; then
    info "$name detected: $(command -v "$command_name")"
  else
    info "$name not found on PATH; config can still be linked, but the app must be installed separately."
  fi
}

install_nvim() {
  say "Neovim"
  check_tool Neovim nvim
  check_tool Git git
  local target="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
  if [[ -d "$target" && ! -L "$target" ]]; then
    info "Existing directory contents will be merged file-by-file."
    while IFS= read -r -d '' file; do
      local relative="$file" destination
      relative="${relative#"$DOTFILES_DIR/nvim/"}"
      destination="$target/$relative"
      link_path "$file" "$destination" 1
    done < <(find "$DOTFILES_DIR/nvim" -type f -print0)
  else
    link_path "$DOTFILES_DIR/nvim" "$target" 1
  fi
  info "On first launch, LazyVim will bootstrap lazy.nvim and install plugins."
}

install_simple() {
  local app="$1" label="$2" source="$3" target="$4" tool="$5"
  say "$label"
  check_tool "$label" "$tool"
  link_path "$source" "$target" 1
}

install_codex() {
  local skill
  say "Codex"
  check_tool Codex codex
  link_path "$DOTFILES_DIR/codex/config.toml" "$HOME/.codex/config.toml" 1
  run chmod 600 "$DOTFILES_DIR/codex/config.toml"
  link_path "$DOTFILES_DIR/codex/hooks.json" "$HOME/.codex/hooks.json" 1
  link_path "$DOTFILES_DIR/codex/agents" "$HOME/.codex/agents" 1
  link_path "$DOTFILES_DIR/codex/hooks" "$HOME/.codex/hooks" 1
  link_path "$DOTFILES_DIR/codex/rules" "$HOME/.codex/rules" 1
  while IFS= read -r -d '' skill; do
    link_path "$skill" "$HOME/.codex/skills/$(basename -- "$skill")" 1
  done < <(find "$DOTFILES_DIR/codex/skills" -mindepth 1 -maxdepth 1 -type d ! -name .system -print0)
  info "Codex auth and local state are not touched."
}

install_opencode() {
  local root="${XDG_CONFIG_HOME:-$HOME/.config}/opencode" item
  say "OpenCode"
  check_tool OpenCode opencode
  for item in \
    opencode.jsonc oh-my-opencode-slim.json tui.json tui.jsonc herdr-tui-session.js package.json \
    agents commands plugins skills; do
    link_path "$DOTFILES_DIR/opencode/$item" "$root/$item" 1
  done
  info "Existing OpenCode package files, dependencies, install state, and credentials are left untouched."
  check_tool npm npm
  if [[ ! -d "$root/node_modules/@opencode-ai/plugin" ]]; then
    info "OpenCode plugin runtime dependency is missing; after reviewing package.json, run: npm install --prefix '$root'"
  fi
}

main() {
  if (( DRY_RUN )); then say "Dry run: no files will be changed"; fi
  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    printf 'Warning: %s does not appear to be a Git worktree.\n' "$DOTFILES_DIR" >&2
  fi

  if choose_app "Neovim" y; then
    install_nvim
  fi
  if choose_app "Zellij" y; then
    install_simple zellij Zellij "$DOTFILES_DIR/zellij/config.kdl" "${XDG_CONFIG_HOME:-$HOME/.config}/zellij/config.kdl" zellij
  fi
  if choose_app "Herdr" y; then
    install_simple herdr Herdr "$DOTFILES_DIR/herdr/config.toml" "${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml" herdr
  fi
  if choose_app "Herdr Neovim plugin" y; then
    install_simple herdr_nvim "Herdr Neovim plugin" "$DOTFILES_DIR/herdr-nvim/config.toml" "${XDG_CONFIG_HOME:-$HOME/.config}/herdr-nvim/config.toml" nvim
  fi
  if choose_app "Codex" y; then install_codex; fi
  if choose_app "OpenCode" y; then
    install_opencode
  fi

  say "Done"
  if (( DRY_RUN )); then
    info "No changes made. Rerun without --dry-run to apply."
  else
    info "Review any per-path skips above. Backups, if created, are under $BACKUP_ROOT"
    info "Restart the affected apps to load their configuration."
  fi
}

main "$@"
