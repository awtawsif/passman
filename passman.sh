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
  echo -e "${CYAN}Checking system dependencies...${RESET}"
  if ! command -v jq &> /dev/null; then
    echo -e "${RED}${BOLD}Error: 'jq' is not installed.${RESET}"
    echo -e "${RED}Please install 'jq' to use this script (e.g., on Debian/Ubuntu: ${YELLOW}sudo apt-get install jq${RED}).${RESET}"
    exit 1
  fi
  if ! command -v openssl &> /dev/null; then
    echo -e "${RED}${BOLD}Error: 'openssl' is not installed.${RESET}"
    echo -e "${RED}Please install 'openssl' to use this script (e.g., on Debian/Ubuntu: ${YELLOW}sudo apt-get install openssl${RED}).${RESET}"
    exit 1
  fi
  # Clipboard utility check (warn only)
  if ! command -v xclip &> /dev/null && ! command -v pbcopy &> /dev/null; then
    echo -e "${YELLOW}⚠️  Clipboard integration not available. Install ${BOLD}xclip${RESET}${YELLOW} (Linux) or ${BOLD}pbcopy${RESET}${YELLOW} (macOS) for copy-to-clipboard support.${RESET}"
  fi
  echo -e "${GREEN}Dependencies met. Proceeding...${RESET}\n"
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
    echo -e "${YELLOW}🔑 No encrypted credentials file found at ${BOLD}${ENC_JSON_FILE}${RESET}${YELLOW}. This appears to be your first run or the file was moved.${RESET}"
    echo -e "${YELLOW}You'll be prompted to set up your master password for encryption.${RESET}"
    echo -e "${BOLD}${RED}🚨 WARNING: Remember this password! There is NO recovery if you forget it.${RESET}"
    # get_master_password is from _utils.sh
    get_master_password "Set your new master password: " MASTER_PASSWORD "true" # Prompt for confirmation

    if [[ -z "$MASTER_PASSWORD" ]]; then
      echo -e "${RED}🚫 Master password not set. Exiting.${RESET}"
      exit 1
    fi

    # Initialize in-memory data with an empty JSON array
    CREDENTIALS_DATA="[]"
    IS_AUTHENTICATED="true" # Mark as authenticated so cleanup will encrypt
    echo -e "${GREEN}✅ Initial credentials file created and encrypted!${RESET}"
    clear_screen # Clear after initial setup messages

  else
    # Regular login: Prompt for master password and decrypt
    echo -e "${BOLD}${MAGENTA}--- Welcome Back! ---${RESET}"
    echo -e "${CYAN}Enter your master password to unlock your credentials.${RESET}\n"
    get_master_password "🔑 Enter master password to unlock: " MASTER_PASSWORD "false"

    if [[ -z "$MASTER_PASSWORD" ]]; then
      echo -e "${RED}🚫 Master password not provided. Exiting.${RESET}"
      exit 1
    fi

    echo -e "${CYAN}Attempting to decrypt credentials from ${BOLD}${ENC_JSON_FILE}${RESET}${CYAN}...${RESET}"
    # decrypt_data is from _crypto.sh
    # Redirect stderr of decrypt_data to /dev/null to suppress OpenSSL warnings/errors
    local decrypted_content
    decrypted_content=$(decrypt_data "$ENC_JSON_FILE" "$MASTER_PASSWORD" 2>/dev/null)
    local decrypt_status=$?

    if [[ "$decrypt_status" -ne 0 ]]; then
      echo -e "${RED}❌ Incorrect master password or corrupted file. Please verify your password and try again.${RESET}"
      exit 1
    fi

    # If openssl returned 0, it means decryption *appeared* to succeed,
    # but the content might still not be valid JSON (e.g., if the file was corrupted
    # but the password was technically correct, or openssl produced non-JSON output).
    # This check is crucial to catch that.
    if echo "$decrypted_content" | jq -e . &>/dev/null; then
      CREDENTIALS_DATA="$decrypted_content" # Store decrypted content in memory
      IS_AUTHENTICATED="true" # Mark as authenticated
      echo -e "${GREEN}✅ Credentials decrypted successfully!${RESET}"
      clear_screen
    else
      echo -e "${RED}❌ The decrypted content is corrupted or not valid JSON. Unable to proceed. Please check the encrypted file.${RESET}" >&2
      exit 1
    fi
  fi

  # Main menu loop (only accessible if authenticated)
  if [[ "$IS_AUTHENTICATED" == "true" ]]; then
    while true; do
      echo -e "${BOLD}${MAGENTA}--- Main Menu ---${RESET}"
      echo -e "${CYAN}Select an option to manage your passwords.${RESET}\n"
      echo -e "${BOLD}1)${RESET} ${YELLOW}Add new entry${RESET}"
      echo -e "${BOLD}2)${RESET} ${YELLOW}Search entries${RESET}"
      echo -e "${BOLD}3)${RESET} ${YELLOW}View all entries${RESET}"
      echo -e "${BOLD}4)${RESET} ${YELLOW}Edit existing entry${RESET}"
      echo -e "${BOLD}5)${RESET} ${YELLOW}Remove entry${RESET}"
      echo -e "${BOLD}6)${RESET} ${YELLOW}Quit${RESET}"
      echo -e "${BOLD}7)${RESET} ${YELLOW}Change master password${RESET}"
      echo -e "${BOLD}8)${RESET} ${YELLOW}Manage Settings${RESET}" # Updated menu item
      echo "" # Extra space
      read -rp "$(printf "${YELLOW}Enter your choice [1-8]:${RESET} ") " choice
      choice=$(trim "$choice") # trim is from _utils.sh
      echo "" # Extra space

      case "$choice" in
        1) add_entry ;; # from _crud_operations.sh
        2) search_entries ;; # from _display_search.sh
        3) view_all_entries_menu ;; # from _display_search.sh
        4) edit_entry ;; # from _crud_operations.sh
        5) remove_entry ;; # from _crud_operations.sh
        6) echo -e "${CYAN}👋 Goodbye! Your data is securely locked.${RESET}"; exit 0 ;; # Exits, triggering trap
        7) change_master_password ;; # from _change_master.sh
        8) manage_settings ;; # from _config.sh (new)
        *) echo -e "${RED}❌ Invalid option. Please enter a number between ${BOLD}1${RESET}${RED} and ${BOLD}8${RESET}${RED}.${RESET}" ;;
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
