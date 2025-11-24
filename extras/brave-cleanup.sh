#!/usr/bin/env bash

# Brave Browser Lock Cleanup Script
# This script fixes the "profile appears to be in use by another Brave process" error

set -e

echo "🔧 Brave Browser Lock Cleanup Script"
echo "===================================="

# Check if Brave is actually running
echo "🔍 Checking for running Brave processes..."
# Use more specific patterns and exclude this script's PID
BRAVE_PIDS=$(ps aux | grep -E "(brave-browser|BraveSoftware)" | grep -v grep | grep -v $$ | awk '{print $2}' | tr '\n' ' ' | sed 's/[[:space:]]*$//')

if [ -n "$BRAVE_PIDS" ]; then
    echo "⚠️  Found running Brave processes: $BRAVE_PIDS"
    echo "🔍 Process details:"
    ps -p $BRAVE_PIDS -o pid,cmd 2>/dev/null || echo "   (PIDs may have already terminated)"
    read -p "Do you want to kill these processes? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔄 Killing Brave processes..."
        # Kill specific PIDs instead of using pkill pattern
        if [ -n "$BRAVE_PIDS" ]; then
            kill $BRAVE_PIDS 2>/dev/null || true
            sleep 2
        fi
    else
        echo "❌ Cannot proceed while Brave is running. Please close Brave manually first."
        exit 1
    fi
else
    echo "✅ No running Brave processes found."
fi

# Define Brave config directory
BRAVE_DIR="$HOME/.config/BraveSoftware/Brave-Browser"

if [ ! -d "$BRAVE_DIR" ]; then
    echo "❌ Brave config directory not found: $BRAVE_DIR"
    exit 1
fi

echo "🧹 Cleaning up lock files and sockets..."

# Remove various lock files
LOCK_FILES=(
    "$BRAVE_DIR/Default/LOCK"
    "$BRAVE_DIR/SingletonSocket"
    "$BRAVE_DIR/SingletonLock"
    "$BRAVE_DIR/SingletonCookie"
)

CLEANED=0
for lock_file in "${LOCK_FILES[@]}"; do
    if [ -f "$lock_file" ] || [ -S "$lock_file" ]; then
        echo "🗑️  Removing: $lock_file"
        rm -f "$lock_file"
        CLEANED=1
    fi
done

# Find and remove any other potential lock files
echo "🔍 Searching for additional lock files..."
OTHER_LOCKS=$(find "$BRAVE_DIR" -name "*lock*" -o -name "*Lock*" -o -name "*LOCK*" -o -name "*singleton*" -o -name "*Singleton*" 2>/dev/null || true)

if [ -n "$OTHER_LOCKS" ]; then
    echo "🗑️  Found additional lock files:"
    echo "$OTHER_LOCKS"
    echo "$OTHER_LOCKS" | xargs rm -f
    CLEANED=1
fi

if [ $CLEANED -eq 1 ]; then
    echo "✅ Lock files cleaned up successfully!"
else
    echo "ℹ️  No lock files found to clean up."
fi

# Test if Brave can start
echo "🧪 Testing Brave startup..."
if timeout 5 brave --version >/dev/null 2>&1; then
    echo "✅ Brave version check successful!"
    
    # Optional: Test actual GUI startup (uncomment if desired)
    # echo "🚀 Testing GUI startup..."
    # timeout 10 brave --no-first-run >/dev/null 2>&1 &
    # sleep 3
    # if pgrep -f brave >/dev/null; then
    #     echo "✅ Brave GUI started successfully!"
    #     pkill -f brave
    # else
    #     echo "⚠️  Brave GUI test failed, but version check worked."
    # fi
else
    echo "❌ Brave version check failed. There may be other issues."
    exit 1
fi

echo ""
echo "🎉 Cleanup complete! You can now try starting Brave:"
echo "   • Direct: brave"
echo "   • With nixGL: brave-nixgl"
echo "   • Desktop shortcut should also work"
echo ""
echo "💡 If the issue persists, the problem might be:"
echo "   • Network/hostname changes affecting sync"
echo "   • Profile corruption requiring reset"
echo "   • Multiple device sync conflicts"
