#!/bin/bash
# _display_search.sh
# Contains functions for displaying and searching credential entries.
# Sourced by passman.sh.

# --- Strict Mode for Robustness ---
set -e
set -u
set -o pipefail

# Dependencies:
# - _colors.sh (for color variables like RED, GREEN, YELLOW, CYAN, BLUE, BOLD, RESET)
# - _utils.sh (for clear_screen, pause, trim)
# - _data_storage.sh (for load_entries)

# Searches for entries based on user-provided filters.
search_entries() {
  clear_screen
  echo -e "${BOLD}${MAGENTA}--- Search Credentials ---${RESET}"
  echo -e "${CYAN}🔎 Select which fields to filter by. You can pick multiple, separated by commas (e.g. 1,3,5).${RESET}\n"

  # List of filterable fields
  local field_names=("Website" "Email" "Username" "Logged in via" "Linked email" "Recovery email")
  local field_vars=("f_website" "f_email" "f_username" "f_logged_in_via" "f_linked_email" "f_recovery_email")
  local field_prompts=(
    "🌐 Website contains"
    "📧 Email contains"
    "👤 Username contains"
    "🔗 Logged in via contains"
    "📧 Linked email contains"
    "🚨 Recovery email contains"
  )

  # Show menu
  for i in "${!field_names[@]}"; do
    echo -e "  ${BOLD}$((i+1)))${RESET} ${field_names[$i]}"
  done
  echo ""

  read -p "$(printf "${YELLOW}Enter field numbers to filter by (comma-separated), or press Enter to show all:${RESET} ")" field_choices
  field_choices=$(trim "$field_choices")

  # Initialize all filters as empty
  for var in "${field_vars[@]}"; do
    eval "$var=''"
  done

  # If user entered choices, prompt only for those fields
  if [[ -n "$field_choices" ]]; then
    IFS=',' read -ra selected_fields <<< "$field_choices"
    for idx in "${selected_fields[@]}"; do
      idx=$(echo "$idx" | xargs) # trim spaces
      if [[ "$idx" =~ ^[1-6]$ ]]; then
        prompt="${field_prompts[$((idx-1))]}"
        read -p "$(printf "${YELLOW}%s: ${RESET}" "$prompt")" value
        value=$(trim "$value")
        eval "${field_vars[$((idx-1))]}=\"\$value\""
        echo ""
      fi
    done
  else
    # If no selection, prompt for nothing (show all)
    :
  fi

  echo -e "${CYAN}Searching for matching credentials...${RESET}\n"

  local entries_json
  entries_json=$(load_entries)
  if [[ $? -ne 0 ]]; then
    pause
    return
  fi

  local jq_filter='.'
  local conditions=()

  if [[ -n "$f_website" ]]; then
    conditions+=("(.website | ascii_downcase | contains(\"$(echo "$f_website" | sed 's/\\/\\\\/g' | sed 's/\"/\\"/g' | tr '[:upper:]' '[:lower:]')\"))")
  fi
  if [[ -n "$f_email" ]]; then
    conditions+=("((.email // \"\") | ascii_downcase | contains(\"$(echo "$f_email" | sed 's/\\/\\\\/g' | sed 's/\"/\\"/g' | tr '[:upper:]' '[:lower:]')\"))")
  fi
  if [[ -n "$f_username" ]]; then
    conditions+=("((.username // \"\") | ascii_downcase | contains(\"$(echo "$f_username" | sed 's/\\/\\\\/g' | sed 's/\"/\\"/g' | tr '[:upper:]' '[:lower:]')\"))")
  fi
  if [[ -n "$f_logged_in_via" ]]; then
    conditions+=("((.logged_in_via // \"\") | ascii_downcase | contains(\"$(echo "$f_logged_in_via" | sed 's/\\/\\\\/g' | sed 's/\"/\\"/g' | tr '[:upper:]' '[:lower:]')\"))")
  fi
  if [[ -n "$f_linked_email" ]]; then
    conditions+=("((.linked_email // \"\") | ascii_downcase | contains(\"$(echo "$f_linked_email" | sed 's/\\/\\\\/g' | sed 's/\"/\\"/g' | tr '[:upper:]' '[:lower:]')\"))")
  fi
  if [[ -n "$f_recovery_email" ]]; then
    conditions+=("((.recovery_email // \"\") | ascii_downcase | contains(\"$(echo "$f_recovery_email" | sed 's/\\/\\\\/g' | sed 's/\"/\\"/g' | tr '[:upper:]' '[:lower:]')\"))")
  fi

  # Ask user for filter mode (AND/OR)
  local filter_mode="and"
  if [[ ${#conditions[@]} -gt 1 ]]; then
    echo -e "${YELLOW}How should filters be combined?${RESET}"
    echo -e "  ${BOLD}1)${RESET} Match ${BOLD}ALL${RESET} filters (AND)"
    echo -e "  ${BOLD}2)${RESET} Match ${BOLD}ANY${RESET} filter (OR)"
    read -p "$(printf "${YELLOW}Enter 1 for AND, 2 for OR [default: 1]:${RESET} ")" filter_mode_choice
    filter_mode_choice=$(trim "$filter_mode_choice")
    if [[ "$filter_mode_choice" == "2" ]]; then
      filter_mode="or"
    fi
  fi
  
  # Safely join the conditions
  local filter_joined=""
  if [[ ${#conditions[@]} -gt 0 ]]; then
    filter_joined=$(printf "%s" "${conditions[0]}")
    for (( i=1; i<${#conditions[@]}; i++ )); do
      if [[ "$filter_mode" == "and" ]]; then
        filter_joined="$filter_joined and ${conditions[$i]}"
      else
        filter_joined="$filter_joined or ${conditions[$i]}"
      fi
    done
    jq_filter=".[] | select($filter_joined)"
  else
    jq_filter=".[]"
  fi

  local filtered_json_array
  filtered_json_array=$(echo "$entries_json" | jq -c "$jq_filter" | jq -s '.')

  # Check if any results were found (length of the array is 0)
  if echo "$filtered_json_array" | jq -e 'length == 0' &>/dev/null; then
    echo -e "${RED}❌ No matching entries found based on your filters.${RESET}"
  else
    echo -e "${GREEN}--- Matching Entries Found ---${RESET}"
    echo "" # Extra space

    # Define ANSI color codes for awk.
    local bold_code=$BOLD # From _colors.sh
    local reset_code=$RESET # From _colors.sh
    local cyan_code=$CYAN # From _colors.sh
    local blue_code=$BLUE # From _colors.sh

    # Use jq to iterate over the array and format output with index, similar to view_entries_formatted
    echo "$filtered_json_array" | jq -r '
      .[] |
      "\(.website)\t\(.email // "")\t\(.username // "")\t\(.password // "")\t\(.logged_in_via // "")\t\(.linked_email // "")\t\(.recovery_email // "")\t\(.added)"
    ' | awk -F'\t' \
      -v BOLD_AWK="${bold_code}" \
      -v RESET_AWK="${reset_code}" \
      -v CYAN_AWK="${cyan_code}" \
      -v BLUE_AWK="${blue_code}" \
      '{
      printf "  %s%s%s\n", BLUE_AWK, "===================================", RESET_AWK
      printf "  %sResult %d:%s\n", BOLD_AWK, NR, RESET_AWK
      printf "    %s🌐 Website      :%s %s\n", CYAN_AWK, RESET_AWK, $1 # Always display website

      if ($2 != "") { # Display Email if not empty
          printf "    %s📧 Email        :%s %s\n", CYAN_AWK, RESET_AWK, $2
      }
      if ($3 != "") { # Display Username if not empty
          printf "    %s👤 Username     :%s %s\n", CYAN_AWK, RESET_AWK, $3
      }
      if ($4 != "") { # Display Password if not empty
          printf "    %s🔑 Password     :%s %s\n", CYAN_AWK, RESET_AWK, $4
      }

      if ($5 != "") { # Display Logged in via if not empty
          printf "    %s🔗 Logged in via:%s %s\n", CYAN_AWK, RESET_AWK, $5
      }
      if ($6 != "") { # Display Linked email if not empty
          printf "    %s📧 Linked email :%s %s\n", CYAN_AWK, RESET_AWK, $6
      }
      if ($7 != "") { # Display Recovery email if not empty (new field)
          printf "    %s🚨 Recovery email:%s %s\n", CYAN_AWK, RESET_AWK, $7
      }
      printf "    %s📅 Added        :%s %s\n", CYAN_AWK, RESET_AWK, $8 # Always display added date
      printf "  %s%s%s\n", BLUE_AWK, "===================================", RESET_AWK
    }' || true # This was the previous fix.

    # --- Clipboard Integration ---
    local num_results=$(echo "$filtered_json_array" | jq 'length')
    if [[ "$num_results" -gt 0 ]]; then
      echo -e "${YELLOW}Would you like to copy a field from a result to the clipboard?${RESET}"
      read -p "$(printf "${YELLOW}Enter result number [1-%d] to copy, or press Enter to skip:${RESET} " "$num_results")" copy_idx
      copy_idx=$(trim "$copy_idx")
      if [[ "$copy_idx" =~ ^[0-9]+$ ]] && (( copy_idx >= 1 && copy_idx <= num_results )); then
        # Determine available fields for the selected entry
        local entry_json
        entry_json=$(echo "$filtered_json_array" | jq ".[$((copy_idx-1))]")
        local options=()
        local option_labels=()
        local field_map=()
        local opt_num=1

        if [[ "$(echo "$entry_json" | jq -r '.password // empty')" != "" ]]; then
          options+=("password")
          option_labels+=("Password")
          field_map+=(".password // \"\"")
        fi
        if [[ "$(echo "$entry_json" | jq -r '.email // empty')" != "" ]]; then
          options+=("email")
          option_labels+=("Email")
          field_map+=(".email // \"\"")
        fi
        if [[ "$(echo "$entry_json" | jq -r '.username // empty')" != "" ]]; then
          options+=("username")
          option_labels+=("Username")
          field_map+=(".username // \"\"")
        fi
        if [[ "$(echo "$entry_json" | jq -r '.linked_email // empty')" != "" ]]; then
          options+=("linked_email")
          option_labels+=("Linked Email")
          field_map+=(".linked_email // \"\"")
        fi

        if [[ "${#options[@]}" -eq 0 ]]; then
          echo -e "${YELLOW}No available fields to copy for this entry.${RESET}"
        else
          echo -e "${YELLOW}Which field do you want to copy?${RESET}"
          for i in "${!options[@]}"; do
            echo -e "  ${BOLD}$((i+1)))${RESET} ${option_labels[$i]}"
          done
          read -p "$(printf "${YELLOW}Enter field number [1-%d]:${RESET} " "${#options[@]}")" field_idx
          field_idx=$(trim "$field_idx")
          if [[ "$field_idx" =~ ^[0-9]+$ ]] && (( field_idx >= 1 && field_idx <= ${#options[@]} )); then
            local jq_field="${field_map[$((field_idx-1))]}"
            local value_to_copy
            value_to_copy=$(echo "$entry_json" | jq -r "$jq_field")
            if [[ -n "$value_to_copy" ]]; then
              copy_to_clipboard "$value_to_copy"
              if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}Copied to clipboard!${RESET}"
              fi
            else
              echo -e "${YELLOW}No value found for the selected field.${RESET}"
            fi
          fi
        fi
      fi
    fi
  fi

  pause # From _utils.sh
}

# Displays all saved credentials from the JSON file in a formatted list.
# Returns:
#   Number of entries found.
view_entries_formatted() {
  local entries_json
  entries_json=$(load_entries) # From _data_storage.sh
  if [[ $? -ne 0 ]]; then
    return 0 # Indicate no entries could be loaded
  fi

  local num_entries=$(echo "$entries_json" | jq 'length')

  if [[ "$num_entries" -eq 0 ]]; then
    echo -e "${YELLOW}No entries found yet. Start by adding a new one!${RESET}"
    return 0
  fi

  echo -e "${BOLD}All saved credentials (${num_entries} entries):${RESET}"
  echo "" # Extra space

  # Define ANSI color codes in shell variables, then pass them to awk.
  local bold_code=$BOLD # From _colors.sh
  local reset_code=$RESET # From _colors.sh
  local cyan_code=$CYAN # From _colors.sh
  local blue_code=$BLUE # From _colors.sh

  # Use jq to iterate and format output with index
  # jq output remains tab-separated for awk's -F'\t'. Use empty string instead of "N/A" for awk logic.
  echo "$entries_json" | jq -r '
    .[] |
    "\(.website)\t\(.email // "")\t\(.username // "")\t\(.password // "")\t\(.logged_in_via // "")\t\(.linked_email // "")\t\(.recovery_email // "")\t\(.added)"
  ' | awk -F'\t' \
    -v BOLD_AWK="${bold_code}" \
    -v RESET_AWK="${reset_code}" \
    -v CYAN_AWK="${cyan_code}" \
    -v BLUE_AWK="${blue_code}" \
    '{ # Use tab as field separator
    # Print a header for the entry
    printf "  %s%s%s\n", BLUE_AWK, "===================================", RESET_AWK
    printf "  %sEntry %d:%s\n", BOLD_AWK, NR, RESET_AWK # Correctly use awk variables for color

    printf "    %s🌐 Website      :%s %s\n", CYAN_AWK, RESET_AWK, $1 # Always display website

    if ($2 != "") { # Display Email if not empty
        printf "    %s📧 Email        :%s %s\n", CYAN_AWK, RESET_AWK, $2
    }
    if ($3 != "") { # Display Username if not empty
        printf "    %s👤 Username     :%s %s\n", CYAN_AWK, RESET_AWK, $3
    }
    if ($4 != "") { # Display Password if not empty
        printf "    %s🔑 Password     :%s %s\n", CYAN_AWK, RESET_AWK, $4
    }

    if ($5 != "") { # Display Logged in via if not empty
        printf "    %s🔗 Logged in via:%s %s\n", CYAN_AWK, RESET_AWK, $5
    }
    if ($6 != "") { # Display Linked email if not empty
        printf "    %s📧 Linked email :%s %s\n", CYAN_AWK, RESET_AWK, $6
    }
    if ($7 != "") { # Display Recovery email if not empty (new field)
        printf "    %s🚨 Recovery email:%s %s\n", CYAN_AWK, RESET_AWK, $7
    }
    printf "    %s📅 Added        :%s %s\n", CYAN_AWK, RESET_AWK, $8 # Always display added date
    printf "  %s%s%s\n", BLUE_AWK, "===================================", RESET_AWK
  }' || true # Add || true to prevent script exit on display errors

  # The key fix: always return 0 for successful completion of the display function.
  return 0
}

# Wrapper for view_entries_formatted to be used in the main menu.
view_all_entries_menu() {
  clear_screen # From _utils.sh
  echo -e "${BOLD}${MAGENTA}--- View All Credentials ---${RESET}\n"
  view_entries_formatted

  # --- Clipboard Integration for All Entries ---
  local entries_json
  entries_json=$(load_entries)
  local num_entries=$(echo "$entries_json" | jq 'length')
  if [[ "$num_entries" -gt 0 ]]; then
    echo -e "${YELLOW}Would you like to copy a field from an entry to the clipboard?${RESET}"
    read -p "$(printf "${YELLOW}Enter entry number [1-%d] to copy, or press Enter to skip:${RESET} " "$num_entries")" copy_idx
    copy_idx=$(trim "$copy_idx")
    if [[ "$copy_idx" =~ ^[0-9]+$ ]] && (( copy_idx >= 1 && copy_idx <= num_entries )); then
      # Determine available fields for the selected entry
      local entry_json
      entry_json=$(echo "$entries_json" | jq ".[$((copy_idx-1))]")
      local options=()
      local option_labels=()
      local field_map=()
      local opt_num=1

      if [[ "$(echo "$entry_json" | jq -r '.password // empty')" != "" ]]; then
        options+=("password")
        option_labels+=("Password")
        field_map+=(".password // \"\"")
      fi
      if [[ "$(echo "$entry_json" | jq -r '.email // empty')" != "" ]]; then
        options+=("email")
        option_labels+=("Email")
        field_map+=(".email // \"\"")
      fi
      if [[ "$(echo "$entry_json" | jq -r '.username // empty')" != "" ]]; then
        options+=("username")
        option_labels+=("Username")
        field_map+=(".username // \"\"")
      fi
      if [[ "$(echo "$entry_json" | jq -r '.linked_email // empty')" != "" ]]; then
        options+=("linked_email")
        option_labels+=("Linked Email")
        field_map+=(".linked_email // \"\"")
      fi

      if [[ "${#options[@]}" -eq 0 ]]; then
        echo -e "${YELLOW}No available fields to copy for this entry.${RESET}"
      else
        echo -e "${YELLOW}Which field do you want to copy?${RESET}"
        for i in "${!options[@]}"; do
          echo -e "  ${BOLD}$((i+1)))${RESET} ${option_labels[$i]}"
        done
        read -p "$(printf "${YELLOW}Enter field number [1-%d]:${RESET} " "${#options[@]}")" field_idx
        field_idx=$(trim "$field_idx")
        if [[ "$field_idx" =~ ^[0-9]+$ ]] && (( field_idx >= 1 && field_idx <= ${#options[@]} )); then
          local jq_field="${field_map[$((field_idx-1))]}"
          local value_to_copy
          value_to_copy=$(echo "$entry_json" | jq -r "$jq_field")
          if [[ -n "$value_to_copy" ]]; then
            copy_to_clipboard "$value_to_copy"
            if [[ $? -eq 0 ]]; then
              echo -e "${GREEN}Copied to clipboard!${RESET}"
            fi
          else
            echo -e "${YELLOW}No value found for the selected field.${RESET}"
          fi
        fi
      fi
    fi
  fi

  pause # From _utils.sh
}
