VS Code Hash Update Script
==========================

Script: `extras/update-vscode-hash.sh`

Purpose
-------
Fetch the latest VS Code (stable or insiders) tarball hash using `nix-prefetch-url --unpack`, update the corresponding `sha256` in `applications/vscode.nix`, and record the change in `docs/vscode_hash_log.md`.

Usage
-----
```
extras/update-vscode-hash.sh [stable|insiders|auto]
```

Arguments
---------
* `stable`   – Force updating the stable build hash.
* `insiders` – Force updating the insiders build hash.
* `auto` (default if omitted) – Reads the `useInsiders` flag inside `applications/vscode.nix` and updates that channel only.

Behavior
--------
1. Determines channel (argument or auto-detected).
2. Runs `nix-prefetch-url --unpack` against the proper URL:
   * Insiders: `https://update.code.visualstudio.com/latest/linux-x64/insider`
   * Stable:   `https://update.code.visualstudio.com/latest/linux-x64/stable`
3. Compares new hash to the current `sha256` in the channel's `fetchTarball` block.
4. If different, replaces the hash and prepends a log line to `docs/vscode_hash_log.md`:

   ```
   YYYY-MM-DDThh:mm:ss+TZ channel sha256:HASH
   ```

   Timezone is Europe/Stockholm.
5. If unchanged, no log entry is added and the file is left intact.
6. On success (hash changed) the script reminds you to run:
   `nix-home-rebuild`

Log File Format
---------------
`docs/vscode_hash_log.md` starts with a header and the newest entries are always added at the top (after the header lines).

Example snippet:
```
# VS Code Hash Update Log
# Newest entries first. Timestamp Europe/Stockholm.

2025-08-26T19:22:11+0200 insiders sha256:0cfdzn0jndwdb7c70kasyr09hjp7q8nwd5pas23cyq13p05q0nlk
2025-08-20T10:05:44+0200 stable   sha256:01wcbbgss6qcfm69zd68bpl6gk0l7qiwldgdky126bvjgrgkbz3n
```

Notes
-----
* The script removes the need for manually commented previous hashes.
* Only updates one channel per invocation.
* Uses atomic temp file replacement for `applications/vscode.nix`.
* Requires `nix-prefetch-url` in PATH.

Troubleshooting
---------------
* "Could not determine useInsiders" – Ensure `useInsiders = true;` or `useInsiders = false;` appears plainly (not generated) near the top of `applications/vscode.nix`.
* "Could not locate existing sha256" – The script expects an un-commented line containing `"sha256:` within the appropriate channel block after the URL line.

Future Enhancements (Ideas)
---------------------------
* Optional flag to automatically run `nix-home-rebuild` upon success.
* Support for pinning a specific version tag rather than always `latest`.
* JSON output mode for integration with CI.

Installing a Shell Alias
------------------------
To add a convenient alias (`nix-vscode-update`) to your shell, run:

```
extras/add-nix-vscode-update-alias.sh
```

Afterwards, reload your shell:
```
source ~/.bashrc
```

Then you can simply execute:
```
nix-vscode-update        # auto mode
nix-vscode-update stable
nix-vscode-update insiders
```
