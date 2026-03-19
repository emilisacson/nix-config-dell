# Tailscale and Secrets Manager Specification

This document specifies how Tailscale and a reusable secrets-management layer should be integrated into this Fedora + Home Manager repository.

## Summary

The recommended design is:

- **Tailscale** integrated as a hybrid solution:
  - declarative **package + helper/UX integration** in Home Manager
  - privileged **daemon setup** handled by Fedora systemd and a helper script
- **Secrets management** built on **`sops-nix` with `age` keys**
  - reusable across many modules in the repo
  - suitable for Home Manager on non-NixOS Linux
  - supports structured secret files, templating, and future growth

This repository is **not NixOS**. That matters a lot. System daemons like `tailscaled` should not be treated as if Home Manager owns the entire host. User configuration belongs in Home Manager; privileged daemon lifecycle belongs in Fedora-level setup.

## Goals

### Primary goals

- Add Tailscale in a way that fits this repo's existing architecture.
- Introduce a secrets manager that can be reused by multiple modules.
- Avoid committing plaintext secrets to the repository.
- Keep user-level config declarative and reproducible.
- Keep privileged service setup explicit and reliable.

### Secondary goals

- Support secrets for Tailscale auth keys when desired.
- Support future use cases like API tokens, app credentials, registry auth, and service config templates.
- Keep the setup understandable for a single-user Fedora workstation.

## Non-goals

- Fully declarative host management of privileged services as if this were NixOS.
- Storing long-lived plaintext secrets in Nix files.
- Building a custom secrets engine from scratch.
- Solving machine bootstrap for every possible host OS beyond the current Fedora-centric workflow.

## Current repository constraints

This repo currently follows a consistent pattern:

- Home Manager manages:
  - user packages
  - user files
  - shell helpers
  - activation checks and reminders
- Fedora/system-level setup is handled by:
  - helper scripts in `extras/`
  - user-facing reminders during activation

Existing examples include `keyd`, NVIDIA setup, and other post-install system configuration.

This means Tailscale should follow the same pattern instead of introducing a different operational model.

## Decision: secrets manager choice

### Recommended choice: `sops-nix` + `age`

`sops-nix` is the recommended secrets layer for this repository.

### Why `sops-nix`

Compared to `agenix`, `sops-nix` is a better fit here because it provides:

- support for **structured secret files** (`yaml`, `json`, `env`, `ini`)
- support for **templated generated config files**
- easier grouping of related secrets in a single encrypted document
- a clearer path for future expansion across multiple app modules
- strong Home Manager support on Linux

### Why not make `agenix` the primary choice

`agenix` is valid and simpler for small one-secret-per-file setups, but it is less ergonomic for this repo's likely future needs.

Examples of future secret consumers in this repo could include:

- Tailscale auth keys
- Microsoft / Graph / Azure credentials
- registry credentials for containers
- private API tokens
- VPN credentials
- service environment files

These are easier to manage cleanly with `sops-nix` templates and structured secret documents.

### Encryption backend choice

Use **`age`** keys, not GPG, as the primary path.

Reasons:

- simpler setup
- fewer moving parts
- easier to document and reproduce
- widely used with `sops-nix`

## Proposed architecture

## High-level design

The repository should gain a reusable secrets foundation plus a Tailscale-specific integration built on top of it.

### Layer 1: secrets foundation

Add a repo-wide secrets system that provides:

- encrypted secret files stored in the repo
- a standard key management workflow
- a standard module for wiring secrets into Home Manager
- support for generated config templates
- support for secret-backed helper scripts and env files

### Layer 2: Tailscale integration

Add a Tailscale module that provides:

- Tailscale user packages
- optional systray package
- helper scripts
- activation health checks
- optional use of a Tailscale auth key from the secrets layer
- a Fedora helper script for installing and enabling `tailscaled`

## Proposed file layout

```text
~/.nix-config/
├── docs/
│   └── tailscale-secrets-spec.md
├── secrets/
│   ├── README.md
│   ├── common.yaml
│   ├── tailscale.yaml
│   └── templates/
├── modules/
│   └── secrets.nix
├── network/
│   ├── network.nix
│   ├── vpn.nix
│   └── tailscale.nix
├── extras/
│   ├── setup-tailscale.sh
│   ├── setup-sops-age.sh
│   └── tailscale-login.sh
├── .sops.yaml
├── flake.nix
└── home.nix
```

Notes:

- `modules/secrets.nix` is suggested as a shared integration layer.
- If you prefer to stay closer to current layout conventions, this could also live under `lib/`.
- `secrets/` contains encrypted files only, never plaintext.

## Flake changes

The flake should eventually add:

- `sops-nix` input
- Home Manager module import for `sops-nix`

Conceptually:

- add `inputs.sops-nix`
- include `sops-nix.homeManagerModules.sops` in the Home Manager module list

This keeps secrets available to any Home Manager module in the repo.

