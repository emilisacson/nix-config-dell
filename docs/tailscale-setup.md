# Tailscale Setup Guide

This guide explains how Tailscale is integrated into this Fedora + Home Manager configuration.

## Integration model

Tailscale is intentionally split across two layers:

- **Home Manager** provides:
  - the `tailscale` and `tailscaled` binaries from Nix
  - helper commands such as `tailscale-connect` and `tailscale-status`
  - optional secret-backed defaults
  - optional `tailscale-systray`
  - activation-time checks and reminders
- **Fedora / systemd** provides:
  - the privileged `tailscaled` daemon
  - system service enable/start lifecycle that points to the Nix-managed binaries

This repository is not NixOS, so the system daemon is handled with a helper script instead of pretending Home Manager owns the whole host.

## What gets installed by Home Manager

After rebuilding Home Manager, you get:

- `tailscale`
- `tailscale-connect`
- `tailscale-disconnect`
- `tailscale-reauth`
- `tailscale-status`
- `setup-tailscale`

If `repoFeatures.tailscale.enableSystray = true;`, you also get:

- `tailscale-systray`
- `tailscale-ui`

If `repoFeatures.tailscale.autoToggle.enable = true;`, you also get:

- `tailscale-auto-toggle`
- automatic background switching via a NetworkManager dispatcher hook installed by `setup-tailscale`

The actual Tailscale binaries come from Nix. The helper script writes a root systemd unit that points at your current Nix profile, so Tailscale stays Nix-managed while Fedora still runs the privileged daemon.

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
- After enabling it for the first time, log out and back in once so GNOME picks up the AppIndicator extension and autostart entry.
- You can also launch it manually in the current session with `tailscale-ui`.

## Automatic home-network switching

The repo can automatically keep Tailscale down on trusted home networks and bring it back up elsewhere whenever NetworkManager reports a network change.

The current config in `home.nix` is:

```nix
repoFeatures.tailscale.autoToggle = {
  enable = true;
  homeConnectionNames = [ "Crynet_5G" ];
  homeSsids = [ "Crynet_5G" ];
  homeGateways = [ "192.168.2.1" ];
};
```

How it works:

- on your home Wi-Fi / gateway, the background hook runs `tailscale down`
- when you move to another network, it runs `tailscale up`
- if the machine is not logged in to Tailscale yet, it skips automatic reconnect and leaves you a clean manual `tailscale-connect` path instead of spamming browser auth flows in the background

You can tune any of these match lists later:

- `homeConnectionNames` for NetworkManager connection names
- `homeSsids` for Wi-Fi SSIDs
- `homeGateways` for default gateway IPs

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

- verify that `tailscale` and `tailscaled` are available from your Home Manager profile
- write `/etc/systemd/system/tailscaled.service` to use the Nix-managed binaries
- write `/etc/NetworkManager/dispatcher.d/90-tailscale-auto-toggle` when automatic switching is enabled
- create an optional `/etc/default/tailscaled` env file for future overrides
- reload systemd
- enable and restart `tailscaled`
- immediately sync the current home/away network state
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

If you use the automatic home-network switching, step 4 should include a quick real-world check:

- on your home network, `tailscale-status` should show Tailscale down
- on another network, it should come back automatically within a few seconds of NetworkManager reconnecting

## Why this is the cleanest model here

For this repo, the low-maintenance split is:

- Home Manager owns the Tailscale package, convenience commands, defaults, and optional UX extras
- Fedora systemd owns running the privileged daemon using the Nix-managed binaries

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
- automatic home-network switching is configured but the NetworkManager hook is not installed

That gives a friendly reminder without forcing root actions during the rebuild.

## Troubleshooting

### `tailscaled` is missing

Run:

```bash
~/.nix-config/extras/setup-tailscale.sh
```

### Automatic home-network switching does not react after a Wi-Fi change

Check that the dispatcher hook exists:

```bash
ls -l /etc/NetworkManager/dispatcher.d/90-tailscale-auto-toggle
```

Then reinstall it:

```bash
~/.nix-config/extras/setup-tailscale.sh
```

And review recent logs:

```bash
journalctl -t tailscale-auto-toggle -n 50 --no-pager
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
