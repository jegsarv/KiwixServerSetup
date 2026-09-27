#!/usr/bin/env bash
# Download / refresh the ZIM files listed in zims.conf, delete older versions,
# and restart the Kiwix container.
#
#   sudo ./update-zims.sh             download or refresh everything in zims.conf
#   ./update-zims.sh --search WORD    list files in a download folder (e.g. devdocs)
#   ./update-zims.sh --dry-run        show what would be downloaded, change nothing
set -euo pipefail

BASE_URL="https://download.kiwix.org/zim"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${ZIMS_CONF:-$SCRIPT_DIR/zims.conf}"
ZIM_DIR="${ZIM_DIR:-/srv/kiwix/zim}"
DRY_RUN=0

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }

# Print the file names in one download.kiwix.org folder, oldest to newest.
list_folder() {
  curl -fsSL "$BASE_URL/$1/" \
    | grep -oE 'href="[^"/]+\.zim"' \
    | sed -E 's/^href="//; s/"$//' \
    | sort -uV
}

# Newest "<prefix>_YYYY-MM.zim" in a folder (empty if none).
latest_for() {
  local folder="$1" prefix="$2"
  list_folder "$folder" | grep -E "^${prefix}_[0-9]{4}-[0-9]{2}\.zim$" | tail -n 1 || true
}

if [[ "${1:-}" == "--search" ]]; then
  word="${2:?usage: $0 --search <folder-or-word>}"
  if list_folder "$word" 2>/dev/null; then exit 0; fi
  echo "No folder named '$word'. Folders available:"
  curl -fsSL "$BASE_URL/" | grep -oE 'href="[a-z_-]+/"' | sed -E 's/href="//; s/\/"//' | grep -i "$word" || true
  exit 0
fi
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

if [[ $DRY_RUN -eq 0 && $EUID -ne 0 ]]; then
  echo "Run with sudo (it writes to $ZIM_DIR and restarts Docker)." >&2
  exit 1
fi
[[ -f "$CONF" ]] || { echo "Missing $CONF" >&2; exit 1; }
mkdir -p "$ZIM_DIR"

changed=0
while read -r folder prefix _; do
  [[ -z "${folder:-}" || "$folder" == \#* || -z "${prefix:-}" || "$prefix" == \<* ]] && continue

  file="$(latest_for "$folder" "$prefix")"
  if [[ -z "$file" ]]; then
    warn "No file matching '${prefix}_YYYY-MM.zim' in $folder/  (try: $0 --search $folder)"
    continue
  fi

  if [[ -f "$ZIM_DIR/$file" ]]; then
    log "Up to date: $file"
  elif [[ $DRY_RUN -eq 1 ]]; then
    log "Would download: $folder/$file"
    continue
  else
    log "Downloading $folder/$file"
    wget -c -q --show-progress -O "$ZIM_DIR/$file.part" "$BASE_URL/$folder/$file"

    # Verify the checksum when Kiwix publishes one.
    if sum="$(curl -fsSL "$BASE_URL/$folder/$file.sha256" 2>/dev/null | awk '{print $1}')" && [[ -n "$sum" ]]; then
      echo "$sum  $ZIM_DIR/$file.part" | sha256sum -c --quiet \
        || { warn "Checksum failed for $file; removing it."; rm -f "$ZIM_DIR/$file.part"; continue; }
    fi
    mv "$ZIM_DIR/$file.part" "$ZIM_DIR/$file"
    changed=1
  fi

  # Remove older dated versions of the same prefix.
  for old in "$ZIM_DIR/${prefix}"_[0-9][0-9][0-9][0-9]-[0-9][0-9].zim; do
    [[ -e "$old" && "$(basename "$old")" != "$file" ]] || continue
    log "Removing old version: $(basename "$old")"
    rm -f "$old"
    changed=1
  done
done < "$CONF"

[[ $DRY_RUN -eq 1 ]] && exit 0

if [[ $changed -eq 1 ]]; then
  log "Restarting Kiwix so it picks up the changes"
  docker restart kiwix >/dev/null 2>&1 || (cd "$SCRIPT_DIR" && docker compose up -d)
else
  log "Nothing changed."
fi
log "Library now holds:"
ls -lh "$ZIM_DIR"/*.zim 2>/dev/null | awk '{print "    " $5 "  " $9}' || true