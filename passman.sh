#!/bin/bash
# passman.sh
# Main entry point for the Secure Password Manager.
# This script orchestrates the application flow, handling authentication
# and loading various functional modules.

# --- Strict Mode for Robustness ---
# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error and exit.
set -u
# Print commands and their arguments as they are executed (useful for debugging).
# The return value of a pipeline is the value of the last (rightmost) command
# to exit with a non-zero status, or zero if all commands in the pipeline exit successfully.
set -o pipefail

# --- Source Library Files ---
# Ensure the current directory is added to the PATH for sourcing.
# This makes sure the script can find the 'lib' directory regardless of where it's run from.
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/lib/_colors.sh"            # Defines color codes
source "${SCRIPT_DIR}/lib/_utils.sh"             # General utility functions
source "${SCRIPT_DIR}/lib/_crypto.sh"            # Encryption/Decryption and cleanup logic
source "${SCRIPT_DIR}/lib/_data_storage.sh"      # Load/Save JSON data
source "${SCRIPT_DIR}/lib/_password_generator.sh" # Password generation logic
source "${SCRIPT_DIR}/lib/_crud_operations.sh"   # Add, Edit, Remove operations
source "${SCRIPT_DIR}/lib/_display_search.sh"    # Display and Search functions
source "${SCRIPT_DIR}/lib/_change_master.sh"     # Change master password logic
source "${SCRIPT_DIR}/lib/_config.sh"            # Configuration management (new)

# --- Global Variables (Managed by main_loop and cleanup_on_exit) ---
# Path to the configuration directory (e.g., where passman.conf is stored)
CONFIG_DIR="${HOME}/.config/passman" # Changed to a more standard XDG Base Directory location
# Path to the configuration file
CONFIG_FILE="${CONFIG_DIR}/passman.conf"
# Default filename for the encrypted credentials
DEFAULT_ENC_FILENAME="credentials.json.enc"

# Stores the directory where the encrypted file is saved (loaded from config or defaulted)
SAVE_LOCATION=""
# The full path to the securely encrypted file. This will be set dynamically.
ENC_JSON_FILE=""

# Global config variables, initialized with their defaults (will be overwritten by load_config if specified in file)
DEFAULT_PASSWORD_LENGTH=12
DEFAULT_PASSWORD_UPPER="y"
DEFAULT_PASSWORD_NUMBERS="y"
DEFAULT_PASSWORD_SYMBOLS="y"
CLIPBOARD_CLEAR_DELAY=10 # seconds
DEFAULT_SEARCH_MODE="and" # "and" or "or"

# Stores the master password during the session (critical for crypto functions).
MASTER_PASSWORD=""
# Flag to track if the user has authenticated successfully.
IS_AUTHENTICATED="false"
# Stores the decrypted JSON data in memory.
CREDENTIALS_DATA=""

# --- Dependency Checks ---
# Ensures that 'jq' and 'openssl' are installed.
check_dependencies() {
  echo -e "${AQUA}Checking system dependencies...${RESET}"
  if ! command -v jq &> /dev/null; then
    echo -e "${NEON_RED}${BRIGHT_BOLD}Error: 'jq' is not installed.${RESET}"
    echo -e "${NEON_RED}Please install 'jq' to use this script (e.g., on Debian/Ubuntu: ${ELECTRIC_YELLOW}sudo apt-get install jq${NEON_RED}).${RESET}"
    exit 1
  fi
  if ! command -v openssl &> /dev/null; then
    echo -e "${NEON_RED}${BRIGHT_BOLD}Error: 'openssl' is not installed.${RESET}"
    echo -e "${NEON_RED}Please install 'openssl' to use this script (e.g., on Debian/Ubuntu: ${ELECTRIC_YELLOW}sudo apt-get install openssl${NEON_RED}).${RESET}"
    exit 1
  fi
  # Clipboard utility check (warn only)
  if ! command -v xclip &> /dev/null && ! command -v pbcopy &> /dev/null; then
    echo -e "${ELECTRIC_YELLOW}⚠️  Clipboard integration not available. Install ${BRIGHT_BOLD}xclip${RESET}${ELECTRIC_YELLOW} (Linux) or ${BRIGHT_BOLD}pbcopy${RESET}${ELECTRIC_YELLOW} (macOS) for copy-to-clipboard support.${RESET}"
  fi
  echo -e "${LIME_GREEN}Dependencies met. Proceeding...${RESET}\n"
}

