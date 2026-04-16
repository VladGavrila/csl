#!/bin/sh
set -e
exec < /dev/tty

BASE_URL="https://raw.githubusercontent.com/VladGavrila/csl/main"
DEST="$HOME/.claude"

FILES="statusline-command.sh settings.json"

mkdir -p "$DEST"

for file in $FILES; do
  dest_file="$DEST/$file"
  if [ -f "$dest_file" ]; then
    printf "File %s already exists. Overwrite?(will create a backup) [y/N] " "$dest_file"
    read -r yn
    case "$yn" in
      [Yy]*)
        cp "$dest_file" "${dest_file}.bak"
        echo "  Backed up to ${dest_file}.bak"
        ;;
      *)
        echo "  Skipping $file"
        continue
        ;;
    esac
  fi
  echo "  Installing $file..."
  curl -fsSL -o "$dest_file" "$BASE_URL/$file"
done

chmod +x "$DEST/statusline-command.sh"
echo "Done."
