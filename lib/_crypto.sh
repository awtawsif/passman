#!/bin/bash
# _crypto.sh
# Handles encryption, decryption, and secure cleanup on script exit.
# Sourced by passman.sh.

# --- Strict Mode for Robustness ---
set -e
set -u
set -o pipefail

# Dependencies:
# - _colors.sh (for color variables like NEON_RED, LIME_GREEN, ELECTRIC_YELLOW, AQUA, BRIGHT_BOLD, RESET)
# - _utils.sh (for spinner, trim functions)
# - _prompts.sh (for prompt strings)
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
#   $1: The path to the encrypted file.
#   $2: The master password for decryption.
# Returns:
#   Decrypted plaintext data on stdout on success, nothing on failure.
decrypt_data() {
  local input_file="$1"
  local master_pass="$2"
  # Use a temporary file for the password to avoid it showing up in process lists
  local pass_file=$(mktemp)
  printf "%s" "$master_pass" > "$pass_file"
  # Decrypt, suppressing error messages from openssl
  openssl enc -aes-256-cbc -d -pass "file:$pass_file" -in "$input_file" 2>/dev/null
  local status=$?
  rm -f "$pass_file" # Clean up the password file immediately
  return $status
}

# Handles secure cleanup on script exit.
# Encrypts in-memory data back to file if authenticated, then wipes sensitive variables.
cleanup_on_exit() {
  # Only encrypt and save if authenticated and master password is set
  if [[ "$IS_AUTHENTICATED" == "true" ]] && [[ -n "$MASTER_PASSWORD" ]]; then
    local temp_encrypted_content=$(mktemp)
    local temp_openssl_stderr=$(mktemp) # Capture stderr for debugging if needed

    echo -e "${AQUA}Encrypting and saving credentials before exit...${RESET}"
    # Redirect stderr of encrypt_data to a temporary file to suppress it from console
    if ! encrypt_data "$CREDENTIALS_DATA" "$MASTER_PASSWORD" "$temp_encrypted_content" 2> "$temp_openssl_stderr"; then
      echo -e "${NEON_RED}❌ Error: Failed to re-encrypt data during cleanup. Data might not be saved.${RESET}" >&2
      # Optionally log the openssl error for debugging
      # cat "$temp_openssl_stderr" >&2
      rm -f "$temp_encrypted_content" # Clean up temp encrypted file on failure
    else
      mv "$temp_encrypted_content" "$ENC_JSON_FILE"
      if [[ $? -eq 0 ]]; then
        echo -e "$(printf "$SUCCESS_CREDENTIALS_SAVED" "$ENC_JSON_FILE")"
      else
        echo -e "$ERROR_FAILED_TO_MOVE_ENCRYPTED_DATA" >&2
      fi
    fi
    rm -f "$temp_openssl_stderr" # Clean up stderr temp file
  else
    echo -e "$INFO_SKIPPING_SAVE_NOT_AUTH"
  fi

  # Final security reminder
  echo -e "$IMPORTANT_SECURITY_REMINDER_HEADER"
  echo -e "$IMPORTANT_SECURITY_REMINDER_LINE1"
  echo -e "$IMPORTANT_SECURITY_REMINDER_LINE2"
  echo -e "$IMPORTANT_SECURITY_REMINDER_LINE3"
  echo -e "$IMPORTANT_SECURITY_REMINDER_FOOTER"

  # Unset sensitive variables from memory
  unset MASTER_PASSWORD # Unset the master password from memory
  CREDENTIALS_DATA="" # Clear the in-memory plaintext data
  # Overwrite with zeros/random data if possible (more complex in bash)
  # For simple variables, unsetting is the primary mechanism.
  # For large strings, a loop could overwrite characters, but less critical for shell vars.
}
