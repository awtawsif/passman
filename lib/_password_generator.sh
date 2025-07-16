#!/bin/bash
# _password_generator.sh
# Contains functions for generating random passwords.
# Sourced by passman.sh.

# --- Strict Mode for Robustness ---
set -e
set -u
set -o pipefail

# Dependencies:
# None explicit, but _colors.sh provides variables used in calling functions' prompts.

# Generates a random password based on specified criteria.
# Arguments:
#   $1: Length of the password.
#   $2: "y" to include uppercase letters, "n" otherwise.
#   $3: "y" to include numbers, "n" otherwise.
#   $4: "y" to include symbols, "n" otherwise.
# Returns:
#   Generated password on stdout.
generate_password() {
  local length=$1
  local use_upper=$2
  local use_numbers=$3
  local use_symbols=$4

  local lower_chars="abcdefghijklmnopqrstuvwxyz"
  local upper_chars="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  local number_chars="0123456789"
  local symbol_chars="!@#$%^&*()-_=+[]{}|;:<>,./?"

  local char_pool="$lower_chars"
  [[ "$use_upper" =~ ^[yY]$ ]] && char_pool+="$upper_chars"
  [[ "$use_numbers" =~ ^[yY]$ ]] && char_pool+="$number_chars"
  [[ "$use_symbols" =~ ^[yY]$ ]] && char_pool+="$symbol_chars"

  # Use /dev/urandom for cryptographically secure random password generation
  < /dev/urandom tr -dc "$char_pool" | head -c "$length"
  echo
}