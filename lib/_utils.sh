#!/bin/bash
# _utils.sh
# Contains general utility functions for the password manager.
# Sourced by passman.sh.

# --- Strict Mode for Robustness ---
set -e
set -u
set -o pipefail

# Dependencies:
# - _colors.sh (for color variables)
# - _prompts.sh (for prompt strings)

# Clears the screen and displays a welcome banner.
clear_screen() {
  clear
  echo -e "$PROMPT_CLEAR_SCREEN_TITLE_LINE1"
  echo -e "$PROMPT_CLEAR_SCREEN_TITLE_LINE2"
  echo -e "$PROMPT_CLEAR_SCREEN_TITLE_LINE3"
}

# Pauses script execution until the user presses Enter, then clears the screen.
pause() {
  echo -e "$PROMPT_PRESS_ENTER_TO_CONTINUE"
  read -r
  clear_screen
}

# Trims leading and trailing whitespace from a string.
# Arguments:
#   $*: The string to trim.
# Returns:
#   Trimmed string on stdout.
trim() {
  local var="$*"
  # Remove leading whitespace
  var="${var#"${var%%[![:space:]]*}"}"
  # Remove trailing whitespace
  var="${var%"${var##*[![:space:]]}"}"
  echo -n "$var"
}

# Displays a spinning indicator while a background process is running.
# Arguments:
#   $1: PID of the background process to monitor.
#   $2: Message to display next to the spinner.
spinner() {
  local pid=$1
  local message=$2
  local delay=0.1
  local spinstr='|/-\\' # Spinning characters
  while kill -0 "$pid" 2>/dev/null; do # Check if process is still alive
    for (( i=0; i<${#spinstr}; i++ )); do
      printf "\r${AQUA}${spinstr:i:1} %s...${RESET}" "$message"
      sleep $delay
    done
  done
  # Clear the spinner line and print "Done" message
  printf "$PROMPT_SPINNER_COMPLETE_MESSAGE" "$message" # Using variable for "Done" message
}

# Prompts the user for a master password, optionally confirming it.
# Arguments:
#   $1: The message to display as a prompt.
#   $2: The name of the variable to store the password in (passed by name).
#   $3: "true" to require confirmation, "false" otherwise.
get_master_password() {
  local prompt_msg="$1"
  local password_var_name="$2" # Name of the variable to set (e.g., "MASTER_PASSWORD")
  local confirm_password="$3"

  while true; do
    printf "$PROMPT_MASTER_PASSWORD_INPUT_GENERIC" "$prompt_msg"
    read -s -r master_pass # Read password silently
    echo

    if [[ -z "$master_pass" ]]; then
      echo -e "$ERROR_MASTER_PASSWORD_EMPTY"
      continue
    fi

    if [[ "$confirm_password" == "true" ]]; then
      printf "$PROMPT_CONFIRM_MASTER_PASSWORD"
      read -s -r master_pass_confirm
      echo
      if [[ "$master_pass" != "$master_pass_confirm" ]]; then
        echo -e "$ERROR_PASSWORDS_DO_NOT_MATCH"
        continue
      fi
    fi
    # Use printf -v for safer variable assignment by name.
    printf -v "$password_var_name" "%s" "$master_pass"
    break
  done
}

# Function to get input for an optional field with REMOVE confirmation.
# Args: $1=prompt, $2=current_value, $3=variable_to_update (by name)
# Returns: 0 if input handled, 1 if user typed 'C' (cancel)
get_optional_input_with_remove() {
  local prompt_msg="$1"
  local current_val="$2"
  local var_name="$3" # The name of the variable to update (e.g., "new_email")
  local input_val

  while true; do
    read -p "$(printf "$PROMPT_OPTIONAL_INPUT_WITH_REMOVE" "$prompt_msg" "${current_val:-None}")" input_val
    input_val=$(trim "$input_val")
    echo "" # Extra space

    local lower_input
    lower_input=$(echo "$input_val" | tr '[:upper:]' '[:lower:]')

    if [[ "$lower_input" == "c" ]]; then
      return 1 # Indicate cancellation
    elif [[ -z "$input_val" ]]; then
      # User left blank, keep current value
      printf -v "$var_name" "%s" "$current_val"
      break
    elif [[ "$lower_input" == "x" ]]; then
      # User typed X, set to empty to remove from JSON
      printf -v "$var_name" "%s" ""
      echo -e "$PROMPT_FIELD_WILL_BE_REMOVED"
      break
    else
      # User provided a new value
      printf -v "$var_name" "%s" "$input_val"
      break
    fi
  done
  return 0 # Indicate success
}

# Function to get input for a conditionally mandatory field.
# Args: $1=prompt, $2=current_value, $3=variable_to_update (by name), $4=is_mandatory_flag (true/false)
# Returns: 0 if input handled, 1 if user typed 'C' (cancel)
get_mandatory_input_conditional() {
  local prompt_msg="$1"
  local current_val="$2"
  local var_name="$3" # The name of the variable to update (e.g., "new_website")
  local is_mandatory="$4"
  local input_val

  while true; do
    if [[ "$is_mandatory" == "true" ]]; then
        read -p "$(printf "$PROMPT_MANDATORY_INPUT_CONDITIONAL" "$prompt_msg" "${current_val:-None}")" input_val
        input_val=$(trim "$input_val")
        echo "" # Extra space
        local lower_input
        lower_input=$(echo "$input_val" | tr '[:upper:]' '[:lower:]')
        if [[ "$lower_input" == "c" ]]; then
          return 1 # Indicate cancellation
        fi
        if [[ -n "$input_val" ]]; then
            printf -v "$var_name" "%s" "$input_val"
            break
        else
            echo -e "$ERROR_FIELD_CANNOT_BE_EMPTY"
            echo "" # Extra space
        fi
    else # This branch should technically not be reached if get_optional_input_with_remove is used for optional fields
        # Fallback in case this is called incorrectly, treat as optional
        get_optional_input_with_remove "$prompt_msg" "$current_val" "$var_name"
        return $? # Pass on the return status of get_optional_input_with_remove
    fi
  done
  return 0 # Indicate success
}

# Copies a string to the clipboard using xclip (Linux) or pbcopy (macOS).
# Arguments:
#   $1: The string to copy.
# Returns:
#   0 if successful, 1 if no clipboard utility found.
copy_to_clipboard() {
  local text="$1"
  if command -v xclip &> /dev/null; then
    printf "%s" "$text" | xclip -selection clipboard
    return 0
  elif command -v pbcopy &> /dev/null; then
    printf "%s" "$text" | pbcopy
    return 0
  else
    echo -e "$WARNING_NO_CLIPBOARD_UTILITY"
    return 1
  fi
}
