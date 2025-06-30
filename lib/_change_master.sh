#!/bin/bash
# _change_master.sh
# Provides a function to change the master password securely.

# Dependencies:
# - _colors.sh, _utils.sh, _crypto.sh, _data_storage.sh
# Uses global variables: ENC_JSON_FILE, DEC_JSON_FILE, MASTER_PASSWORD, IS_AUTHENTICATED

change_master_password() {
  clear_screen
  echo -e "${BOLD}${MAGENTA}--- Change Master Password ---${RESET}"
  echo -e "${CYAN}You will be prompted to enter your current master password, then set a new one.${RESET}\n"

  # Prompt for current password and verify
  local current_pass
  get_master_password "Enter current master password: " current_pass "false"
  if [[ -z "$current_pass" ]]; then
    echo -e "${RED}🚫 No password entered. Aborting.${RESET}"
    pause
    return
  fi

  # Attempt to decrypt with current password to verify
  if ! decrypt_data "$ENC_JSON_FILE" "$current_pass" >/dev/null 2>&1; then
    echo -e "${RED}❌ Incorrect current master password. Aborting.${RESET}"
    pause
    return
  fi

  # Prompt for new password (with confirmation)
  local new_pass
  get_master_password "Enter NEW master password: " new_pass "true"
  if [[ -z "$new_pass" ]]; then
    echo -e "${RED}🚫 New password not set. Aborting.${RESET}"
    pause
    return
  fi

  if [[ "$new_pass" == "$current_pass" ]]; then
    echo -e "${YELLOW}New password is the same as the current password. No changes made.${RESET}"
    pause
    return
  fi

  # Decrypt current data
  local decrypted_content
  decrypted_content=$(decrypt_data "$ENC_JSON_FILE" "$current_pass" 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Failed to decrypt data with current password. Aborting.${RESET}"
    pause
    return
  fi

  # Encrypt with new password
  local temp_encrypted_file
  temp_encrypted_file=$(mktemp)
  if ! encrypt_data "$decrypted_content" "$new_pass" > "$temp_encrypted_file" 2>/dev/null; then
    echo -e "${RED}❌ Failed to encrypt data with new password. Aborting.${RESET}"
    rm -f "$temp_encrypted_file"
    pause
    return
  fi

  # Overwrite the encrypted file
  mv "$temp_encrypted_file" "$ENC_JSON_FILE"

  # Update in-memory master password for this session
  MASTER_PASSWORD="$new_pass"

  echo -e "${GREEN}✅ Master password changed successfully!${RESET}"
  pause
}
