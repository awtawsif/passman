#!/bin/bash
# _config.sh
# Handles configuration loading and saving, including the encrypted file location
# and other user preferences.

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
# New global config variables:
# - DEFAULT_PASSWORD_LENGTH
# - DEFAULT_PASSWORD_UPPER
# - DEFAULT_PASSWORD_NUMBERS
# - DEFAULT_PASSWORD_SYMBOLS
# - CLIPBOARD_CLEAR_DELAY
# - DEFAULT_SEARCH_MODE

# Loads the configuration from the config file.
# Sets global variables based on loaded values or defaults.
load_config() {
  # Ensure CONFIG_DIR exists
  mkdir -p "$CONFIG_DIR"

  # Set default values
  SAVE_LOCATION="$SCRIPT_DIR"
  DEFAULT_PASSWORD_LENGTH=12
  DEFAULT_PASSWORD_UPPER="y"
  DEFAULT_PASSWORD_NUMBERS="y"
  DEFAULT_PASSWORD_SYMBOLS="y"
  CLIPBOARD_CLEAR_DELAY=10 # seconds
  DEFAULT_SEARCH_MODE="and" # "and" or "or"

  if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "${CYAN}Loading configuration from: ${BOLD}${CONFIG_FILE}${RESET}"
    # Read config file line by line, setting variables
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
      # Remove leading/trailing whitespace and quotes from key and value
      key=$(trim "$key")
      value=$(trim "$value")
      value="${value%\"}" # Remove trailing quote
      value="${value#\"}" # Remove leading quote

      case "$key" in
        "SAVE_LOCATION")
          # Expand tilde (~) to home directory if present
          if [[ "$value" == "~"* ]]; then
            value="${HOME}${value:1}"
          fi
          # Remove trailing slash if present, unless it's just "/"
          value="${value%/}"

          if [[ -d "$value" ]]; then
            SAVE_LOCATION="$value"
          else
            echo -e "${YELLOW}⚠️  Configured save location '${value}' does not exist or is not a directory. Using default: ${BOLD}${SCRIPT_DIR}${RESET}"
            SAVE_LOCATION="$SCRIPT_DIR"
          fi
          ;;
        "DEFAULT_PASSWORD_LENGTH")
          if [[ "$value" =~ ^[0-9]+$ ]] && (( value >= 1 )); then
            DEFAULT_PASSWORD_LENGTH="$value"
          else
            echo -e "${YELLOW}⚠️ Invalid DEFAULT_PASSWORD_LENGTH in config. Using default: ${BOLD}12${RESET}"
          fi
          ;;
        "DEFAULT_PASSWORD_UPPER") [[ "$value" =~ ^[yYnN]$ ]] && DEFAULT_PASSWORD_UPPER="$value" || echo -e "${YELLOW}⚠️ Invalid DEFAULT_PASSWORD_UPPER in config. Using default: ${BOLD}y${RESET}" ;;
        "DEFAULT_PASSWORD_NUMBERS") [[ "$value" =~ ^[yYnN]$ ]] && DEFAULT_PASSWORD_NUMBERS="$value" || echo -e "${YELLOW}⚠️ Invalid DEFAULT_PASSWORD_NUMBERS in config. Using default: ${BOLD}y${RESET}" ;;
        "DEFAULT_PASSWORD_SYMBOLS") [[ "$value" =~ ^[yYnN]$ ]] && DEFAULT_PASSWORD_SYMBOLS="$value" || echo -e "${YELLOW}⚠️ Invalid DEFAULT_PASSWORD_SYMBOLS in config. Using default: ${BOLD}y${RESET}" ;;
        "CLIPBOARD_CLEAR_DELAY")
          if [[ "$value" =~ ^[0-9]+$ ]] && (( value >= 0 )); then
            CLIPBOARD_CLEAR_DELAY="$value"
          else
            echo -e "${YELLOW}⚠️ Invalid CLIPBOARD_CLEAR_DELAY in config. Using default: ${BOLD}10${RESET}"
          fi
          ;;
        "DEFAULT_SEARCH_MODE") [[ "$value" == "and" || "$value" == "or" ]] && DEFAULT_SEARCH_MODE="$value" || echo -e "${YELLOW}⚠️ Invalid DEFAULT_SEARCH_MODE in config. Using default: ${BOLD}and${RESET}" ;;
      esac
    done < "$CONFIG_FILE"
  else
    echo -e "${YELLOW}No configuration file found. Using default settings.${RESET}"
  fi

  # Set the global encrypted JSON file path based on the determined save location
  ENC_JSON_FILE="${SAVE_LOCATION}/${DEFAULT_ENC_FILENAME}"

  # Always save config after loading to ensure file exists and defaults are written
  save_config
}

