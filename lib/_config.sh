#!/bin/bash
# _config.sh
# Handles application configuration settings like data file location and password generation defaults.
# Sourced by passman.sh.

# --- Strict Mode for Robustness ---
set -e
set -u
set -o pipefail

# Dependencies:
# - _colors.sh (for color variables like NEON_RED, LIME_GREEN, ELECTRIC_YELLOW, RESET)
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
# - DEFAULT_EMAIL: Default email address to pre-fill in add/edit entry.
# - DEFAULT_SERVICE: Default service name to pre-fill in add/edit entry (e.g., 'Google').

# Loads configuration from the config file or sets defaults.
load_config() {
  # Ensure the config directory exists
  mkdir -p "$CONFIG_DIR"

  # Set default save location if not already set (this happens on first run)
  : "${SAVE_LOCATION:=${HOME}/Documents}" # Default to user's Documents folder
  # Set other defaults if not already set
  : "${DEFAULT_PASSWORD_LENGTH:=12}"
  : "${DEFAULT_PASSWORD_UPPER:=y}"
  : "${DEFAULT_PASSWORD_NUMBERS:=y}"
  : "${DEFAULT_PASSWORD_SYMBOLS:=y}"
  : "${CLIPBOARD_CLEAR_DELAY:=10}"
  : "${DEFAULT_SEARCH_MODE:=and}"
  : "${DEFAULT_EMAIL:=}" # Default to empty
  : "${DEFAULT_SERVICE:=}" # Default to empty


  # Check if config file exists
  if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "${AQUA}Loading configuration from ${BRIGHT_BOLD}${CONFIG_FILE}${RESET}${AQUA}...${RESET}"
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
        DEFAULT_EMAIL) DEFAULT_EMAIL="$value" ;; # Load new default email
        DEFAULT_SERVICE) DEFAULT_SERVICE="$value" ;; # Load new default service
        *) echo -e "${ELECTRIC_YELLOW}Warning: Unknown configuration key '${key}' in ${CONFIG_FILE}.${RESET}" >&2 ;;
      esac
    done < "$CONFIG_FILE"
    echo -e "${LIME_GREEN}Configuration loaded.${RESET}\n"
  else
    echo -e "${ELECTRIC_YELLOW}No configuration file found. Using default settings.${RESET}\n"
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
    echo "SAVE_LOCATION=\"$SAVE_LOCATION\"" # Quoted to handle paths with spaces
    echo "DEFAULT_PASSWORD_LENGTH=$DEFAULT_PASSWORD_LENGTH"
    echo "DEFAULT_PASSWORD_UPPER=$DEFAULT_PASSWORD_UPPER"
    echo "DEFAULT_PASSWORD_NUMBERS=$DEFAULT_PASSWORD_NUMBERS"
    echo "DEFAULT_PASSWORD_SYMBOLS=$DEFAULT_PASSWORD_SYMBOLS"
    echo "CLIPBOARD_CLEAR_DELAY=$CLIPBOARD_CLEAR_DELAY"
    echo "DEFAULT_SEARCH_MODE=\"$DEFAULT_SEARCH_MODE\"" # Quoted
    echo "DEFAULT_EMAIL=\"$DEFAULT_EMAIL\"" # Save new default email
    echo "DEFAULT_SERVICE=\"$DEFAULT_SERVICE\"" # Save new default service
  } > "$CONFIG_FILE"
  echo -e "${LIME_GREEN}Configuration saved to ${BRIGHT_BOLD}${CONFIG_FILE}${RESET}${LIME_GREEN}.${RESET}"
}

# Updates the SAVE_LOCATION in the config file.
# Arguments:
#   $1: The new path for SAVE_LOCATION.
update_save_location_in_config() {
  local new_path="$1"
  SAVE_LOCATION="$new_path" # Update the global variable
  save_config # Call save_config to write the updated global to file
  echo -e "${LIME_GREEN}Default save location updated to: ${BRIGHT_BOLD}$SAVE_LOCATION${RESET}${LIME_GREEN}.${RESET}"
}


