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
*

[main]
# Main configuration: Use Swedish Dvorak layout normally
# When Ctrl is held, temporarily switch to Swedish QWERTY positions

# This is the key: we use 'overload' to make Control keys
# switch to a different layer when held

# Map Control keys to switch layers while held
leftcontrol = overload(control_qwerty, leftcontrol)
rightcontrol = overload(control_qwerty, rightcontrol)

[control_qwerty:C]
# When Ctrl is held, remap Dvorak positions to QWERTY positions
# This layer is active when leftcontrol or rightcontrol are held

# Top row (Dvorak -> QWERTY mapping)
# Dvorak: ö å ä p y f g c r l , ^
# QWERTY: q w e r t y u i o p å ^
q = q  # ö -> q
w = w  # å -> w
e = e  # ä -> e
r = r  # p -> r
t = t  # y -> t
y = y  # f -> y
u = u  # g -> u
i = i  # c -> i
o = o  # r -> o
p = p  # l -> p

# Home row (Dvorak -> QWERTY mapping)
# Dvorak: a o e u i d h t n s -
# QWERTY: a s d f g h j k l ö ä
a = a  # a -> a
s = s  # o -> s
d = d  # e -> d
f = f  # u -> f
g = g  # i -> g
h = h  # d -> h
j = j  # h -> j
k = k  # t -> k
l = l  # n -> l

# Bottom row (Dvorak -> QWERTY mapping)
# Dvorak: . q j k x b m w v z
# QWERTY: z x c v b n m , . -
z = z  # . -> z
x = x  # q -> x
c = c  # j -> c
v = v  # k -> v
b = b  # x -> b
n = n  # b -> n
m = m  # m -> m

# Keep special keys as-is
space = space
enter = enter
backspace = backspace
tab = tab
esc = esc
EOF

# Reload keyd configuration
echo "Reloading keyd configuration..."
sudo systemctl restart keyd

echo ""
echo "✅ keyd installed and configured!"
echo ""
echo "Configuration:"
echo "  - Swedish Dvorak is your base layout"
echo "  - Hold Ctrl to temporarily use Swedish QWERTY positions"
echo "  - This works properly in Wayland!"
echo ""
echo "To test: Try Ctrl+C, Ctrl+V in different applications"
echo ""
echo "To disable: sudo systemctl stop keyd && sudo systemctl disable keyd"
echo "To modify: sudo nano /etc/keyd/default.conf && sudo systemctl restart keyd"