# Saves the current configuration to the config file.
save_config() {
  mkdir -p "$CONFIG_DIR" # Ensure config directory exists before writing
  {
    echo "SAVE_LOCATION=\"$SAVE_LOCATION\""
    echo "DEFAULT_PASSWORD_LENGTH=\"$DEFAULT_PASSWORD_LENGTH\""
    echo "DEFAULT_PASSWORD_UPPER=\"$DEFAULT_PASSWORD_UPPER\""
    echo "DEFAULT_PASSWORD_NUMBERS=\"$DEFAULT_PASSWORD_NUMBERS\""
    echo "DEFAULT_PASSWORD_SYMBOLS=\"$DEFAULT_PASSWORD_SYMBOLS\""
    echo "CLIPBOARD_CLEAR_DELAY=\"$CLIPBOARD_CLEAR_DELAY\""
    echo "DEFAULT_SEARCH_MODE=\"$DEFAULT_SEARCH_MODE\""
  } > "$CONFIG_FILE"
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
  save_config

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


# Allows the user to view and modify various application settings.
manage_settings() {
  clear_screen
  while true; do
    echo -e "${BOLD}${MAGENTA}--- Manage Application Settings ---${RESET}"
    echo -e "${CYAN}Configure various defaults for PassMan.${RESET}\n"

    echo -e "${BOLD}1)${RESET} ${YELLOW}File Saving Location${RESET}: ${BOLD}${SAVE_LOCATION}${RESET}"
    echo -e "${BOLD}2)${RESET} ${YELLOW}Default Password Length${RESET}: ${BOLD}${DEFAULT_PASSWORD_LENGTH}${RESET}"
    echo -e "${BOLD}3)${RESET} ${YELLOW}Default Password Chars${RESET}: ${BOLD}U:${DEFAULT_PASSWORD_UPPER} N:${DEFAULT_PASSWORD_NUMBERS} S:${DEFAULT_PASSWORD_SYMBOLS}${RESET}"
    echo -e "${BOLD}4)${RESET} ${YELLOW}Clipboard Clear Delay${RESET}: ${BOLD}${CLIPBOARD_CLEAR_DELAY} seconds${RESET}"
    echo -e "${BOLD}5)${RESET} ${YELLOW}Default Search Mode${RESET}: ${BOLD}${DEFAULT_SEARCH_MODE}${RESET}"
    echo -e "${BOLD}6)${RESET} ${YELLOW}Back to Main Menu${RESET}"
    echo "" # Extra space

    read -rp "$(printf "${YELLOW}Enter your choice [1-6]:${RESET} ") " choice
    choice=$(trim "$choice")
    echo "" # Extra space

    case "$choice" in
      1) # Change File Saving Location
        change_save_location
        ;;
      2) # Change Default Password Length
        local new_length
        while true; do
          read -rp "$(printf "${YELLOW}Enter new default password length (current: ${BOLD}%s${RESET}, min 1):${RESET} " "$DEFAULT_PASSWORD_LENGTH")" new_length_input
          new_length=$(trim "$new_length_input")
          echo "" # Extra space
          if [[ "$(echo "$new_length" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
            echo -e "${CYAN}Operation cancelled.${RESET}"
            break 2 # Break out of inner and outer loop
          fi
          if [[ "$new_length" =~ ^[0-9]+$ ]] && (( new_length >= 1 )); then
            DEFAULT_PASSWORD_LENGTH="$new_length"
            save_config
            echo -e "${GREEN}✅ Default password length updated.${RESET}"
            break
          fi
          echo -e "${RED}🚫 Invalid length. Please enter a positive number.${RESET}"
          echo "" # Extra space
        done
        ;;
      3) # Change Default Password Char Sets
        echo -e "${BOLD}${CYAN}--- Configure Default Password Characters ---${RESET}"
        local new_upper new_numbers new_symbols

        while true; do
          read -rp "$(printf "${YELLOW}Include uppercase letters by default? (current: ${BOLD}%s${RESET}, Y/n):${RESET} " "$DEFAULT_PASSWORD_UPPER")" new_upper_input
          new_upper=$(trim "${new_upper_input:-$DEFAULT_PASSWORD_UPPER}")
          echo "" # Extra space
          if [[ "$(echo "$new_upper" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
            echo -e "${CYAN}Operation cancelled.${RESET}"
            break 2
          fi
          if [[ "$new_upper" =~ ^[yYnN]$ ]]; then
            DEFAULT_PASSWORD_UPPER="$new_upper"
            break
          fi
          echo -e "${RED}🚫 Invalid input. Please enter Y or N.${RESET}"
          echo "" # Extra space
        done

        while true; do
          read -rp "$(printf "${YELLOW}Include numbers by default? (current: ${BOLD}%s${RESET}, Y/n):${RESET} " "$DEFAULT_PASSWORD_NUMBERS")" new_numbers_input
          new_numbers=$(trim "${new_numbers_input:-$DEFAULT_PASSWORD_NUMBERS}")
          echo "" # Extra space
          if [[ "$(echo "$new_numbers" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
            echo -e "${CYAN}Operation cancelled.${RESET}"
            break 2
          fi
          if [[ "$new_numbers" =~ ^[yYnN]$ ]]; then
            DEFAULT_PASSWORD_NUMBERS="$new_numbers"
            break
          fi
          echo -e "${RED}🚫 Invalid input. Please enter Y or N.${RESET}"
          echo "" # Extra space
        done

        while true; do
          read -rp "$(printf "${YELLOW}Include symbols by default? (current: ${BOLD}%s${RESET}, Y/n):${RESET} " "$DEFAULT_PASSWORD_SYMBOLS")" new_symbols_input
          new_symbols=$(trim "${new_symbols_input:-$DEFAULT_PASSWORD_SYMBOLS}")
          echo "" # Extra space
          if [[ "$(echo "$new_symbols" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
            echo -e "${CYAN}Operation cancelled.${RESET}"
            break 2
          fi
          if [[ "$new_symbols" =~ ^[yYnN]$ ]]; then
            DEFAULT_PASSWORD_SYMBOLS="$new_symbols"
            break
          fi
          echo -e "${RED}🚫 Invalid input. Please enter Y or N.${RESET}"
          echo "" # Extra space
        done
        save_config
        echo -e "${GREEN}✅ Default password character sets updated.${RESET}"
        ;;
      4) # Change Clipboard Clear Delay
        local new_delay
        while true; do
          read -rp "$(printf "${YELLOW}Enter new clipboard clear delay in seconds (current: ${BOLD}%s${RESET}, 0 to disable):${RESET} " "$CLIPBOARD_CLEAR_DELAY")" new_delay_input
          new_delay=$(trim "$new_delay_input")
          echo "" # Extra space
          if [[ "$(echo "$new_delay" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
            echo -e "${CYAN}Operation cancelled.${RESET}"
            break 2
          fi
          if [[ "$new_delay" =~ ^[0-9]+$ ]] && (( new_delay >= 0 )); then
            CLIPBOARD_CLEAR_DELAY="$new_delay"
            save_config
            echo -e "${GREEN}✅ Clipboard clear delay updated.${RESET}"
            break
          fi
          echo -e "${RED}🚫 Invalid delay. Please enter a non-negative number.${RESET}"
          echo "" # Extra space
        done
        ;;
      5) # Change Default Search Mode
        local new_search_mode
        while true; do
          read -rp "$(printf "${YELLOW}Set default search mode (current: ${BOLD}%s${RESET}, 'and' or 'or'):${RESET} " "$DEFAULT_SEARCH_MODE")" new_search_mode_input
          new_search_mode=$(trim "$new_search_mode_input")
          echo "" # Extra space
          local lower_input
          lower_input=$(echo "$new_search_mode" | tr '[:upper:]' '[:lower:]')
          if [[ "$lower_input" == "c" ]]; then
            echo -e "${CYAN}Operation cancelled.${RESET}"
            break 2
          fi
          if [[ "$lower_input" == "and" || "$lower_input" == "or" ]]; then
            DEFAULT_SEARCH_MODE="$lower_input"
            save_config
            echo -e "${GREEN}✅ Default search mode updated.${RESET}"
            break
          fi
          echo -e "${RED}🚫 Invalid mode. Please enter 'and' or 'or'.${RESET}"
          echo "" # Extra space
        done
        ;;
      6) # Back to Main Menu
        echo -e "${CYAN}Returning to main menu.${RESET}"
        pause
        return
        ;;
      *)
        echo -e "${RED}❌ Invalid option. Please enter a number between ${BOLD}1${RESET}${RED} and ${BOLD}6${RESET}${RED}.${RESET}"
        ;;
    esac
    pause
    clear_screen
  done
}
