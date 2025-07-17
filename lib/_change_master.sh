#!/bin/bash
# _change_master.sh
# Provides a function to change the master password securely.

# Dependencies:
# - _colors.sh, _utils.sh, _crypto.sh, _data_storage.sh
# Uses global variables: ENC_JSON_FILE, MASTER_PASSWORD, IS_AUTHENTICATED, CREDENTIALS_DATA

change_master_password() {
  clear_screen
  echo -e "${BRIGHT_BOLD}${VIOLET}--- Change Master Password ---${RESET}"
  echo -e "${AQUA}You will be prompted to enter your current master password, then set a new one.${RESET}\n"

  # Prompt for current password and verify
  local current_pass
  get_master_password "Enter current master password: " current_pass "false"
  if [[ -z "$current_pass" ]]; then
    echo -e "${NEON_RED}🚫 No password entered. Aborting.${RESET}"
    pause
    return 1 # Indicate failure/cancellation
  fi

  # Attempt to decrypt with current password to verify
  # We decrypt the *existing* encrypted file with the *current* password to verify it.
  # Redirect stderr to /dev/null to suppress openssl errors during verification
  if ! decrypt_data "$ENC_JSON_FILE" "$current_pass" >/dev/null 2>/dev/null; then
    echo -e "${NEON_RED}❌ Incorrect current master password. Aborting.${RESET}"
    pause
    return 1 # Indicate failure
  fi

  # Prompt for new password (with confirmation)
  local new_pass
  get_master_password "Enter NEW master password: " new_pass "true"
  if [[ -z "$new_pass" ]]; then
    echo -e "${NEON_RED}🚫 New password not set. Aborting.${RESET}"
    pause
    return 1 # Indicate failure/cancellation
  fi

  if [[ "$new_pass" == "$current_pass" ]]; then
    echo -e "${ELECTRIC_YELLOW}New password is the same as the current password. No changes made.${RESET}"
    pause
    return 0 # Indicate success (no change needed)
  fi

  # Encrypt the in-memory data with the new password
  local temp_encrypted_file
  temp_encrypted_file=$(mktemp)
  # Redirect stderr of encrypt_data to /dev/null to suppress openssl errors
  if ! encrypt_data "$CREDENTIALS_DATA" "$new_pass" "$temp_encrypted_file" 2>/dev/null; then
    echo -e "${NEON_RED}❌ Failed to encrypt data with new password. Aborting.${RESET}"
    rm -f "$temp_encrypted_file"
    pause
    return 1 # Indicate failure
  fi

  # Overwrite the encrypted file with the newly encrypted content
  mv "$temp_encrypted_file" "$ENC_JSON_FILE"
  if [[ $? -ne 0 ]]; then
    echo -e "${NEON_RED}❌ Failed to move encrypted data to final file. Check permissions.${RESET}"
    rm -f "$temp_encrypted_file" # Clean up temp file
    pause
    return 1 # Indicate failure
  fi

  # Update the global MASTER_PASSWORD only after successful change
  MASTER_PASSWORD="$new_pass"
  echo -e "${LIME_GREEN}✅ Master password successfully changed!${RESET}"
  pause
  return 0 # Indicate success
}