# Allows the user to manage various application settings.
manage_settings() {
  clear_screen
  echo -e "${BRIGHT_BOLD}${VIOLET}--- Manage Settings ---${RESET}"
  echo -e "${AQUA}Configure default password generation and data file location.${RESET}\n"

  local setting_choice
  while true; do
    echo -e "${BRIGHT_BOLD}Current Settings:${RESET}"
    echo -e "  ${BRIGHT_BOLD}1)${RESET} Default Password Length: ${BRIGHT_BOLD}$DEFAULT_PASSWORD_LENGTH${RESET}"
    echo -e "  ${BRIGHT_BOLD}2)${RESET} Include Uppercase: ${BRIGHT_BOLD}$DEFAULT_PASSWORD_UPPER${RESET}"
    echo -e "  ${BRIGHT_BOLD}3)${RESET} Include Numbers: ${BRIGHT_BOLD}$DEFAULT_PASSWORD_NUMBERS${RESET}"
    echo -e "  ${BRIGHT_BOLD}4)${RESET} Include Symbols: ${BRIGHT_BOLD}$DEFAULT_PASSWORD_SYMBOLS${RESET}"
    echo -e "  ${BRIGHT_BOLD}5)${RESET} Clipboard Clear Delay (seconds): ${BRIGHT_BOLD}$CLIPBOARD_CLEAR_DELAY${RESET}"
    echo -e "  ${BRIGHT_BOLD}6)${RESET} Default Data File Location: ${BRIGHT_BOLD}$SAVE_LOCATION${RESET}"
    echo -e "  ${BRIGHT_BOLD}7)${RESET} Default Search Mode: ${BRIGHT_BOLD}$DEFAULT_SEARCH_MODE${RESET} ('and' or 'or')"
    echo -e "  ${BRIGHT_BOLD}8)${RESET} Default Email: ${BRIGHT_BOLD}${DEFAULT_EMAIL:-<empty>}${RESET}" # Display <empty> if not set
    echo -e "  ${BRIGHT_BOLD}9)${RESET} Default Service: ${BRIGHT_BOLD}${DEFAULT_SERVICE:-<empty>}${RESET}" # Display <empty> if not set
    echo -e "  ${BRIGHT_BOLD}Q)${RESET} Back to Main Menu${RESET}\n"

    read -rp "$(printf "${ELECTRIC_YELLOW}Enter setting number to change, or 'Q' to quit: ${RESET}") " setting_choice_input
    setting_choice=$(trim "$setting_choice_input")
    echo "" # Extra space

    local lower_choice
    lower_choice=$(echo "$setting_choice" | tr '[:upper:]' '[:lower:]')

    if [[ "$lower_choice" == "q" ]]; then
      clear_screen
      break
    fi

    case "$setting_choice" in
      1) # Default Password Length
        local new_length
        while true; do
          read -rp "$(printf "${ELECTRIC_YELLOW}Enter new default password length (current: ${BRIGHT_BOLD}%s${RESET}${ELECTRIC_YELLOW}, min 1): ${RESET}" "$DEFAULT_PASSWORD_LENGTH")" new_length_input
          new_length=$(trim "$new_length_input")
          echo "" # Extra space
          if [[ "$new_length" =~ ^[0-9]+$ ]] && (( new_length >= 1 )); then
            DEFAULT_PASSWORD_LENGTH="$new_length"
            echo -e "${LIME_GREEN}Default password length updated to ${BRIGHT_BOLD}$DEFAULT_PASSWORD_LENGTH${RESET}.${RESET}"
            break
          else
            echo -e "${NEON_RED}🚫 Invalid length. Please enter a positive number.${RESET}"
            echo "" # Extra space
          fi
        done
        ;;
      2) # Include Uppercase
        local new_upper
        while true; do
          read -rp "$(printf "${ELECTRIC_YELLOW}Include uppercase letters? (current: ${BRIGHT_BOLD}%s${RESET}${ELECTRIC_YELLOW}, Y/n): ${RESET}" "$DEFAULT_PASSWORD_UPPER") " new_upper_input
          # Use default if input is empty
          new_upper=$(trim "${new_upper_input:-$DEFAULT_PASSWORD_UPPER}")
          echo "" # Extra space
          if [[ "$new_upper" =~ ^[yYnN]$ ]]; then
            DEFAULT_PASSWORD_UPPER=$(echo "$new_upper" | tr '[:upper:]' '[:lower:]')
            echo -e "${LIME_GREEN}Include uppercase updated to ${BRIGHT_BOLD}$DEFAULT_PASSWORD_UPPER${RESET}.${RESET}"
            break
          else
            echo -e "${NEON_RED}🚫 Invalid input. Please enter 'Y' or 'N'.${RESET}"
            echo "" # Extra space
          fi
        done
        ;;
      3) # Include Numbers
        local new_numbers
        while true; do
          read -rp "$(printf "${ELECTRIC_YELLOW}Include numbers? (current: ${BRIGHT_BOLD}%s${RESET}${ELECTRIC_YELLOW}, Y/n): ${RESET}" "$DEFAULT_PASSWORD_NUMBERS") " new_numbers_input
          new_numbers=$(trim "${new_numbers_input:-$DEFAULT_PASSWORD_NUMBERS}")
          echo "" # Extra space
          if [[ "$new_numbers" =~ ^[yYnN]$ ]]; then
            DEFAULT_PASSWORD_NUMBERS=$(echo "$new_numbers" | tr '[:upper:]' '[:lower:]')
            echo -e "${LIME_GREEN}Include numbers updated to ${BRIGHT_BOLD}$DEFAULT_PASSWORD_NUMBERS${RESET}.${RESET}"
            break
          else
            echo -e "${NEON_RED}🚫 Invalid input. Please enter 'Y' or 'N'.${RESET}"
            echo "" # Extra space
          fi
        done
        ;;
      4) # Include Symbols
        local new_symbols
        while true; do
          read -rp "$(printf "${ELECTRIC_YELLOW}Include symbols? (current: ${BRIGHT_BOLD}%s${RESET}${ELECTRIC_YELLOW}, Y/n): ${RESET}" "$DEFAULT_PASSWORD_SYMBOLS") " new_symbols_input
          new_symbols=$(trim "${new_symbols_input:-$DEFAULT_PASSWORD_SYMBOLS}")
          echo "" # Extra space
          if [[ "$new_symbols" =~ ^[yYnN]$ ]]; then
            DEFAULT_PASSWORD_SYMBOLS=$(echo "$new_symbols" | tr '[:upper:]' '[:lower:]')
            echo -e "${LIME_GREEN}Include symbols updated to ${BRIGHT_BOLD}$DEFAULT_PASSWORD_SYMBOLS${RESET}.${RESET}"
            break
          else
            echo -e "${NEON_RED}🚫 Invalid input. Please enter 'Y' or 'N'.${RESET}"
            echo "" # Extra space
          fi
        done
        ;;
      5) # Clipboard Clear Delay
        local new_delay
        while true; do
          read -rp "$(printf "${ELECTRIC_YELLOW}Enter new clipboard clear delay in seconds (current: ${BRIGHT_BOLD}%s${RESET}${ELECTRIC_YELLOW}, 0 for no clear): ${RESET}" "$CLIPBOARD_CLEAR_DELAY")" new_delay_input
          new_delay=$(trim "$new_delay_input")
          echo "" # Extra space
          if [[ "$new_delay" =~ ^[0-9]+$ ]] && (( new_delay >= 0 )); then
            CLIPBOARD_CLEAR_DELAY="$new_delay"
            echo -e "${LIME_GREEN}Clipboard clear delay updated to ${BRIGHT_BOLD}$CLIPBOARD_CLEAR_DELAY${RESET} seconds.${RESET}"
            break
          else
            echo -e "${NEON_RED}🚫 Invalid delay. Please enter a non-negative number.${RESET}"
            echo "" # Extra space
          fi
        done
        ;;
      6) # Default Data File Location
        local new_save_location
        while true; do
          read -rp "$(printf "${ELECTRIC_YELLOW}Enter new default data file directory (current: ${BRIGHT_BOLD}%s${RESET}${ELECTRIC_YELLOW}): ${RESET}" "$SAVE_LOCATION")" new_save_location_input
          new_save_location=$(trim "$new_save_location_input")
          echo "" # Extra space
          if [[ -d "$new_save_location" ]]; then
            SAVE_LOCATION="$new_save_location"
            ENC_JSON_FILE="${SAVE_LOCATION}/${DEFAULT_ENC_FILENAME}" # Update global ENC_JSON_FILE immediately
            echo -e "${LIME_GREEN}Default data file location updated to ${BRIGHT_BOLD}$SAVE_LOCATION${RESET}.${RESET}"
            echo -e "${ELECTRIC_YELLOW}Encrypted file will now be saved/loaded from: ${BRIGHT_BOLD}$ENC_JSON_FILE${RESET}${ELECTRIC_YELLOW}.${RESET}"
            break
          else
            echo -e "${NEON_RED}🚫 Directory not found. Please enter a valid directory path.${RESET}"
            echo "" # Extra space
          fi
        done
        ;;
      7) # Default Search Mode
        local new_search_mode
        while true; do
          read -rp "$(printf "${ELECTRIC_YELLOW}Enter new default search mode (current: ${BRIGHT_BOLD}%s${RESET}${ELECTRIC_YELLOW}, 'and' or 'or'): ${RESET}" "$DEFAULT_SEARCH_MODE") " new_search_mode_input
          new_search_mode=$(trim "$new_search_mode_input")
          echo "" # Extra space
          local lower_mode=$(echo "$new_search_mode" | tr '[:upper:]' '[:lower:]')
          if [[ "$lower_mode" == "and" || "$lower_mode" == "or" ]]; then
            DEFAULT_SEARCH_MODE="$lower_mode"
            echo -e "${LIME_GREEN}Default search mode updated to ${BRIGHT_BOLD}$DEFAULT_SEARCH_MODE${RESET}.${RESET}"
            break
          else
            echo -e "${NEON_RED}🚫 Invalid input. Please enter 'and' or 'or'.${RESET}"
            echo "" # Extra space
          fi
        done
        ;;
      8) # Default Email
        local new_default_email
        while true; do
          read -rp "$(printf "${ELECTRIC_YELLOW}Enter new default email (current: ${BRIGHT_BOLD}%s${RESET}${ELECTRIC_YELLOW}, leave blank to clear, or type '${BRIGHT_BOLD}C${RESET}${ELECTRIC_YELLOW}' to cancel): ${RESET}" "${DEFAULT_EMAIL:-<empty>}") " new_default_email_input
          new_default_email=$(trim "$new_default_email_input")
          echo "" # Extra space
          local lower_input=$(echo "$new_default_email" | tr '[:upper:]' '[:lower:]')
          if [[ "$lower_input" == "c" ]]; then
            echo -e "${AQUA}Default email configuration cancelled.${RESET}"
            break 2 # Exit both loops
          fi
          DEFAULT_EMAIL="$new_default_email"
          echo -e "${LIME_GREEN}Default email updated to ${BRIGHT_BOLD}${DEFAULT_EMAIL:-<empty>}${RESET}.${RESET}"
          break
        done
        ;;
      9) # Default Service
        local new_default_service
        while true; do
          read -rp "$(printf "${ELECTRIC_YELLOW}Enter new default service (current: ${BRIGHT_BOLD}%s${RESET}${ELECTRIC_YELLOW}, leave blank to clear, or type '${BRIGHT_BOLD}C${RESET}${ELECTRIC_YELLOW}' to cancel): ${RESET}" "${DEFAULT_SERVICE:-<empty>}") " new_default_service_input
          new_default_service=$(trim "$new_default_service_input")
          echo "" # Extra space
          local lower_input=$(echo "$new_default_service" | tr '[:upper:]' '[:lower:]')
          if [[ "$lower_input" == "c" ]]; then
            echo -e "${AQUA}Default service configuration cancelled.${RESET}"
            break 2 # Exit both loops
          fi
          DEFAULT_SERVICE="$new_default_service"
          echo -e "${LIME_GREEN}Default service updated to ${BRIGHT_BOLD}${DEFAULT_SERVICE:-<empty>}${RESET}.${RESET}"
          break
        done
        ;;
      *)
        echo -e "${NEON_RED}❌ Invalid option. Please enter a number from 1-9 or 'Q'.${RESET}"
        echo "" # Extra space
        ;;
    esac
    save_config # Save changes after each setting update
    pause # From _utils.sh
    clear_screen
  done
}