## Secrets foundation design

## Key management model

### User key location

Primary decryption key location:

```text
~/.config/sops/age/keys.txt
```

This key is local to the workstation and must not be committed.

### Public key usage

The corresponding **public age key** is used in `.sops.yaml` so encrypted files in `secrets/` can be safely committed.

### Setup workflow

A helper script should eventually:

- install required tools if needed
- generate the age key if missing
- print the public key
- explain how to add it to `.sops.yaml`

Suggested script:

```text
extras/setup-sops-age.sh
```

## Secret classification

Secrets in this repo should be organized into a few categories.

### 1. User-local secrets

Secrets needed by the current user on the current workstation.

Examples:

- Tailscale auth key
- GitHub token
- Azure client secret
- registry credentials

### 2. Shared repo secrets

Secrets shared across multiple modules or workflows.

Examples:

- common API endpoints with accompanying tokens
- shared development credentials
- reusable auth material for helper tools

### 3. Machine-specific secrets

Secrets tied to one machine or one detected system.

Examples:

- host-specific service credentials
- future machine-specific tunnels or routes

### 4. Template-generated secrets-backed config

Configs assembled from one or more secrets into a generated file.

Examples:

- `.env` files
- YAML config files
- Tailscale env wrappers
- app config fragments

## Secret naming model

Recommended secret naming style:

```text
service.item
service.environment.item
shared.category.item
```

Examples:

- `tailscale.authKey`
- `tailscale.controlUrl`
- `azure.graph.clientSecret`
- `containers.githubRegistry.password`
- `shared.github.token`

If `sops-nix` templates are used, names should remain stable and predictable.

## Secret storage layout

Recommended encrypted files:

```text
secrets/common.yaml
secrets/tailscale.yaml
secrets/azure.yaml
secrets/containers.yaml
```

This keeps related credentials grouped together.

For example, `secrets/tailscale.yaml` could logically contain:

```yaml
tailscale:
  authKey: "..."
  tailnet: "..."
  tags: "tag:workstation"
  exitNode: "..."
```

The encrypted form is what gets committed.

## Secret consumption model

Modules should consume secrets through one of three patterns.

### Pattern A: direct secret file path

Use the decrypted secret file path directly.

Best for:

- password files
- auth token files
- certificate files

### Pattern B: generated template file

Use `sops-nix` templates to generate a config or env file.

Best for:

- `.env`
- YAML config files
- INI/TOML fragments
- shell-export files

### Pattern C: activation-time validation

Use Home Manager activation to validate that required secrets exist and print actionable guidance if they do not.

Best for:

- optional features
- first-time workstation setup
- integrations that can be enabled later

## Tailscale design

## Tailscale operating model

Tailscale should be split into two responsibilities.

### Home Manager responsibilities

The Tailscale Home Manager module should manage:

- `pkgs.tailscale`
- optional `pkgs.tailscale-systray`
- optional automatic home-network switching policy
- helper scripts like:
  - `tailscale-status`
  - `tailscale-connect`
  - `tailscale-disconnect`
  - `tailscale-reauth`
  - `tailscale-auto-toggle`
- activation checks for:
  - whether `tailscaled` is installed
  - whether `tailscaled` is active
  - whether the machine appears logged in
- optional secret-backed runtime config

### Fedora/system responsibilities

Fedora-level setup should manage:

- enabling and starting the `tailscaled` daemon
- installing or refreshing a systemd unit that points at Nix-managed Tailscale binaries
- installing or refreshing a NetworkManager dispatcher hook for background home/away switching
- any root-level daemon configuration
- any systray startup integration that requires system support

This should be handled via:

```text
extras/setup-tailscale.sh
```

## Tailscale auth strategy

### Default mode

Default mode should be **interactive login**.

That means:

- install daemon
- start daemon
- run `tailscale up`
- authenticate in browser

This is safest and easiest to understand.

### Optional secret-backed mode

If the user wants unattended enrollment, the module may optionally use a secret-backed auth key from `sops-nix`.

Examples:

- `tailscale.authKey`
- `tailscale.tags`
- `tailscale.hostname`
- `tailscale.acceptRoutes`

This should remain optional, not mandatory.

### Why auth key support should be optional

- interactive setup is safer for a workstation
- auth keys may expire or be rotated
- not every machine should auto-enroll
- it avoids forcing secrets bootstrapping just to try Tailscale

## Tailscale secret consumers

Potential secrets used by the Tailscale module:

- auth key
- control URL (if non-default)
- advertised tag set
- exit node selection defaults
- route acceptance or advertisement policy inputs

Not all of these must be implemented immediately.

## Tailscale helper script behavior

Suggested helper script responsibilities:

### `extras/setup-tailscale.sh`

- check whether Tailscale is available on the system
- enable `tailscaled`
- start `tailscaled`
- install/remove the NetworkManager dispatcher hook for automatic home-network switching
- optionally enable systray support
- print next-step instructions

