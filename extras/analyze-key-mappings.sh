#!/usr/bin/env bash
# Script to understand the exact key mappings between SVDVORAK and Swedish QWERTY
# This helps us create the correct keyd configuration

echo "SVDVORAK to Swedish QWERTY Key Position Analysis"
echo "================================================"
echo ""

# Detect if we have a Swedish physical keyboard
echo "Detecting physical keyboard layout..."
current_layout=$(setxkbmap -query | grep layout | awk '{print $2}')
if [[ "$current_layout" == "se" ]]; then
    echo "Swedish keyboard detected"
    PHYSICAL_LAYOUT="Swedish"
else
    echo "Non-Swedish layout detected: $current_layout"
    PHYSICAL_LAYOUT="Unknown"
fi
echo ""

echo "Physical Swedish keyboard layout (standard positions):"
echo "Row 1: Q W E R T Y U I O P Å"
echo "Row 2: A S D F G H J K L Ö Ä"  
echo "Row 3: Z X C V B N M , . -"
echo ""

echo "SVDVORAK layout (what letters appear at each physical position on Swedish keyboard):"
echo "Row 1: Å , . P Y F G C R L '"
echo "Row 2: A O E U I D H T N S -"
echo "Row 3: Ö Ä Q J K X B M W V Z"
echo ""

echo "Key mapping for Ctrl shortcuts (Swedish physical keyboard):"
echo "Physical Position | Swedish Letter | SVDVORAK Letter | Desired Ctrl Action"
echo "------------------|----------------|-----------------|-------------------"
echo "Pos 1 (Q)         | Q              | Å               | Ctrl+Q (quit)"
echo "Pos 2 (W)         | W              | ,               | Ctrl+W (close)"
echo "Pos 3 (E)         | E              | .               | Ctrl+E (same)"
echo "Pos 4 (R)         | R              | P               | Ctrl+R (refresh)"
echo "Pos 5 (T)         | T              | Y               | Ctrl+T (new tab)"
echo "Pos 6 (Y)         | Y              | F               | Ctrl+Y (redo)"
echo "Pos 7 (U)         | U              | G               | Ctrl+U (view source)"
echo "Pos 8 (I)         | I              | C               | Ctrl+I (italic)"
echo "Pos 9 (O)         | O              | R               | Ctrl+O (open)"
echo "Pos 10 (P)        | P              | L               | Ctrl+P (print)"
echo "Pos 11 (Å)        | Å              | '               | Ctrl+Å (?)"
echo ""
echo "Pos 12 (A)        | A              | A               | Ctrl+A (same)"
echo "Pos 13 (S)        | S              | O               | Ctrl+S (save)"
echo "Pos 14 (D)        | D              | E               | Ctrl+D (bookmark)"
echo "Pos 15 (F)        | F              | U               | Ctrl+F (find)"
echo "Pos 16 (G)        | G              | I               | Ctrl+G (find next)"
echo "Pos 17 (H)        | H              | D               | Ctrl+H (history)"
echo "Pos 18 (J)        | J              | H               | Ctrl+J (downloads)"
echo "Pos 19 (K)        | K              | T               | Ctrl+K (search bar)"
echo "Pos 20 (L)        | L              | N               | Ctrl+L (location bar)"
echo "Pos 21 (Ö)        | Ö              | S               | Ctrl+Ö (?)"
echo "Pos 22 (Ä)        | Ä              | -               | Ctrl+Ä (?)"
echo ""
echo "Pos 23 (Z)        | Z              | Ö               | Ctrl+Z (?)"
echo "Pos 24 (X)        | X              | Ä               | Ctrl+X (cut)"
echo "Pos 25 (C)        | C              | Q               | Ctrl+C (copy)"
echo "Pos 26 (V)        | V              | J               | Ctrl+V (paste)"
echo "Pos 27 (B)        | B              | K               | Ctrl+B (bold)"
echo "Pos 28 (N)        | N              | X               | Ctrl+N (new)"
echo "Pos 29 (M)        | M              | B               | Ctrl+M (same)"
echo "Pos 30 (,)        | ,              | M               | Ctrl+, (preferences)"
echo "Pos 31 (.)        | .              | W               | Ctrl+. (?)"
echo "Pos 32 (-)        | -              | V               | Ctrl+- (?)"
echo "Pos 33 (Z-end)    | (none)         | Z               | Ctrl+Z (undo)"
echo ""

echo "Solution: When Ctrl is held down in SVDVORAK layout, we need to:"
echo "• Map the SVDVORAK letter to the Swedish QWERTY action of that physical position"
echo "• So when user presses Ctrl+K (where K is at physical C position), it should copy"
echo "• The mapping should be: SVDVORAK letter → Swedish letter function"
echo ""

echo "Critical mappings for common shortcuts:"
echo "SVDVORAK Q (at Swedish C position) → Ctrl+C (copy)"
echo "SVDVORAK Ä (at Swedish X position) → Ctrl+X (cut)"
echo "SVDVORAK J (at Swedish V position) → Ctrl+V (paste)"
echo "SVDVORAK Ö (at Swedish Z position) → Ctrl+Z (undo)"
echo "SVDVORAK O (at Swedish S position) → Ctrl+S (save)"

# Test current layout
echo ""
echo "Current layout test:"
current_layout=$(setxkbmap -query | grep layout | awk '{print $2}')
current_variant=$(setxkbmap -query | grep variant | awk '{print $2}')
echo "Layout: $current_layout"
echo "Variant: $current_variant"

if [[ "$current_variant" == *"svdvorak"* ]]; then
    echo "SVDVORAK is currently active"
    echo "Try typing these keys and see what letters appear:"
    echo "Physical positions (Swedish): q w e r t"
    echo "Should show (SVDVORAK):       å o e u i"
    echo ""
    echo "Test Ctrl shortcuts:"
    echo "Physical C key should show 'Q' → Ctrl+Q should copy (but we want Ctrl+C)"
    echo "Physical X key should show 'Ä' → Ctrl+Ä should cut (but we want Ctrl+X)"
    echo "Physical V key should show 'J' → Ctrl+J should paste (but we want Ctrl+V)"
else
    echo "SVDVORAK is not currently active"
    echo "Switch to SVDVORAK (Super+Space) to test key positions"
    echo ""
    echo "When switched to SVDVORAK:"
    echo "- Physical C key will show 'Q'"
    echo "- Physical X key will show 'Ä'" 
    echo "- Physical V key will show 'J'"
    echo "- We need to remap these so Ctrl+[physical key] works as expected"
fi
