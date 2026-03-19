# Tailscale Setup Guide

This guide explains how Tailscale is integrated into this Fedora + Home Manager configuration.

## Integration model

Tailscale is intentionally split across two layers:

- **Home Manager** provides:
  - helper commands such as `tailscale-connect` and `tailscale-status`
  - optional secret-backed defaults
  - optional `tailscale-systray`
  - activation-time checks and reminders
- **Fedora / systemd** provides:
  - the `tailscale` CLI package
  - the privileged `tailscaled` daemon
  - package installation and updates
  - system service enable/start lifecycle

This repository is not NixOS, so the system daemon is handled with a helper script instead of pretending Home Manager owns the whole host.

## What gets installed by Home Manager

After rebuilding Home Manager, you get:

- `tailscale-connect`
- `tailscale-disconnect`
- `tailscale-reauth`
- `tailscale-status`
- `setup-tailscale`

If `repoFeatures.tailscale.enableSystray = true;`, you also get:

- `tailscale-systray`
- `tailscale-ui`

The actual `tailscale` CLI and `tailscaled` daemon come from Fedora, which keeps upgrades and service ownership in one place.

## Systray toggle

The systray is now controlled by a simple repo setting in `home.nix`:

```nix
repoFeatures.tailscale.enableSystray = false;
```

Set it to `true` if you want:

- `tailscale-systray` installed
- the `tailscale-ui` launcher script
- a desktop autostart entry at login

Notes:

- The toggle is off by default.
- On GNOME, visibility of status icons can still depend on your shell/extensions setup.

## First-time setup

### 1. Rebuild Home Manager

```bash
cd ~/.nix-config
NIXPKGS_ALLOW_UNFREE=1 nix run --impure "path:$HOME/.nix-config#homeConfigurations.$USER.activationPackage"
```

### 2. Install and start the system daemon

```bash
~/.nix-config/extras/setup-tailscale.sh
```

This helper script will:

- try to install `tailscale` system-wide with `dnf` if needed
- add the official Tailscale Fedora repository automatically if the first install attempt fails
- enable and start `tailscaled`
- verify the service is active
- print the next commands to run

### 3. Log in to Tailscale

```bash
tailscale-connect
```

If no auth key is provided, this uses the normal interactive browser-based login flow.

### 4. Verify status

```bash
tailscale-status
```

## Everyday commands

### Connect / log in

```bash
tailscale-connect
```

### Disconnect

```bash
tailscale-disconnect
```

### Force reauthentication

```bash
tailscale-reauth
```

### Show status

```bash
tailscale-status
```

## Optional auth key usage

The default workflow is interactive login, but `tailscale-connect` also supports optional non-interactive auth-key input.

### Option 1: environment variable

```bash
export TAILSCALE_AUTHKEY="tskey-..."
tailscale-connect
```

### Option 2: auth key file

```bash
export TAILSCALE_AUTHKEY_FILE="$XDG_RUNTIME_DIR/tailscale/authkey"
tailscale-connect
```

If the file exists, `tailscale-connect` will read the key from it.

This is designed so the repository's secrets layer can later render a runtime-only auth key file without putting plaintext secrets into the Nix store.

## Secret-backed defaults via `sops-nix`

If you create an encrypted `secrets/tailscale.yaml`, the Tailscale module will decrypt it to a runtime-only YAML file and `tailscale-connect` will read supported defaults automatically.

Supported keys:

- `authKey`
- `hostname`
- `controlUrl`
- `advertiseTags`
- `exitNode`
- `acceptRoutes`
- `extraUpFlags`

Example plaintext content before encryption:

```yaml
authKey: "tskey-..."
hostname: "fedora-laptop"
advertiseTags: "tag:workstation"
acceptRoutes: "true"
```

Typical flow:

1. Bootstrap age + sops:
  - `~/.nix-config/extras/setup-sops-age.sh`
2. Add your public key to `.sops.yaml`
3. Create the encrypted file:
  - `sops ~/.nix-config/secrets/tailscale.yaml`
4. Rebuild Home Manager
5. Run `tailscale-connect`

If `authKey` is omitted, `tailscale-connect` still uses interactive browser login while applying any other supported defaults.

## What you actually need from Tailscale

Short version: for a normal desktop login, you need almost nothing in advance.

### Simplest setup: interactive login only

You only need:

- your Tailscale account
- access to log in in the browser

Then run:

```bash
tailscale-connect
```

That is enough for most laptop/workstation use.

### If you want secret-backed automation

These values are optional and only needed if you want non-interactive or opinionated setup.

#### 1. `authKey`

You need this only if you want `tailscale-connect` to log in without opening the browser.

What to get:

- a Tailscale auth key from the admin console / keys area

Recommended choice:

- a **one-off auth key** for a single workstation

Use a reusable key only if you intentionally want to reuse it across device enrollments.

#### 2. `advertiseTags`

You need this only if you want the device tagged.

What to get first:

- the tag name you want, such as `tag:workstation`
- the tailnet policy must allow that tag via `tagOwners`

If tag ownership is not configured in your Tailscale policy, tagged login will fail.

#### 3. `hostname`

Optional. Pick whatever device name you want this machine to use inside Tailscale.

Examples:

- `fedora-laptop`
- `dell-latitude-7410`

#### 4. `exitNode`

Optional. Only needed if you want this machine to use an exit node.

What to get:

- the machine name or IP of an existing Tailscale device that is already advertising exit-node capability

You can usually discover this from:

- the Tailscale admin console
- or `tailscale status` on another enrolled device

#### 5. `acceptRoutes`

Optional. Set this if you want the machine to accept subnet routes advertised by another Tailscale node.

Use:

- `"true"` to accept them
- `"false"` to explicitly not accept them

#### 6. `controlUrl`

Usually leave this blank.

You only need it if you are **not** using standard Tailscale control infrastructure, for example with a custom control plane.

### Practical recommendation

For your setup, I recommend this progression:

1. Start with no secret file at all
2. Run `setup-tailscale`
3. Run `tailscale-connect`
4. Confirm everything works
5. Only then add an encrypted `tailscale.yaml` if you want automation or stable defaults

## Why this is the cleanest model here

For this repo, the low-maintenance split is:

- Fedora owns the real Tailscale installation and daemon
- Home Manager owns convenience, defaults, and optional UX extras

That means on another Fedora machine the flow stays simple:

1. clone/apply the same config
2. run `setup-tailscale`
3. run `tailscale-connect`
4. authenticate

No NixOS-only service options, no daemon hidden inside user config, and no duplicated package ownership. Much less yak shaving; fewer surprised future-yous.

## Activation checks

During Home Manager activation, the config will warn if:

- `tailscaled` is not installed
- `tailscaled` is not running
- daemon connectivity cannot be confirmed

That gives a friendly reminder without forcing root actions during the rebuild.

## Troubleshooting

### `tailscaled` is missing

Run:

```bash
~/.nix-config/extras/setup-tailscale.sh
```

### `tailscaled` is installed but not running

Run:

```bash
sudo systemctl enable --now tailscaled
```

### CLI cannot talk to daemon

Check:

```bash
tailscale-status
```

If the non-root call fails, the helper will retry with `sudo`.

### Home Manager activation succeeded but Tailscale still is not connected

That usually just means the daemon is installed but the machine has not been authenticated yet.

Run:

```bash
tailscale-connect
```

## Related documentation

- [Tailscale & Secrets Spec](tailscale-secrets-spec.md)
- [System Detection Guide](system-detection-guide.md)
