#!/bin/bash
# _data_storage.sh
# Handles loading and saving of JSON credential data.
# Sourced by passman.sh.

# --- Strict Mode for Robustness ---
set -e
set -u
set -o pipefail

# Dependencies:
# - _colors.sh (for color variables like RED, YELLOW, RESET)
# Global variables from passman.sh that are used here:
# - CREDENTIALS_DATA: The in-memory decrypted plaintext JSON data.

# Loads plaintext JSON entries from CREDENTIALS_DATA.
# Returns:
#   Plaintext JSON content on stdout.
load_entries() {
  local json_content="$CREDENTIALS_DATA"

  # Validate if content is valid JSON using jq.
  # jq -e . will exit with 0 if valid JSON, 1 if invalid.
  # We redirect stderr to /dev/null to suppress jq's error messages if content is bad.
  if echo "$json_content" | jq -e . &>/dev/null; then
    echo "$json_content"
    return 0
  else
    echo -e "${RED}🚫 Error: In-memory data is corrupted or not valid JSON. Unable to load entries.${RESET}" >&2
    echo "[]" # Return an empty array to prevent further jq errors in calling functions
    return 1 # Indicate an error occurred
  fi
}

# Saves plaintext JSON data to CREDENTIALS_DATA.
# This function updates the in-memory decrypted data.
# Arguments:
#   $1: The JSON data to save.
save_entries() {
  CREDENTIALS_DATA="$1"
  echo -e "${GREEN}✅ Changes saved to in-memory data.${RESET}"
}
