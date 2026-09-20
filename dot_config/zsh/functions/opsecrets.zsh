# 1Password → environment. Tag items "terminal" in 1Password; the title becomes the variable name.
# Usage: opsecrets        (verbose)   |   opsecrets -q   (quiet, used at shell start)

opsecrets() {
  local quiet=false
  [[ "$1" == "-q" || "$1" == "--quiet" ]] && quiet=true

  if ! command -v op &> /dev/null; then
    $quiet || echo "1Password CLI (op) not installed"
    return 1
  fi
  if ! command -v jq &> /dev/null; then
    $quiet || echo "jq not installed"
    return 1
  fi

  $quiet || echo "Loading secrets from 1Password (tag: terminal)..."

  # Get all items with the "terminal" tag
  local items
  items=$(op item list --tags terminal --format json 2>/dev/null)

  if [[ $? -ne 0 ]]; then
    $quiet || echo "Failed to fetch items. Run 'op signin' first."
    return 1
  fi

  if [[ "$items" == "[]" || -z "$items" ]]; then
    $quiet || echo "No items found with tag 'terminal'"
    return 0
  fi

  # Process each item
  local count=0
  while IFS= read -r item_id; do
    local item_json
    item_json=$(op item get "$item_id" --format json 2>/dev/null) || continue
    [[ -n "$item_json" ]] || continue

    local title
    title=$(jq -r '.title // empty' <<<"$item_json")

    # Convert title to valid env var name (uppercase, replace spaces/dashes with underscore)
    local var_name
    var_name=$(echo "$title" | tr '[:lower:]' '[:upper:]' | tr ' -' '_' | tr -cd '[:alnum:]_')
    # must be a valid shell identifier (non-empty, not starting with a digit) or `export` is fatal
    [[ "$var_name" == [A-Za-z_]* ]] || { $quiet || echo "  Skipped (bad name): $title"; continue; }

    # Get the password or credential field
    local secret
    secret=$(echo "$item_json" | jq -r '.fields[]? | select(.purpose == "PASSWORD" or .id == "password" or .id == "credential" or .label == "password" or .label == "credential" or .label == "secret" or .label == "api_key" or .label == "apikey" or .label == "token") | .value' | head -1)

    if [[ -n "$secret" && "$secret" != "null" ]]; then
      export "$var_name"="$secret"
      [[ -n "$OPSECRETS_OUT" ]] && printf 'export %s=%q\n' "$var_name" "$secret" >> "$OPSECRETS_OUT"
      $quiet || echo "  Exported: $var_name"
      ((count++))
    fi
  done < <(echo "$items" | jq -r '.[].id')

  $quiet || echo "Loaded $count secret(s)"
}

# ---------------------------------------------------------------------------
# Cached loading. `op` is slow and each call can prompt for Touch ID, so shells
# source a cache file and refresh it in the background when it is older than
# OPSECRETS_TTL_HOURS. Only one refresh runs at a time (mkdir lock), and after a
# failed or in-progress attempt no shell retries for OPSECRETS_RETRY_MINUTES.
# Files live in a 700 dir under ~/.cache/zsh. Force a refresh: opsecrets-refresh
# ---------------------------------------------------------------------------
OPSECRETS_CACHE="${OPSECRETS_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh/opsecrets.env}"
OPSECRETS_TTL_HOURS=${OPSECRETS_TTL_HOURS:-12}
OPSECRETS_RETRY_MINUTES=${OPSECRETS_RETRY_MINUTES:-10}

opsecrets-refresh() {
  local dir="${OPSECRETS_CACHE:h}" lock="$OPSECRETS_CACHE.lock" stamp="$OPSECRETS_CACHE.attempt"
  command mkdir -p -m 700 "$dir"

  # Single-flight: the lock is a directory because mkdir is atomic. A lock older than
  # 10 minutes is treated as abandoned (e.g. Ctrl-C mid-refresh) and reclaimed.
  if ! command mkdir "$lock" 2>/dev/null; then
    local abandoned=( "$lock"(N/mm+10) )
    (( $#abandoned )) || return 1
    command rmdir "$lock" 2>/dev/null
    command mkdir "$lock" 2>/dev/null || return 1
  fi
  : > "$stamp"   # "last attempted", read by opsecrets-load for back-off

  # No EXIT trap here: zsh runs a function's EXIT trap after its locals are gone,
  # so cleanup is explicit. mktemp creates the file 600 before any secret is written.
  local tmp rc=1
  if tmp=$(command mktemp "$OPSECRETS_CACHE.XXXXXX"); then
    if OPSECRETS_OUT="$tmp" opsecrets -q &>/dev/null && [[ -s "$tmp" ]]; then
      command mv -f "$tmp" "$OPSECRETS_CACHE" && rc=0
    fi
    command rm -f "$tmp"          # no-op after a successful mv; removes a half-written file otherwise
  fi
  command rmdir "$lock" 2>/dev/null
  return $rc
}

opsecrets-load() {
  [[ -r "$OPSECRETS_CACHE" ]] && source "$OPSECRETS_CACHE"
  local fresh=( "$OPSECRETS_CACHE"(N.mh-$OPSECRETS_TTL_HOURS) )
  (( $#fresh )) && return 0
  local tried=( "$OPSECRETS_CACHE.attempt"(N.mm-$OPSECRETS_RETRY_MINUTES) )
  (( $#tried )) && return 0
  ( opsecrets-refresh &>/dev/null & )
  return 0
}
