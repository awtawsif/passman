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
# - _prompts.sh (for prompt strings)
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
    echo -e "$(printf "$INFO_CONFIG_LOADING" "$CONFIG_FILE")"
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
    echo -e "$SUCCESS_CONFIG_LOADED"
  else
    echo -e "$WARNING_NO_CONFIG_FILE"
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
  echo -e "$(printf "$SUCCESS_CONFIG_SAVED" "$CONFIG_FILE")"
}

# Updates the SAVE_LOCATION in the config file.
# Arguments:
#   $1: The new path for SAVE_LOCATION.
update_save_location_in_config() {
  local new_path="$1"
  SAVE_LOCATION="$new_path" # Update the global variable
  save_config # Call save_config to write the updated global to file
  echo -e "$(printf "$SUCCESS_DEFAULT_SAVE_LOCATION_UPDATED" "$SAVE_LOCATION")"
}


# Allows the user to manage various application settings.
manage_settings() {
  clear_screen
  echo -e "$PROMPT_MANAGE_SETTINGS_TITLE"
  echo -e "$PROMPT_MANAGE_SETTINGS_HINT"

  local setting_choice
  while true; do
    echo -e "$PROMPT_CURRENT_SETTINGS"
    echo -e "$(printf "$PROMPT_SETTING_PASSWORD_LENGTH" "$DEFAULT_PASSWORD_LENGTH")"
    echo -e "$(printf "$PROMPT_SETTING_INCLUDE_UPPERCASE" "$DEFAULT_PASSWORD_UPPER")"
    echo -e "$(printf "$PROMPT_SETTING_INCLUDE_NUMBERS" "$DEFAULT_PASSWORD_NUMBERS")"
    echo -e "$(printf "$PROMPT_SETTING_INCLUDE_SYMBOLS" "$DEFAULT_PASSWORD_SYMBOLS")"
    echo -e "$(printf "$PROMPT_SETTING_CLIPBOARD_DELAY" "$CLIPBOARD_CLEAR_DELAY")"
    echo -e "$(printf "$PROMPT_SETTING_DATA_FILE_LOCATION" "$SAVE_LOCATION")"
    echo -e "$(printf "$PROMPT_SETTING_SEARCH_MODE" "$DEFAULT_SEARCH_MODE")"
    echo -e "$(printf "$PROMPT_SETTING_DEFAULT_EMAIL" "${DEFAULT_EMAIL:-<empty>}")" # Display <empty> if not set
    echo -e "$(printf "$PROMPT_SETTING_DEFAULT_SERVICE" "${DEFAULT_SERVICE:-<empty>}")" # Display <empty> if not set
    echo -e "$PROMPT_SETTING_BACK_TO_MAIN_MENU"

    read -rp "$(printf "${ELECTRIC_YELLOW}${PROMPT_ENTER_SETTING_CHOICE}${RESET}") " setting_choice_input
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
          read -rp "$(printf "${ELECTRIC_YELLOW}${PROMPT_ENTER_NEW_PASSWORD_LENGTH}${RESET}" "$DEFAULT_PASSWORD_LENGTH")" new_length_input
          new_length=$(trim "$new_length_input")
          echo "" # Extra space
          if [[ "$new_length" =~ ^[0-9]+$ ]] && (( new_length >= 1 )); then
            DEFAULT_PASSWORD_LENGTH="$new_length"
            echo -e "$(printf "$SUCCESS_PASSWORD_LENGTH_UPDATED" "$DEFAULT_PASSWORD_LENGTH")"
            break
          else
            echo -e "$ERROR_INVALID_LENGTH_POSITIVE_NUMBER"
            echo "" # Extra space
          fi
        done
        ;;
      2) # Include Uppercase
        local new_upper
        while true; do
          read -rp "$(printf "${ELECTRIC_YELLOW}${PROMPT_INCLUDE_UPPERCASE_QUESTION}${RESET}" "$DEFAULT_PASSWORD_UPPER") " new_upper_input
          # Use default if input is empty
          new_upper=$(trim "${new_upper_input:-$DEFAULT_PASSWORD_UPPER}")
          echo "" # Extra space
          if [[ "$new_upper" =~ ^[yYnN]$ ]]; then
            DEFAULT_PASSWORD_UPPER=$(echo "$new_upper" | tr '[:upper:]' '[:lower:]')
            echo -e "$(printf "$SUCCESS_INCLUDE_UPPERCASE_UPDATED" "$DEFAULT_PASSWORD_UPPER")"
            break
          else
            echo -e "$ERROR_INVALID_YES_NO_INPUT"
            echo "" # Extra space
          fi
        done
        ;;
      3) # Include Numbers
        local new_numbers
        while true; do
          read -rp "$(printf "${ELECTRIC_YELLOW}${PROMPT_INCLUDE_NUMBERS_QUESTION}${RESET}" "$DEFAULT_PASSWORD_NUMBERS") " new_numbers_input
          new_numbers=$(trim "${new_numbers_input:-$DEFAULT_PASSWORD_NUMBERS}")
          echo "" # Extra space
          if [[ "$new_numbers" =~ ^[yYnN]$ ]]; then
            DEFAULT_PASSWORD_NUMBERS=$(echo "$new_numbers" | tr '[:upper:]' '[:lower:]')
            echo -e "$(printf "$SUCCESS_INCLUDE_NUMBERS_UPDATED" "$DEFAULT_PASSWORD_NUMBERS")"
            break
          else
            echo -e "$ERROR_INVALID_YES_NO_INPUT"
            echo "" # Extra space
          fi
        done
        ;;
      4) # Include Symbols
        local new_symbols
        while true; do
          read -rp "$(printf "${ELECTRIC_YELLOW}${PROMPT_INCLUDE_SYMBOLS_QUESTION}${RESET}" "$DEFAULT_PASSWORD_SYMBOLS") " new_symbols_input
          new_symbols=$(trim "${new_symbols_input:-$DEFAULT_PASSWORD_SYMBOLS}")
          echo "" # Extra space
          if [[ "$new_symbols" =~ ^[yYnN]$ ]]; then
            DEFAULT_PASSWORD_SYMBOLS=$(echo "$new_symbols" | tr '[:upper:]' '[:lower:]')
            echo -e "$(printf "$SUCCESS_INCLUDE_SYMBOLS_UPDATED" "$DEFAULT_PASSWORD_SYMBOLS")"
            break
          else
            echo -e "$ERROR_INVALID_YES_NO_INPUT"
            echo "" # Extra space
          fi
        done
        ;;
      5) # Clipboard Clear Delay
        local new_delay
        while true; do
          read -rp "$(printf "${ELECTRIC_YELLOW}${PROMPT_ENTER_NEW_CLIPBOARD_DELAY}${RESET}" "$CLIPBOARD_CLEAR_DELAY")" new_delay_input
          new_delay=$(trim "$new_delay_input")
          echo "" # Extra space
          if [[ "$new_delay" =~ ^[0-9]+$ ]] && (( new_delay >= 0 )); then
            CLIPBOARD_CLEAR_DELAY="$new_delay"
            echo -e "$(printf "$SUCCESS_CLIPBOARD_DELAY_UPDATED" "$CLIPBOARD_CLEAR_DELAY")"
            break
          else
            echo -e "$ERROR_INVALID_DELAY_NON_NEGATIVE"
            echo "" # Extra space
          fi
        done
        ;;
      6) # Default Data File Location
        local new_save_location
        while true; do
          read -rp "$(printf "${ELECTRIC_YELLOW}${PROMPT_ENTER_NEW_SAVE_LOCATION}${RESET}" "$SAVE_LOCATION")" new_save_location_input
          new_save_location=$(trim "$new_save_location_input")
          echo "" # Extra space
          if [[ -d "$new_save_location" ]]; then
            SAVE_LOCATION="$new_save_location"
            ENC_JSON_FILE="${SAVE_LOCATION}/${DEFAULT_ENC_FILENAME}" # Update global ENC_JSON_FILE immediately
            echo -e "$(printf "$SUCCESS_DATA_FILE_LOCATION_UPDATED" "$SAVE_LOCATION")"
            echo -e "$(printf "$INFO_ENCRYPTED_FILE_LOCATION" "$ENC_JSON_FILE")"
            break
          else
            echo -e "$ERROR_DIRECTORY_NOT_FOUND"
            echo "" # Extra space
          fi
        done
        ;;
      7) # Default Search Mode
        local new_search_mode
        while true; do
          read -rp "$(printf "${ELECTRIC_YELLOW}${PROMPT_ENTER_NEW_SEARCH_MODE}${RESET}" "$DEFAULT_SEARCH_MODE") " new_search_mode_input
          new_search_mode=$(trim "$new_search_mode_input")
          echo "" # Extra space
          local lower_mode=$(echo "$new_search_mode" | tr '[:upper:]' '[:lower:]')
          if [[ "$lower_mode" == "and" || "$lower_mode" == "or" ]]; then
            DEFAULT_SEARCH_MODE="$lower_mode"
            echo -e "$(printf "$SUCCESS_SEARCH_MODE_UPDATED" "$DEFAULT_SEARCH_MODE")"
            break
          else
            echo -e "$ERROR_INVALID_SEARCH_MODE"
            echo "" # Extra space
          fi
        done
        ;;
      8) # Default Email
        local new_default_email
        while true; do
          read -rp "$(printf "${ELECTRIC_YELLOW}${PROMPT_ENTER_NEW_DEFAULT_EMAIL}${RESET}" "${DEFAULT_EMAIL:-<empty>}") " new_default_email_input
          new_default_email=$(trim "$new_default_email_input")
          echo "" # Extra space
          local lower_input=$(echo "$new_default_email" | tr '[:upper:]' '[:lower:]')
          if [[ "$lower_input" == "c" ]]; then
            echo -e "$INFO_DEFAULT_EMAIL_CANCELLED"
            break 2 # Exit both loops
          fi
          DEFAULT_EMAIL="$new_default_email"
          echo -e "$(printf "$SUCCESS_DEFAULT_EMAIL_UPDATED" "${DEFAULT_EMAIL:-<empty>}")"
          break
        done
        ;;
      9) # Default Service
        local new_default_service
        while true; do
          read -rp "$(printf "${ELECTRIC_YELLOW}${PROMPT_ENTER_NEW_DEFAULT_SERVICE}${RESET}" "${DEFAULT_SERVICE:-<empty>}") " new_default_service_input
          new_default_service=$(trim "$new_default_service_input")
          echo "" # Extra space
          local lower_input=$(echo "$new_default_service" | tr '[:upper:]' '[:lower:]')
          if [[ "$lower_input" == "c" ]]; then
            echo -e "$INFO_DEFAULT_SERVICE_CANCELLED"
            break 2 # Exit both loops
          fi
          DEFAULT_SERVICE="$new_default_service"
          echo -e "$(printf "$SUCCESS_DEFAULT_SERVICE_UPDATED" "${DEFAULT_SERVICE:-<empty>}")"
          break
        done
        ;;
      *)
        echo -e "$ERROR_INVALID_OPTION_SETTINGS"
        echo "" # Extra space
        ;;\
    esac
    save_config # Save changes after each setting update
    pause # From _utils.sh
    clear_screen
  done
}
