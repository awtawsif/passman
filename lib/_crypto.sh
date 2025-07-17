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
# - MASTER_PASSWORD: The master password for encryption/decryption.
# - IS_AUTHENTICATED: Flag to determine if cleanup should encrypt and wipe.
# - CREDENTIALS_DATA: The in-memory decrypted plaintext JSON data.

# Encrypts data using openssl AES-256-CBC.
# Arguments:
#   $1: The plain text data to encrypt.
#   $2: The master password for encryption.
# Returns:
#   Encrypted data on stdout. Errors to stderr.
encrypt_data() {
  local data="$1"
  local master_pass="$2"
  printf "%s" "$data" | openssl enc -aes-256-cbc -salt -pass "file:/dev/fd/3" 3<<<"$master_pass"
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
  openssl enc -aes-256-cbc -d -salt -in "$encrypted_data_path" -pass "file:/dev/fd/3" 3<<<"$master_pass"
  return $? # Return openssl's exit status
}

# Cleanup function called on script exit.
# This function is critical for securely saving encrypted data.
# It relies on global variables set in passman.sh.
cleanup_on_exit() {
  # Only attempt to encrypt and clean up if successfully authenticated.
  if [[ "$IS_AUTHENTICATED" == "true" ]]; then
    echo -e "\n${BOLD}${CYAN}-----------------------------------------------------${RESET}"
    echo -e "${BOLD}${CYAN}   🔐 Securely saving and cleaning up...${RESET}"
    echo -e "${BOLD}${CYAN}-----------------------------------------------------${RESET}"

    local decrypted_content="$CREDENTIALS_DATA"
    
    local temp_encrypted_file=$(mktemp)
    local temp_openssl_stderr=$(mktemp) # Capture stderr for potential encryption errors

    # Run encryption in a subshell so we can monitor its PID with the spinner.
    (encrypt_data "$decrypted_content" "$MASTER_PASSWORD" > "$temp_encrypted_file" 2>"$temp_openssl_stderr") &
    local openssl_pid=$!
    spinner "$openssl_pid" "Encrypting data" # spinner from _utils.sh
    wait "$openssl_pid" # Wait for the background encryption process to finish
    local openssl_exit_status=$?

    if [[ "$openssl_exit_status" -ne 0 ]]; then
      if [[ -s "$temp_openssl_stderr" ]]; then # If stderr file has content
        cat "$temp_openssl_stderr" >&2 # Display openssl's error if encryption failed
      fi
      echo -e "${RED}❌ Error: Failed to encrypt data on exit. Your data might not be fully saved securely.${RESET}" >&2
      rm -f "$temp_encrypted_file" # Clean up temp encrypted file on failure
    else
      mv "$temp_encrypted_file" "$ENC_JSON_FILE"
      if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Credentials securely saved to ${BOLD}${ENC_JSON_FILE}${RESET}${GREEN}.${RESET}"
      else
        echo -e "${RED}❌ Failed to move encrypted data to final file. Check permissions.${RESET}" >&2
      fi
    fi
    rm -f "$temp_openssl_stderr" # Clean up stderr temp file
  fi

  # Final security reminder
  echo -e "\n${BOLD}${RED}--- IMPORTANT SECURITY REMINDER ---${RESET}"
  echo -e "${RED}Your password data was handled in-memory during this session.${RESET}"
  echo -e "${RED}No plaintext data should have been written to disk.${RESET}"
  echo -e "${RED}For maximum security, always ensure your system is free from malware and memory dumps are cleared.${RESET}"
  echo -e "${BOLD}${RED}-----------------------------------${RESET}\n"
}
