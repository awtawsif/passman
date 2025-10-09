# Passman: Secure Password Manager

A robust and user-friendly command-line password manager designed for secure storage and easy management of your digital credentials. This tool encrypts your sensitive data using openssl AES-256-CBC encryption, ensuring your passwords are safe.

## Features

*   **Secure Authentication:** Protects your data with a master password.
*   **Strong Encryption:** Encrypts all credential entries using openssl AES-256-CBC for maximum security.
*   **Credential Management:**
    *   Add new entries with details like website, email, username, and password.
    *   Edit existing entries.
    *   Remove unwanted entries.
*   **Intelligent Search & Display:**
    *   Search for credentials by various fields, including Website, Email, Username, Logged-in-via, Linked Email, and Recovery Email.
    *   View all stored entries.
*   **Password Generation:** Generate strong, customizable random passwords. New entries will automatically use your default generation settings configured in the "Manage Settings" menu, streamlining the process.
*   **Master Password Management:** Easily change your master password securely.
*   **Secure Cleanup:** Automatically handles the secure deletion of temporary decrypted files upon exit to prevent data residue.

## Installation on Arch Linux

This project can be installed as a package on Arch Linux using an automated script.

### Prerequisites

Before running the installation script, ensure you have `git` installed to clone the repository.
```bash
sudo pacman -Syu --needed git
```

### Easy Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/awtawsif/passman.git
    cd passman
    ```

2.  **Run the installation script:**
    This script will automatically check for all other dependencies (like `jq`, `openssl`, `xclip`, `wl-clipboard`, and `makepkg`), create the source tarball, and build and install the package.
    ```bash
    chmod +x install.sh
    ./install.sh
    ```
    The script will prompt you for your password to install the package and any missing dependencies.

## Usage

Once installed, you can run the application from anywhere in your terminal:
```bash
passman
```

Upon the first run, you will be prompted to set a new master password. Remember this password, as it's crucial for accessing your stored credentials.

### Main Menu Options:

*   **Add new entry:** Interactively add details for a new credential (website, email, username, password, etc.). You can also choose to generate a strong password automatically.
*   **Search entries:** Filter your stored credentials by various criteria like website, email, or username.
*   **View all entries:** Display a list of all your stored credential entries.
*   **Edit existing entry:** Modify details for an already saved credential.
*   **Remove entry:** Permanently delete a credential entry from your secure storage.
*   **Quit:** Exit the application. Your data will be securely locked.
*   **Change master password:** Update your master password.
*   **Manage Settings:** Configure application settings, including default password generation criteria.

## File Structure

*   **passman.sh:** The main entry point of the application, handling authentication and orchestrating functional modules.
*   **lib/:** Directory containing modular shell scripts for various functionalities:
    *   `_change_master.sh`: Handles the logic for securely changing the master password.
    *   `_colors.sh`: Defines ANSI color codes for enhanced terminal output.
    *   `_config.sh`: Manages application settings and configurations.
    *   `_crud_operations.sh`: Contains functions for adding, editing, and removing credential entries.
    *   `_crypto.sh`: Manages encryption, decryption, and secure cleanup operations.
    *   `_data_storage.sh`: Handles loading and saving of JSON credential data to and from the encrypted file.
    *   `_display_search.sh`: Provides functions for displaying and searching through credential entries.
    *   `_password_generator.sh`: Implements logic for generating random, strong passwords.
    *   `_utils.sh`: Contains general utility functions like screen clearing, pausing, trimming input, and displaying spinners.
