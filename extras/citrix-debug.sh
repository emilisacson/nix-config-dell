#!/bin/bash
#
# Citrix Workspace WebKit Debug & Fix Script
# This script helps diagnose and fix WebKit library issues with Citrix Workspace
#

set -e

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_header() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }
print_success() { echo -e "${GREEN}$1${NC}"; }
print_warning() { echo -e "${YELLOW}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}"; }
print_info() { echo -e "$1"; }

print_header "Citrix Workspace WebKit Debug & Fix Script"

# Check for existing Citrix installations
print_header "Checking Citrix Installation Locations"
CITRIX_PATHS=(
  "$HOME/.citrix-workspace/opt/Citrix/ICAClient"
  "$HOME/.local/share/citrix-workspace"
  "/opt/Citrix/ICAClient"
)

FOUND_PATH=""
for path in "${CITRIX_PATHS[@]}"; do
  if [ -d "$path" ]; then
    if [ -x "$path/selfservice" ]; then
      FOUND_PATH="$path"
      print_success "✓ Found Citrix installation at: $FOUND_PATH"
    else
      print_warning "! Directory exists but missing executable: $path/selfservice"
    fi
  else
    print_info "- Not found: $path"
  fi
done

if [ -z "$FOUND_PATH" ]; then
  print_error "ERROR: Citrix Workspace not found at any expected location."
  print_info "Please make sure you have installed Citrix Workspace properly."
  exit 1
fi

# Check WebKit libraries in Citrix directory
print_header "Checking WebKit Libraries in Citrix Directory"
CITRIX_DIR="$FOUND_PATH"
WEBKIT_FILES=(
  "libwebkit2gtk-4.0.so"
  "libwebkit2gtk-4.0.so.37"
  "libwebkit2gtk-4.1.so"
  "libwebkit2gtk-4.1.so.37"
)

for file in "${WEBKIT_FILES[@]}"; do
  if [ -e "$CITRIX_DIR/$file" ]; then
    if [ -L "$CITRIX_DIR/$file" ]; then
      TARGET=$(readlink -f "$CITRIX_DIR/$file")
      if [ -e "$TARGET" ]; then
        print_success "✓ $file is a valid symlink to: $TARGET"
      else
        print_error "✗ $file is a broken symlink to: $TARGET"
      fi
    else
      print_info "- $file exists but is not a symlink"
    fi
  else
    print_info "- $file not found in $CITRIX_DIR"
  fi
done

# Find all WebKit libraries in the system
print_header "Finding WebKit Libraries in System"
WEBKIT_LIBS=()

# Search patterns for WebKit libraries
SEARCH_PATTERNS=(
  "/nix/store/*/libwebkit2gtk-4.0.so.37"
  "/nix/store/*/libwebkit2gtk-4.1.so.37"
  "/nix/store/*/lib/libwebkit2gtk-4.0.so.37"
  "/nix/store/*/lib/libwebkit2gtk-4.1.so.37"
  "/nix/store/*webkitgtk*/lib/libwebkit2gtk-4.0.so*"
  "/nix/store/*webkitgtk*/lib/libwebkit2gtk-4.1.so*"
)

for pattern in "${SEARCH_PATTERNS[@]}"; do
  while IFS= read -r lib; do
    if [ -n "$lib" ] && [ -f "$lib" ]; then
      WEBKIT_LIBS+=("$lib")
    fi
  done < <(find $pattern 2>/dev/null || true)
done

