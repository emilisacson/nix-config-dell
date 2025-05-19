#!/usr/bin/env bash

# Improved script to manually install Citrix Workspace from tarball with detailed logging

set -e

CITRIX_TAR="${HOME}/Downloads/linuxx64-24.11.0.85.tar.gz"
TEMP_DIR=$(mktemp -d)
LOG_FILE="${HOME}/citrix-installation-log.txt"

echo "Installing Citrix Workspace from ${CITRIX_TAR}" | tee -a ${LOG_FILE}
echo "Using temporary directory: ${TEMP_DIR}" | tee -a ${LOG_FILE}
echo "Log file: ${LOG_FILE}" | tee -a ${LOG_FILE}
echo "Installation date: $(date)" | tee -a ${LOG_FILE}

# Check if tarball exists
if [ ! -f "${CITRIX_TAR}" ]; then
  echo "Error: Citrix tarball not found at ${CITRIX_TAR}" | tee -a ${LOG_FILE}
  exit 1
fi

# Create a state snapshot before installation
echo "=== System state before installation ===" | tee -a ${LOG_FILE}
echo "Checking for existing Citrix directories:" | tee -a ${LOG_FILE}
ls -la /opt/Citrix 2>/dev/null || echo "No /opt/Citrix directory found" | tee -a ${LOG_FILE}
ls -la ${HOME}/.ICAClient 2>/dev/null || echo "No ${HOME}/.ICAClient directory found" | tee -a ${LOG_FILE}
ls -la ${HOME}/.citrix-workspace 2>/dev/null || echo "No ${HOME}/.citrix-workspace directory found" | tee -a ${LOG_FILE}

# Extract tarball to temp directory
echo "Extracting Citrix tarball..." | tee -a ${LOG_FILE}
tar -xzf "${CITRIX_TAR}" -C "${TEMP_DIR}"

# Run the Citrix installer with sudo
echo "Running Citrix installer with sudo..." | tee -a ${LOG_FILE}
cd "${TEMP_DIR}"
echo "You may need to enter your password for sudo access" | tee -a ${LOG_FILE}
sudo ./linuxx64/hinst CDROM "$(pwd)" | tee -a ${LOG_FILE}

# Create detailed report of installed files
echo "=== Creating file structure report ===" | tee -a ${LOG_FILE}

# System directories
echo "Files installed in /opt/Citrix:" > ${HOME}/citrix-files.txt
sudo find /opt/Citrix -type f | sort >> ${HOME}/citrix-files.txt 2>/dev/null || echo "No files in /opt/Citrix" >> ${HOME}/citrix-files.txt

echo "Files installed in /usr/share:" >> ${HOME}/citrix-files.txt
sudo find /usr/share -name "*citrix*" -o -name "*ica*" | sort >> ${HOME}/citrix-files.txt 2>/dev/null || echo "No Citrix files in /usr/share" >> ${HOME}/citrix-files.txt

echo "Executable files:" >> ${HOME}/citrix-files.txt
sudo find /usr/bin -name "*citrix*" -o -name "*ica*" -o -name "wfica*" -o -name "selfservice*" | sort >> ${HOME}/citrix-files.txt 2>/dev/null || echo "No Citrix executables in /usr/bin" >> ${HOME}/citrix-files.txt

# User directories
echo "User-level files in ~/.ICAClient:" >> ${HOME}/citrix-files.txt
find ${HOME}/.ICAClient -type f | sort >> ${HOME}/citrix-files.txt 2>/dev/null || echo "No files in ${HOME}/.ICAClient" >> ${HOME}/citrix-files.txt

echo "User-level files in ~/.citrix-workspace:" >> ${HOME}/citrix-files.txt
find ${HOME}/.citrix-workspace -type f | sort >> ${HOME}/citrix-files.txt 2>/dev/null || echo "No files in ${HOME}/.citrix-workspace" >> ${HOME}/citrix-files.txt

echo "Symlinks in ~/.local/bin:" >> ${HOME}/citrix-files.txt
find ${HOME}/.local/bin -name "*citrix*" -o -name "*ica*" -o -name "wfica*" -o -name "selfservice*" -type l -exec ls -l {} \; >> ${HOME}/citrix-files.txt 2>/dev/null || echo "No Citrix symlinks in ${HOME}/.local/bin" >> ${HOME}/citrix-files.txt

# Check for configuration files
echo "=== Checking for configuration files ===" | tee -a ${LOG_FILE}
echo "Looking for EULA acceptance files:" | tee -a ${LOG_FILE}
find /opt/Citrix -name "*.eula*" 2>/dev/null | tee -a ${LOG_FILE} || echo "No EULA files found in /opt/Citrix" | tee -a ${LOG_FILE}
find ${HOME}/.ICAClient -name "*.eula*" 2>/dev/null | tee -a ${LOG_FILE} || echo "No EULA files found in ${HOME}/.ICAClient" | tee -a ${LOG_FILE}
find ${HOME}/.citrix-workspace -name "*.eula*" 2>/dev/null | tee -a ${LOG_FILE} || echo "No EULA files found in ${HOME}/.citrix-workspace" | tee -a ${LOG_FILE}

# Test Citrix commands
echo "=== Testing Citrix commands ===" | tee -a ${LOG_FILE}
which selfservice 2>/dev/null | tee -a ${LOG_FILE} || echo "selfservice command not found" | tee -a ${LOG_FILE}
which wfica 2>/dev/null | tee -a ${LOG_FILE} || echo "wfica command not found" | tee -a ${LOG_FILE}

echo "Installation complete." | tee -a ${LOG_FILE}
echo "A report of installed files has been saved to: ${HOME}/citrix-files.txt" | tee -a ${LOG_FILE}
echo "A detailed log has been saved to: ${LOG_FILE}" | tee -a ${LOG_FILE}
echo "You can now try running 'selfservice' or 'wfica' commands." | tee -a ${LOG_FILE}

# Clean up temp directory
rm -rf "${TEMP_DIR}"