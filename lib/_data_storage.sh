#!/bin/bash
# _data_storage.sh
# Handles loading and saving of JSON credential data.
# Sourced by passman.sh.

# --- Strict Mode for Robustness ---
set -e
set -u
set -o pipefail

# Dependencies:
# - _colors.sh (for color variables like NEON_RED, ELECTRIC_YELLOW, RESET)
# - _crypto.sh (for encrypt_data, decrypt_data)
# - _utils.sh (for pause, clear_screen, trim, get_master_password)
# - _config.sh (for update_save_location_in_config)
# - _prompts.sh (for user-facing prompts)
# Global variables from passman.sh that are used here:
# - CREDENTIALS_DATA: The in-memory decrypted plaintext JSON data.
# - ENC_JSON_FILE: Path to the securely encrypted file (read-only here, updated in passman.sh).
# - MASTER_PASSWORD: The master password for encryption/decryption (read-only here).
# - IS_AUTHENTICATED: Flag to indicate if the session is authenticated.

# Source prompt definitions
source "${LIB_DIR}/_prompts.sh"

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
    echo -e "${NEON_RED}🚫 Error: In-memory data is corrupted or not valid JSON. Unable to load entries.${RESET}" >&2
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
  echo -e "${LIME_GREEN}✅ Changes saved to in-memory data.${RESET}"
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
    echo -e "${NEON_RED}❌ Decryption failed for '${filepath}'. Incorrect password or corrupted file.${RESET}" >&2
    return 1
  fi

  if echo "$decrypted_content" | jq -e . &>/dev/null; then
    CREDENTIALS_DATA="$decrypted_content" # Update the global in-memory data
    return 0
  else
    echo -e "${NEON_RED}🚫 Error: Decrypted data from '${filepath}' is corrupted or not valid JSON. Unable to load.${RESET}" >&2
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
      echo -e "${NEON_RED}❌ Failed to move encrypted data to final file '${filepath}'. Check permissions.${RESET}" >&2
      rm -f "$temp_encrypted_file"
      return 1
    fi
  else
    echo -e "${NEON_RED}❌ Failed to encrypt data for '${filepath}'.${RESET}" >&2
    rm -f "$temp_encrypted_file"
    return 1
  fi
}

# Prompts the user to load an external encrypted credentials file from a directory.
# If the file doesn't exist in the directory, it offers to create it.
# On success, updates global ENC_JSON_FILE, MASTER_PASSWORD, and CREDENTIALS_DATA.
# Returns:
#   0 on success, 1 on cancellation or failure.
load_external_credentials() {
  clear_screen
  echo -e "$PROMPT_LOAD_EXTERNAL_TITLE"
  echo -e "$PROMPT_LOAD_EXTERNAL_DIR_HINT"
  echo -e "$PROMPT_LOAD_EXTERNAL_CANCEL_HINT"

  local external_dir_path_input
  local external_dir_path
  while true; do
    read -rp "$(printf "$PROMPT_ENTER_DIR_PATH_WITH_PWD" "$(pwd)")" external_dir_path_input
    external_dir_path_input=$(trim "$external_dir_path_input")
    echo "" # Extra space

    local lower_input
    lower_input=$(echo "$external_dir_path_input" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
      pause
      return 1 # Indicate cancellation
    fi

    # Resolve the path to an absolute path. Handles `.` `..` and `~`
    # The `-m` flag ensures that it doesn't fail if the path doesn't exist yet.
    external_dir_path=$(realpath -m -- "$external_dir_path_input")

    # Now check if the resolved path is a directory
    # We use the input path for the check to give a more intuitive error message
    if [[ -d "$external_dir_path_input" ]]; then
      break
    else
      # If it's not a directory, maybe the user wants to create it.
      # For now, we require an existing directory.
      printf "${ERROR_DIR_NOT_FOUND}\n" "$external_dir_path_input"
      echo "" # Extra space
    fi
  done

  local external_file_path="${external_dir_path}/${DEFAULT_ENC_FILENAME}"
  local session_master_password=""
  local success="false"

  if [[ -f "$external_file_path" ]]; then
    # --- Handle Existing File ---
    local external_file_master_pass
    get_master_password "$(printf "$PROMPT_ENTER_EXTERNAL_FILE_MASTER_PASS" "$external_file_path")" external_file_master_pass "false"

    if [[ -z "$external_file_master_pass" ]]; then
      echo -e "$ERROR_EXTERNAL_MASTER_PASSWORD_NOT_PROVIDED"
      pause
      return 1
    fi

    printf "${INFO_ATTEMPTING_DECRYPT_EXTERNAL}\n" "$external_file_path"
    if read_encrypted_file "$external_file_path" "$external_file_master_pass"; then
      printf "${SUCCESS_EXTERNAL_FILE_LOADED}\n" "$external_file_path"
      session_master_password="$external_file_master_pass"
      success="true"
    else
      echo -e "$ERROR_FAILED_LOAD_EXTERNAL_CREDENTIALS"
      pause
      return 1
    fi
  else
    # --- Handle New File ---
    printf "${WARNING_FILE_NOT_FOUND_IN_DIR}\n" "$external_file_path"
    echo -e "$INFO_CREATING_NEW_FILE"
    echo -e "$WARNING_NO_RECOVERY"

    get_master_password "$PROMPT_SET_NEW_FILE_MASTER_PASSWORD" session_master_password "true" # Prompt for confirmation

    if [[ -z "$session_master_password" ]]; then
      echo -e "$ERROR_MASTER_PASSWORD_NOT_SET_EXIT" # Reusing existing prompt
      pause
      return 1
    fi

    CREDENTIALS_DATA="[]"
    printf "${SUCCESS_NEW_FILE_INITIALIZED}\n" "$external_file_path"
    success="true"
  fi

  if [[ "$success" == "true" ]]; then
    # --- Ask to make permanent (common logic for new and existing files) ---
    local make_permanent_choice="n" # Default to no
    while true; do
      read -rp "$(printf "$PROMPT_MAKE_EXTERNAL_FILE_DEFAULT")" make_permanent_input
      make_permanent_input=$(trim "${make_permanent_input:-n}") # Default to 'n' (temporary)
      echo "" # Extra space
      local lower_input=$(echo "$make_permanent_input" | tr '[:upper:]' '[:lower:]')

      if [[ "$lower_input" == "c" ]]; then
        make_permanent_choice="n" # Treat cancel as temporary
        break
      fi
      if [[ "$make_permanent_input" =~ ^[yYnN]$ ]]; then
        make_permanent_choice=$(echo "$make_permanent_input" | tr '[:upper:]' '[:lower:]')
        break
      fi
      echo -e "$ERROR_INVALID_YES_NO_INPUT_EXTERNAL"
      echo "" # Extra space
    done

    if [[ "$make_permanent_choice" == "y" ]]; then
      update_save_location_in_config "$external_dir_path"
      echo -e "$SUCCESS_EXTERNAL_FILE_SET_DEFAULT"
    else
      echo -e "$INFO_EXTERNAL_FILE_LOADED_TEMPORARILY"
    fi

    # --- Update global state for the new session ---
    ENC_JSON_FILE="$external_file_path"
    MASTER_PASSWORD="$session_master_password"
    IS_AUTHENTICATED="true"
    pause
    return 0
  else
    # This case should not be hit with the current logic, but is a safeguard.
    return 1
  fi
}
