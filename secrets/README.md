# Secrets Directory

This directory is reserved for **encrypted** secret files managed with `sops-nix` and `age`.

## Principles

- Commit **encrypted** files only.
- Never commit plaintext exports, decrypted copies, or private keys.
- Use grouped per-service files when possible.

Recommended files over time:

- `common.yaml`
- `tailscale.yaml`
- `azure.yaml`
- `containers.yaml`

## Bootstrap

1. Rebuild Home Manager:
   - `cd ~/.nix-config && NIXPKGS_ALLOW_UNFREE=1 nix run --impure "path:$HOME/.nix-config#homeConfigurations.$USER.activationPackage"`
2. Generate your local age key:
   - `~/.nix-config/extras/setup-sops-age.sh`
3. Add the printed public key to `~/.nix-config/.sops.yaml`.
4. Create or edit an encrypted file:
   - `sops ~/.nix-config/secrets/common.yaml`

## Example plaintext structure

```yaml
shared:
  github:
    token: "replace-me"
```

After saving with `sops`, the committed file will be encrypted.

## Tailscale secret format

If you want to use secret-backed Tailscale defaults, create `secrets/tailscale.yaml` with keys like these:

```yaml
authKey: "tskey-..."
hostname: "fedora-laptop"
controlUrl: ""
advertiseTags: "tag:workstation"
exitNode: ""
acceptRoutes: "true"
extraUpFlags: ""
```

Notes:

- All values should be strings so they play nicely with `sops`.
- `authKey` is optional. If omitted, `tailscale-connect` falls back to interactive login.
- `acceptRoutes` should be either `"true"` or `"false"` when set.
- `extraUpFlags` is for advanced opt-in flags passed directly to `tailscale up`.

When present, Home Manager decrypts this file to a runtime-only path and `tailscale-connect` reads it automatically.

## Future use in Home Manager

Later modules can consume secrets in three common ways:

- direct secret file paths
- templated config files generated from secrets
- activation-time checks for optional integrations

Tailscale is intended to be one of the first consumers of this shared secrets foundation.
