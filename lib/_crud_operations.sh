#!/bin/bash
# _crud_operations.sh
# Contains functions for adding, editing, and removing credential entries.
# Sourced by passman.sh.

# --- Strict Mode for Robustness ---
set -e
set -u
set -o pipefail

# Dependencies:
# - _colors.sh (for color variables like NEON_RED, LIME_GREEN, ELECTRIC_YELLOW, AQUA, CYBER_BLUE, BRIGHT_BOLD, RESET)
# - _utils.sh (for clear_screen, pause, trim, get_optional_input_with_remove, get_mandatory_input_conditional)
# - _data_storage.sh (for load_entries, save_entries)
# - _password_generator.sh (for generate_password)
# - _prompts.sh (for prompt strings)
# Uses global variables: DEFAULT_PASSWORD_LENGTH, DEFAULT_PASSWORD_UPPER,
# DEFAULT_PASSWORD_NUMBERS, DEFAULT_PASSWORD_SYMBOLS, DEFAULT_EMAIL, DEFAULT_SERVICE from _config.sh.

# Prompts the user for new credential details and adds them to the JSON file.
add_entry() {
  clear_screen # From _utils.sh
  echo -e "$PROMPT_ADD_ENTRY_TITLE"
  echo -e "$PROMPT_CANCEL_OPERATION_HINT\n" # Hint for cancellation
  echo "" # Extra space

  local website email username password logged_in_via linked_email recovery_email timestamp

  while true; do
    read -rp "$(printf "${ELECTRIC_YELLOW}${PROMPT_ENTER_WEBSITE_NAME} ${RESET}") " website_input
    website=$(trim "$website_input") # From _utils.sh
    echo "" # Extra space
    if [[ "$(echo "$website" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
      echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
      pause # From _utils.sh
      return
    fi
    [[ -n "$website" ]] && break
    echo -e "$ERROR_WEBSITE_EMPTY"
    echo "" # Extra space
  done

  local logged_in_via_input_raw
  # Offer DEFAULT_SERVICE if it's set
  if [[ -n "$DEFAULT_SERVICE" ]]; then
    read -rp "$(printf "$PROMPT_LOGGED_IN_VIA_DEFAULT" "$DEFAULT_SERVICE") " logged_in_via_input_raw
  else
    read -rp "$(printf "$PROMPT_LOGGED_IN_VIA") " logged_in_via_input_raw
  fi
  logged_in_via=$(trim "$logged_in_via_input_raw") # From _utils.sh
  echo "" # Extra space

  # Handle 'X' to clear default service
  if [[ "$(echo "$logged_in_via" | tr '[:upper:]' '[:lower:]')" == "x" ]]; then
    logged_in_via=""
    echo -e "$PROMPT_DEFAULT_SERVICE_CLEARED"
  elif [[ -z "$logged_in_via" && -n "$DEFAULT_SERVICE" ]]; then
    logged_in_via="$DEFAULT_SERVICE" # Use default if user pressed Enter
    echo -e "$(printf "$PROMPT_USING_DEFAULT_SERVICE" "$logged_in_via")"
  fi

  if [[ "$(echo "$logged_in_via" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
    echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
    pause # From _utils.sh
    return
  fi


  if [[ -n "$logged_in_via" ]]; then
    # Prompt for linked email (mandatory if logged_in_via is set, but can be 'X' to remove default)
    while true; do
      local linked_email_prompt
      if [[ -n "$DEFAULT_EMAIL" ]]; then
        linked_email_prompt="$PROMPT_LINKED_EMAIL_DEFAULT"
        read -rp "$(printf "$linked_email_prompt" "$logged_in_via" "$DEFAULT_EMAIL")" linked_email_input
      else
        linked_email_prompt="$PROMPT_LINKED_EMAIL"
        read -rp "$(printf "$linked_email_prompt" "$logged_in_via")" linked_email_input
      fi
      linked_email=$(trim "$linked_email_input") # From _utils.sh
      echo "" # Extra space

      if [[ "$(echo "$linked_email" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
        echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
        pause # From _utils.sh
        return
      fi

      # Handle 'X' to clear default email
      if [[ "$(echo "$linked_email" | tr '[:upper:]' '[:lower:]')" == "x" ]]; then
        linked_email=""
        echo -e "$PROMPT_DEFAULT_EMAIL_CLEARED"
      elif [[ -z "$linked_email" && -n "$DEFAULT_EMAIL" ]]; then
        linked_email="$DEFAULT_EMAIL" # Use default if user pressed Enter
        echo -e "$(printf "$PROMPT_USING_DEFAULT_EMAIL" "$linked_email")"
      fi

      [[ -n "$linked_email" ]] && break
      echo -e "$ERROR_LINKED_EMAIL_EMPTY"
      echo "" # Extra space
    done

    # Prompt for username (optional)
    read -rp "$(printf "$PROMPT_ENTER_USERNAME_OPTIONAL") " username_input
    username=$(trim "$username_input")
    echo "" # Extra space

    email=""        # Ensure email is empty if logging in via another service
  else
    while true; do
      local email_prompt
      if [[ -n "$DEFAULT_EMAIL" ]]; then
        email_prompt="$PROMPT_EMAIL_DEFAULT"
        read -rp "$(printf "$email_prompt" "$DEFAULT_EMAIL") " email_input
      else
        email_prompt="$PROMPT_EMAIL"
        read -rp "$(printf "$email_prompt") " email_input
      fi
      email=$(trim "$email_input") # From _utils.sh
      echo "" # Extra space

      if [[ "$(echo "$email" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
        echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
        pause # From _utils.sh
        return
      fi

      # Handle 'X' to clear default email
      if [[ "$(echo "$email" | tr '[:upper:]' '[:lower:]')" == "x" ]]; then
        email=""
        echo -e "$PROMPT_DEFAULT_EMAIL_CLEARED"
      elif [[ -z "$email" && -n "$DEFAULT_EMAIL" ]]; then
        email="$DEFAULT_EMAIL" # Use default if user pressed Enter
        echo -e "$(printf "$PROMPT_USING_DEFAULT_EMAIL" "$email")"
      fi

      if [[ "$(echo "$email" | tr '[:upper:]' '[:lower:]')" == "u" ]]; then
        # User wants to use username instead of email (mandatory)
        while true; do
          read -rp "$(printf "$PROMPT_ENTER_USERNAME_MANDATORY") " username_input
          username=$(trim "$username_input")
          echo "" # Extra space
          if [[ "$(echo "$username" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
            echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
            pause # From _utils.sh
            return
          fi
          [[ -n "$username" ]] && break
          echo -e "$ERROR_USERNAME_EMPTY"
          echo "" # Extra space
        done
        email=""
        break
      fi
      if [[ -n "$email" ]]; then
        # Optionally prompt for username (can leave blank)
        read -rp "$(printf "$PROMPT_ENTER_USERNAME_OPTIONAL_EMAIL_USED") " username_input
        username=$(trim "$username_input")
        echo "" # Extra space
        break
      fi
      echo -e "$ERROR_EMAIL_EMPTY_OR_USERNAME_OPTION"
      echo "" # Extra space
    done
    linked_email="" # Ensure linked_email is empty if direct email is used
  fi

  local recovery_email_input
  while true; do
    read -rp "$(printf "$PROMPT_RECOVERY_EMAIL_OPTIONAL") " recovery_email_input
    recovery_email=$(trim "$recovery_email_input") # From _utils.sh
    echo "" # Extra space
    if [[ "$(echo "$recovery_email" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
      echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
      pause # From _utils.sh
      return
    fi
    break # Optional field, can be empty
  done

  local use_generator
  while true; do
    read -rp "$(printf "$PROMPT_GENERATE_PASSWORD") " use_generator_input
    use_generator=$(trim "${use_generator_input:-n}") # Default to 'n'
    echo "" # Extra space
    if [[ "$(echo "$use_generator" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
      echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
      pause # From _utils.sh
      return
    fi
    if [[ "$use_generator" =~ ^[yYnN]$ ]]; then
      break
    fi
    echo -e "$ERROR_INVALID_YES_NO_INPUT"
    echo "" # Extra space
  done

  if [[ "$use_generator" =~ ^[yY]$ ]]; then
    # Directly use global defaults for password generation when adding a new entry
    password=$(generate_password "$DEFAULT_PASSWORD_LENGTH" "$DEFAULT_PASSWORD_UPPER" "$DEFAULT_PASSWORD_NUMBERS" "$DEFAULT_PASSWORD_SYMBOLS") # From _password_generator.sh
    echo -e "$(printf "$PROMPT_GENERATED_PASSWORD" "$password")"
  else
    # If not generating, prompt for manual password entry
    if [[ -n "$logged_in_via" ]]; then
      # If using service login, password for service is optional
      while true; do
        printf "$PROMPT_ENTER_SERVICE_PASSWORD_OPTIONAL"
        read -s password_input # Read password silently
        echo
        password=$(trim "$password_input") # From _utils.sh
        echo "" # Extra space
        if [[ "$(echo "$password" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
          echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
          pause # From _utils.sh
          return
        fi
        break
      done
    else
      # If not using service login, password for website is mandatory
      while true; do
        printf "$PROMPT_ENTER_WEBSITE_PASSWORD_MANDATORY"
        read -s password_input # Read password silently
        echo
        password=$(trim "$password_input") # From _utils.sh
        echo "" # Extra space
        if [[ "$(echo "$password" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
          echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
          pause # From _utils.sh
          return
        fi
        [[ -n "$password" ]] && break
        echo -e "$ERROR_WEBSITE_PASSWORD_EMPTY"
        echo "" # Extra space
      done
    fi
  fi

  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  # Load existing entries from the JSON file
  local entries_json
  entries_json=$(load_entries) # From _data_storage.sh
  if [[ $? -ne 0 ]]; then
    pause # From _utils.sh
    return
  fi

  # Create a new JSON object for the entry, dynamically adding fields if they are not empty
  local new_entry_json
  new_entry_json=$(jq -n \
    --arg website "$website" \
    --arg email "$email" \
    --arg username "$username" \
    --arg password "$password" \
    --arg logged_in_via "$logged_in_via" \
    --arg linked_email "$linked_email" \
    --arg recovery_email "$recovery_email" \
    --arg added "$timestamp" \
    '{website: $website, email: $email, username: $username, password: $password, logged_in_via: $logged_in_via, linked_email: $linked_email, recovery_email: $recovery_email, added: $added}' \
  | jq 'walk(if type == "string" and . == "" then empty else . end)') # Remove empty fields

  # Append the new entry to the existing JSON array and save it back
  local updated_entries_json
  updated_entries_json=$(echo "$entries_json" | jq --argjson new_entry "$new_entry_json" '. + [$new_entry]')

  # --- Confirmation before saving ---
  echo -e "\n$PROMPT_REVIEW_NEW_ENTRY"
  echo -e "  🌐 Website      : ${BRIGHT_BOLD}$website${RESET}"
  if [[ -n "$logged_in_via" ]]; then
    echo -e "  🔗 Logged in via: ${BRIGHT_BOLD}$logged_in_via${RESET}"
    [[ -n "$linked_email" ]] && echo -e "  📧 Linked Email : ${BRIGHT_BOLD}$linked_email${RESET}"
    [[ -n "$username" ]] && echo -e "  👤 Username     : ${BRIGHT_BOLD}$username${RESET}"
  elif [[ -n "$email" ]]; then
    echo -e "  📧 Email        : ${BRIGHT_BOLD}$email${RESET}"
  elif [[ -n "$username" ]]; then
    echo -e "  👤 Username     : ${BRIGHT_BOLD}$username${RESET}"
  fi
  if [[ -n "$recovery_email" ]]; then
    echo -e "  🚨 Recovery Email: ${BRIGHT_BOLD}$recovery_email${RESET}"
  fi
  if [[ -n "$password" ]]; then # Only display if password exists
    echo -e "  🔑 Password     : ${BRIGHT_BOLD}$password${RESET}" # Display for confirmation
  fi
  echo -e "  📅 Added        : ${BRIGHT_BOLD}$timestamp${RESET}"
  echo "" # Extra space

  local confirm_save
  while true; do
    read -rp "$(printf "$PROMPT_CONFIRM_SAVE_ENTRY") " confirm_save_input
    confirm_save=$(trim "${confirm_save_input:-y}") # From _utils.sh - Default to 'y'
    echo "" # Extra space
    if [[ "$(echo "$confirm_save" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
      echo -e "$PROMPT_ENTRY_NOT_SAVED"
      pause # From _utils.sh
      return
    fi
    if [[ "$confirm_save" =~ ^[yYnN]$ ]]; then
      break
    fi
    echo -e "$ERROR_INVALID_YES_NO_INPUT"
    echo "" # Extra space
  done

  if [[ "$confirm_save" =~ ^[yY]$ ]]; then
    save_entries "$updated_entries_json" # From _data_storage.sh
    echo -e "$SUCCESS_ENTRY_ADDED_SAVED"
  else
    echo -e "$PROMPT_ENTRY_NOT_SAVED"
  fi
  pause # From _utils.sh
}

# Allows the user to select and edit an existing entry.
edit_entry() {
  clear_screen # From _utils.sh
  echo -e "$PROMPT_EDIT_ENTRY_TITLE"
  echo -e "$PROMPT_CANCEL_OPERATION_HINT\n" # Hint for cancellation
  echo "" # Extra space

  local entries_json
  entries_json=$(load_entries) # From _data_storage.sh
  if [[ $? -ne 0 ]]; then
    pause # From _utils.sh
    return
  fi

  local num_entries
  num_entries=$(echo "$entries_json" | jq 'length')

  if [[ "$num_entries" -eq 0 ]]; then
    echo -e "$PROMPT_NO_ENTRIES_TO_EDIT"
    pause # From _utils.sh
    return
  fi

  # Display entries with numbers for selection
  echo -e "$PROMPT_CHOOSE_ENTRY_TO_EDIT"
  echo "" # Extra space

  # Define ANSI color codes for awk.
  local bold_code=$BRIGHT_BOLD # From _colors.sh
  local reset_code=$RESET # From _colors.sh

  echo "$entries_json" | jq -r '
    .[] |
    # Prepare optional fields for awk. Output website always.
    # Then for email/service:
    # If logged_in_via and linked_email are present, use linked_email and service.
    # Else if email is present, use email.
    # Otherwise, empty string for these parts.
    .website + "\t" +
    (if (.logged_in_via | length > 0) and (.linked_email | length > 0) then "Account Email: " + .linked_email
     elif (.email | length > 0) then "Account Email: " + .email
     else ""
     end) + "\t" +
    (if (.logged_in_via | length > 0) then "Service: " + .logged_in_via
     else ""
     end) + "\t" +
    (if (.recovery_email | length > 0) then "Recovery Email: " + .recovery_email
     else ""
     end)
  ' | awk -F'\t' \
    -v BOLD_AWK="${bold_code}" \
    -v RESET_AWK="${reset_code}" \
    '{
    printf "  %s[%d]%s %s", BOLD_AWK, NR, RESET_AWK, $1 # Website is always printed

    # info_in_paren will track if any info (email, service, recovery_email) is printed inside parentheses
    info_in_paren = 0;

    if ($2 != "") { # Account Email part (e.g., "Account Email: user@example.com")
        printf " (%s", $2
        info_in_paren = 1
    }

    if ($3 != "") { # Service part (e.g., "Service: Google")
        if (info_in_paren == 1) { # If email was printed, add comma
            printf ", %s", $3
        } else { # If no email, just open parenthesis for service
            printf " (%s", $3
        }
        info_in_paren = 1 # Mark that info was printed
    }

    if ($4 != "") { # Recovery Email part (new field)
        if (info_in_paren == 1) { # If any other info was printed, add comma
            printf ", %s", $4
        } else { # If no other info, just open parenthesis for recovery email
            printf " (%s", $4
        }
        info_in_paren = 1 # Mark that info was printed
    }

    if (info_in_paren == 1) { # Close parenthesis if any info was printed
        printf ")"
    }
    printf "\n"
  }'
  echo "" # Extra space

  local selected_index
  while true; do
    read -rp "$(printf "$PROMPT_ENTER_ENTRY_NUMBER_TO_EDIT" "$num_entries")" selected_index_input
    selected_index=$(trim "$selected_index_input") # From _utils.sh
    echo "" # Extra space

    local lower_input
    lower_input=$(echo "$selected_index" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
      pause # From _utils.sh
      return
    fi

    if [[ "$selected_index" =~ ^[0-9]+$ ]] && (( selected_index >= 1 && selected_index <= num_entries )); then
      break
    fi
    echo -e "$(printf "$ERROR_INVALID_ENTRY_NUMBER" "$num_entries")"
    echo "" # Extra space
  done

  # Get the selected entry's current data
  local current_entry_json
  current_entry_json=$(echo "$entries_json" | jq ".[$((selected_index - 1))]")

  # Extract current values for all fields
  local current_website
  current_website=$(echo "$current_entry_json" | jq -r '.website // ""')
  local current_email
  current_email=$(echo "$current_entry_json" | jq -r '.email // ""')
  local current_username
  current_username=$(echo "$current_entry_json" | jq -r '.username // ""')
  local current_password
  current_password=$(echo "$current_entry_json" | jq -r '.password // ""')
  local current_logged_in_via
  current_logged_in_via=$(echo "$current_entry_json" | jq -r '.logged_in_via // ""')
  local current_linked_email
  current_linked_email=$(echo "$current_entry_json" | jq -r '.linked_email // ""')
  local current_recovery_email
  current_recovery_email=$(echo "$current_entry_json" | jq -r '.recovery_email // ""')
  local current_added
  current_added=$(echo "$current_entry_json" | jq -r '.added // ""')

  # Variables to hold new values, initialized with current values
  local new_website="$current_website"
  local new_email="$current_email"
  local new_username="$current_username"
  local new_password="$current_password"
  local new_logged_in_via="$current_logged_in_via"
  local new_linked_email="$current_linked_email"
  local new_recovery_email="$current_recovery_email"

  # --- Display preview of the selected entry ---
  display_single_entry_details() {
    local entry_json_to_display="$1"
    echo -e "$(printf "$PROMPT_CURRENTLY_SELECTED_ENTRY" "$selected_index")"
    echo -e "  🌐 Website      : ${BRIGHT_BOLD}$(echo "$entry_json_to_display" | jq -r '.website // ""')${RESET}"
    local disp_logged_in_via=$(echo "$entry_json_to_display" | jq -r '.logged_in_via // ""')
    local disp_linked_email=$(echo "$entry_json_to_display" | jq -r '.linked_email // ""')
    local disp_username=$(echo "$entry_json_to_display" | jq -r '.username // ""')
    local disp_email=$(echo "$entry_json_to_display" | jq -r '.email // ""')
    local disp_recovery_email=$(echo "$entry_json_to_display" | jq -r '.recovery_email // ""')
    local disp_password=$(echo "$entry_json_to_display" | jq -r '.password // ""')
    local disp_added=$(echo "$entry_json_to_display" | jq -r '.added // ""')

    if [[ -n "$disp_logged_in_via" ]]; then
      echo -e "  🔗 Logged in via: ${BRIGHT_BOLD}$disp_logged_in_via${RESET}"
      [[ -n "$disp_linked_email" ]] && echo -e "  📧 Linked Email : ${BRIGHT_BOLD}$disp_linked_email${RESET}"
      [[ -n "$disp_username" ]] && echo -e "  👤 Username     : ${BRIGHT_BOLD}$disp_username${RESET}"
    elif [[ -n "$disp_email" ]]; then
      echo -e "  📧 Email        : ${BRIGHT_BOLD}$disp_email${RESET}"
      [[ -n "$disp_username" ]] && echo -e "  👤 Username     : ${BRIGHT_BOLD}$disp_username${RESET}"
    elif [[ -n "$disp_username" ]]; then
      echo -e "  👤 Username     : ${BRIGHT_BOLD}$disp_username${RESET}"
    fi
    if [[ -n "$disp_recovery_email" ]]; then
      echo -e "  🚨 Recovery Email: ${BRIGHT_BOLD}$disp_recovery_email${RESET}"
    fi
    if [[ -n "$disp_password" ]]; then
        echo -e "  🔑 Password     : ${BRIGHT_BOLD}$disp_password${RESET}"
    fi
    echo -e "  📅 Added        : ${BRIGHT_BOLD}$disp_added${RESET}"
    echo "" # Extra space
  }

  display_single_entry_details "$current_entry_json"

  local field_options=(
    "Website"
    "Email"
    "Username"
    "Password"
    "Logged in via"
    "Linked Email"
    "Recovery Email"
  )
  local field_vars=(
    "new_website"
    "new_email"
    "new_username"
    "new_password"
    "new_logged_in_via"
    "new_linked_email"
    "new_recovery_email"
  )
  local field_prompts=(
    "$PROMPT_UPDATE_WEBSITE_NAME"
    "$PROMPT_UPDATE_EMAIL"
    "$PROMPT_UPDATE_USERNAME"
    "$PROMPT_UPDATE_WEBSITE_PASSWORD"
    "$PROMPT_UPDATE_LOGGED_IN_VIA"
    "$PROMPT_UPDATE_LINKED_EMAIL"
    "$PROMPT_UPDATE_RECOVERY_EMAIL"
  )

  local continue_editing="y"
  while [[ "$continue_editing" =~ ^[yY]$ ]]; do
    echo -e "$PROMPT_SELECT_FIELD_TO_EDIT"
    for i in "${!field_options[@]}"; do
      local current_val_for_display
      # Dynamically get the current value for display in the menu
      case "${field_options[$i]}" in
        "Website") current_val_for_display="$new_website" ;;
        "Email") current_val_for_display="$new_email" ;;
        "Username") current_val_for_display="$new_username" ;;
        "Password") current_val_for_display="********" ;; # Mask password
        "Logged in via") current_val_for_display="$new_logged_in_via" ;;
        "Linked Email") current_val_for_display="$new_linked_email" ;;
        "Recovery Email") current_val_for_display="$new_recovery_email" ;;
      esac
      echo -e "  ${BRIGHT_BOLD}$((i+1)))${RESET} ${field_options[$i]} ${TEXT_CYAN}(current: ${BRIGHT_BOLD}${current_val_for_display:-None}${TEXT_CYAN})${RESET}"
    done
    echo "" # Extra space
    echo -e "  ${AQUA}${BRIGHT_BOLD}Q)${RESET} Finish Editing and Review"
    echo "" # Extra space

    local field_choice
    read -rp "$(printf "${ELECTRIC_YELLOW}${PROMPT_ENTER_FIELD_NUMBER_TO_EDIT}${RESET} ") " field_choice_input
    field_choice=$(trim "$field_choice_input")
    echo "" # Extra space

    local lower_field_choice=$(echo "$field_choice" | tr '[:upper:]' '[:lower:]')

    if [[ "$lower_field_choice" == "q" ]]; then
      break # Exit editing loop
    fi

    if [[ "$lower_field_choice" == "c" ]]; then
      echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
      pause
      return
    fi

    if ! [[ "$field_choice" =~ ^[0-9]+$ ]] || (( field_choice < 1 || field_choice > ${#field_options[@]} )); then
      echo -e "$ERROR_INVALID_FIELD_NUMBER"
      echo "" # Extra space
      continue
    fi

    local selected_field_idx=$((field_choice - 1))
    local selected_field_name="${field_options[$selected_field_idx]}"
    local selected_field_var_name="${field_vars[$selected_field_idx]}"
    local selected_field_prompt="${field_prompts[$selected_field_idx]}"

    clear_screen
    echo -e "$(printf "$PROMPT_EDITING_FIELD" "$selected_field_name")"

    case "$selected_field_name" in
      "Website")
        if ! get_mandatory_input_conditional "$selected_field_prompt" "${!selected_field_var_name}" "$selected_field_var_name" "true"; then
          echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
          pause
          return
        fi
        ;;
      "Email")
        # If logged_in_via is set, email should be cleared.
        if [[ -n "$new_logged_in_via" ]]; then
          echo -e "$WARNING_CANNOT_SET_EMAIL_WITH_SERVICE"
          echo -e "${AQUA}To set an email, first remove the 'Logged in via' service.${RESET}"
          pause
          continue
        fi
        local prompt_email_default="${!selected_field_var_name}"
        if [[ -z "${!selected_field_var_name}" && -n "$DEFAULT_EMAIL" ]]; then
          prompt_email_default="$DEFAULT_EMAIL"
        fi
        if ! get_optional_input_with_remove "$selected_field_prompt" "$prompt_email_default" "$selected_field_var_name"; then
          echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
          pause
          return
        fi
        # If email is set, clear username and linked_email
        if [[ -n "${!selected_field_var_name}" ]]; then
          new_username=""
          new_linked_email=""
        fi
        ;;
      "Username")
        # If logged_in_via is set, username is for service. If email is set, username is optional.
        if [[ -n "$new_email" ]]; then
          # Username is optional if email is set
          if ! get_optional_input_with_remove "$selected_field_prompt" "${!selected_field_var_name}" "$selected_field_var_name"; then
            echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
            pause
            return
          fi
        elif [[ -z "$new_logged_in_via" ]]; then
          # Username is mandatory if no email and no service
          if ! get_mandatory_input_conditional "$selected_field_prompt" "${!selected_field_var_name}" "$selected_field_var_name" "true"; then
            echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
            pause
            return
          fi
          new_email="" # Clear email if username is used as primary identifier
        else
          # Username for service, optional
          if ! get_optional_input_with_remove "$selected_field_prompt" "${!selected_field_var_name}" "$selected_field_var_name"; then
            echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
            pause
            return
          fi
        fi
        ;;
      "Password")
        local use_generator_choice # Renamed to avoid clash with potential 'use_generator' from password generation block
        while true; do
          read -rp "$(printf "$PROMPT_GENERATE_NEW_PASSWORD") " use_generator_choice_input
          use_generator_choice_input=$(trim "${use_generator_choice_input:-n}") # From _utils.sh - Default to 'n'
          echo "" # Extra space
          local lower_input
          lower_input=$(echo "$use_generator_choice_input" | tr '[:upper:]' '[:lower:]')
          if [[ "$lower_input" == "c" ]]; then
            echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
            pause # From _utils.sh
            return
          fi
          if [[ "$use_generator_choice_input" =~ ^[yYnN]$ ]]; then
            use_generator_choice="$use_generator_choice_input"
            break
          fi
          echo -e "$ERROR_INVALID_YES_NO_INPUT"
          echo "" # Extra space
        done

        if [[ "$use_generator_choice" =~ ^[yY]$ ]]; then
          local length
          while true; do
            read -rp "$(printf "$PROMPT_NEW_PASSWORD_LENGTH" "$DEFAULT_PASSWORD_LENGTH")" length_input
            length_input=$(trim "$length_input") # From _utils.sh
            echo "" # Extra space
            local lower_input
            lower_input=$(echo "$length_input" | tr '[:upper:]' '[:lower:]')
            if [[ "$lower_input" == "c" ]]; then
              echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
              pause # From _utils.sh
              return
            fi
            length=${length_input:-$DEFAULT_PASSWORD_LENGTH} # Use global default
            if [[ "$length" =~ ^[0-9]+$ && "$length" -ge 1 ]]; then
              break
            fi
            echo -e "$ERROR_INVALID_LENGTH"
            echo "" # Extra space
          done

          local upper numbers symbols
          while true; do
            read -rp "$(printf "$PROMPT_INCLUDE_UPPERCASE" "$DEFAULT_PASSWORD_UPPER")" upper_input
            upper=$(trim "${upper_input:-$DEFAULT_PASSWORD_UPPER}") # Use global default
            echo "" # Extra space
            local lower_input
            lower_input=$(echo "$upper_input" | tr '[:upper:]' '[:lower:]')
            if [[ "$lower_input" == "c" ]]; then
              echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
              pause # From _utils.sh
              return
            fi
            if [[ "$upper" =~ ^[yYnN]$ ]]; then
              break
            fi
            echo -e "$ERROR_INVALID_YES_NO_INPUT"
            echo "" # Extra space
          done

          while true; do
            read -rp "$(printf "$PROMPT_INCLUDE_NUMBERS" "$DEFAULT_PASSWORD_NUMBERS")" numbers_input
            numbers=$(trim "${numbers_input:-$DEFAULT_PASSWORD_NUMBERS}") # Use global default
            echo "" # Extra space
            local lower_input
            lower_input=$(echo "$numbers_input" | tr '[:upper:]' '[:lower:]')
            if [[ "$lower_input" == "c" ]]; then
              echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
              pause # From _utils.sh
              return
            fi
            if [[ "$numbers" =~ ^[yYnN]$ ]]; then
              break
            fi
            echo -e "$ERROR_INVALID_YES_NO_INPUT"
            echo "" # Extra space
          done

          while true; do
            read -rp "$(printf "$PROMPT_INCLUDE_SYMBOLS" "$DEFAULT_PASSWORD_SYMBOLS")" symbols_input
            symbols=$(trim "${symbols_input:-$DEFAULT_PASSWORD_SYMBOLS}") # Use global default
            echo "" # Extra space
            local lower_input
            lower_input=$(echo "$symbols_input" | tr '[:upper:]' '[:lower:]')
            if [[ "$lower_input" == "c" ]]; then
              echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
              pause # From _utils.sh
              return
            fi
            if [[ "$symbols" =~ ^[yYnN]$ ]]; then
              break
            fi
            echo -e "$ERROR_INVALID_YES_NO_INPUT"
            echo "" # Extra space
          done

          new_password=$(generate_password "$length" "$upper" "$numbers" "$symbols") # From _password_generator.sh
          echo -e "$(printf "$PROMPT_GENERATED_NEW_PASSWORD" "$new_password")"
        else
            # If not generating, prompt for manual password entry
            if ! get_optional_input_with_remove "$selected_field_prompt" "$current_password" new_password; then
              echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
              pause
              return
            fi
        fi
        ;;
      "Logged in via")
        local prompt_logged_in_via_default="$new_logged_in_via"
        if [[ -z "$new_logged_in_via" && -n "$DEFAULT_SERVICE" ]]; then
          prompt_logged_in_via_default="$DEFAULT_SERVICE"
        fi
        if ! get_optional_input_with_remove "$selected_field_prompt" "$prompt_logged_in_via_default" new_logged_in_via; then
          echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
          pause
          return
        fi

        # If logged_in_via is set, clear email
        if [[ -n "$new_logged_in_via" ]]; then
          new_email=""
        else
          # If logged_in_via is cleared, also clear linked_email and username for service
          new_linked_email=""
          new_username=""
        fi
        ;;
      "Linked Email")
        # Linked email is only applicable if "Logged in via" is set
        if [[ -z "$new_logged_in_via" ]]; then
          echo -e "$WARNING_CANNOT_SET_LINKED_EMAIL_WITHOUT_SERVICE"
          echo -e "${AQUA}To set a linked email, first set the 'Logged in via' service.${RESET}"
          pause
          continue
        fi
        local prompt_linked_email_default="$new_linked_email"
        if [[ -z "$new_linked_email" && -n "$DEFAULT_EMAIL" ]]; then
          prompt_linked_email_default="$DEFAULT_EMAIL"
        fi
        if ! get_optional_input_with_remove "$(printf "$selected_field_prompt" "$new_logged_in_via")" "$prompt_linked_email_default" new_linked_email; then
          echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
          pause
          return
        fi
        # If linked email is set, clear username for service
        if [[ -n "$new_linked_email" ]]; then
          new_username=""
        fi
        ;;
      "Recovery Email")
        if ! get_optional_input_with_remove "$selected_field_prompt" "${!selected_field_var_name}" "$selected_field_var_name"; then
          echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
          pause
          return
        fi
        ;;
    esac

    # After each field edit, show the updated preview
    local temp_updated_entry_json_for_preview=$(jq -n \
      --arg website "$new_website" \
      --arg email "$new_email" \
      --arg username "$new_username" \
      --arg password "$new_password" \
      --arg logged_in_via "$new_logged_in_via" \
      --arg linked_email "$new_linked_email" \
      --arg recovery_email "$new_recovery_email" \
      --arg added "$current_added" \
      '{website: $website, email: $email, username: $username, password: $password, logged_in_via: $logged_in_via, linked_email: $linked_email, recovery_email: $recovery_email, added: $added}' \
    | jq 'walk(if type == "string" and . == "" then empty else . end)') # Remove empty fields

    clear_screen
    echo -e "$PROMPT_CURRENT_ENTRY_STATUS"
    display_single_entry_details "$temp_updated_entry_json_for_preview"

    # Ask if user wants to edit another field
    while true; do
      read -rp "$(printf "$PROMPT_EDIT_ANOTHER_FIELD") " continue_editing_input
      continue_editing=$(trim "${continue_editing_input:-y}")
      echo "" # Extra space
      if [[ "$(echo "$continue_editing" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
        echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
        pause
        return
      fi
      if [[ "$continue_editing" =~ ^[yYnN]$ ]]; then
        break
      fi
      echo -e "$ERROR_INVALID_YES_NO_INPUT"
      echo "" # Extra space
    done
    clear_screen # Clear screen before showing field selection again
  done

  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  # Build the updated entry dynamically using jq --arg, which handles escaping correctly
  local updated_single_entry_json
  updated_single_entry_json=$(jq -n \
    --arg website "$new_website" \
    --arg email "$new_email" \
    --arg username "$new_username" \
    --arg password "$new_password" \
    --arg logged_in_via "$new_logged_in_via" \
    --arg linked_email "$new_linked_email" \
    --arg recovery_email "$new_recovery_email" \
    --arg added "$timestamp" \
    '{website: $website, email: $email, username: $username, password: $password, logged_in_via: $logged_in_via, linked_email: $linked_email, recovery_email: $recovery_email, added: $added}' \
  | jq 'walk(if type == "string" and . == "" then empty else . end)') # Remove empty fields

  # Update the entry in the JSON array
  local updated_entries_json
  updated_entries_json=$(echo "$entries_json" | \
    jq --arg idx "$((selected_index - 1))" \
       --argjson updated_entry "$updated_single_entry_json" \
       '.[$idx | tonumber] = $updated_entry')

  local confirm_update
  echo -e "\n$PROMPT_REVIEW_UPDATED_ENTRY"
  echo -e "  🌐 Website      : ${BRIGHT_BOLD}$new_website${RESET}"
  if [[ -n "$new_logged_in_via" ]]; then
    echo -e "  🔗 Logged in via: ${BRIGHT_BOLD}$new_logged_in_via${RESET}"
    [[ -n "$new_linked_email" ]] && echo -e "  📧 Linked Email : ${BRIGHT_BOLD}$new_linked_email${RESET}"
    [[ -n "$new_username" ]] && echo -e "  👤 Username     : ${BRIGHT_BOLD}$new_username${RESET}"
  elif [[ -n "$new_email" ]]; then
    echo -e "  📧 Email        : ${BRIGHT_BOLD}$new_email${RESET}"
  elif [[ -n "$new_username" ]]; then
    echo -e "  👤 Username     : ${BRIGHT_BOLD}$new_username${RESET}"
  fi
  if [[ -n "$new_recovery_email" ]]; then
    echo -e "  🚨 Recovery Email: ${BRIGHT_BOLD}$new_recovery_email${RESET}"
  fi
  if [[ -n "$new_password" ]]; then
      echo -e "  🔑 Password     : ${BRIGHT_BOLD}$new_password${RESET}"
  fi
  echo -e "  📅 Updated      : ${BRIGHT_BOLD}$timestamp${RESET}"
  echo "" # Extra space

  while true; do
    read -rp "$(printf "$PROMPT_CONFIRM_SAVE_CHANGES") " confirm_update_input
    confirm_update=$(trim "${confirm_update_input:-y}") # From _utils.sh - Default to 'y'
    echo "" # Extra space
    local lower_input
    lower_input=$(echo "$confirm_update" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "$PROMPT_CHANGES_NOT_SAVED"
      pause # From _utils.sh
      return
    fi
    if [[ "$confirm_update" =~ ^[yYnN]$ ]]; then
      break
    fi
    echo -e "$ERROR_INVALID_YES_NO_INPUT"
    echo "" # Extra space
  done

  if [[ "$confirm_update" =~ ^[yY]$ ]]; then
    save_entries "$updated_entries_json" # From _data_storage.sh
    echo -e "$SUCCESS_ENTRY_UPDATED_SAVED"
  else
    echo -e "$PROMPT_CHANGES_NOT_SAVED"
  fi
  pause # From _utils.sh
}

# Allows the user to select and remove one or multiple existing entries.
remove_entry() {
  clear_screen # From _utils.sh
  echo -e "$PROMPT_REMOVE_ENTRY_TITLE"
  echo -e "$PROMPT_CANCEL_OPERATION_HINT\n" # Hint for cancellation
  echo "" # Extra space

  local entries_json
  entries_json=$(load_entries) # From _data_storage.sh
  if [[ $? -ne 0 ]]; then
    pause # From _utils.sh
    return
  fi

  local num_entries
  num_entries=$(echo "$entries_json" | jq 'length')

  if [[ "$num_entries" -eq 0 ]]; then
    echo -e "$PROMPT_NO_ENTRIES_TO_REMOVE"
    pause # From _utils.sh
    return
  fi

  # Display entries with numbers for selection
  echo -e "$PROMPT_CHOOSE_ENTRY_TO_REMOVE"
  echo "" # Extra space

  # Define ANSI color codes for awk.
  local bold_code=$BRIGHT_BOLD # From _colors.sh
  local reset_code=$RESET # From _colors.sh

  echo "$entries_json" | jq -r '
    .[] |
    # Prepare optional fields for awk. Output website always.
    # Then for email/service:
    # If logged_in_via and linked_email are present, use linked_email and service.
    # Else if email is present, use email.
    # Otherwise, empty string for these parts.
    .website + "\t" +
    (if (.logged_in_via | length > 0) and (.linked_email | length > 0) then "Account Email: " + .linked_email
     elif (.email | length > 0) then "Account Email: " + .email
     else ""
     end) + "\t" +
    (if (.logged_in_via | length > 0) then "Service: " + .logged_in_via
     else ""
     end) + "\t" +
    (if (.recovery_email | length > 0) then "Recovery Email: " + .recovery_email
     else ""
     end)
  ' | awk -F'\t' \
    -v BOLD_AWK="${bold_code}" \
    -v RESET_AWK="${reset_code}" \
    '{
    printf "  %s[%d]%s %s", BOLD_AWK, NR, RESET_AWK, $1 # Website is always printed

    # info_in_paren will track if any info (email, service, recovery_email) is printed inside parentheses
    info_in_paren = 0;

    if ($2 != "") { # Account Email part (e.g., "Account Email: user@example.com")
        printf " (%s", $2
        info_in_paren = 1
    }

    if ($3 != "") { # Service part (e.g., "Service: Google")
        if (info_in_paren == 1) { # If email was printed, add comma
            printf ", %s", $3
        } else { # If no email, just open parenthesis for service
            printf " (%s", $3
        }
        info_in_paren = 1 # Mark that info was printed
    }

    if ($4 != "") { # Recovery Email part (new field)
        if (info_in_paren == 1) { # If any other info was printed, add comma
            printf ", %s", $4
        } else { # If no other info, just open parenthesis for recovery email
            printf " (%s", $4
        }
        info_in_paren = 1 # Mark that info was printed
    }

    if (info_in_paren == 1) { # Close parenthesis if any info was printed
        printf ")"
    }
    printf "\n"
  }'
  echo "" # Extra space

  local selected_indices_str
  local selected_indices=()
  local valid_indices=()

  while true; do
    read -rp "$(printf "$PROMPT_ENTER_NUMBERS_TO_REMOVE") " selected_indices_str_input
    selected_indices_str=$(trim "$selected_indices_str_input") # From _utils.sh
    echo "" # Extra space

    local lower_input
    lower_input=$(echo "$selected_indices_str" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "$PROMPT_OPERATION_CANCELLED_RETURN_MENU"
      pause # From _utils.sh
      return
    fi

    IFS=',' read -r -a selected_indices <<< "$selected_indices_str"
    valid_indices=()
    local all_valid=true

    for idx_str in "${selected_indices[@]}"; do
      local idx
      idx=$(trim "$idx_str") # From _utils.sh
      if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= num_entries )); then
        valid_indices+=("$idx")
      else
        echo -e "$(printf "$ERROR_INVALID_ENTRY_NUMBER_REMOVE" "$idx_str")"
        all_valid=false
        break
      fi
    done

    if [[ "$all_valid" == "true" ]] && [[ "${#valid_indices[@]}" -gt 0 ]]; then
      # Sort indices in descending order to avoid array shifting issues during deletion
      IFS=$'\n' sorted_indices=($(sort -nr <<<"${valid_indices[*]}"))
      unset IFS
      valid_indices=("${sorted_indices[@]}")
      break
    elif [[ "$all_valid" == "true" ]] && [[ "${#valid_indices[@]}" -eq 0 ]]; then
      echo -e "$ERROR_NO_VALID_ENTRIES_SELECTED"
    fi
    echo "" # Extra space
  done

  # --- Display preview of selected entries for removal ---
  echo -e "\n$PROMPT_ENTRIES_TO_BE_PERMANENTLY_REMOVED"

  # Use the same preview format as view_entries_formatted for the selected entries
  local entries_to_remove_json
  entries_to_remove_json=$(echo "$entries_json" | jq "[ $(IFS=,; for idx in "${valid_indices[@]}"; do echo ".[$((idx-1))]"; done | paste -sd, -) ]")

  # Define ANSI color codes for awk.
  local bold_code=$BRIGHT_BOLD
  local reset_code=$RESET
  local cyan_code=$AQUA
  local blue_code=$CYBER_BLUE

  echo "$entries_to_remove_json" | jq -r '
    .[] |
    "\(.website)\t\(.email // "")\t\(.username // "")\t\(.password // "")\t\(.logged_in_via // "")\t\(.linked_email // "")\t\(.recovery_email // "")\t\(.added)"
  ' | awk -F'\t' \
    -v BOLD_AWK="${bold_code}" \
    -v RESET_AWK="${reset_code}" \
    -v CYAN_AWK="${cyan_code}" \
    -v BLUE_AWK="${blue_code}" \
    '{
      printf "  %s%s%s\n", BLUE_AWK, "===================================", RESET_AWK
      printf "  %sEntry %d:%s\n", BOLD_AWK, NR, RESET_AWK
      printf "    %s🌐 Website      :%s %s\n", CYAN_AWK, RESET_AWK, $1
      if ($2 != "") {
          printf "    %s📧 Email        :%s %s\n", CYAN_AWK, RESET_AWK, $2
      }
      if ($3 != "") {
          printf "    %s👤 Username     :%s %s\n", CYAN_AWK, RESET_AWK, $3
      }
      if ($4 != "") {
          printf "    %s🔑 Password     :%s %s\n", CYAN_AWK, RESET_AWK, $4
      }
      if ($5 != "") {
          printf "    %s🔗 Logged in via:%s %s\n", CYAN_AWK, RESET_AWK, $5
      }
      if ($6 != "") {
          printf "    %s📧 Linked email :%s %s\n", CYAN_AWK, RESET_AWK, $6
      }
      if ($7 != "") {
          printf "    %s🚨 Recovery email:%s %s\n", CYAN_AWK, RESET_AWK, $7
      }
      printf "    %s📅 Added        :%s %s\n", CYAN_AWK, RESET_AWK, $8
      printf "  %s%s%s\n", BLUE_AWK, "===================================", RESET_AWK
    }' || true
  echo "" # Extra space

  local confirm_removal
  while true; do
    read -rp "$(printf "$PROMPT_CONFIRM_PERMANENT_REMOVAL") " confirm_removal_input
    confirm_removal=$(trim "${confirm_removal_input:-n}") # From _utils.sh - Default to 'n'
    echo "" # Extra space
    local lower_input
    lower_input=$(echo "$confirm_removal" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "$PROMPT_REMOVAL_CANCELLED"
      pause # From _utils.sh
      return
    fi
    if [[ "$confirm_removal" =~ ^[yYnN]$ ]]; then
      break
    fi
    echo -e "$ERROR_INVALID_YES_NO_INPUT_REMOVE"
    echo "" # Extra space
  done

  if [[ "$confirm_removal" =~ ^[yY]$ ]]; then
    local updated_entries_json="$entries_json"
    for idx in "${valid_indices[@]}"; do
      echo -e "$(printf "$PROMPT_REMOVING_ENTRY" "$idx")"
      # Remove the entry using jq. Note: indices are 0-based in jq.
      updated_entries_json=$(echo "$updated_entries_json" | jq "del(.[$((idx - 1))])")
    done
    save_entries "$updated_entries_json" # From _data_storage.sh
    echo -e "$SUCCESS_ENTRIES_REMOVED"
  else
    echo -e "$PROMPT_REMOVAL_CANCELLED_GENERIC"
  fi
  pause # From _utils.sh
}
