#!/bin/bash
# _config.sh
# Handles configuration loading and saving, including the encrypted file location.

# --- Strict Mode for Robustness ---
set -e
set -u
set -o pipefail

# Dependencies:
# - _colors.sh (for color variables)
# - _utils.sh (for clear_screen, pause, trim)
# Global variables from passman.sh that are used/set here:
# - SCRIPT_DIR
# - CONFIG_DIR
# - CONFIG_FILE
# - DEFAULT_ENC_FILENAME
# - SAVE_LOCATION (updated by this script)
# - ENC_JSON_FILE (updated by this script)

# Loads the configuration, specifically the SAVE_LOCATION.
# If no config file exists, it defaults SAVE_LOCATION to SCRIPT_DIR.
load_config_and_set_paths() {
  # Ensure CONFIG_DIR exists
  mkdir -p "$CONFIG_DIR"

  if [[ -f "$CONFIG_FILE" ]]; then
    # Read the save location from the config file
    local loaded_location
    loaded_location=$(<"$CONFIG_FILE")
    # Trim whitespace from the loaded location
    loaded_location=$(trim "$loaded_location")

    # Check if the loaded location is a valid directory
    if [[ -d "$loaded_location" ]]; then
      SAVE_LOCATION="$loaded_location"
      echo -e "${CYAN}Loaded save location: ${BOLD}${SAVE_LOCATION}${RESET}"
    else
      # If the configured path is invalid, reset to script directory and save this default
      echo -e "${YELLOW}⚠️  Configured save location '${loaded_location}' does not exist or is not a directory. Resetting to script directory.${RESET}"
      SAVE_LOCATION="$SCRIPT_DIR"
      save_config_file_location # Save the corrected default
    fi
  else
    # First run or config file missing, default to script directory
    SAVE_LOCATION="$SCRIPT_DIR"
    echo -e "${YELLOW}No configuration file found. Defaulting save location to script directory: ${BOLD}${SAVE_LOCATION}${RESET}"
    save_config_file_location # Save the default location
  fi

  # Set the global encrypted JSON file path based on the determined save location
  ENC_JSON_FILE="${SAVE_LOCATION}/${DEFAULT_ENC_FILENAME}"
}

# Saves the current SAVE_LOCATION to the configuration file.
save_config_file_location() {
  mkdir -p "$CONFIG_DIR" # Ensure config directory exists before writing
  echo -n "$SAVE_LOCATION" > "$CONFIG_FILE"
  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Configuration saved to ${BOLD}${CONFIG_FILE}${RESET}${GREEN}.${RESET}"
  else
    echo -e "${RED}❌ Failed to save configuration to ${BOLD}${CONFIG_FILE}${RESET}${RED}. Check permissions.${RESET}" >&2
  fi
}