# --- MAIN APPLICATION LOGIC ---
main_loop() {
  clear_screen

  # Ensure all necessary external tools (jq, openssl) are installed
  check_dependencies

  # Load the saved configuration for file location and other settings, sets ENC_JSON_FILE
  load_config

  # Handle initial setup or regular login
  if [[ ! -f "$ENC_JSON_FILE" ]]; then
    echo -e "${ELECTRIC_YELLOW}🔑 No encrypted credentials file found at ${BRIGHT_BOLD}${ENC_JSON_FILE}${RESET}${ELECTRIC_YELLOW}. This appears to be your first run or the file was moved.${RESET}"
    echo -e "${ELECTRIC_YELLOW}You'll be prompted to set up your master password for encryption.${RESET}"
    echo -e "${BRIGHT_BOLD}${NEON_RED}🚨 WARNING: Remember this password! There is NO recovery if you forget it.${RESET}"
    # get_master_password is from _utils.sh
    get_master_password "Set your new master password: " MASTER_PASSWORD "true" # Prompt for confirmation

    if [[ -z "$MASTER_PASSWORD" ]]; then
      echo -e "${NEON_RED}🚫 Master password not set. Exiting.${RESET}"
      exit 1
    fi

    # Initialize in-memory data with an empty JSON array
    CREDENTIALS_DATA="[]"
    IS_AUTHENTICATED="true" # Mark as authenticated so cleanup will encrypt
    echo -e "${LIME_GREEN}✅ Initial credentials file created and encrypted!${RESET}"
    clear_screen # Clear after initial setup messages

  else
    # Regular login: Prompt for master password and decrypt
    echo -e "${BRIGHT_BOLD}${VIOLET}--- Welcome Back! ---${RESET}"
    echo -e "${AQUA}Enter your master password to unlock your credentials.${RESET}\n"
    get_master_password "🔑 Enter master password to unlock: " MASTER_PASSWORD "false"

    if [[ -z "$MASTER_PASSWORD" ]]; then
      echo -e "${NEON_RED}🚫 Master password not provided. Exiting.${RESET}"
      exit 1
    fi

    echo -e "${AQUA}Attempting to decrypt credentials from ${BRIGHT_BOLD}${ENC_JSON_FILE}${RESET}${AQUA}...${RESET}"
    # read_encrypted_file is from _data_storage.sh
    if read_encrypted_file "$ENC_JSON_FILE" "$MASTER_PASSWORD"; then
      IS_AUTHENTICATED="true" # Mark as authenticated
      echo -e "${LIME_GREEN}✅ Credentials decrypted successfully!${RESET}"
      clear_screen
    else
      echo -e "${NEON_RED}❌ Incorrect master password or corrupted file. Please verify your password and try again.${RESET}"
      exit 1
    fi
  fi

  # Main menu loop (only accessible if authenticated)
  if [[ "$IS_AUTHENTICATED" == "true" ]]; then
    while true; do
      echo -e "${BRIGHT_BOLD}${VIOLET}--- Main Menu ---${RESET}"
      echo -e "${AQUA}Select an option to manage your passwords.${RESET}\n"
      echo -e "${BRIGHT_BOLD}1)${RESET} ${ELECTRIC_YELLOW}Add new entry${RESET}"
      echo -e "${BRIGHT_BOLD}2)${RESET} ${ELECTRIC_YELLOW}Search entries${RESET}"
      echo -e "${BRIGHT_BOLD}3)${RESET} ${ELECTRIC_YELLOW}View all entries${RESET}"
      echo -e "${BRIGHT_BOLD}4)${RESET} ${ELECTRIC_YELLOW}Edit existing entry${RESET}"
      echo -e "${BRIGHT_BOLD}5)${RESET} ${ELECTRIC_YELLOW}Remove entry${RESET}"
      echo -e "${BRIGHT_BOLD}6)${RESET} ${ELECTRIC_YELLOW}Quit${RESET}"
      echo -e "${BRIGHT_BOLD}7)${RESET} ${ELECTRIC_YELLOW}Change master password${RESET}"
      echo -e "${BRIGHT_BOLD}8)${RESET} ${ELECTRIC_YELLOW}Manage Settings${RESET}"
      echo -e "${BRIGHT_BOLD}9)${RESET} ${ELECTRIC_YELLOW}Load another credentials file${RESET}" # New menu item
      echo "" # Extra space
      read -rp "$(printf "${ELECTRIC_YELLOW}Enter your choice [1-9]:${RESET} ") " choice
      choice=$(trim "$choice") # trim is from _utils.sh
      echo "" # Extra space

      case "$choice" in
        1) add_entry ;; # from _crud_operations.sh
        2) search_entries ;; # from _display_search.sh
        3) view_all_entries_menu ;; # from _display_search.sh
        4) edit_entry ;; # from _crud_operations.sh
        5) remove_entry ;; # from _crud_operations.sh
        6) echo -e "${AQUA}👋 Goodbye! Your data is securely locked.${RESET}"; exit 0 ;; # Exits, triggering trap
        7)
          # Store current state before attempting to change master password
          local original_master_password_before_change="$MASTER_PASSWORD"
          local original_credentials_data_before_change="$CREDENTIALS_DATA"

          if change_master_password; then
            echo -e "${LIME_GREEN}Master password updated successfully.${RESET}"
          else
            echo -e "${NEON_RED}Failed to change master password. Reverting to previous password and data.${RESET}"
            # Revert to original state if change failed
            MASTER_PASSWORD="$original_master_password_before_change"
            CREDENTIALS_DATA="$original_credentials_data_before_change"
            # No need to change ENC_JSON_FILE as it would not have been moved if encryption failed
          fi
          ;;
        8) manage_settings ;; # from _config.sh
        9)
          # Store current state in temporary variables in case the load operation fails.
          local original_enc_json_file="$ENC_JSON_FILE"
          local original_master_password="$MASTER_PASSWORD"
          local original_credentials_data="$CREDENTIALS_DATA"
          local original_is_authenticated="$IS_AUTHENTICATED"

          # Call the function to load an external file.
          # This function now directly updates the global variables if successful.
          if load_external_credentials; then
            echo -e "${LIME_GREEN}Successfully switched to new credentials file.${RESET}"
          else
            echo -e "${ELECTRIC_YELLOW}Failed to load external credentials or operation cancelled. Reverting to previous session.${RESET}"
            # Revert global variables to their original state
            ENC_JSON_FILE="$original_enc_json_file"
            MASTER_PASSWORD="$original_master_password"
            CREDENTIALS_DATA="$original_credentials_data"
            IS_AUTHENTICATED="$original_is_authenticated"
          fi
          ;;
        *) echo -e "${NEON_RED}❌ Invalid option. Please enter a number between ${BRIGHT_BOLD}1${RESET}${NEON_RED} and ${BRIGHT_BOLD}9${RESET}${NEON_RED}.${RESET}" ;;
      esac
    done
  fi
}

# --- Trap for Cleanup (defined in _crypto.sh, but needs to be set here in main script) ---
# Register cleanup function to run on exit, interrupt, and terminate signals.
# The cleanup_on_exit function is sourced from _crypto.sh.
trap cleanup_on_exit EXIT INT TERM

# --- Execute the main application loop ---
main_loop