### `tailscale-auto-toggle`

- run as a background NetworkManager dispatcher target
- match trusted/home networks by configured SSID, connection name, or gateway
- automatically run `tailscale down` on home/trusted networks
- automatically run `tailscale up` when leaving home, but skip auto-connect if Tailscale still needs interactive login

### `tailscale-connect`

- prefer interactive login by default
- optionally use secret-backed auth key if enabled in config

### `tailscale-status`

- print daemon state
- print login state
- print IPs / tailnet status

## Future reusable consumers of the secrets layer

The secrets manager should be usable beyond Tailscale.

### Candidate future consumers

#### OneNote / Microsoft Graph tooling

Potential secrets:

- client secret
- tenant-specific settings
- API tokens if future tooling changes

#### Azure / Entra helper scripts

Potential secrets:

- app registration credentials
- service principal secrets
- tenant IDs and scoped configuration

#### Containers / registries

Potential secrets:

- registry passwords
- auth tokens
- machine-user PATs

#### VPN and network tooling

Potential secrets:

- certificate bundles
- usernames or token files
- per-provider config templates

#### Future app integrations

Potential secrets:

- Discord/webhook tokens
- GitHub tokens
- automation API keys
- backup credentials

## Security requirements

### Must-have requirements

- no plaintext secrets committed to git
- no secrets embedded directly in Nix expressions
- decrypted secrets should live outside the Nix store
- secret-backed files should have least-privilege permissions
- the default workflow should be understandable and auditable

### Repo hygiene requirements

The repository should eventually ignore:

- generated plaintext secret outputs
- local age key material
- temporary decrypted files
- local env files derived from templates

Examples to consider for `.gitignore` if not already covered:

```text
secrets/*.dec
.env.local
.envrc.local
```

Do **not** ignore the encrypted secret sources themselves.

## Bootstrapping workflow

## Initial setup flow

### Phase 1: secrets foundation bootstrap

1. Rebuild Home Manager after adding `sops-nix` support.
2. Run the age-key setup helper.
3. Generate or register the age public key.
4. Add the public key to `.sops.yaml`.
5. Create encrypted secrets in `secrets/`.

### Phase 2: Tailscale bootstrap

1. Rebuild Home Manager with the Tailscale module enabled.
2. Run `extras/setup-tailscale.sh`.
3. Log in interactively with `tailscale up`.
4. Optionally add an auth key to encrypted secrets later.

### Phase 3: migrate future consumers

1. Identify modules currently relying on manual secrets.
2. Move credentials into encrypted `sops` files.
3. Generate templates or secret files as needed.
4. Add activation checks and docs.

## Implementation phases

## Phase 1: documentation and skeleton

Deliverables:

- this spec
- `sops-nix` added to flake inputs
- shared secrets module skeleton
- `.sops.yaml`
- `secrets/README.md`
- bootstrap helper for age keys

## Phase 2: Tailscale foundation

Deliverables:

- `network/tailscale.nix`
- import in `network/network.nix`
- user packages and helper scripts
- activation checks
- `extras/setup-tailscale.sh`
- docs for first-time setup

## Phase 3: secret-backed Tailscale options

Deliverables:

- optional auth key support
- optional templated env/config support
- optional hostname / tags / route defaults from secrets or settings

## Phase 4: repo-wide secret adoption

Deliverables:

- migrate future secret consumers one by one
- standardize docs and secret naming
- keep integrations consistent across modules

## Recommended module interface

A shared secrets module should expose a simple repository convention.

Conceptually, modules should be able to:

- declare which secrets they need
- reference stable secret paths
- use generated templates when needed
- fail gracefully with good messages if secrets are absent

Tailscale should be one consumer of that shared foundation, not a special one-off mechanism.

## Open questions

These should be answered before implementation finalization.

1. Should Tailscale systray be enabled by default on GNOME, or remain optional?
2. Should the first iteration support auth keys immediately, or interactive login only?
3. Should machine-specific secrets be split by `system_id` in separate encrypted files?
4. Should the shared secrets module live under `modules/` or `lib/` to best match repo conventions?
5. Should the repository standardize on a single encrypted file per service, or allow both grouped and per-secret files?

## Recommended answers

Current recommendation:

1. **Systray optional**
2. **Interactive login first, auth key second**
3. **Allow machine-specific files later if needed**
4. **Use `modules/secrets.nix` or `lib/secrets.nix`; choose one and standardize**
5. **Prefer grouped per-service encrypted files**

## Final recommendation

Implement:

- **`sops-nix` + `age`** as the repository-wide secrets manager
- **hybrid Tailscale integration** with Home Manager + Fedora helper script

This gives the repo:

- a reusable secrets foundation
- a safe and conventional Tailscale integration
- a path for future modules to consume secrets without inventing new patterns each time

In short: one secrets system, many consumers, no plaintext surprises.
