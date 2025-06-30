#!/bin/bash
# _crypto.sh
# Handles encryption, decryption, and secure cleanup on script exit.
# Sourced by passman.sh.

# --- Strict Mode for Robustness ---
set -e
set -u
set -o pipefail

# Dependencies:
# - _colors.sh (for color variables like RED, GREEN, YELLOW, CYAN, BOLD, RESET)
# - _utils.sh (for spinner, trim functions)
# Global variables from passman.sh that are used here:
# - ENC_JSON_FILE: Path to the securely encrypted file.
# - DEC_JSON_FILE: Path to the temporary decrypted plaintext JSON file.
# - MASTER_PASSWORD: The master password for encryption/decryption.
# - IS_AUTHENTICATED: Flag to determine if cleanup should encrypt and wipe.

# Encrypts data using openssl AES-256-CBC.
# Arguments:
#   $1: The plain text data to encrypt.
#   $2: The master password for encryption.
# Returns:
#   Encrypted data on stdout. Errors to stderr.
encrypt_data() {
  local data="$1"
  local master_pass="$2"
  printf "%s" "$data" | openssl enc -aes-256-cbc -salt -pass pass:"$master_pass"
  return $? # Return openssl's exit status
}

# Decrypts data from a file using openssl AES-256-CBC.
# Arguments:
#   $1: Path to the encrypted file.
#   $2: The master password for decryption.
# Returns:
#   Decrypted data on stdout if successful. Errors to stderr.
decrypt_data() {
  local encrypted_data_path="$1"
  local master_pass="$2"
  openssl enc -aes-256-cbc -d -salt -in "$encrypted_data_path" -pass pass:"$master_pass"
  return $? # Return openssl's exit status
}

# Cleanup function called on script exit.
# This function is critical for securely saving encrypted data and wiping
# the temporary plaintext file. It relies on global variables set in passman.sh.
cleanup_on_exit() {
  # Only attempt to encrypt and clean up if successfully authenticated.
  # This prevents encryption of an empty or invalid temp file if login failed.
  if [[ "$IS_AUTHENTICATED" == "true" && -f "$DEC_JSON_FILE" ]]; then
    echo -e "\n${BOLD}${CYAN}-----------------------------------------------------${RESET}"
    echo -e "${BOLD}${CYAN}   🔐 Securely saving and cleaning up...${RESET}"
    echo -e "${BOLD}${CYAN}-----------------------------------------------------${RESET}"

    local decrypted_content
    # Check if DEC_JSON_FILE exists and is readable before attempting to cat
    if [[ -f "$DEC_JSON_FILE" && -r "$DEC_JSON_FILE" ]]; then
      decrypted_content=$(cat "$DEC_JSON_FILE")
    else
      echo -e "${RED}❌ Warning: Temporary decrypted file '${DEC_JSON_FILE}' not found or not readable during cleanup. Cannot save data securely.${RESET}" >&2
      # Attempt to delete the possibly existing empty/corrupted temp file anyway.
      if [[ -f "$DEC_JSON_FILE" ]]; then
        rm -f "$DEC_JSON_FILE"
      fi
      # Skip encryption if content can't be read.
      # Proceed to final security reminder.
      echo -e "${YELLOW}Proceeding with final cleanup reminder.${RESET}"
      return 0
    fi
    
    local temp_encrypted_content=$(mktemp)
    local temp_openssl_stderr=$(mktemp) # Capture stderr for potential encryption errors

    # Run encryption in a subshell so we can monitor its PID with the spinner.
    (encrypt_data "$decrypted_content" "$MASTER_PASSWORD" > "$temp_encrypted_content" 2>"$temp_openssl_stderr") &
    local openssl_pid=$!
    spinner "$openssl_pid" "Encrypting data" # spinner from _utils.sh
    wait "$openssl_pid" # Wait for the background encryption process to finish
    local openssl_exit_status=$?

    if [[ "$openssl_exit_status" -ne 0 ]]; then
      if [[ -s "$temp_openssl_stderr" ]]; then # If stderr file has content
        cat "$temp_openssl_stderr" >&2 # Display openssl's error if encryption failed
      fi
      echo -e "${RED}❌ Error: Failed to encrypt data on exit. Your data might not be fully saved securely.${RESET}" >&2
      rm -f "$temp_encrypted_content" # Clean up temp encrypted file on failure
    else
      mv "$temp_encrypted_content" "$ENC_JSON_FILE"
      if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Credentials securely saved to ${BOLD}${ENC_JSON_FILE}${RESET}${GREEN}.${RESET}"
      else
        echo -e "${RED}❌ Failed to move encrypted data to final file. Check permissions.${RESET}" >&2
      fi
    fi
    rm -f "$temp_openssl_stderr" # Clean up stderr temp file

    # Securely wipe and delete the temporary plaintext file
    echo -e "${CYAN}Securely wiping temporary decrypted file...${RESET}"
    if command -v shred &> /dev/null; then
      shred -u "$DEC_JSON_FILE" # Securely wipe and then delete
      if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Temporary file securely deleted.${RESET}"
      else
        echo -e "${YELLOW}Warning: 'shred' failed. Attempting regular delete of temporary file.${RESET}" >&2
        rm -f "$DEC_JSON_FILE" # Fallback to regular delete
      fi
    else
      echo -e "${YELLOW}Warning: 'shred' not found. Deleting temporary file without secure wipe.${RESET}" >&2
      rm -f "$DEC_JSON_FILE"
    fi
  elif [[ -f "$DEC_JSON_FILE" ]]; then
      # If not authenticated but temp file exists (e.g., initial login failure or Ctrl+C before login),
      # just delete it without attempting encryption (as there's no valid master password or data).
      echo -e "${YELLOW}Deleting temporary decrypted file due to unauthenticated session or interruption.${RESET}" >&2
      if command -v shred &> /dev/null; then
        shred -u "$DEC_JSON_FILE"
      else
        rm -f "$DEC_JSON_FILE"
      fi
  fi

  # Final security reminder
  echo -e "\n${BOLD}${RED}--- IMPORTANT SECURITY REMINDER ---${RESET}"
  echo -e "${RED}Your password data was decrypted to a temporary file (${BOLD}${DEC_JSON_FILE}${RED}) during this session.${RESET}"
  echo -e "${RED}While cleanup was attempted, no plaintext data should remain on disk.${RESET}"
  echo -e "${RED}For maximum security, always ensure your system is free from malware and memory dumps are cleared.${RESET}"
  echo -e "${BOLD}${RED}-----------------------------------${RESET}\n"
}
