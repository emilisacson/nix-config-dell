# Fix mimeapps.list error when rebuilding with Nix
mv ~/.config/mimeapps.list ~/.config/mimeapps.list.backup



# Update desktop application index and icon cache
update-desktop-database ~/.local/share/applications/ ~/.nix-profile/share/applications/

gtk-update-icon-cache -f ~/.nix-profile/share/icons/hicolor 2>/dev/null || true; gtk-update-icon-cache -f ~/.local/share/icons/hicolor 2>/dev/null || true

busctl --user call org.gnome.Shell /org/gnome/Shell org.gnome.Shell Eval s 'Meta.restart("Restarting…")'


# flatpak override
`flatpak override --user --env=GTK_THEME=Adwaita:dark org.gnome.Evolution`
- Does not impact the flatpack itself, but rather the environment in which the application runs.
- Specific user
- Set environment variable for GTK_THEME to Adwaita:dark for org.gnome.Evolution every time it runs.
- Path where the overrides are housed: `~/.local/share/flatpak/overrides/`
- Can be reset with `flatpak override --user --reset org.gnome.Evolution`