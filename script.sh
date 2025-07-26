#!/usr/bin/env bash
set -euo pipefail

# ============================
# Options
# ============================
NEW_KEY="bb-HCM-TIME"
REPLACE_R7=false

# Parse args
for arg in "$@"; do
  case "$arg" in
    --replace-r7) REPLACE_R7=true ;;
    --key=*)      NEW_KEY="${arg#--key=}" ;;
    -k=*)         NEW_KEY="${arg#-k=}" ;;
    --help|-h)
      cat <<'HELP'
Usage:
  ./update_key.sh [--key=NEW_KEY] [--replace-r7]

Defaults:
  NEW_KEY = bb-HCM-TIME

Flags:
  --replace-r7   Also replace any "r7:*" keys to NEW_KEY (more aggressive)

What it does:
  1) Update default key in ./utils/TimeUtils.mqh to NEW_KEY
  2) Replace common old keys across project with NEW_KEY:
     - "lastRunYMD_7H_BIASBOT"
     - "lastRunYMD_7H"
     - "lastRunYMD_HCM_0700_BIASBOT"
     - "lastRunYMD_HCM_0700"
  3) (optional) If --replace-r7, replace any string literal starting with "r7:".

Backups:
  - Creates .bak files next to modified sources.
HELP
      exit 0
      ;;
    *)
      # If only one bare arg is provided, treat as key
      if [[ $# -eq 1 ]]; then
        NEW_KEY="$arg"
      else
        echo "Unknown arg: $arg (use --help)" >&2
        exit 1
      fi
      ;;
  esac
done

echo "🔧 Updating run key to: \"$NEW_KEY\""
[[ "$REPLACE_R7" == true ]] && echo "⚠️  --replace-r7 enabled (will rewrite any \"r7:*\" keys)."

ROOT="$(pwd)"
UTILS_FILE="$ROOT/utils/TimeUtils.mqh"

# Detect sed flavor (GNU vs BSD)
SED_INPLACE=()
if sed --version >/dev/null 2>&1; then
  # GNU sed
  SED_INPLACE=(-i)
else
  # BSD/macOS sed requires a suffix (use .bak; we'll keep our own backups anyway)
  SED_INPLACE=(-i '')
fi

# ============================
# 1) Update default key in TimeUtils.mqh
# ============================
if [[ -f "$UTILS_FILE" ]]; then
  cp "$UTILS_FILE" "$UTILS_FILE.bak"

  # Replace default parameter values: key = "...."
  # Target our functions' signatures and alias defaults
  sed "${SED_INPLACE[@]}" -E \
    -e 's/(isRun7HOncePersist\([^,]*,\s*const string key\s*=\s*")[^"]*("\))/\1'"$NEW_KEY"'\2/' \
    -e 's/(isRun7HOnceCatchup\([^,]*,[^,]*,\s*const string key\s*=\s*")[^"]*("\))/\1'"$NEW_KEY"'\2/' \
    -e 's/(ShouldRunAt0700HCMOncePersist\([^,]*,\s*const string key\s*=\s*")[^"]*("\))/\1'"$NEW_KEY"'\2/' \
    -e 's/(isRunAt0700HCMOncePersist\([^,]*,\s*const string key\s*=\s*")[^"]*("\))/\1'"$NEW_KEY"'\2/' \
    "$UTILS_FILE"

  echo "✅ Updated defaults in: $UTILS_FILE (backup: $UTILS_FILE.bak)"
else
  echo "ℹ️  $UTILS_FILE not found. Skipping default-key update."
fi

# ============================
# 2) Replace common old keys across the project
# ============================
shopt -s globstar nullglob
FILES=( **/*.mqh **/*.mq5 **/*.mql5 **/*.mq4 **/*.mql4 )
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "ℹ️  No MQL files found. Done."
  exit 0
fi

for f in "${FILES[@]}"; do
  [[ -f "$f" ]] || continue
  # Skip backups
  [[ "$f" == *.bak ]] && continue

  cp "$f" "$f.bak"

  # Replace known sample keys
  sed "${SED_INPLACE[@]}" -E \
    -e 's/"lastRunYMD_7H_BIASBOT"/"'"$NEW_KEY"'"/g' \
    -e 's/"lastRunYMD_7H"/"'"$NEW_KEY"'"/g' \
    -e 's/"lastRunYMD_HCM_0700_BIASBOT"/"'"$NEW_KEY"'"/g' \
    -e 's/"lastRunYMD_HCM_0700"/"'"$NEW_KEY"'"/g' \
    "$f"

  # Optional: replace any r7:* string literal
  if [[ "$REPLACE_R7" == true ]]; then
    sed "${SED_INPLACE[@]}" -E \
      -e 's/"r7:[^"]*"/"'"$NEW_KEY"'"/g' \
      "$f"
  fi
done

echo "✅ Replaced old keys in ${#FILES[@]} files (backups: *.bak)"
echo "🎯 Done. New run key = \"$NEW_KEY\""
