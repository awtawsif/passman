#!/bin/bash
# _change_master.sh
# Provides a function to change the master password securely.

# Dependencies:
# - _colors.sh, _utils.sh, _crypto.sh, _data_storage.sh
# - _prompts.sh (for prompt strings)
# Uses global variables: ENC_JSON_FILE, MASTER_PASSWORD, IS_AUTHENTICATED, CREDENTIALS_DATA

change_master_password() {
  clear_screen
  echo -e "$PROMPT_CHANGE_MASTER_TITLE"
  echo -e "$PROMPT_CHANGE_MASTER_HINT"

  # Prompt for current password and verify
  local current_pass
  get_master_password "$PROMPT_ENTER_CURRENT_MASTER_PASS" current_pass "false"
  if [[ -z "$current_pass" ]]; then
    echo -e "$ERROR_NO_PASSWORD_ENTERED"
    pause
    return 1 # Indicate failure/cancellation
  fi

  # Attempt to decrypt with current password to verify
  # We decrypt the *existing* encrypted file with the *current* password to verify it.
  # Redirect stderr to /dev/null to suppress openssl errors during verification
  if ! decrypt_data "$ENC_JSON_FILE" "$current_pass" >/dev/null 2>/dev/null; then
    echo -e "$ERROR_INCORRECT_CURRENT_MASTER_PASS"
    pause
    return 1 # Indicate failure
  fi

  # Prompt for new password (with confirmation)
  local new_pass
  get_master_password "$PROMPT_ENTER_NEW_MASTER_PASS" new_pass "true"
  if [[ -z "$new_pass" ]]; then
    echo -e "$ERROR_NEW_PASSWORD_NOT_SET"
    pause
    return 1 # Indicate failure/cancellation
  fi

  if [[ "$new_pass" == "$current_pass" ]]; then
    echo -e "$WARNING_NEW_PASS_SAME_AS_CURRENT"
    pause
    return 0 # Indicate success (no change needed)
  fi

  # Encrypt the in-memory data with the new password
  local temp_encrypted_file
  temp_encrypted_file=$(mktemp)
  # Redirect stderr of encrypt_data to /dev/null to suppress openssl errors
  if ! encrypt_data "$CREDENTIALS_DATA" "$new_pass" "$temp_encrypted_file" 2>/dev/null; then
    echo -e "$ERROR_ENCRYPT_NEW_PASS_FAILED"
    rm -f "$temp_encrypted_file"
    pause
    return 1 # Indicate failure
  fi

  # Overwrite the encrypted file with the newly encrypted content
  mv "$temp_encrypted_file" "$ENC_JSON_FILE"
  if [[ $? -ne 0 ]]; then
    echo -e "$ERROR_MOVE_ENCRYPTED_FILE_FAILED"
    rm -f "$temp_encrypted_file" # Clean up temp file
    pause
    return 1 # Indicate failure
  fi

  # Update the global MASTER_PASSWORD only after successful change
  MASTER_PASSWORD="$new_pass"
  echo -e "$SUCCESS_MASTER_PASSWORD_CHANGED"
  pause
  return 0 # Indicate success
}
