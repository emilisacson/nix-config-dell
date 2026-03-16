#!/usr/bin/env bash
# Setup keyd for Swedish Dvorak with Ctrl overlay
set -e

echo "Setting up keyd for SVDVORAK on Keychron..."

# Check if keyd is installed
if ! command -v keyd &> /dev/null; then
    echo "keyd is not installed. Installing via dnf..."
    sudo dnf install -y keyd
fi

# Create keyd configuration directory
sudo mkdir -p /etc/keyd

# Create keyd configuration
echo "Creating keyd configuration..."
sudo tee /etc/keyd/default.conf > /dev/null << 'KEYD_EOF'
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
KEYD_EOF

# Enable and start keyd service
echo "Enabling and starting keyd service..."
sudo systemctl enable --now keyd

# Reload keyd if already running
sudo systemctl restart keyd

echo "✅ keyd setup complete!"
echo "Configuration:"
echo "  - Keychron Q11: Full SVDVORAK layout with QWERTY Ctrl shortcuts"
echo "  - Laptop keyboard: Swedish QWERTY (unaffected by keyd)"
echo ""
echo "Test: Type normally for SVDVORAK, Ctrl+C/V for standard shortcuts"