# Display found WebKit libraries
if [ ${#WEBKIT_LIBS[@]} -eq 0 ]; then
  print_error "No WebKit libraries found in the system!"
else
  print_success "Found ${#WEBKIT_LIBS[@]} WebKit libraries:"
  for lib in "${WEBKIT_LIBS[@]}"; do
    echo "  - $lib"
  done
fi

# Find the most appropriate WebKit library
print_header "Finding Best WebKit Library Match"
BEST_WEBKIT=""
BEST_VERSION=""

# Prefer 4.0 libraries over 4.1 if they exist
for lib in "${WEBKIT_LIBS[@]}"; do
  if [[ "$lib" == *"libwebkit2gtk-4.0.so"* ]]; then
    BEST_WEBKIT="$lib"
    BEST_VERSION="4.0"
    print_success "Selected WebKit 4.0 library: $BEST_WEBKIT"
    break
  fi
done

# If no 4.0 library found, use 4.1
if [ -z "$BEST_WEBKIT" ]; then
  for lib in "${WEBKIT_LIBS[@]}"; do
    if [[ "$lib" == *"libwebkit2gtk-4.1.so"* ]]; then
      BEST_WEBKIT="$lib"
      BEST_VERSION="4.1"
      print_success "Selected WebKit 4.1 library: $BEST_WEBKIT"
      break
    fi
  done
fi

if [ -z "$BEST_WEBKIT" ]; then
  print_error "Could not find a suitable WebKit library!"
  print_info "You may need to install webkit2gtk or webkitgtk in your configuration."
  exit 1
fi

# Create symlinks to the WebKit library
print_header "Creating WebKit Symlinks"

create_webkit_symlinks() {
  local dir="$1"
  local webkit_lib="$2"
  
  if [ ! -d "$dir" ]; then
    print_warning "Directory does not exist: $dir"
    return
  fi
  
  print_info "Creating symlinks in: $dir"
  
  # Create symlinks for both 4.0 and 4.1 versions
  ln -sf "$webkit_lib" "$dir/libwebkit2gtk-4.0.so.37"
  ln -sf "$webkit_lib" "$dir/libwebkit2gtk-4.0.so"
  ln -sf "$webkit_lib" "$dir/libwebkit2gtk-4.1.so.37" 
  ln -sf "$webkit_lib" "$dir/libwebkit2gtk-4.1.so"
  
  print_success "✓ WebKit symlinks created in $dir"
}

# Create symlinks in all Citrix paths
for path in "${CITRIX_PATHS[@]}"; do
  create_webkit_symlinks "$path" "$BEST_WEBKIT"
done

# Check for ldd dependencies
print_header "Checking Citrix Executable Dependencies"
if [ -x "$FOUND_PATH/selfservice" ]; then
  print_info "Dependencies for $FOUND_PATH/selfservice:"
  ldd "$FOUND_PATH/selfservice" | grep -i webkit || echo "No WebKit dependency found!"
  
  # Check for other missing dependencies
  MISSING=$(ldd "$FOUND_PATH/selfservice" 2>/dev/null | grep "not found")
  if [ -n "$MISSING" ]; then
    print_error "Missing dependencies detected:"
    echo "$MISSING"
  else
    print_success "✓ No missing dependencies detected"
  fi
else
  print_error "Cannot check dependencies: selfservice executable not found"
fi

# Create a test launch script to help diagnose issues
print_header "Creating Test Launch Script"
TEST_SCRIPT="$HOME/launch-citrix-test.sh"

cat > "$TEST_SCRIPT" << EOF
#!/bin/bash

# Citrix test launcher with extensive debugging
# Created by Citrix Debug Script

export ICAROOT="$FOUND_PATH"
export CITRIX_DEBUG=1
export CITRIX_ENGINE_LOGLEVEL=9
export WEBKIT_DEBUG=1
export G_MESSAGES_DEBUG=all

# SSL settings for troubleshooting
export LIBCITRIX_DISABLE_CTX_MITM_CHECK=1
export LIBCITRIX_CTX_SSL_FORCE_ACCEPT=1
export LIBCITRIX_CTX_SSL_VERIFY_MODE=0
export ICA_SSL_VERIFY_MODE=0

# Set up library paths - using both the system libs and Citrix's libs
export LD_LIBRARY_PATH=\$ICAROOT:\$ICAROOT/lib:$(dirname "$BEST_WEBKIT")

# Runtime logging
echo "Starting Citrix in debug mode"
echo "ICAROOT=\$ICAROOT"
echo "LD_LIBRARY_PATH=\$LD_LIBRARY_PATH"
echo "WebKit library: $BEST_WEBKIT"

# Run with GDB to catch any segfaults
if command -v gdb >/dev/null 2>&1; then
  echo "Running with GDB for crash analysis..."
  gdb -ex "run" -ex "bt" -ex "quit" --args \$ICAROOT/selfservice "\$@"
else
  # Run directly if GDB is not available
  echo "Running Citrix directly (no GDB)..."
  \$ICAROOT/selfservice "\$@"
fi
EOF

chmod +x "$TEST_SCRIPT"
print_success "✓ Created test script at $TEST_SCRIPT"

# Print summary and next steps
print_header "Summary"
if [ -n "$FOUND_PATH" ] && [ -n "$BEST_WEBKIT" ]; then
  print_success "✓ Citrix installation found at: $FOUND_PATH"
  print_success "✓ WebKit library found at: $BEST_WEBKIT"
  print_success "✓ WebKit symlinks created in all Citrix locations"
  print_success "✓ Test script created at: $TEST_SCRIPT"
  
  print_info ""
  print_info "Next steps:"
  print_info "1. Try running the regular Citrix launcher to see if it works now"
  print_info "2. If it still doesn't work, run the test script: $TEST_SCRIPT"
  print_info "3. The test script will provide detailed error information"
else
  print_error "Some issues were detected. Please review the output above."
fi

print_header "Do you want to run the test launcher now? (y/n)"
read -r RESPONSE
if [[ "$RESPONSE" =~ ^[Yy] ]]; thenI use Nix package Manager with Home manager on my Fedora 42 laptop.
I am in the process of setting up my nix config to install applications and for configuration.
Currently I'm having trouble with my Citrix workspace configuration and need help fixing it.

The following command should be run to test the Nix config:
nix run --impure .#homeConfigurations.$USER.activationPackage

Use it to see the error it currently gets and fix it.
  print_info "Running test launcher..."
  "$TEST_SCRIPT"
fi