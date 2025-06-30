# 🔐 Secure Password Manager

A robust and user-friendly command-line password manager designed for secure storage and easy management of your digital credentials. This tool encrypts your sensitive data using `openssl AES-256-CBC` encryption, ensuring your passwords are safe.

## ✨ Features

  * **Secure Authentication:** Protects your data with a master password.
  * **Strong Encryption:** Encrypts all credential entries using `openssl AES-256-CBC` for maximum security.
  * **Credential Management:**
      * Add new entries with details like website, email, username, and password.
      * Edit existing entries.
      * Remove unwanted entries.
  * **Intelligent Search & Display:**
      * Search for credentials by various fields, including Website, Email, Username, Logged-in-via, Linked Email, and Recovery Email.
      * View all stored entries.
  * **Password Generation:** Generate strong, customizable random passwords with options for length, uppercase letters, numbers, and symbols.
  * **Master Password Management:** Easily change your master password securely.
  * **Secure Cleanup:** Automatically handles the secure deletion of temporary decrypted files upon exit to prevent data residue.

## 💻 Installation

Before running the password manager, ensure you have the necessary dependencies installed on your system.

### Prerequisites

  * `bash` (usually pre-installed on Linux/macOS)
  * `jq`: A lightweight and flexible command-line JSON processor.
  * `openssl`: A robust, commercial-grade, and full-featured toolkit for the Transport Layer Security (TLS) and Secure Sockets Layer (SSL) protocols and a rich cryptography library.

#### Install Dependencies

**Debian/Ubuntu:**

```bash
sudo apt update
sudo apt install jq openssl
```

**Fedora:**

```bash
sudo dnf install jq openssl
```

**Arch Linux:**

```bash
sudo pacman -Sy jq openssl
```

**macOS (using Homebrew):**

```bash
brew install jq openssl
```

### Setup

1.  **Clone the repository:**

    ```bash
    git clone <your-repository-url>
    cd <your-repository-directory>
    ```

2.  **Make the main script executable:**

    ```bash
    chmod +x passman.sh
    ```

## 🚀 Usage

To start the password manager, run the `passman.sh` script from your terminal:

```bash
./passman.sh
```

Upon the first run, you will be prompted to set a new master password. Remember this password, as it's crucial for accessing your stored credentials.

### Main Menu Options:

1.  **Add new entry:** Interactively add details for a new credential (website, email, username, password, etc.). You can also choose to generate a strong password automatically.
2.  **Search entries:** Filter your stored credentials by various criteria like website, email, or username.
3.  **View all entries:** Display a list of all your stored credential entries.
4.  **Edit existing entry:** Modify details for an already saved credential.
5.  **Remove entry:** Permanently delete a credential entry from your secure storage.
6.  **Quit:** Exit the application. Your data will be securely locked.
7.  **Change master password:** Update your master password.

## 📂 File Structure

  * `passman.sh`: The main entry point of the application, handling authentication and orchestrating functional modules.
  * `lib/`: Directory containing modular shell scripts for various functionalities:
      * `_change_master.sh`: Handles the logic for securely changing the master password.
      * `_colors.sh`: Defines ANSI color codes for enhanced terminal output.
      * `_crud_operations.sh`: Contains functions for adding, editing, and removing credential entries.
      * `_crypto.sh`: Manages encryption, decryption, and secure cleanup operations.
      * `_data_storage.sh`: Handles loading and saving of JSON credential data to and from the encrypted file.
      * `_display_search.sh`: Provides functions for displaying and searching through credential entries.
      * `_password_generator.sh`: Implements logic for generating random, strong passwords.
      * `_utils.sh`: Contains general utility functions like screen clearing, pausing, trimming input, and displaying spinners.
