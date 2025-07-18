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
# Uses global variables: DEFAULT_PASSWORD_LENGTH, DEFAULT_PASSWORD_UPPER,
# DEFAULT_PASSWORD_NUMBERS, DEFAULT_PASSWORD_SYMBOLS, DEFAULT_EMAIL, DEFAULT_SERVICE from _config.sh.

# Prompts the user for new credential details and adds them to the JSON file.
add_entry() {
  clear_screen # From _utils.sh
  echo -e "${BRIGHT_BOLD}${VIOLET}--- Add New Credential Entry ---${RESET}"
  echo -e "${AQUA}💡 At any point, type '${BRIGHT_BOLD}C${RESET}${AQUA}' to cancel this operation.${RESET}\n" # Hint for cancellation
  echo "" # Extra space

  local website email username password logged_in_via linked_email recovery_email timestamp

  while true; do
    read -rp "$(printf "${ELECTRIC_YELLOW}🌐 Enter Website Name: ${RESET}") " website_input
    website=$(trim "$website_input") # From _utils.sh
    echo "" # Extra space
    if [[ "$(echo "$website" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
      echo -e "${AQUA}Operation cancelled. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi
    [[ -n "$website" ]] && break
    echo -e "${NEON_RED}🚫 Website/Service name cannot be empty! Please provide a value or type '${AQUA}C' to cancel.${RESET}"
    echo "" # Extra space
  done

  local logged_in_via_input_raw
  # Offer DEFAULT_SERVICE if it's set
  if [[ -n "$DEFAULT_SERVICE" ]]; then
    read -rp "$(printf "${ELECTRIC_YELLOW}🔗 Did you log into this site using another service (e.g., Google, Facebook)? (Default: ${BRIGHT_BOLD}%s${RESET}${ELECTRIC_YELLOW}, Leave blank if not, '${BRIGHT_BOLD}X${RESET}${ELECTRIC_YELLOW}' to clear default): ${RESET}" "$DEFAULT_SERVICE") " logged_in_via_input_raw
  else
    read -rp "$(printf "${ELECTRIC_YELLOW}🔗 Did you log into this site using another service (e.g., Google, Facebook)? (Leave blank if not): ${RESET}") " logged_in_via_input_raw
  fi
  logged_in_via=$(trim "$logged_in_via_input_raw") # From _utils.sh
  echo "" # Extra space

  # Handle 'X' to clear default service
  if [[ "$(echo "$logged_in_via" | tr '[:upper:]' '[:lower:]')" == "x" ]]; then
    logged_in_via=""
    echo -e "${AQUA}Default service cleared for this entry.${RESET}"
  elif [[ -z "$logged_in_via" && -n "$DEFAULT_SERVICE" ]]; then
    logged_in_via="$DEFAULT_SERVICE" # Use default if user pressed Enter
    echo -e "${AQUA}Using default service: ${BRIGHT_BOLD}$logged_in_via${RESET}.${RESET}"
  fi

  if [[ "$(echo "$logged_in_via" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
    echo -e "${AQUA}Operation cancelled. Returning to main menu.${RESET}"
    pause # From _utils.sh
    return
  fi


  if [[ -n "$logged_in_via" ]]; then
    # Prompt for linked email (mandatory if logged_in_via is set, but can be 'X' to remove default)
    while true; do
      local linked_email_prompt
      if [[ -n "$DEFAULT_EMAIL" ]]; then
        linked_email_prompt="📧 Enter the email used for ${BRIGHT_BOLD}%s${RESET} (Default: ${BRIGHT_BOLD}%s${RESET}${ELECTRIC_YELLOW}, cannot be empty, '${BRIGHT_BOLD}X${RESET}${ELECTRIC_YELLOW}' to clear default, type 'C' to cancel): ${RESET}"
        read -rp "$(printf "$linked_email_prompt" "$logged_in_via" "$DEFAULT_EMAIL")" linked_email_input
      else
        linked_email_prompt="📧 Enter the email used for ${BRIGHT_BOLD}%s${RESET} (cannot be empty, type 'C' to cancel): ${RESET}"
        read -rp "$(printf "$linked_email_prompt" "$logged_in_via")" linked_email_input
      fi
      linked_email=$(trim "$linked_email_input") # From _utils.sh
      echo "" # Extra space

      if [[ "$(echo "$linked_email" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
        echo -e "${AQUA}Operation cancelled. Returning to main menu.${RESET}"
        pause # From _utils.sh
        return
      fi

      # Handle 'X' to clear default email
      if [[ "$(echo "$linked_email" | tr '[:upper:]' '[:lower:]')" == "x" ]]; then
        linked_email=""
        echo -e "${AQUA}Default email cleared for this entry.${RESET}"
      elif [[ -z "$linked_email" && -n "$DEFAULT_EMAIL" ]]; then
        linked_email="$DEFAULT_EMAIL" # Use default if user pressed Enter
        echo -e "${AQUA}Using default email: ${BRIGHT_BOLD}$linked_email${RESET}.${RESET}"
      fi

      [[ -n "$linked_email" ]] && break
      echo -e "${NEON_RED}🚫 Linked email cannot be empty if a service is specified! Please provide a value or type '${AQUA}C' to cancel.${RESET}"
      echo "" # Extra space
    done

    # Prompt for username (optional)
    read -rp "$(printf "${ELECTRIC_YELLOW}👤 Enter a username for this service (optional, leave blank if none):${RESET} ")" username_input
    username=$(trim "$username_input")
    echo "" # Extra space

    email=""        # Ensure email is empty if logging in via another service
  else
    while true; do
      local email_prompt
      if [[ -n "$DEFAULT_EMAIL" ]]; then
        email_prompt="📧 Enter your Email for this site (Default: ${BRIGHT_BOLD}%s${RESET}${ELECTRIC_YELLOW}, cannot be empty, or type 'U' to use username, '${BRIGHT_BOLD}X${RESET}${ELECTRIC_YELLOW}' to clear default):${RESET} "
        read -rp "$(printf "$email_prompt" "$DEFAULT_EMAIL") " email_input
      else
        email_prompt="📧 Enter your Email for this site (cannot be empty, or type 'U' to use username):${RESET} "
        read -rp "$(printf "$email_prompt") " email_input
      fi
      email=$(trim "$email_input") # From _utils.sh
      echo "" # Extra space

      if [[ "$(echo "$email" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
        echo -e "${AQUA}Operation cancelled. Returning to main menu.${RESET}"
        pause # From _utils.sh
        return
      fi

      # Handle 'X' to clear default email
      if [[ "$(echo "$email" | tr '[:upper:]' '[:lower:]')" == "x" ]]; then
        email=""
        echo -e "${AQUA}Default email cleared for this entry.${RESET}"
      elif [[ -z "$email" && -n "$DEFAULT_EMAIL" ]]; then
        email="$DEFAULT_EMAIL" # Use default if user pressed Enter
        echo -e "${AQUA}Using default email: ${BRIGHT_BOLD}$email${RESET}.${RESET}"
      fi

      if [[ "$(echo "$email" | tr '[:upper:]' '[:lower:]')" == "u" ]]; then
        # User wants to use username instead of email (mandatory)
        while true; do
          read -rp "$(printf "${ELECTRIC_YELLOW}👤 Enter your Username for this site (cannot be empty):${RESET} ") " username_input
          username=$(trim "$username_input")
          echo "" # Extra space
          if [[ "$(echo "$username" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
            echo -e "${AQUA}Operation cancelled. Returning to main menu.${RESET}"
            pause # From _utils.sh
            return
          fi
          [[ -n "$username" ]] && break
          echo -e "${NEON_RED}🚫 Username cannot be empty! Please provide a value or type '${AQUA}C' to cancel.${RESET}"
          echo "" # Extra space
        done
        email=""
        break
      fi
      if [[ -n "$email" ]]; then
        # Optionally prompt for username (can leave blank)
        read -rp "$(printf "${ELECTRIC_YELLOW}👤 Enter a username for this site (optional, leave blank if none):${RESET} ")" username_input
        username=$(trim "$username_input")
        echo "" # Extra space
        break
      fi
      echo -e "${NEON_RED}🚫 Email cannot be empty! Please provide a value, type '${AQUA}C' to cancel, or '${AQUA}U' to use username.${RESET}"
      echo "" # Extra space
    done
    linked_email="" # Ensure linked_email is empty if direct email is used
  fi

  local recovery_email_input
  while true; do
    read -rp "$(printf "${ELECTRIC_YELLOW}🚨 Recovery Email (optional, leave blank if none):${RESET} ") " recovery_email_input
    recovery_email=$(trim "$recovery_email_input") # From _utils.sh
    echo "" # Extra space
    if [[ "$(echo "$recovery_email" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
      echo -e "${AQUA}Operation cancelled. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi
    break # Optional field, can be empty
  done

  local use_generator
  while true; do
    read -rp "$(printf "${ELECTRIC_YELLOW}🔑 Generate a random password for this entry? (${BRIGHT_BOLD}y/N${RESET}${ELECTRIC_YELLOW}):${RESET}") " use_generator_input
    use_generator=$(trim "${use_generator_input:-n}") # Default to 'n'
    echo "" # Extra space
    if [[ "$(echo "$use_generator" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
      echo -e "${AQUA}Operation cancelled. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi
    if [[ "$use_generator" =~ ^[yYnN]$ ]]; then
      break
    fi
    echo -e "${NEON_RED}🚫 Invalid input. Please enter '${BRIGHT_BOLD}Y${RESET}${NEON_RED}' for Yes, '${BRIGHT_BOLD}N${RESET}${NEON_RED}' for No, or '${AQUA}C${NEON_RED}' to cancel.${RESET}"
    echo "" # Extra space
  done

  if [[ "$use_generator" =~ ^[yY]$ ]]; then
    # Directly use global defaults for password generation when adding a new entry
    password=$(generate_password "$DEFAULT_PASSWORD_LENGTH" "$DEFAULT_PASSWORD_UPPER" "$DEFAULT_PASSWORD_NUMBERS" "$DEFAULT_PASSWORD_SYMBOLS") # From _password_generator.sh
    echo -e "${LIME_GREEN}🔐 Generated password using default settings: ${BRIGHT_BOLD}$password${RESET}\n"
  else
    # If not generating, prompt for manual password entry
    if [[ -n "$logged_in_via" ]]; then
      # If using service login, password for service is optional
      while true; do
        printf "${ELECTRIC_YELLOW}🔑 Enter service password (optional, leave blank if none): ${RESET}"
        read -s password_input # Read password silently
        echo
        password=$(trim "$password_input") # From _utils.sh
        echo "" # Extra space
        if [[ "$(echo "$password" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
          echo -e "${AQUA}Operation cancelled. Returning to main menu.${RESET}"
          pause # From _utils.sh
          return
        fi
        break
      done
    else
      # If not using service login, password for website is mandatory
      while true; do
        printf "${ELECTRIC_YELLOW}🔑 Enter website password (cannot be empty): ${RESET}"
        read -s password_input # Read password silently
        echo
        password=$(trim "$password_input") # From _utils.sh
        echo "" # Extra space
        if [[ "$(echo "$password" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
          echo -e "${AQUA}Operation cancelled. Returning to main menu.${RESET}"
          pause # From _utils.sh
          return
        fi
        [[ -n "$password" ]] && break
        echo -e "${NEON_RED}🚫 Website password cannot be empty! Please provide a value or type '${AQUA}C' to cancel.${RESET}"
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
  local new_entry_json_builder="{"
  new_entry_json_builder+="\"website\": \"$(jq -rR <<< "$website" )\"" # Use jq -rR for proper JSON string escaping
  [[ -n "$email" ]] && new_entry_json_builder+=", \"email\": \"$(jq -rR <<< "$email" )\""
  [[ -n "$username" ]] && new_entry_json_builder+=", \"username\": \"$(jq -rR <<< "$username" )\""
  [[ -n "$password" ]] && new_entry_json_builder+=", \"password\": \"$(jq -rR <<< "$password" )\""
  [[ -n "$logged_in_via" ]] && new_entry_json_builder+=", \"logged_in_via\": \"$(jq -rR <<< "$logged_in_via" )\""
  [[ -n "$linked_email" ]] && new_entry_json_builder+=", \"linked_email\": \"$(jq -rR <<< "$linked_email" )\""
  [[ -n "$recovery_email" ]] && new_entry_json_builder+=", \"recovery_email\": \"$(jq -rR <<< "$recovery_email" )\""
  new_entry_json_builder+=", \"added\": \"$timestamp\""
  new_entry_json_builder+="}"

  local new_entry_json
  new_entry_json=$(echo "$new_entry_json_builder" | jq '.')


  # Append the new entry to the existing JSON array and save it back
  local updated_entries_json
  updated_entries_json=$(echo "$entries_json" | jq --argjson new_entry "$new_entry_json" '. + [$new_entry]')

  # --- Confirmation before saving ---
  echo -e "\n${BRIGHT_BOLD}${CYBER_BLUE}--- Review New Entry ---${RESET}"
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
    read -rp "$(printf "${ELECTRIC_YELLOW}Do you want to ${BRIGHT_BOLD}SAVE${RESET}${ELECTRIC_YELLOW} this entry? (${BRIGHT_BOLD}Y/n${RESET}${ELECTRIC_YELLOW}):${RESET}") " confirm_save_input
    confirm_save=$(trim "${confirm_save_input:-y}") # From _utils.sh - Default to 'y'
    echo "" # Extra space
    if [[ "$(echo "$confirm_save" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
      echo -e "${AQUA}Entry not saved. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi
    if [[ "$confirm_save" =~ ^[yYnN]$ ]]; then
      break
    fi
    echo -e "${NEON_RED}🚫 Invalid input. Please enter '${BRIGHT_BOLD}Y${RESET}${NEON_RED}' for Yes, '${BRIGHT_BOLD}N${RESET}${NEON_RED}' for No, or '${AQUA}C${NEON_RED}' to cancel.${RESET}"
    echo "" # Extra space
  done

  if [[ "$confirm_save" =~ ^[yY]$ ]]; then
    save_entries "$updated_entries_json" # From _data_storage.sh
    echo -e "${LIME_GREEN}✅ Entry successfully added and saved!${RESET}"
  else
    echo -e "${AQUA}Entry not saved. Returning to main menu.${RESET}"
  fi
  pause # From _utils.sh
}

# Allows the user to select and edit an existing entry.
edit_entry() {
  clear_screen # From _utils.sh
  echo -e "${BRIGHT_BOLD}${VIOLET}--- Edit Existing Credential Entry ---${RESET}"
  echo -e "${AQUA}💡 At any point, type '${BRIGHT_BOLD}C${RESET}${AQUA}' to cancel this operation.${RESET}\n" # Hint for cancellation
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
    echo -e "${ELECTRIC_YELLOW}No entries to edit. Please add some first.${RESET}"
    pause # From _utils.sh
    return
  fi

  # Display entries with numbers for selection
  echo -e "${AQUA}Choose an entry to edit by its number:${RESET}"
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
    read -rp "$(printf "${ELECTRIC_YELLOW}Enter the number of the entry to edit [1-%d]:${RESET} " "$num_entries")" selected_index_input
    selected_index=$(trim "$selected_index_input") # From _utils.sh
    echo "" # Extra space

    local lower_input
    lower_input=$(echo "$selected_index" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "${AQUA}Operation cancelled. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi

    if [[ "$selected_index" =~ ^[0-9]+$ ]] && (( selected_index >= 1 && selected_index <= num_entries )); then
      break
    fi
    echo -e "${NEON_RED}🚫 Invalid input. Please enter a number between 1 and ${num_entries}, or type '${AQUA}C${NEON_RED}' to cancel.${RESET}"
    echo "" # Extra space
  done

  # Get the selected entry's current data
  local current_entry_json
  current_entry_json=$(echo "$entries_json" | jq ".[$((selected_index - 1))]")

  local current_website
  current_website=$(echo "$current_entry_json" | jq -r '.website')
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
  current_recovery_email=$(echo "$current_entry_json" | jq -r '.recovery_email // ""') # New field
  local current_added
  current_added=$(echo "$current_entry_json" | jq -r '.added')

  # --- Display preview of the selected entry ---
  echo -e "${BRIGHT_BOLD}${CYBER_BLUE}--- Currently Selected Entry (#${selected_index}) ---${RESET}"
  echo -e "  🌐 Website      : ${BRIGHT_BOLD}$current_website${RESET}"
  if [[ -n "$current_logged_in_via" ]]; then
    echo -e "  🔗 Logged in via: ${BRIGHT_BOLD}$current_logged_in_via${RESET}"
    [[ -n "$current_linked_email" ]] && echo -e "  📧 Linked Email : ${BRIGHT_BOLD}$current_linked_email${RESET}"
    [[ -n "$current_username" ]] && echo -e "  👤 Username     : ${BRIGHT_BOLD}$current_username${RESET}"
  elif [[ -n "$current_email" ]]; then
    echo -e "  📧 Email        : ${BRIGHT_BOLD}$current_email${RESET}"
  elif [[ -n "$current_username" ]]; then
    echo -e "  👤 Username     : ${BRIGHT_BOLD}$current_username${RESET}"
  fi
  if [[ -n "$current_recovery_email" ]]; then
    echo -e "  🚨 Recovery Email: ${BRIGHT_BOLD}$current_recovery_email${RESET}"
  fi
  if [[ -n "$current_password" ]]; then
      echo -e "  🔑 Password     : ${BRIGHT_BOLD}$current_password${RESET}" # Display current password if it exists
  fi
  echo -e "  📅 Added        : ${BRIGHT_BOLD}$current_added${RESET}"
  echo "" # Extra space
  echo -e "${AQUA}You are now editing this entry. Use the options provided for each field.${RESET}"
  echo "" # Extra space

  local new_website="$current_website"
  while true; do
    read -rp "$(printf "${ELECTRIC_YELLOW}🌐 Update Website/Service Name (current: ${BRIGHT_BOLD}%s${RESET}):${RESET} " "$current_website")" new_website_input
    new_website_input=$(trim "${new_website_input}") # From _utils.sh
    echo "" # Extra space
    local lower_input
    lower_input=$(echo "$new_website_input" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "${AQUA}Operation cancelled. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi
    if [[ -n "$new_website_input" ]]; then
      new_website="$new_website_input"
      break
    elif [[ -n "$current_website" ]]; then
      # If current website exists and new input is empty, keep current
      echo -e "${AQUA}Keeping current website: ${BRIGHT_BOLD}$current_website${RESET}${RESET}\n"
      new_website="$current_website"
      break
    else
      echo -e "${NEON_RED}🚫 Website/Service name cannot be empty! Please provide a value or type '${AQUA}C${NEON_RED}' to cancel.${RESET}"
      echo "" # Extra space
    fi
  done

  local new_logged_in_via_temp
  # Use DEFAULT_SERVICE as the default value for the prompt if it's set and current_logged_in_via is empty
  local prompt_logged_in_via_default="$current_logged_in_via"
  if [[ -z "$current_logged_in_via" && -n "$DEFAULT_SERVICE" ]]; then
    prompt_logged_in_via_default="$DEFAULT_SERVICE"
  fi

  if ! get_optional_input_with_remove "🔗 Update Logged in via" "$prompt_logged_in_via_default" new_logged_in_via_temp; then
    echo -e "${CYBER_BLUE}Operation cancelled. Returning to main menu.${RESET}" # Added message
    pause # Added pause
    clear_screen
    return
  fi

  if [[ $? -ne 0 ]]; then clear_screen; return; fi # Check for CANCEL and clear screen

  local new_email=""
  local new_linked_email=""
  local new_username=""
  local actual_logged_in_via="$new_logged_in_via_temp"

  if [[ -n "$new_logged_in_via_temp" ]]; then
    # If a service is specified, linked email or username is now optionally mandatory (X/BLANK/C allowed)
    while true; do
      local prompt_linked_email_default="$current_linked_email"
      if [[ -z "$current_linked_email" && -n "$DEFAULT_EMAIL" ]]; then
        prompt_linked_email_default="$DEFAULT_EMAIL"
      fi

      if ! get_optional_input_with_remove "📧 Update Linked email for ${new_logged_in_via_temp}" "$prompt_linked_email_default" new_linked_email; then
        echo -e "${CYBER_BLUE}Operation cancelled. Returning to main menu.${RESET}" # Added message
        pause # Added pause
        clear_screen
        return
      fi
      if [[ -z "$new_linked_email" ]]; then
        if ! get_optional_input_with_remove "👤 Update Username for ${new_logged_in_via_temp}" "$current_username" new_username; then
          echo -e "${CYBER_BLUE}Operation cancelled. Returning to main menu.${RESET}" # Added message
          pause # Added pause
          clear_screen
          return
        fi
        if [[ -z "$new_username" ]]; then
          echo -e "${ELECTRIC_YELLOW}Both Linked email and Username were removed or left blank, therefore 'Logged in via' will also be removed for consistency.${RESET}"
          actual_logged_in_via=""
        fi
        break
      else
        new_username=""
        break
      fi
    done
  fi

  if [[ -z "$actual_logged_in_via" ]]; then
    # If no service, direct email or username is used and one is mandatory
    while true; do
      local prompt_email_default="$current_email"
      if [[ -z "$current_email" && -n "$DEFAULT_EMAIL" ]]; then
        prompt_email_default="$DEFAULT_EMAIL"
      fi

      if ! get_optional_input_with_remove "📧 Update Email" "$prompt_email_default" new_email; then
        echo -e "${CYBER_BLUE}Operation cancelled. Returning to main menu.${RESET}" # Added message
        pause # Added pause
        clear_screen
        return
      fi
      if [[ -z "$new_email" ]]; then
        if ! get_optional_input_with_remove "👤 Update Username" "$current_username" new_username; then
          echo -e "${CYBER_BLUE}Operation cancelled. Returning to main menu.${RESET}" # Added message
          pause # Added pause
          clear_screen
          return
        fi
        if [[ -z "$new_username" ]]; then
          echo -e "${NEON_RED}🚫 Either Email or Username is required! Please provide at least one.${RESET}"
          continue
        fi
      else
        new_username=""
      fi
      break
    done
    new_linked_email="" # Ensure linked email is cleared
  fi

  local new_recovery_email
  if ! get_optional_input_with_remove "🚨 Update Recovery Email" "$current_recovery_email" new_recovery_email; then
    echo -e "${CYBER_BLUE}Operation cancelled. Returning to main menu.${RESET}" # Added message
    pause # Added pause
    clear_screen
    return
  fi

  local new_password=""
  local use_generator_choice # Renamed to avoid clash with potential 'use_generator' from password generation block
  while true; do
    read -rp "$(printf "${ELECTRIC_YELLOW}🔑 Generate a new random password for this entry? (${BRIGHT_BOLD}y/N${RESET}${ELECTRIC_YELLOW}):${RESET}") " use_generator_choice_input
    use_generator_choice_input=$(trim "${use_generator_choice_input:-n}") # From _utils.sh - Default to 'n'
    echo "" # Extra space
    local lower_input
    lower_input=$(echo "$use_generator_choice_input" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "${AQUA}Password generation cancelled. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi
    if [[ "$use_generator_choice_input" =~ ^[yYnN]$ ]]; then
      use_generator_choice="$use_generator_choice_input"
      break
    fi
    echo -e "${NEON_RED}🚫 Invalid input. Please enter '${BRIGHT_BOLD}Y${RESET}${NEON_RED}' for Yes, '${BRIGHT_BOLD}N${RESET}${NEON_RED}' for No, or '${AQUA}C${NEON_RED}' to cancel.${RESET}"
    echo "" # Extra space
  done

  if [[ "$use_generator_choice" =~ ^[yY]$ ]]; then
    local length
    while true; do
      read -rp "$(printf "${ELECTRIC_YELLOW}🔢 New password length (default: ${BRIGHT_BOLD}%s${RESET}${ELECTRIC_YELLOW}):${RESET}" "$DEFAULT_PASSWORD_LENGTH")" length_input
      length_input=$(trim "$length_input") # From _utils.sh
      echo "" # Extra space
      local lower_input
      lower_input=$(echo "$length_input" | tr '[:upper:]' '[:lower:]')
      if [[ "$lower_input" == "c" ]]; then
        echo -e "${AQUA}Password generation cancelled. Returning to main menu.${RESET}"
        pause # From _utils.sh
        return
      fi
      length=${length_input:-$DEFAULT_PASSWORD_LENGTH} # Use global default
      if [[ "$length" =~ ^[0-9]+$ && "$length" -ge 1 ]]; then
        break
      fi
      echo -e "${NEON_RED}🚫 Invalid length. Please enter a positive number or type '${AQUA}C${NEON_RED}' to cancel.${RESET}"
      echo "" # Extra space
    done

    local upper numbers symbols
    while true; do
      read -rp "$(printf "${ELECTRIC_YELLOW}⬆️ Include uppercase letters? (default: ${BRIGHT_BOLD}%s${RESET}${ELECTRIC_YELLOW}):${RESET}" "$DEFAULT_PASSWORD_UPPER")" upper_input
      upper=$(trim "${upper_input:-$DEFAULT_PASSWORD_UPPER}") # Use global default
      echo "" # Extra space
      local lower_input
      lower_input=$(echo "$upper_input" | tr '[:upper:]' '[:lower:]')
      if [[ "$lower_input" == "c" ]]; then
        echo -e "${AQUA}Password generation cancelled. Returning to main menu.${RESET}"
        pause # From _utils.sh
        return
      fi
      if [[ "$upper" =~ ^[yYnN]$ ]]; then
        break
      fi
      echo -e "${NEON_RED}🚫 Invalid input. Please enter '${BRIGHT_BOLD}Y${RESET}${NEON_RED}' for Yes, '${BRIGHT_BOLD}N${RESET}${NEON_RED}' for No, or '${AQUA}C${NEON_RED}' to cancel.${RESET}"
      echo "" # Extra space
    done

    while true; do
      read -rp "$(printf "${ELECTRIC_YELLOW}🔢 Include numbers? (default: ${BRIGHT_BOLD}%s${RESET}${ELECTRIC_YELLOW}):${RESET}" "$DEFAULT_PASSWORD_NUMBERS")" numbers_input
      numbers=$(trim "${numbers_input:-$DEFAULT_PASSWORD_NUMBERS}") # Use global default
      echo "" # Extra space
      local lower_input
      lower_input=$(echo "$numbers_input" | tr '[:upper:]' '[:lower:]')
      if [[ "$lower_input" == "c" ]]; then
        echo -e "${AQUA}Password generation cancelled. Returning to main menu.${RESET}"
        pause # From _utils.sh
        return
      fi
      if [[ "$numbers" =~ ^[yYnN]$ ]]; then
        break
      fi
      echo -e "${NEON_RED}🚫 Invalid input. Please enter '${BRIGHT_BOLD}Y${RESET}${NEON_RED}' for Yes, '${BRIGHT_BOLD}N${NEON_RED}' for No, or '${AQUA}C${NEON_RED}' to cancel.${RESET}"
      echo "" # Extra space
    done

    while true; do
      read -rp "$(printf "${ELECTRIC_YELLOW}🔣 Include symbols? (default: ${BRIGHT_BOLD}%s${RESET}${ELECTRIC_YELLOW}):${RESET}" "$DEFAULT_PASSWORD_SYMBOLS")" symbols_input
      symbols=$(trim "${symbols_input:-$DEFAULT_PASSWORD_SYMBOLS}") # Use global default
      echo "" # Extra space
      local lower_input
      lower_input=$(echo "$symbols_input" | tr '[:upper:]' '[:lower:]')
      if [[ "$lower_input" == "c" ]]; then
        echo -e "${AQUA}Password generation cancelled. Returning to main menu.${RESET}"
        pause # From _utils.sh
        return
      fi
      if [[ "$symbols" =~ ^[yYnN]$ ]]; then
        break
      fi
      echo -e "${NEON_RED}🚫 Invalid input. Please enter '${BRIGHT_BOLD}Y${RESET}${NEON_RED}' for Yes, '${BRIGHT_BOLD}N${RESET}${NEON_RED}' for No, or '${AQUA}C${NEON_RED}' to cancel.${RESET}"
      echo "" # Extra space
    done

    new_password=$(generate_password "$length" "$upper" "$numbers" "$symbols") # From _password_generator.sh
    echo -e "${LIME_GREEN}🔐 Generated new password: ${BRIGHT_BOLD}$new_password${RESET}\n"
  else
      # If not generating, prompt for manual password entry
      # Always use get_optional_input_with_remove for password in edit mode
      # This allows keeping current, setting new, or removing (with 'X')
      if ! get_optional_input_with_remove "🔑 Update Website password" "$current_password" new_password; then
        clear_screen
        return
      fi
    fi
  echo "" # Extra space

  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  # Build the updated entry dynamically, removing fields if their new value is empty
  local updated_entry_json_builder="{"
  updated_entry_json_builder+="\"website\": \"$(jq -rR <<< "$new_website" )\"" # Use jq -rR for proper JSON string escaping
  [[ -n "$new_email" ]] && updated_entry_json_builder+=", \"email\": \"$(jq -rR <<< "$new_email" )\""
  [[ -n "$new_username" ]] && updated_entry_json_builder+=", \"username\": \"$(jq -rR <<< "$new_username" )\""
  [[ -n "$new_password" ]] && updated_entry_json_builder+=", \"password\": \"$(jq -rR <<< "$new_password" )\""
  [[ -n "$actual_logged_in_via" ]] && updated_entry_json_builder+=", \"logged_in_via\": \"$(jq -rR <<< "$actual_logged_in_via" )\""
  [[ -n "$new_linked_email" ]] && updated_entry_json_builder+=", \"linked_email\": \"$(jq -rR <<< "$new_linked_email" )\""
  [[ -n "$new_recovery_email" ]] && updated_entry_json_builder+=", \"recovery_email\": \"$(jq -rR <<< "$new_recovery_email" )\""
  updated_entry_json_builder+=", \"added\": \"$timestamp\""
  updated_entry_json_builder+="}"

  local updated_single_entry_json
  updated_single_entry_json=$(echo "$updated_entry_json_builder" | jq '.')


  # Update the entry in the JSON array
  local updated_entries_json
  updated_entries_json=$(echo "$entries_json" | \
    jq --arg idx "$((selected_index - 1))" \
       --argjson updated_entry "$updated_single_entry_json" \
       '.[$idx | tonumber] = $updated_entry')

  local confirm_update
  echo -e "\n${BRIGHT_BOLD}${CYBER_BLUE}--- Review Updated Entry ---${RESET}"
  echo -e "  🌐 Website      : ${BRIGHT_BOLD}$new_website${RESET}"
  if [[ -n "$actual_logged_in_via" ]]; then
    echo -e "  🔗 Logged in via: ${BRIGHT_BOLD}$actual_logged_in_via${RESET}"
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
    read -rp "$(printf "${ELECTRIC_YELLOW}Do you want to ${BRIGHT_BOLD}SAVE${RESET}${ELECTRIC_YELLOW} these changes? (${BRIGHT_BOLD}Y/n${RESET}${ELECTRIC_YELLOW}):${RESET}") " confirm_update_input
    confirm_update=$(trim "${confirm_update_input:-y}") # From _utils.sh - Default to 'y'
    echo "" # Extra space
    local lower_input
    lower_input=$(echo "$confirm_update" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "${AQUA}Changes not saved. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi
    if [[ "$confirm_update" =~ ^[yYnN]$ ]]; then
      break
    fi
    echo -e "${NEON_RED}🚫 Invalid input. Please enter '${BRIGHT_BOLD}Y${RESET}${NEON_RED}' for Yes, '${BRIGHT_BOLD}N${NEON_RED}' for No, or '${AQUA}C${NEON_RED}' to cancel.${RESET}"
    echo "" # Extra space
  done

  if [[ "$confirm_update" =~ ^[yY]$ ]]; then
    save_entries "$updated_entries_json" # From _data_storage.sh
    echo -e "${LIME_GREEN}✅ Entry successfully updated and saved!${RESET}"
  else
    echo -e "${AQUA}Changes not saved. Returning to main menu.${RESET}"
  fi
  pause # From _utils.sh
}

# Allows the user to select and remove one or multiple existing entries.
remove_entry() {
  clear_screen # From _utils.sh
  echo -e "${BRIGHT_BOLD}${VIOLET}--- Remove Credential Entries ---${RESET}"
  echo -e "${AQUA}💡 At any point, type '${BRIGHT_BOLD}C${RESET}${AQUA}' to cancel this operation.${RESET}\n" # Hint for cancellation
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
    echo -e "${ELECTRIC_YELLOW}No entries to remove. Please add some first.${RESET}"
    pause # From _utils.sh
    return
  fi

  # Display entries with numbers for selection
  echo -e "${AQUA}Choose an entry to edit by its number:${RESET}"
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
    read -rp "$(printf "${ELECTRIC_YELLOW}Enter numbers of entries to remove (e.g., '${BRIGHT_BOLD}1,3,5${RESET}${ELECTRIC_YELLOW}'):${RESET} ") " selected_indices_str_input
    selected_indices_str=$(trim "$selected_indices_str_input") # From _utils.sh
    echo "" # Extra space

    local lower_input
    lower_input=$(echo "$selected_indices_str" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "${AQUA}Operation cancelled. Returning to main menu.${RESET}"
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
        echo -e "${NEON_RED}🚫 Invalid entry number: '${idx_str}'. Please enter valid numbers or type '${AQUA}C${NEON_RED}' to cancel.${RESET}"
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
      echo -e "${NEON_RED}🚫 No valid entries selected. Please enter at least one number, or type '${AQUA}C${NEON_RED}' to cancel.${RESET}"
    fi
    echo "" # Extra space
  done

  # --- Display preview of selected entries for removal ---
  echo -e "\n${BRIGHT_BOLD}${CYBER_BLUE}--- Entries to be Permanently Removed ---${RESET}"

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
    read -rp "$(printf "${ELECTRIC_YELLOW}Are you ${BRIGHT_BOLD}SURE${RESET}${ELECTRIC_YELLOW} you want to PERMANENTLY remove these entries? (${NEON_RED}y/N${RESET}${ELECTRIC_YELLOW}):${RESET}") " confirm_removal_input
    confirm_removal=$(trim "${confirm_removal_input:-n}") # From _utils.sh - Default to 'n'
    echo "" # Extra space
    local lower_input
    lower_input=$(echo "$confirm_removal" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "${AQUA}Removal cancelled. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi
    if [[ "$confirm_removal" =~ ^[yYnN]$ ]]; then
      break
    fi
    echo -e "${NEON_RED}🚫 Invalid input. Please enter '${BRIGHT_BOLD}Y${RESET}${NEON_RED}' for Yes, '${BRIGHT_BOLD}N${NEON_RED}' for No, or '${AQUA}C${NEON_RED}' to cancel.${RESET}"
    echo "" # Extra space
  done

  if [[ "$confirm_removal" =~ ^[yY]$ ]]; then
    local updated_entries_json="$entries_json"
    for idx in "${valid_indices[@]}"; do
      echo -e "${AQUA}Removing entry ${idx}...${RESET}"
      # Remove the entry using jq. Note: indices are 0-based in jq.
      updated_entries_json=$(echo "$updated_entries_json" | jq "del(.[$((idx - 1))])")
    done
    save_entries "$updated_entries_json" # From _data_storage.sh
    echo -e "${LIME_GREEN}✅ Selected entries removed successfully!${RESET}"
  else
    echo -e "${AQUA}Removal cancelled.${RESET}"
  fi
  pause # From _utils.sh
}
