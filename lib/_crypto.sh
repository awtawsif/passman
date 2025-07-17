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
#   $3: The output file path to write encrypted data to.
# Returns:
#   0 on success, non-zero on failure.
encrypt_data() {
  local data="$1"
  local master_pass="$2"
  local output_file="$3"
  printf "%s" "$data" | openssl enc -aes-256-cbc -salt -pass "file:/dev/fd/3" 3<<<"$master_pass" > "$output_file" 2>/dev/null
  return $?
}

# Decrypts data from a file using openssl AES-256-CBC.
# Arguments:
#   $1: Path to the encrypted file.
#   $2: The master password for decryption.
# Returns:
#   Decrypted data on stdout. Errors to stderr.
decrypt_data() {
  local encrypted_file="$1"
  local master_pass="$2"
  openssl enc -d -aes-256-cbc -pass "file:/dev/fd/3" 3<<<"$master_pass" < "$encrypted_file" 2>/dev/null
  return $?
}

# Cleans up temporary files and securely saves credentials on exit.
# This function is registered as a trap in passman.sh.
cleanup_on_exit() {
  # Only attempt to save if authenticated and MASTER_PASSWORD is set
  if [[ "$IS_AUTHENTICATED" == "true" && -n "${MASTER_PASSWORD:-}" ]]; then
    echo -e "\n${BOLD}${BLUE}-----------------------------------------------------${RESET}"
    echo -e "${BOLD}${BLUE}  🔐 Securely saving and cleaning up...${RESET}"
    echo -e "${BOLD}${BLUE}-----------------------------------------------------${RESET}"

    local temp_encrypted_content
    temp_encrypted_content=$(mktemp) # Create a temporary file for encrypted content

    # Encrypt the in-memory data to the temporary file in the background
    # Redirect stderr of openssl to a temporary file to capture errors without showing them directly
    local temp_openssl_stderr
    temp_openssl_stderr=$(mktemp)
    encrypt_data "$CREDENTIALS_DATA" "$MASTER_PASSWORD" "$temp_encrypted_content" 2> "$temp_openssl_stderr" &
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
  else
    echo -e "\n${BOLD}${BLUE}-----------------------------------------------------${RESET}"
    echo -e "${BOLD}${BLUE}  🔐 Skipping save: Not authenticated or master password not set.${RESET}"
    echo -e "${BOLD}${BLUE}-----------------------------------------------------${RESET}"
  fi

  # Final security reminder
  echo -e "\\n${BOLD}${RED}--- IMPORTANT SECURITY REMINDER ---${RESET}"
  echo -e "${RED}Your password data was handled in-memory during this session.${RESET}"
  echo -e "${RED}No plaintext data should have been written to disk.${RESET}"
  echo -e "${RED}For maximum security, always ensure your system is free from malware and memory dumps are cleared.${RESET}"
  echo -e "${BOLD}${RED}-----------------------------------${RESET}"

  # Unset sensitive variables from memory
  unset MASTER_PASSWORD # Unset the variable to ensure it's not lingering
  CREDENTIALS_DATA="" # Clear the in-memory plaintext data
}
