#!/bin/bash
# _config.sh
# Handles application configuration settings like data file location and password generation defaults.
# Sourced by passman.sh.

# --- Strict Mode for Robustness ---
set -e
set -u
set -o pipefail

# Dependencies:
# - _colors.sh (for color variables like RED, GREEN, YELLOW, RESET)
# - _utils.sh (for pause, trim)
# Global variables from passman.sh that are used/set here:
# - CONFIG_DIR: Path to the configuration directory.
# - CONFIG_FILE: Path to the configuration file.
# - DEFAULT_ENC_FILENAME: Default name for the encrypted credentials file.
# - SAVE_LOCATION: Directory where the encrypted file is saved.
# - ENC_JSON_FILE: Full path to the encrypted credentials file.
# - DEFAULT_PASSWORD_LENGTH, DEFAULT_PASSWORD_UPPER, DEFAULT_PASSWORD_NUMBERS, DEFAULT_PASSWORD_SYMBOLS: Password generation settings.
# - CLIPBOARD_CLEAR_DELAY: Delay for clipboard clear.
# - DEFAULT_SEARCH_MODE: Default search mode ("and" or "or").

# Loads configuration from the config file or sets defaults.
load_config() {
  # Ensure the config directory exists
  mkdir -p "$CONFIG_DIR"

  # Set default save location if not already set (this happens on first run)
  : "${SAVE_LOCATION:=${HOME}/Documents}" # Default to user's Documents folder

  # Check if config file exists
  if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "${CYAN}Loading configuration from ${BOLD}${CONFIG_FILE}${RESET}${CYAN}...${RESET}"
    while IFS='=' read -r key value; do
      # Trim whitespace from key and value
      key=$(trim "$key")
      value=$(trim "$value")

      # Strip any leading/trailing quotes from the value
      value=$(echo "$value" | sed 's/^"//;s/"$//')

      # Skip comments and empty lines
      if [[ "$key" =~ ^#.* ]] || [[ -z "$key" ]]; then
        continue
      fi

      case "$key" in
        SAVE_LOCATION) SAVE_LOCATION="$value" ;;
        DEFAULT_PASSWORD_LENGTH) DEFAULT_PASSWORD_LENGTH="$value" ;;
        DEFAULT_PASSWORD_UPPER) DEFAULT_PASSWORD_UPPER="$value" ;;
        DEFAULT_PASSWORD_NUMBERS) DEFAULT_PASSWORD_NUMBERS="$value" ;;
        DEFAULT_PASSWORD_SYMBOLS) DEFAULT_PASSWORD_SYMBOLS="$value" ;;
        CLIPBOARD_CLEAR_DELAY) CLIPBOARD_CLEAR_DELAY="$value" ;;
        DEFAULT_SEARCH_MODE) DEFAULT_SEARCH_MODE="$value" ;;
        *) echo -e "${YELLOW}Warning: Unknown configuration key '${key}' in ${CONFIG_FILE}.${RESET}" >&2 ;;
      esac
    done < "$CONFIG_FILE"
    echo -e "${GREEN}Configuration loaded.${RESET}\n"
  else
    echo -e "${YELLOW}No configuration file found. Using default settings.${RESET}\n"
    # Save default config to file for future runs
    save_config
  fi

  # Set the full path to the encrypted JSON file based on loaded/default SAVE_LOCATION
  ENC_JSON_FILE="${SAVE_LOCATION}/${DEFAULT_ENC_FILENAME}"
}

# Saves current configuration settings to the config file.
save_config() {
  mkdir -p "$CONFIG_DIR" # Ensure config directory exists
  {
    echo "# Passman Configuration File"
    echo "# Last updated: $(date "+%Y-%m-%d %H:%M:%S")"
    echo ""
    echo "SAVE_LOCATION=$SAVE_LOCATION"
    echo "DEFAULT_PASSWORD_LENGTH=$DEFAULT_PASSWORD_LENGTH"
    echo "DEFAULT_PASSWORD_UPPER=$DEFAULT_PASSWORD_UPPER"
    echo "DEFAULT_PASSWORD_NUMBERS=$DEFAULT_PASSWORD_NUMBERS"
    echo "DEFAULT_PASSWORD_SYMBOLS=$DEFAULT_PASSWORD_SYMBOLS"
    echo "CLIPBOARD_CLEAR_DELAY=$CLIPBOARD_CLEAR_DELAY"
    echo "DEFAULT_SEARCH_MODE=$DEFAULT_SEARCH_MODE"
  } > "$CONFIG_FILE"
  echo -e "${GREEN}Configuration saved to ${BOLD}${CONFIG_FILE}${RESET}${GREEN}.${RESET}"
}

