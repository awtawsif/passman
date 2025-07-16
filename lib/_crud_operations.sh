#!/bin/bash
# _crud_operations.sh
# Contains functions for adding, editing, and removing credential entries.
# Sourced by passman.sh.

# --- Strict Mode for Robustness ---
set -e
set -u
set -o pipefail

# Dependencies:
# - _colors.sh (for color variables like RED, GREEN, YELLOW, CYAN, BLUE, BOLD, RESET)
# - _utils.sh (for clear_screen, pause, trim, get_optional_input_with_remove, get_mandatory_input_conditional)
# - _data_storage.sh (for load_entries, save_entries)
# - _password_generator.sh (for generate_password)

# Prompts the user for new credential details and adds them to the JSON file.
add_entry() {
  clear_screen # From _utils.sh
  echo -e "${BOLD}${MAGENTA}--- Add New Credential Entry ---${RESET}"
  echo -e "${CYAN}💡 At any point, type '${BOLD}C${RESET}${CYAN}' to cancel this operation.${RESET}\n" # Hint for cancellation
  echo "" # Extra space

  local website email username password logged_in_via linked_email recovery_email timestamp

  while true; do
    read -p "$(printf "${YELLOW}🌐 Enter Website Name: ${RESET}") " website_input
    website=$(trim "$website_input") # From _utils.sh
    echo "" # Extra space
    if [[ "$(echo "$website" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
      echo -e "${CYAN}Operation cancelled. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi
    [[ -n "$website" ]] && break
    echo -e "${RED}🚫 Website/Service name cannot be empty! Please provide a value or type '${CYAN}C' to cancel.${RESET}"
    echo "" # Extra space
  done

  local logged_in_via_input
  while true; do
    read -p "$(printf "${YELLOW}🔗 Did you log into this site using another service (e.g., Google, Facebook)? (Leave blank if not): ${RESET}") " logged_in_via_input
    logged_in_via=$(trim "$logged_in_via_input") # From _utils.sh
    echo "" # Extra space
    if [[ "$(echo "$logged_in_via" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
      echo -e "${CYAN}Operation cancelled. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi
    break # User can leave this empty
  done


  if [[ -n "$logged_in_via" ]]; then
    # Prompt for linked email (mandatory)
    while true; do
      read -p "$(printf "${YELLOW}📧 Enter the email used for ${BOLD}%s${RESET} (cannot be empty, type 'C' to cancel): ${RESET}" "$logged_in_via")" linked_email_input
      linked_email=$(trim "$linked_email_input") # From _utils.sh
      echo "" # Extra space
      if [[ "$(echo "$linked_email" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
        echo -e "${CYAN}Operation cancelled. Returning to main menu.${RESET}"
        pause # From _utils.sh
        return
      fi
      [[ -n "$linked_email" ]] && break
      echo -e "${RED}🚫 Linked email cannot be empty if a service is specified! Please provide a value or type '${CYAN}C' to cancel.${RESET}"
      echo "" # Extra space
    done

    # Prompt for username (optional)
    read -p "$(printf "${YELLOW}👤 Enter a username for this service (optional, leave blank if none):${RESET} ")" username_input
    username=$(trim "$username_input")
    echo "" # Extra space

    email=""        # Ensure email is empty if logging in via another service
  else
    while true; do
      read -p "$(printf "${YELLOW}📧 Enter your Email for this site (cannot be empty, or type 'U' to use username):${RESET} ") " email_input
      email=$(trim "$email_input") # From _utils.sh
      echo "" # Extra space
      if [[ "$(echo "$email" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
        echo -e "${CYAN}Operation cancelled. Returning to main menu.${RESET}"
        pause # From _utils.sh
        return
      fi
      if [[ "$(echo "$email" | tr '[:upper:]' '[:lower:]')" == "u" ]]; then
        # User wants to use username instead of email (mandatory)
        while true; do
          read -p "$(printf "${YELLOW}👤 Enter your Username for this site (cannot be empty):${RESET} ") " username_input
          username=$(trim "$username_input")
          echo "" # Extra space
          if [[ "$(echo "$username" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
            echo -e "${CYAN}Operation cancelled. Returning to main menu.${RESET}"
            pause # From _utils.sh
            return
          fi
          [[ -n "$username" ]] && break
          echo -e "${RED}🚫 Username cannot be empty! Please provide a value or type '${CYAN}C' to cancel.${RESET}"
          echo "" # Extra space
        done
        email=""
        break
      fi
      if [[ -n "$email" ]]; then
        # Optionally prompt for username (can leave blank)
        read -p "$(printf "${YELLOW}👤 Enter a username for this site (optional, leave blank if none):${RESET} ")" username_input
        username=$(trim "$username_input")
        echo "" # Extra space
        break
      fi
      echo -e "${RED}🚫 Email cannot be empty! Please provide a value, type '${CYAN}C' to cancel, or '${CYAN}U' to use username.${RESET}"
      echo "" # Extra space
    done
    linked_email="" # Ensure linked_email is empty if direct email is used
  fi

  local recovery_email_input
  while true; do
    read -p "$(printf "${YELLOW}🚨 Recovery Email (optional, leave blank if none):${RESET} ") " recovery_email_input
    recovery_email=$(trim "$recovery_email_input") # From _utils.sh
    echo "" # Extra space
    if [[ "$(echo "$recovery_email" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
      echo -e "${CYAN}Operation cancelled. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi
    break # Optional field, can be empty
  done

  local use_generator
  while true; do
    read -p "$(printf "${YELLOW}🔑 Generate a random password for this entry? (${BOLD}y/N${RESET}${YELLOW}):${RESET}") " use_generator_input
    use_generator=$(trim "${use_generator_input:-n}") # Default to 'n'
    echo "" # Extra space
    if [[ "$(echo "$use_generator" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
      echo -e "${CYAN}Operation cancelled. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi
    if [[ "$use_generator" =~ ^[yYnN]$ ]]; then
      break
    fi
    echo -e "${RED}🚫 Invalid input. Please enter '${BOLD}Y${RESET}${RED}' for Yes, '${BOLD}N${RESET}${RED}' for No, or '${CYAN}C${RED}' to cancel.${RESET}"
    echo "" # Extra space
  done

  if [[ "$use_generator" =~ ^[yY]$ ]]; then
    local length
    while true; do
      read -p "$(printf "${YELLOW}🔢 Password length (default: ${BOLD}12${RESET}${YELLOW}):${RESET}") " length_input
      length_input=$(trim "$length_input") # From _utils.sh
      echo "" # Extra space
      if [[ "$(echo "$length_input" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
        echo -e "${CYAN}Password generation cancelled. Returning to main menu.${RESET}"
        pause # From _utils.sh
        return
      fi
      length=${length_input:-12}
      if [[ "$length" =~ ^[0-9]+$ && "$length" -ge 1 ]]; then
        break
      fi
      echo -e "${RED}🚫 Invalid length. Please enter a positive number or type '${CYAN}C${RED}' to cancel.${RESET}"
      echo "" # Extra space
    done

    local upper numbers symbols
    while true; do
      read -p "$(printf "${YELLOW}⬆️ Include uppercase letters? (${BOLD}Y/n${RESET}${YELLOW}):${RESET}") " upper_input
      upper=$(trim "${upper_input:-y}") # Default to 'y'
      echo "" # Extra space
      if [[ "$(echo "$upper" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
        echo -e "${CYAN}Password generation cancelled. Returning to main menu.${RESET}"
        pause # From _utils.sh
        return
      fi
      if [[ "$upper" =~ ^[yYnN]$ ]]; then
        break
      fi
      echo -e "${RED}🚫 Invalid input. Please enter '${BOLD}Y${RESET}${RED}' for Yes, '${BOLD}N${RESET}${RED}' for No, or '${CYAN}C${RED}' to cancel.${RESET}"
      echo "" # Extra space
    done

    while true; do
      read -p "$(printf "${YELLOW}🔢 Include numbers? (${BOLD}Y/n${RESET}${YELLOW}):${RESET}") " numbers_input
      numbers=$(trim "${numbers_input:-y}") # Default to 'y'
      echo "" # Extra space
      if [[ "$(echo "$numbers" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
        echo -e "${CYAN}Password generation cancelled. Returning to main menu.${RESET}"
        pause # From _utils.sh
        return
      fi
      if [[ "$numbers" =~ ^[yYnN]$ ]]; then
        break
      fi
      echo -e "${RED}🚫 Invalid input. Please enter '${BOLD}Y${RESET}${RED}' for Yes, '${BOLD}N${RESET}${RED}' for No, or '${CYAN}C${RED}' to cancel.${RESET}"
      echo "" # Extra space
    done

    while true; do
      read -p "$(printf "${YELLOW}🔣 Include symbols? (${BOLD}Y/n${RESET}${YELLOW}):${RESET}") " symbols_input
      symbols=$(trim "${symbols_input:-y}") # Default to 'y'
      echo "" # Extra space
      if [[ "$(echo "$symbols" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
        echo -e "${CYAN}Password generation cancelled. Returning to main menu.${RESET}"
        pause # From _utils.sh
        return
      fi
      if [[ "$symbols" =~ ^[yYnN]$ ]]; then
        break
      fi
      echo -e "${RED}🚫 Invalid input. Please enter '${BOLD}Y${RESET}${RED}' for Yes, '${BOLD}N${RESET}${RED}' for No, or '${CYAN}C${RED}' to cancel.${RESET}"
      echo "" # Extra space
    done

    password=$(generate_password "$length" "$upper" "$numbers" "$symbols") # From _password_generator.sh
    echo -e "${GREEN}🔐 Generated password: ${BOLD}$password${RESET}\n"
  else
    # If not generating, prompt for manual password entry
    if [[ -n "$logged_in_via" ]]; then
      # If using service login, password for service is optional
      while true; do
        printf "${YELLOW}🔑 Enter service password (optional, leave blank if none): ${RESET}"
        read -s password_input # Read password silently
        echo
        password=$(trim "$password_input") # From _utils.sh
        echo "" # Extra space
        if [[ "$(echo "$password" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
          echo -e "${CYAN}Operation cancelled. Returning to main menu.${RESET}"
          pause # From _utils.sh
          return
        fi
        break
      done
    else
      # If not using service login, password for website is mandatory
      while true; do
        printf "${YELLOW}🔑 Enter website password (cannot be empty): ${RESET}"
        read -s password_input # Read password silently
        echo
        password=$(trim "$password_input") # From _utils.sh
        echo "" # Extra space
        if [[ "$(echo "$password" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
          echo -e "${CYAN}Operation cancelled. Returning to main menu.${RESET}"
          pause # From _utils.sh
          return
        fi
        [[ -n "$password" ]] && break
        echo -e "${RED}🚫 Website password cannot be empty! Please provide a value or type '${CYAN}C' to cancel.${RESET}"
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
  new_entry_json_builder+="\"website\": \"$website\""
  [[ -n "$email" ]] && new_entry_json_builder+=", \"email\": \"$email\""
  [[ -n "$username" ]] && new_entry_json_builder+=", \"username\": \"$username\""
  [[ -n "$password" ]] && new_entry_json_builder+=", \"password\": \"$password\""
  [[ -n "$logged_in_via" ]] && new_entry_json_builder+=", \"logged_in_via\": \"$logged_in_via\""
  [[ -n "$linked_email" ]] && new_entry_json_builder+=", \"linked_email\": \"$linked_email\""
  [[ -n "$recovery_email" ]] && new_entry_json_builder+=", \"recovery_email\": \"$recovery_email\""
  new_entry_json_builder+=", \"added\": \"$timestamp\""
  new_entry_json_builder+="}"

  local new_entry_json
  new_entry_json=$(echo "$new_entry_json_builder" | jq '.')

  # Append the new entry to the existing JSON array and save it back
  local updated_entries_json
  updated_entries_json=$(echo "$entries_json" | jq --argjson new_entry "$new_entry_json" '. + [$new_entry]')

  # --- Confirmation before saving ---
  echo -e "\n${BOLD}${BLUE}--- Review New Entry ---${RESET}"
  echo -e "  🌐 Website      : ${BOLD}$website${RESET}"
  if [[ -n "$logged_in_via" ]]; then
    echo -e "  🔗 Logged in via: ${BOLD}$logged_in_via${RESET}"
    [[ -n "$linked_email" ]] && echo -e "  📧 Linked Email : ${BOLD}$linked_email${RESET}"
    [[ -n "$username" ]] && echo -e "  👤 Username     : ${BOLD}$username${RESET}"
  elif [[ -n "$email" ]]; then
    echo -e "  📧 Email        : ${BOLD}$email${RESET}"
  elif [[ -n "$username" ]]; then
    echo -e "  👤 Username     : ${BOLD}$username${RESET}"
  fi
  if [[ -n "$recovery_email" ]]; then
    echo -e "  🚨 Recovery Email: ${BOLD}$recovery_email${RESET}"
  fi
  if [[ -n "$password" ]]; then # Only display if password exists
    echo -e "  🔑 Password     : ${BOLD}$password${RESET}" # Display for confirmation
  fi
  echo -e "  📅 Added        : ${BOLD}$timestamp${RESET}"
  echo "" # Extra space

  local confirm_save
  while true; do
    read -p "$(printf "${YELLOW}Do you want to ${BOLD}SAVE${RESET}${YELLOW} this entry? (${BOLD}Y/n${RESET}${YELLOW}):${RESET}") " confirm_save_input
    confirm_save=$(trim "${confirm_save_input:-y}") # From _utils.sh - Default to 'y'
    echo "" # Extra space
    if [[ "$(echo "$confirm_save" | tr '[:upper:]' '[:lower:]')" == "c" ]]; then
      echo -e "${CYAN}Entry not saved. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi
    if [[ "$confirm_save" =~ ^[yYnN]$ ]]; then
      break
    fi
    echo -e "${RED}🚫 Invalid input. Please enter '${BOLD}Y${RESET}${RED}' for Yes, '${BOLD}N${RESET}${RED}' for No, or '${CYAN}C${RED}' to cancel.${RESET}"
    echo "" # Extra space
  done

  if [[ "$confirm_save" =~ ^[yY]$ ]]; then
    save_entries "$updated_entries_json" # From _data_storage.sh
    echo -e "${GREEN}✅ Entry successfully added and saved!${RESET}"
  else
    echo -e "${CYAN}Entry not saved. Returning to main menu.${RESET}"
  fi
  pause # From _utils.sh
}

# Allows the user to select and edit an existing entry.
edit_entry() {
  clear_screen # From _utils.sh
  echo -e "${BOLD}${MAGENTA}--- Edit Existing Credential Entry ---${RESET}"
  echo -e "${CYAN}💡 At any point, type '${BOLD}C${RESET}${CYAN}' to cancel this operation.${RESET}\n" # Hint for cancellation
  echo "" # Extra space

  local entries_json
  entries_json=$(load_entries) # From _data_storage.sh
  if [[ $? -ne 0 ]]; then
    pause # From _utils.sh
    return
  fi

  local num_entries=$(echo "$entries_json" | jq 'length')

  if [[ "$num_entries" -eq 0 ]]; then
    echo -e "${YELLOW}No entries to edit. Please add some first.${RESET}"
    pause # From _utils.sh
    return
  fi

  # Display entries with numbers for selection
  echo -e "${CYAN}Choose an entry to edit by its number:${RESET}"
  echo "" # Extra space

  # Define ANSI color codes for awk.
  local bold_code=$BOLD # From _colors.sh
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
    read -p "$(printf "${YELLOW}Enter the number of the entry to edit [1-%d]:${RESET} " "$num_entries")" selected_index_input
    selected_index=$(trim "$selected_index_input") # From _utils.sh
    echo "" # Extra space

    local lower_input=$(echo "$selected_index" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "${CYAN}Operation cancelled. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi

    if [[ "$selected_index" =~ ^[0-9]+$ ]] && (( selected_index >= 1 && selected_index <= num_entries )); then
      break
    fi
    echo -e "${RED}🚫 Invalid input. Please enter a number between 1 and ${num_entries}, or type '${CYAN}C${RED}' to cancel.${RESET}"
    echo "" # Extra space
  done

  # Get the selected entry's current data
  local current_entry_json
  current_entry_json=$(echo "$entries_json" | jq ".[$((selected_index - 1))]")

  local current_website=$(echo "$current_entry_json" | jq -r '.website')
  local current_email=$(echo "$current_entry_json" | jq -r '.email // ""')
  local current_username=$(echo "$current_entry_json" | jq -r '.username // ""')
  local current_password=$(echo "$current_entry_json" | jq -r '.password // ""')
  local current_logged_in_via=$(echo "$current_entry_json" | jq -r '.logged_in_via // ""')
  local current_linked_email=$(echo "$current_entry_json" | jq -r '.linked_email // ""')
  local current_recovery_email=$(echo "$current_entry_json" | jq -r '.recovery_email // ""') # New field
  local current_added=$(echo "$current_entry_json" | jq -r '.added')

  # --- Display preview of the selected entry ---
  echo -e "${BOLD}${BLUE}--- Currently Selected Entry (#${selected_index}) ---${RESET}"
  echo -e "  🌐 Website      : ${BOLD}$current_website${RESET}"
  if [[ -n "$current_logged_in_via" ]]; then
    echo -e "  🔗 Logged in via: ${BOLD}$current_logged_in_via${RESET}"
    [[ -n "$current_linked_email" ]] && echo -e "  📧 Linked Email : ${BOLD}$current_linked_email${RESET}"
    [[ -n "$current_username" ]] && echo -e "  👤 Username     : ${BOLD}$current_username${RESET}"
  elif [[ -n "$current_email" ]]; then
    echo -e "  📧 Email        : ${BOLD}$current_email${RESET}"
  elif [[ -n "$current_username" ]]; then
    echo -e "  👤 Username     : ${BOLD}$current_username${RESET}"
  fi
  if [[ -n "$current_recovery_email" ]]; then
    echo -e "  🚨 Recovery Email: ${BOLD}$current_recovery_email${RESET}"
  fi
  if [[ -n "$current_password" ]]; then
      echo -e "  🔑 Password     : ${BOLD}$current_password${RESET}" # Display current password if it exists
  fi
  echo -e "  📅 Added        : ${BOLD}$current_added${RESET}"
  echo "" # Extra space
  echo -e "${CYAN}You are now editing this entry. Use the options provided for each field.${RESET}"
  echo "" # Extra space

  # Prompt for new values, handling "X" for remove and "C" for cancel
  local new_website="$current_website"
  while true; do
    read -p "$(printf "${YELLOW}🌐 Update Website/Service Name (current: ${BOLD}%s${RESET}, cannot be empty):${RESET} " "$current_website")" new_website_input
    new_website_input=$(trim "${new_website_input}") # From _utils.sh
    echo "" # Extra space
    local lower_input=$(echo "$new_website_input" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "${CYAN}Operation cancelled. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi
    if [[ -n "$new_website_input" ]]; then
      new_website="$new_website_input"
      break
    elif [[ -n "$current_website" ]]; then
      # If current website exists and new input is empty, keep current
      echo -e "${CYAN}Keeping current website: ${BOLD}$current_website${RESET}${RESET}"
      new_website="$current_website"
      break
    else
      echo -e "${RED}🚫 Website/Service name cannot be empty! Please provide a value or type '${CYAN}C${RED}' to cancel.${RESET}"
      echo "" # Extra space
    fi
  done

  local new_logged_in_via_temp
  get_optional_input_with_remove "🔗 Update Logged in via" "$current_logged_in_via" new_logged_in_via_temp # From _utils.sh
  if [[ $? -ne 0 ]]; then clear_screen; return; fi # Check for CANCEL and clear screen

  local new_email=""
  local new_linked_email=""
  local new_username=""
  local actual_logged_in_via="$new_logged_in_via_temp"

  if [[ -n "$new_logged_in_via_temp" ]]; then
    # If a service is specified, linked email or username is now optionally mandatory (X/BLANK/C allowed)
    while true; do
      get_optional_input_with_remove "📧 Update Linked email for ${new_logged_in_via_temp}" "$current_linked_email" new_linked_email # From _utils.sh
      if [[ $? -ne 0 ]]; then clear_screen; return; fi # Check for CANCEL and clear screen
      if [[ -z "$new_linked_email" ]]; then
        get_optional_input_with_remove "👤 Update Username for ${new_logged_in_via_temp}" "$current_username" new_username
        if [[ $? -ne 0 ]]; then clear_screen; return; fi
        if [[ -z "$new_username" ]]; then
          echo -e "${YELLOW}Both Linked email and Username were removed or left blank, therefore 'Logged in via' will also be removed for consistency.${RESET}"
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
      get_optional_input_with_remove "📧 Update Email" "$current_email" new_email
      if [[ $? -ne 0 ]]; then clear_screen; return; fi
      if [[ -z "$new_email" ]]; then
        get_optional_input_with_remove "👤 Update Username" "$current_username" new_username
        if [[ $? -ne 0 ]]; then clear_screen; return; fi
        if [[ -z "$new_username" ]]; then
          echo -e "${RED}🚫 Either Email or Username is required! Please provide at least one.${RESET}"
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
  get_optional_input_with_remove "🚨 Update Recovery Email" "$current_recovery_email" new_recovery_email # From _utils.sh
  if [[ $? -ne 0 ]]; then clear_screen; return; fi # Check for CANCEL and clear screen

  local new_password=""
  local use_generator_choice # Renamed to avoid clash with potential 'use_generator' from password generation block
  while true; do
    read -p "$(printf "${YELLOW}🔑 Generate a new random password for this entry? (${BOLD}Y/n${RESET}${YELLOW}):${RESET}") " use_generator_choice_input
    use_generator_choice_input=$(trim "${use_generator_choice_input:-y}") # From _utils.sh - Default to 'y'
    echo "" # Extra space
    local lower_input=$(echo "$use_generator_choice_input" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "${CYAN}Password generation cancelled. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi
    if [[ "$use_generator_choice_input" =~ ^[yYnN]$ ]]; then
      use_generator_choice="$use_generator_choice_input"
      break
    fi
    echo -e "${RED}🚫 Invalid input. Please enter '${BOLD}Y${RESET}${RED}' for Yes, '${BOLD}N${RESET}${RED}' for No, or '${CYAN}C${RED}' to cancel.${RESET}"
    echo "" # Extra space
  done

  if [[ "$use_generator_choice" =~ ^[yY]$ ]]; then
    local length
    while true; do
      read -p "$(printf "${YELLOW}🔢 New password length (default: ${BOLD}12${RESET}${YELLOW}):${RESET}") " length_input
      length_input=$(trim "$length_input") # From _utils.sh
      echo "" # Extra space
      local lower_input=$(echo "$length_input" | tr '[:upper:]' '[:lower:]')
      if [[ "$lower_input" == "c" ]]; then
        echo -e "${CYAN}Password generation cancelled. Returning to main menu.${RESET}"
        pause # From _utils.sh
        return
      fi
      length=${length_input:-12}
      if [[ "$length" =~ ^[0-9]+$ && "$length" -ge 1 ]]; then
        break
      fi
      echo -e "${RED}🚫 Invalid length. Please enter a positive number or type '${CYAN}C${RED}' to cancel.${RESET}"
      echo "" # Extra space
    done

    local upper numbers symbols
    while true; do
      read -p "$(printf "${YELLOW}⬆️ Include uppercase letters? (${BOLD}Y/n${RESET}${YELLOW}):${RESET}") " upper_input
      upper=$(trim "${upper_input:-y}") # From _utils.sh - Default to 'y'
      echo "" # Extra space
      local lower_input=$(echo "$upper_input" | tr '[:upper:]' '[:lower:]')
      if [[ "$lower_input" == "c" ]]; then
        echo -e "${CYAN}Password generation cancelled. Returning to main menu.${RESET}"
        pause # From _utils.sh
        return
      fi
      if [[ "$upper" =~ ^[yYnN]$ ]]; then
        break
      fi
      echo -e "${RED}🚫 Invalid input. Please enter '${BOLD}Y${RESET}${RED}' for Yes, '${BOLD}N${RESET}${RED}' for No, or '${CYAN}C${RED}' to cancel.${RESET}"
      echo "" # Extra space
    done

    while true; do
      read -p "$(printf "${YELLOW}🔢 Include numbers? (${BOLD}Y/n${RESET}${YELLOW}):${RESET}") " numbers_input
      numbers=$(trim "${numbers_input:-y}") # From _utils.sh - Default to 'y'
      echo "" # Extra space
      local lower_input=$(echo "$numbers_input" | tr '[:upper:]' '[:lower:]')
      if [[ "$lower_input" == "c" ]]; then
        echo -e "${CYAN}Password generation cancelled. Returning to main menu.${RESET}"
        pause # From _utils.sh
        return
      fi
      if [[ "$numbers" =~ ^[yYnN]$ ]]; then
        break
      fi
      echo -e "${RED}🚫 Invalid input. Please enter '${BOLD}Y${RESET}${RED}' for Yes, '${BOLD}N${RESET}${RED}' for No, or '${CYAN}C${RED}' to cancel.${RESET}"
      echo "" # Extra space
    done

    while true; do
      read -p "$(printf "${YELLOW}🔣 Include symbols? (${BOLD}Y/n${RESET}${YELLOW}):${RESET}") " symbols_input
      symbols=$(trim "${symbols_input:-y}") # From _utils.sh - Default to 'y'
      echo "" # Extra space
      local lower_input=$(echo "$symbols_input" | tr '[:upper:]' '[:lower:]')
      if [[ "$lower_input" == "c" ]]; then
        echo -e "${CYAN}Password generation cancelled. Returning to main menu.${RESET}"
        pause # From _utils.sh
        return
      fi
      if [[ "$symbols" =~ ^[yYnN]$ ]]; then
        break
      fi
      echo -e "${RED}🚫 Invalid input. Please enter '${BOLD}Y${RESET}${RED}' for Yes, '${BOLD}N${RESET}${RED}' for No, or '${CYAN}C${RED}' to cancel.${RESET}"
      echo "" # Extra space
    done

    new_password=$(generate_password "$length" "$upper" "$numbers" "$symbols") # From _password_generator.sh
    echo -e "${GREEN}🔐 Generated new password: ${BOLD}$new_password${RESET}\n"
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

  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  # Build the updated entry dynamically, removing fields if their new value is empty
  local updated_entry_json_builder="{"
  updated_entry_json_builder+="\"website\": \"$new_website\""
  [[ -n "$new_email" ]] && updated_entry_json_builder+=", \"email\": \"$new_email\""
  [[ -n "$new_username" ]] && updated_entry_json_builder+=", \"username\": \"$new_username\""
  [[ -n "$new_password" ]] && updated_entry_json_builder+=", \"password\": \"$new_password\""
  [[ -n "$actual_logged_in_via" ]] && updated_entry_json_builder+=", \"logged_in_via\": \"$actual_logged_in_via\""
  [[ -n "$new_linked_email" ]] && updated_entry_json_builder+=", \"linked_email\": \"$new_linked_email\""
  [[ -n "$new_recovery_email" ]] && updated_entry_json_builder+=", \"recovery_email\": \"$new_recovery_email\""
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
  echo -e "\n${BOLD}${BLUE}--- Review Updated Entry ---${RESET}"
  echo -e "  🌐 Website      : ${BOLD}$new_website${RESET}"
  if [[ -n "$actual_logged_in_via" ]]; then
    echo -e "  🔗 Logged in via: ${BOLD}$actual_logged_in_via${RESET}"
    [[ -n "$new_linked_email" ]] && echo -e "  📧 Linked Email : ${BOLD}$new_linked_email${RESET}"
    [[ -n "$new_username" ]] && echo -e "  👤 Username     : ${BOLD}$new_username${RESET}"
  elif [[ -n "$new_email" ]]; then
    echo -e "  📧 Email        : ${BOLD}$new_email${RESET}"
  elif [[ -n "$new_username" ]]; then
    echo -e "  👤 Username     : ${BOLD}$new_username${RESET}"
  fi
  if [[ -n "$new_recovery_email" ]]; then
    echo -e "  🚨 Recovery Email: ${BOLD}$new_recovery_email${RESET}"
  fi
  if [[ -n "$new_password" ]]; then
      echo -e "  🔑 Password     : ${BOLD}$new_password${RESET}"
  fi
  echo -e "  📅 Updated      : ${BOLD}$timestamp${RESET}"
  echo "" # Extra space

  while true; do
    read -p "$(printf "${YELLOW}Do you want to ${BOLD}SAVE${RESET}${YELLOW} these changes? (${BOLD}Y/n${RESET}${YELLOW}):${RESET}") " confirm_update_input
    confirm_update=$(trim "${confirm_update_input:-y}") # From _utils.sh - Default to 'y'
    echo "" # Extra space
    local lower_input=$(echo "$confirm_update" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "${CYAN}Changes not saved. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi
    if [[ "$confirm_update" =~ ^[yYnN]$ ]]; then
      break
    fi
    echo -e "${RED}🚫 Invalid input. Please enter '${BOLD}Y${RESET}${RED}' for Yes, '${BOLD}N${RESET}${RED}' for No, or '${CYAN}C${RED}' to cancel.${RESET}"
    echo "" # Extra space
  done

  if [[ "$confirm_update" =~ ^[yY]$ ]]; then
    save_entries "$updated_entries_json" # From _data_storage.sh
    echo -e "${GREEN}✅ Entry successfully updated and saved!${RESET}"
  else
    echo -e "${CYAN}Changes not saved. Returning to main menu.${RESET}"
  fi
  pause # From _utils.sh
}

# Allows the user to select and remove one or multiple existing entries.
remove_entry() {
  clear_screen # From _utils.sh
  echo -e "${BOLD}${MAGENTA}--- Remove Credential Entries ---${RESET}"
  echo -e "${CYAN}💡 At any point, type '${BOLD}C${RESET}${CYAN}' to cancel this operation.${RESET}\n" # Hint for cancellation
  echo "" # Extra space

  local entries_json
  entries_json=$(load_entries) # From _data_storage.sh
  if [[ $? -ne 0 ]]; then
    pause # From _utils.sh
    return
  fi

  local num_entries=$(echo "$entries_json" | jq 'length')

  if [[ "$num_entries" -eq 0 ]]; then
    echo -e "${YELLOW}No entries to remove. Please add some first.${RESET}"
    pause # From _utils.sh
    return
  fi

  # Display entries with numbers for selection
  echo -e "${CYAN}Select one or more entries to remove by their numbers (comma-separated):${RESET}"
  echo "" # Extra space

  # Define ANSI color codes for awk.
  local bold_code=$BOLD # From _colors.sh
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
    read -p "$(printf "${YELLOW}Enter numbers of entries to remove (e.g., '${BOLD}1,3,5${RESET}${YELLOW}'):${RESET} ") " selected_indices_str_input
    selected_indices_str=$(trim "$selected_indices_str_input") # From _utils.sh
    echo "" # Extra space

    local lower_input=$(echo "$selected_indices_str" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "${CYAN}Operation cancelled. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi

    IFS=',' read -r -a selected_indices <<< "$selected_indices_str"
    valid_indices=()
    local all_valid=true

    for idx_str in "${selected_indices[@]}"; do
      local idx=$(trim "$idx_str") # From _utils.sh
      if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= num_entries )); then
        valid_indices+=("$idx")
      else
        echo -e "${RED}🚫 Invalid entry number: '${idx_str}'. Please enter valid numbers or type '${CYAN}C${RED}' to cancel.${RESET}"
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
      echo -e "${RED}🚫 No valid entries selected. Please enter at least one number, or type '${CYAN}C${RED}' to cancel.${RESET}"
    fi
    echo "" # Extra space
  done

  # --- Display preview of selected entries for removal ---
  echo -e "\n${BOLD}${BLUE}--- Entries to be Permanently Removed ---${RESET}"

  # Use the same preview format as view_entries_formatted for the selected entries
  local entries_to_remove_json
  entries_to_remove_json=$(echo "$entries_json" | jq "[ $(IFS=,; for idx in "${valid_indices[@]}"; do echo ".[$((idx-1))]"; done | paste -sd, -) ]")

  # Define ANSI color codes for awk.
  local bold_code=$BOLD
  local reset_code=$RESET
  local cyan_code=$CYAN
  local blue_code=$BLUE

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
    read -p "$(printf "${YELLOW}Are you ${BOLD}SURE${RESET}${YELLOW} you want to PERMANENTLY remove these entries? (${RED}y/N${RESET}${YELLOW}):${RESET}") " confirm_removal_input
    confirm_removal=$(trim "${confirm_removal_input:-n}") # From _utils.sh - Default to 'n'
    echo "" # Extra space
    local lower_input=$(echo "$confirm_removal" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "c" ]]; then
      echo -e "${CYAN}Removal cancelled. Returning to main menu.${RESET}"
      pause # From _utils.sh
      return
    fi
    if [[ "$confirm_removal" =~ ^[yYnN]$ ]]; then
      break
    fi
    echo -e "${RED}🚫 Invalid input. Please enter '${BOLD}Y${RESET}${RED}' for Yes, '${BOLD}N${RESET}${RED}' for No, or '${CYAN}C${RED}' to cancel.${RESET}"
    echo "" # Extra space
  done

  if [[ "$confirm_removal" =~ ^[yY]$ ]]; then
    local updated_entries_json="$entries_json"
    for idx in "${valid_indices[@]}"; do
      echo -e "${CYAN}Removing entry ${idx}...${RESET}"
      # Remove the entry using jq. Note: indices are 0-based in jq.
      updated_entries_json=$(echo "$updated_entries_json" | jq "del(.[$((idx - 1))])")
    done
    save_entries "$updated_entries_json" # From _data_storage.sh
    echo -e "${GREEN}✅ Selected entries removed successfully!${RESET}"
  else
    echo -e "${CYAN}Removal cancelled.${RESET}"
  fi
  pause # From _utils.sh
}
