#!/usr/bin/env bash
# Install and configure keyd for SVDVORAK with Ctrl overlay
# keyd is a key remapping daemon that works properly with Wayland

set -e

echo "Installing keyd (keyboard remapping daemon for Wayland)..."

# Check if keyd is already installed
if command -v keyd &> /dev/null; then
    echo "keyd is already installed"
else
    echo "Installing keyd via dnf..."
    sudo dnf install -y keyd
fi

# Enable and start keyd service
echo "Enabling keyd service..."
sudo systemctl enable keyd
sudo systemctl start keyd

# Create keyd configuration for SVDVORAK with Ctrl overlay
echo "Creating keyd configuration..."
sudo mkdir -p /etc/keyd

sudo tee /etc/keyd/default.conf << 'EOF'
[ids]
# Only apply to Keychron Q11 keyboard
3434:01e1:4ea6cde2
3434:01e1:c804c731
3434:01e1:839d521b

[main]
leftcontrol = control
rightcontrol = control

# SVDVORAK character mappings
q = [
w = ,
e = .
r = p
t = y
y = f
u = g
i = c
o = r
p = l
[ = \
] = ]

a = a
s = o
d = e
f = u
g = i
h = d
j = h
k = t
l = n
; = s
' = /
\ = 102nd

102nd = ;
z = '
x = q
c = j
v = k
b = x
n = b
m = m
, = w
. = v
/ = z

[control]
q = C-q
w = C-w
e = C-e
r = C-r
t = C-t
y = C-y
u = C-u
i = C-i
o = C-o
p = C-p

a = C-a
s = C-s
d = C-d
f = C-f
g = C-g
h = C-h
j = C-j
k = C-k
l = C-l

z = C-z
x = C-x
c = C-c
v = C-v
b = C-b
n = C-n
m = C-m
EOF

# Reload keyd configuration
echo "Reloading keyd configuration..."
sudo systemctl restart keyd

echo ""
echo "✅ keyd installed and configured!"
echo ""
echo "Configuration:"
echo "  - Keychron Q11: Full SVDVORAK layout with QWERTY Ctrl shortcuts"
echo "  - Laptop keyboard: Swedish QWERTY (unaffected by keyd)"
echo "  - This works properly in Wayland!"
echo ""
echo "To test: Type normally for SVDVORAK, Ctrl+C/V for standard shortcuts"
echo ""
echo "To disable: sudo systemctl stop keyd && sudo systemctl disable keyd"
echo "To modify: sudo nano /etc/keyd/default.conf && sudo systemctl restart keyd"