# Allows the user to change the directory where the encrypted file is saved.
change_save_location() {
  clear_screen
  echo -e "${BOLD}${MAGENTA}--- Change File Saving Location ---${RESET}"
  echo -e "${CYAN}Your encrypted password file is currently saved in: ${BOLD}${SAVE_LOCATION}${RESET}"
  echo -e "${CYAN}💡 Type '${BOLD}C${RESET}${CYAN}' to cancel this operation.${RESET}\n"

  local old_enc_file="$ENC_JSON_FILE" # Store current full path before potential change
  local old_save_location="$SAVE_LOCATION" # Store current directory

  local new_location_input
  local new_location

  while true; do
    read -rp "$(printf "${YELLOW}Enter the NEW directory path to save your encrypted file:${RESET} ") " new_location_input
    new_location=$(trim "$new_location_input")
    echo "" # Extra space

    local lower_input
    lower_input=$(echo "$new_location" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "${CYAN}Operation cancelled. Returning to main menu.${RESET}"
      pause
      return
    fi

    # Expand tilde (~) to home directory if present
    if [[ "$new_location" == "~"* ]]; then
      new_location="${HOME}${new_location:1}"
    fi

    # Resolve absolute path for consistency
    if [[ "$new_location" == /* ]]; then # If it's an absolute path
      new_location="$new_location"
    else # If it's a relative path, make it absolute relative to current working directory
      new_location="$(pwd)/$new_location"
    fi

    # Remove trailing slash if present, unless it's just "/"
    new_location="${new_location%/}"

    if [[ -z "$new_location" ]]; then
      echo -e "${RED}🚫 Directory path cannot be empty! Please provide a path or type '${CYAN}C${RED}' to cancel.${RESET}"
      echo "" # Extra space
      continue
    fi

    # Check if the directory exists or can be created
    if [[ ! -d "$new_location" ]]; then
      echo -e "${YELLOW}Directory '${new_location}' does not exist.${RESET}"
      local create_dir_confirm
      while true; do
        read -rp "$(printf "${YELLOW}Do you want to create it? (${BOLD}Y/n${RESET}${YELLOW}):${RESET}") " create_dir_confirm_input
        create_dir_confirm=$(trim "${create_dir_confirm_input:-y}")
        echo "" # Extra space
        if [[ "$(echo "$create_dir_confirm" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
          echo -e "${CYAN}Directory creation cancelled. Please enter a valid path or type '${CYAN}C${RED}' to cancel.${RESET}"
          break
        fi
        if [[ "$create_dir_confirm" =~ ^[yYnN]$ ]]; then
          break
        fi
        echo -e "${RED}🚫 Invalid input. Please enter '${BOLD}Y${RESET}${RED}' for Yes, '${BOLD}N${RESET}${RED}' for No, or '${CYAN}C${RED}' to cancel.${RESET}"
        echo "" # Extra space
      done

      if [[ "$create_dir_confirm" =~ ^[yY]$ ]]; then
        if ! mkdir -p "$new_location"; then
          echo -e "${RED}❌ Failed to create directory '${new_location}'. Check permissions or path.${RESET}"
          echo "" # Extra space
          continue
        else
          echo -e "${GREEN}✅ Directory '${new_location}' created.${RESET}"
        fi
      else
        echo -e "${YELLOW}Directory not created. Please enter an existing path or allow creation.${RESET}"
        echo "" # Extra space
        continue
      fi
    fi

    # Check if the new location is the same as the current one
    if [[ "$new_location" == "$old_save_location" ]]; then
      echo -e "${YELLOW}New save location is the same as the current one. No changes made.${RESET}"
      pause
      return
    fi

    # Check if the new location is writable
    if [[ ! -w "$new_location" ]]; then
      echo -e "${RED}❌ Directory '${new_location}' is not writable. Please choose a writable location.${RESET}"
      echo "" # Extra space
      continue
    fi

    break # Valid new location found
  done

  # Update global SAVE_LOCATION and save to config
  SAVE_LOCATION="$new_location"
  save_config_file_location

  # Update the global ENC_JSON_FILE based on the new SAVE_LOCATION
  ENC_JSON_FILE="${SAVE_LOCATION}/${DEFAULT_ENC_FILENAME}"

  # Offer to move the existing encrypted file
  if [[ -f "$old_enc_file" ]] && [[ "$old_enc_file" != "$ENC_JSON_FILE" ]]; then
    echo -e "${YELLOW}An existing encrypted file was found at '${old_enc_file}'.${RESET}"
    local move_file_confirm
    while true; do
      read -rp "$(printf "${YELLOW}Do you want to move it to the new location '${ENC_JSON_FILE}'? (${BOLD}Y/n${RESET}${YELLOW}):${RESET}") " move_file_confirm_input
      move_file_confirm=$(trim "${move_file_confirm_input:-y}")
      echo "" # Extra space
      if [[ "$(echo "$move_file_confirm" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
        echo -e "${CYAN}File move cancelled. The old file remains at '${old_enc_file}'. The new location is set for future saves.${RESET}"
        break
      fi
      if [[ "$move_file_confirm" =~ ^[yYnN]$ ]]; then
        break
      fi
      echo -e "${RED}🚫 Invalid input. Please enter '${BOLD}Y${RESET}${RED}' for Yes, '${BOLD}N${RESET}${RED}' for No, or '${CYAN}C${RED}' to cancel.${RESET}"
      echo "" # Extra space
    done

    if [[ "$move_file_confirm" =~ ^[yY]$ ]]; then
      if mv "$old_enc_file" "$ENC_JSON_FILE"; then
        echo -e "${GREEN}✅ Encrypted file successfully moved to '${ENC_JSON_FILE}'.${RESET}"
      else
        echo -e "${RED}❌ Failed to move encrypted file. Please move it manually if desired: '${old_enc_file}' to '${ENC_JSON_FILE}'.${RESET}"
      fi
    fi
  elif [[ -f "$old_enc_file" ]] && [[ "$old_enc_file" == "$ENC_JSON_FILE" ]]; then
    echo -e "${YELLOW}Encrypted file is already at the new location. No move needed.${RESET}"
  fi

  echo -e "${GREEN}✅ File saving location updated to: ${BOLD}${SAVE_LOCATION}${RESET}"
  echo -e "${CYAN}All future saves and loads will use this new location.${RESET}"
  pause
}
