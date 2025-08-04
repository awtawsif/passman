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

This project can be installed as a package on Arch Linux.

### Prerequisites

Ensure you have the necessary dependencies installed on your system.

*   **bash:** (usually pre-installed on Linux/macOS)
*   **jq:** A lightweight and flexible command-line JSON processor.
*   **openssl:** A robust, commercial-grade, and full-featured toolkit for the Transport Layer Security (TLS) and Secure Sockets Layer (SSL) protocols and a rich cryptography library.
*   **git:** (for cloning the repository)

You can install them using `pacman`:
```bash
sudo pacman -Syu --needed bash jq openssl git
```

### Building from Source

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/awtawsif/passman.git
    cd passman
    ```

2.  **Create the source tarball:**
    The `PKGBUILD` is configured to use a source tarball. Create it with the following command:
    ```bash
    tar -czf passman-1.0.0.tar.gz --exclude='.git' --exclude='.gitignore' --exclude='*.pkg.tar.zst' .
    ```

3.  **Build and install the package:**
    Use `makepkg` to build and install the package. The `-si` flags will automatically install the dependencies and the package itself.
    ```bash
    makepkg -si
    ```

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
*   **Manage Settings:** Configure application settings, including default password generation criteria and data file location.

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
