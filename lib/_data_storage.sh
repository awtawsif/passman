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
# - _crypto.sh (for encrypt_data, decrypt_data)
# - _utils.sh (for pause, clear_screen, trim, get_master_password)
# Global variables from passman.sh that are used here:
# - CREDENTIALS_DATA: The in-memory decrypted plaintext JSON data.
# - ENC_JSON_FILE: Path to the securely encrypted file (read-only here, updated in passman.sh).
# - MASTER_PASSWORD: The master password for encryption/decryption (read-only here).
# - IS_AUTHENTICATED: Flag to indicate if the session is authenticated.

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
  # Note: Actual encryption to disk happens on script exit via cleanup_on_exit trap.
}

# Reads and decrypts an encrypted file into CREDENTIALS_DATA.
# Arguments:
#   $1: Path to the encrypted file.
#   $2: The master password for decryption.
# Returns:
#   0 on success, 1 on failure.
# On success, updates the global CREDENTIALS_DATA.
read_encrypted_file() {
  local filepath="$1"
  local master_pass="$2"

  local decrypted_content
  # Redirect stderr of decrypt_data to /dev/null to suppress OpenSSL warnings/errors
  decrypted_content=$(decrypt_data "$filepath" "$master_pass" 2>/dev/null)
  local decrypt_status=$?

  if [[ "$decrypt_status" -ne 0 ]]; then
    echo -e "${RED}❌ Decryption failed for '${filepath}'. Incorrect password or corrupted file.${RESET}" >&2
    return 1
  fi

  if echo "$decrypted_content" | jq -e . &>/dev/null; then
    CREDENTIALS_DATA="$decrypted_content" # Update the global in-memory data
    return 0
  else
    echo -e "${RED}🚫 Error: Decrypted data from '${filepath}' is corrupted or not valid JSON. Unable to load.${RESET}" >&2
    CREDENTIALS_DATA="[]" # Reset in-memory data to empty array to prevent further errors
    return 1
  fi
}

# Encrypts CREDENTIALS_DATA and writes it to a file.
# Arguments:
#   $1: Path to the output encrypted file.
#   $2: The master password for encryption.
# Returns:
#   0 on success, 1 on failure.
write_encrypted_file() {
  local filepath="$1"
  local master_pass="$2"

  local temp_encrypted_file
  temp_encrypted_file=$(mktemp)

  if encrypt_data "$CREDENTIALS_DATA" "$master_pass" "$temp_encrypted_file"; then
    mv "$temp_encrypted_file" "$filepath"
    if [[ $? -eq 0 ]]; then
      return 0
    else
      echo -e "${RED}❌ Failed to move encrypted data to final file '${filepath}'. Check permissions.${RESET}" >&2
      rm -f "$temp_encrypted_file"
      return 1
    fi
  else
    echo -e "${RED}❌ Failed to encrypt data for '${filepath}'.${RESET}" >&2
    rm -f "$temp_encrypted_file"
    return 1
  fi
}

# Prompts the user to load an external encrypted credentials file.
# On success, updates global ENC_JSON_FILE, MASTER_PASSWORD, and CREDENTIALS_DATA.
# Returns:
#   0 on success, 1 on cancellation or failure.
load_external_credentials() {
  clear_screen
  echo -e "${BOLD}${MAGENTA}--- Load External Credentials File ---${RESET}"
  echo -e "${CYAN}💡 Enter the full path to the encrypted file you wish to load.${RESET}"
  echo -e "${CYAN}Type '${BOLD}C${RESET}${CYAN}' to cancel.${RESET}\n"

  local external_file_path
  while true; do
    read -rp "$(printf "${YELLOW}📁 Enter path to encrypted file: ${RESET}") " external_file_path_input
    external_file_path=$(trim "$external_file_path_input")
    echo "" # Extra space

    local lower_input
    lower_input=$(echo "$external_file_path" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "${CYAN}Operation cancelled. Returning to main menu.${RESET}"
      pause
      return 1 # Indicate cancellation
    fi

    if [[ -f "$external_file_path" ]]; then
      break
    else
      echo -e "${RED}❌ File not found at '${BOLD}$external_file_path${RESET}${RED}'. Please enter a valid path or type '${CYAN}C${RED}' to cancel.${RESET}"
      echo "" # Extra space
    fi
  done

  local external_file_master_pass
  # Prompt for the master password specific to the external file
  get_master_password "🔑 Enter master password for '${external_file_path}': " external_file_master_pass "false"

  if [[ -z "$external_file_master_pass" ]]; then
    echo -e "${RED}🚫 Master password not provided. Aborting load.${RESET}"
    pause
    return 1
  fi

  echo -e "${CYAN}Attempting to decrypt and load credentials from ${BOLD}${external_file_path}${RESET}${CYAN}...${RESET}"
  if read_encrypted_file "$external_file_path" "$external_file_master_pass"; then
    # If successful, update the global variables
    ENC_JSON_FILE="$external_file_path"
    MASTER_PASSWORD="$external_file_master_pass"
    IS_AUTHENTICATED="true" # Mark as authenticated with the new file
    echo -e "${GREEN}✅ Credentials from ${BOLD}${external_file_path}${RESET}${GREEN} loaded successfully!${RESET}"
    pause
    return 0
  else
    echo -e "${RED}❌ Failed to load external credentials. Please check the password and file integrity.${RESET}"
    pause
    return 1
  fi
}
