#!/bin/bash
# _colors.sh
# Defines unique ANSI color escape codes for a "Cyberpunk" terminal output theme.

# === CYBERPUNK COLOR PALETTE ===
NEON_RED='\033[1;91m'    # Critical errors, warnings that demand immediate attention
LIME_GREEN='\033[1;92m'  # Success messages, positive confirmations, secure actions
ELECTRIC_YELLOW='\033[1;93m' # Prompts, important user input fields, highlights
CYBER_BLUE='\033[0;34m'   # General information, hints, subtle guidance
VIOLET='\033[1;35m'      # Distinct section headers, main menu titles
AQUA='\033[1;36m'        # Stronger emphasis, decorative lines, special features
DIM_GREY='\033[0;90m'    # Less important information, subtle separators, background text
TEXT_CYAN='\033[0;36m'       # Subtle text, default values, secondary info

# === TEXT ATTRIBUTES ===
BRIGHT_BOLD='\033[1m\033[1;97m'           # Standard bold text (can be combined with colors)
RESET='\033[0m'          # Reset all attributes to default
