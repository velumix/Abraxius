#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tauri_dir="$repo_dir/app/Abraxius.Linux/src-tauri"
# rustup installations are commonly not on PATH in desktop launchers or npm shells.
if ! command -v cargo >/dev/null 2>&1 && [ -f "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi
if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo is required to build Abraxius Tauri" >&2
  exit 1
fi
cargo build --release --manifest-path "$tauri_dir/Cargo.toml"
desktop_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
bin_path="$bin_dir/abraxius"
mkdir -p "$bin_dir"
install -m 755 "$tauri_dir/target/release/abraxius-linux" "$bin_path"
mkdir -p "$desktop_dir"
sed -e "s|@REPO@|$repo_dir|g" -e "s|@BIN@|$bin_path|g" "$repo_dir/app/Abraxius.Linux/abraxius.desktop.in" > "$desktop_dir/abraxius.desktop"
chmod 644 "$desktop_dir/abraxius.desktop"
if [ -d "$HOME/Desktop" ]; then
  install -m 755 "$desktop_dir/abraxius.desktop" "$HOME/Desktop/Abraxius.desktop"
  if command -v gio >/dev/null 2>&1; then
    gio set "$HOME/Desktop/Abraxius.desktop" metadata::trusted true 2>/dev/null || true
  fi
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
fi
echo "Installed Abraxius desktop entry at $desktop_dir/abraxius.desktop"
echo "Tauri binary: $bin_path"
