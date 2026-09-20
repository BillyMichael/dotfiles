# 1Password → environment. Tag items "terminal" in 1Password; the title becomes the variable name.
# Usage: opsecrets        (verbose)   |   opsecrets -q   (quiet, used at shell start)

opsecrets() {
  local quiet=false
  [[ "$1" == "-q" || "$1" == "--quiet" ]] && quiet=true

  if ! command -v op &> /dev/null; then
    $quiet || echo "1Password CLI (op) not installed"
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
    item_json=$(op item get "$item_id" --format json 2>/dev/null)

    local title
    title=$(echo "$item_json" | op read --no-newline "op://$(echo "$item_json" | jq -r '.vault.name')/$(echo "$item_json" | jq -r '.title')/title" 2>/dev/null || echo "$item_json" | jq -r '.title')

    # Convert title to valid env var name (uppercase, replace spaces/dashes with underscore)
    local var_name
    var_name=$(echo "$title" | tr '[:lower:]' '[:upper:]' | tr ' -' '_' | tr -cd '[:alnum:]_')

    # Get the password or credential field
    local secret
    secret=$(echo "$item_json" | jq -r '.fields[]? | select(.purpose == "PASSWORD" or .id == "password" or .id == "credential" or .label == "password" or .label == "credential" or .label == "secret" or .label == "api_key" or .label == "apikey" or .label == "token") | .value' | head -1)

    if [[ -n "$secret" && "$secret" != "null" ]]; then
      export "$var_name"="$secret"
      $quiet || echo "  Exported: $var_name"
      ((count++))
    fi
  done < <(echo "$items" | jq -r '.[].id')

  $quiet || echo "Loaded $count secret(s)"
}
