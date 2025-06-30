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
# - DEC_JSON_FILE: Path to the temporary decrypted plaintext JSON file.

# Loads plaintext JSON entries from DEC_JSON_FILE.
# This function assumes DEC_JSON_FILE is already decrypted and available.
# Returns:
#   Plaintext JSON content on stdout, or "[]" if file not found/empty or corrupted.
load_entries() {
  local json_content=""

  # Check if the temporary decrypted file exists
  if [[ ! -f "$DEC_JSON_FILE" ]]; then
    # This scenario should ideally not happen if main_loop handles initial decryption correctly.
    # However, it's a safe fallback to return an empty array.
    echo -e "${YELLOW}Warning: Decrypted data file '${DEC_JSON_FILE}' not found. Assuming no entries exist.${RESET}" >&2
    echo "[]"
    return 0
  fi

  # Read the content of the temporary file
  json_content=$(cat "$DEC_JSON_FILE")

  # Validate if content is valid JSON using jq.
  # jq -e . will exit with 0 if valid JSON, 1 if invalid.
  # We redirect stderr to /dev/null to suppress jq's error messages if content is bad.
  if echo "$json_content" | jq -e . &>/dev/null; then
    echo "$json_content"
    return 0
  else
    echo -e "${RED}🚫 Error: Temporary decrypted file '${DEC_JSON_FILE}' is corrupted or not valid JSON.${RESET}" >&2
    # For debugging, you could uncomment the next line to see the problematic content:
    # echo -e "${RED}Content received by jq: (start) ${json_content} (end)${RESET}" >&2
    echo "[]" # Return an empty array to prevent further jq errors in calling functions
    return 1 # Indicate an error occurred
  fi
}

# Saves plaintext JSON data to DEC_JSON_FILE.
# This function writes to the temporary decrypted file.
# Arguments:
#   $1: The JSON data to save.
# Returns:
#   Sets exit code to 1 on file write error.
save_entries() {
  local json_data="$1"
  printf "%s" "$json_data" > "$DEC_JSON_FILE"
  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Changes saved to temporary file.${RESET}"
  else
    echo -e "${RED}❌ Failed to write data to temporary file ${DEC_JSON_FILE}${RESET}" >&2
    return 1
  fi
}