# Updates the SAVE_LOCATION in the config file.
# Arguments:
#   $1: The new path for SAVE_LOCATION.
update_save_location_in_config() {
  local new_path="$1"
  SAVE_LOCATION="$new_path" # Update the global variable
  save_config # Call save_config to write the updated global to file
  echo -e "${GREEN}Default save location updated to: ${BOLD}$SAVE_LOCATION${RESET}${GREEN}.${RESET}"
}


# Allows the user to manage various application settings.
manage_settings() {
  clear_screen
  echo -e "${BOLD}${MAGENTA}--- Manage Settings ---${RESET}"
  echo -e "${CYAN}Configure default password generation and data file location.${RESET}\n"

  local setting_choice
  while true; do
    echo -e "${BOLD}Current Settings:${RESET}"
    echo -e "  ${BOLD}1)${RESET} Default Password Length: ${BOLD}$DEFAULT_PASSWORD_LENGTH${RESET}"
    echo -e "  ${BOLD}2)${RESET} Include Uppercase: ${BOLD}$DEFAULT_PASSWORD_UPPER${RESET}"
    echo -e "  ${BOLD}3)${RESET} Include Numbers: ${BOLD}$DEFAULT_PASSWORD_NUMBERS${RESET}"
    echo -e "  ${BOLD}4)${RESET} Include Symbols: ${BOLD}$DEFAULT_PASSWORD_SYMBOLS${RESET}"
    echo -e "  ${BOLD}5)${RESET} Clipboard Clear Delay (seconds): ${BOLD}$CLIPBOARD_CLEAR_DELAY${RESET}"
    echo -e "  ${BOLD}6)${RESET} Default Data File Location: ${BOLD}$SAVE_LOCATION${RESET}"
    echo -e "  ${BOLD}7)${RESET} Default Search Mode: ${BOLD}$DEFAULT_SEARCH_MODE${RESET} ('and' or 'or')"
    echo -e "  ${BOLD}Q)${RESET} Back to Main Menu${RESET}\n"

    read -rp "$(printf "${YELLOW}Enter setting number to change, or 'Q' to quit: ${RESET}") " setting_choice_input
    setting_choice=$(trim "$setting_choice_input")
    echo "" # Extra space

    local lower_choice
    lower_choice=$(echo "$setting_choice" | tr '[:upper:]' '[:lower:]')

    if [[ "$lower_choice" == "q" ]]; then
      break
    fi

    case "$setting_choice" in
      1) # Default Password Length
        local new_length
        while true; do
          read -rp "$(printf "${YELLOW}Enter new default password length (current: ${BOLD}%s${RESET}${YELLOW}, min 1): ${RESET}" "$DEFAULT_PASSWORD_LENGTH")" new_length_input
          new_length=$(trim "$new_length_input")
          echo "" # Extra space
          if [[ "$new_length" =~ ^[0-9]+$ ]] && (( new_length >= 1 )); then
            DEFAULT_PASSWORD_LENGTH="$new_length"
            echo -e "${GREEN}Default password length updated to ${BOLD}$DEFAULT_PASSWORD_LENGTH${RESET}.${RESET}"
            break
          else
            echo -e "${RED}🚫 Invalid length. Please enter a positive number.${RESET}"
            echo "" # Extra space
          fi
        done
        ;;
      2) # Include Uppercase
        local new_upper
        while true; do
          read -rp "$(printf "${YELLOW}Include uppercase letters? (current: ${BOLD}%s${RESET}${YELLOW}, Y/n): ${RESET}" "$DEFAULT_PASSWORD_UPPER") " new_upper_input
          # Use default if input is empty
          new_upper=$(trim "${new_upper_input:-$DEFAULT_PASSWORD_UPPER}")
          echo "" # Extra space
          if [[ "$new_upper" =~ ^[yYnN]$ ]]; then
            DEFAULT_PASSWORD_UPPER=$(echo "$new_upper" | tr '[:upper:]' '[:lower:]')
            echo -e "${GREEN}Include uppercase updated to ${BOLD}$DEFAULT_PASSWORD_UPPER${RESET}.${RESET}"
            break
          else
            echo -e "${RED}🚫 Invalid input. Please enter 'Y' or 'N'.${RESET}"
            echo "" # Extra space
          fi
        done
        ;;
      3) # Include Numbers
        local new_numbers
        while true; do
          read -rp "$(printf "${YELLOW}Include numbers? (current: ${BOLD}%s${RESET}${YELLOW}, Y/n): ${RESET}" "$DEFAULT_PASSWORD_NUMBERS") " new_numbers_input
          new_numbers=$(trim "${new_numbers_input:-$DEFAULT_PASSWORD_NUMBERS}")
          echo "" # Extra space
          if [[ "$new_numbers" =~ ^[yYnN]$ ]]; then
            DEFAULT_PASSWORD_NUMBERS=$(echo "$new_numbers" | tr '[:upper:]' '[:lower:]')
            echo -e "${GREEN}Include numbers updated to ${BOLD}$DEFAULT_PASSWORD_NUMBERS${RESET}.${RESET}"
            break
          else
            echo -e "${RED}🚫 Invalid input. Please enter 'Y' or 'N'.${RESET}"
            echo "" # Extra space
          fi
        done
        ;;
      4) # Include Symbols
        local new_symbols
        while true; do
          read -rp "$(printf "${YELLOW}Include symbols? (current: ${BOLD}%s${RESET}${YELLOW}, Y/n): ${RESET}" "$DEFAULT_PASSWORD_SYMBOLS") " new_symbols_input
          new_symbols=$(trim "${new_symbols_input:-$DEFAULT_PASSWORD_SYMBOLS}")
          echo "" # Extra space
          if [[ "$new_symbols" =~ ^[yYnN]$ ]]; then
            DEFAULT_PASSWORD_SYMBOLS=$(echo "$new_symbols" | tr '[:upper:]' '[:lower:]')
            echo -e "${GREEN}Include symbols updated to ${BOLD}$DEFAULT_PASSWORD_SYMBOLS${RESET}.${RESET}"
            break
          else
            echo -e "${RED}🚫 Invalid input. Please enter 'Y' or 'N'.${RESET}"
            echo "" # Extra space
          fi
        done
        ;;
      5) # Clipboard Clear Delay
        local new_delay
        while true; do
          read -rp "$(printf "${YELLOW}Enter new clipboard clear delay in seconds (current: ${BOLD}%s${RESET}${YELLOW}, 0 for no clear): ${RESET}" "$CLIPBOARD_CLEAR_DELAY")" new_delay_input
          new_delay=$(trim "$new_delay_input")
          echo "" # Extra space
          if [[ "$new_delay" =~ ^[0-9]+$ ]] && (( new_delay >= 0 )); then
            CLIPBOARD_CLEAR_DELAY="$new_delay"
            echo -e "${GREEN}Clipboard clear delay updated to ${BOLD}$CLIPBOARD_CLEAR_DELAY${RESET} seconds.${RESET}"
            break
          else
            echo -e "${RED}🚫 Invalid delay. Please enter a non-negative number.${RESET}"
            echo "" # Extra space
          fi
        done
        ;;
      6) # Default Data File Location
        local new_save_location
        while true; do
          read -rp "$(printf "${YELLOW}Enter new default data file directory (current: ${BOLD}%s${RESET}${YELLOW}): ${RESET}" "$SAVE_LOCATION")" new_save_location_input
          new_save_location=$(trim "$new_save_location_input")
          echo "" # Extra space
          if [[ -d "$new_save_location" ]]; then
            SAVE_LOCATION="$new_save_location"
            ENC_JSON_FILE="${SAVE_LOCATION}/${DEFAULT_ENC_FILENAME}" # Update global ENC_JSON_FILE immediately
            echo -e "${GREEN}Default data file location updated to ${BOLD}$SAVE_LOCATION${RESET}.${RESET}"
            echo -e "${YELLOW}Encrypted file will now be saved/loaded from: ${BOLD}$ENC_JSON_FILE${RESET}${YELLOW}.${RESET}"
            break
          else
            echo -e "${RED}🚫 Directory not found. Please enter a valid directory path.${RESET}"
            echo "" # Extra space
          fi
        done
        ;;
      7) # Default Search Mode
        local new_search_mode
        while true; do
          read -rp "$(printf "${YELLOW}Enter new default search mode (current: ${BOLD}%s${RESET}${YELLOW}, 'and' or 'or'): ${RESET}" "$DEFAULT_SEARCH_MODE") " new_search_mode_input
          new_search_mode=$(trim "$new_search_mode_input")
          echo "" # Extra space
          local lower_mode=$(echo "$new_search_mode" | tr '[:upper:]' '[:lower:]')
          if [[ "$lower_mode" == "and" || "$lower_mode" == "or" ]]; then
            DEFAULT_SEARCH_MODE="$lower_mode"
            echo -e "${GREEN}Default search mode updated to ${BOLD}$DEFAULT_SEARCH_MODE${RESET}.${RESET}"
            break
          else
            echo -e "${RED}🚫 Invalid input. Please enter 'and' or 'or'.${RESET}"
            echo "" # Extra space
          fi
        done
        ;;
      *)
        echo -e "${RED}❌ Invalid option. Please enter a number from 1-7 or 'Q'.${RESET}"
        echo "" # Extra space
        ;;
    esac
    save_config # Save changes after each setting update
    pause # From _utils.sh
    clear_screen
  done
}
