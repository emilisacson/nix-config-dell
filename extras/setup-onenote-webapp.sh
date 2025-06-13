#!/usr/bin/env bash

# Native OneNote web app installation script
# This script will create a browser-based PWA for OneNote
# It's a more reliable alternative to Electron-based p3x-onenote

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up Native OneNote Web App${NC}"
echo "This script will set up a browser-based OneNote solution that bypasses Electron issues"

# Determine which browsers are available
CHROME_BASED_BROWSERS=()

if command -v brave &> /dev/null; then
    CHROME_BASED_BROWSERS+=("brave")
fi

if command -v chromium &> /dev/null; then
    CHROME_BASED_BROWSERS+=("chromium")
fi

if command -v google-chrome &> /dev/null; then
    CHROME_BASED_BROWSERS+=("google-chrome")
fi

if command -v microsoft-edge &> /dev/null; then
    CHROME_BASED_BROWSERS+=("microsoft-edge")
fi

if [ ${#CHROME_BASED_BROWSERS[@]} -eq 0 ]; then
    echo "No Chrome-based browsers found. Please install Brave, Chromium, Google Chrome, or Microsoft Edge."
    exit 1
fi

# Select the best browser
BROWSER=${CHROME_BASED_BROWSERS[0]}
echo -e "Using ${YELLOW}$BROWSER${NC} to create the OneNote web app"

# Create the app
echo "Creating OneNote web app..."
$BROWSER --app=https://www.onenote.com/notebooks

echo -e "${GREEN}Setup complete!${NC}"
echo "You should now be able to use OneNote directly in your browser."
echo -e "${YELLOW}TIP:${NC} You can also install OneNote as a PWA by clicking the install button in your browser's address bar."
echo "This will create a standalone app-like experience without the Electron issues."
