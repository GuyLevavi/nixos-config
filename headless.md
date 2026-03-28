# Headless Deployment Strategy

Split implemented: `home/base.nix` (headless) + `home/gui.nix` (imports base + Wayland).
`home.nix` is a thin wrapper kept at repo root for backwards compatibility.

---

## File structure

```
home/
  base.nix    # headless: bash, nushell, starship, zoxide, fzf, git+delta, neovim+LSPs,
              #           lazygit, ripgrep, fd, bat, eza, btop, dust, sd, procs,
              #           podman-compose, lazydocker, uv, yazi, tmux, glow, lnav,
              #           fastfetch, k9s, helm, posting, opencode
  airgap.nix  # offline delta on top of base.nix:
              #   - autoupdate=false for opencode/atuin
              #   - work tools: glab, jfrog-cli, oc (openshift), mc (minio-client), git-lfs
              #   - credential manager: pass + gnupg + pass-git-helper (GPG-encrypted vault)
              #   - git credential.helper = pass-git-helper
              #   - glab update check disabled
  gui.nix     # imports base.nix + Hyprland, Waybar, Kitty, Wofi, Mako,
              #           browsers, thunar, screenshotting, swww, hyprlock,
              #           keepassxc, gtk, cursor theme
home.nix      # thin wrapper → imports ./home/gui.nix
```

All catppuccin theming stays in the relevant file: base.nix for terminal tools,
gui.nix for everything graphical.

---

## Deployment targets

| Target | Command | Notes |
|---|---|---|
| `nixbox` (current) | `rb` / `sudo nixos-rebuild switch --flake /etc/nixos#nixbox` | full GUI, imports gui.nix |
| NixOS-WSL | `sudo nixos-rebuild switch --flake ~/nixos-config#wsl` | declarative: username, PATH, flakes, home-manager |
| Bare Ubuntu / Docker | `nix run nixpkgs#home-manager -- switch --flake ~/nixos-config#wsl` | standalone home-manager only |
| Remote server | Same as bare Ubuntu path | SSH only |

---

## NixOS-WSL (fully declarative, recommended)

Uses `nixosConfigurations.wsl` — manages the NixOS system AND home-manager in one rebuild.

**First-time setup** (as the default `nixos` user):

```bash
sudo nano /etc/nixos/configuration.nix
```

Add inside the module block:

```nix
wsl.defaultUser = "gl";
wsl.wslConf.interop.appendWindowsPath = false;   # prevents Windows PATH pollution
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

Apply and restart WSL to switch user:

```bash
sudo nixos-rebuild boot
# From PowerShell:
#   wsl -t NixOS
#   wsl -d NixOS --user root exit
#   wsl -t NixOS
#   wsl -d NixOS
```

**Apply this config (as `gl`, first time or any update):**

```bash
git clone https://github.com/GuyLevavi/nixos-config ~/nixos-config  # first time only
cd ~/nixos-config && git pull                                          # on updates
sudo nixos-rebuild switch --flake ~/nixos-config#wsl
```

---

## Bare Ubuntu / standalone (no NixOS)

The `homeConfigurations.wsl` output uses standalone home-manager (no NixOS required).
Use this for bare Ubuntu, Docker containers, and non-NixOS servers.

One-time setup on a fresh machine:

```bash
# 1. Install Nix (single-user, no daemon — works in WSL and Ubuntu)
curl -L https://nixos.org/nix/install | sh -s -- --no-daemon
. ~/.nix-profile/etc/profile.d/nix.sh

# 2. Enable flakes
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf

# 3. Clone config and apply
git clone https://github.com/GuyLevavi/nixos-config ~/nixos-config
nix run nixpkgs#home-manager -- switch --flake ~/nixos-config#wsl

# 4. Subsequent updates
cd ~/nixos-config && nix run nixpkgs#home-manager -- switch --flake .#wsl
```

SSH keys for git: mount `~/.ssh` from the host or copy keys before step 3.
The `credential.helper` is empty in base.nix — git will prompt or use SSH agent.

---

## Docker dev container

Strategy: Ubuntu base + single-user Nix + home-manager activating `base.nix`.
Build on a connected machine; ship the store closure to airgapped targets.

### Dockerfile.dev

```dockerfile
# Dockerfile.dev — reproducible dev container for RunAI / Python work
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    curl xz-utils sudo git ca-certificates && \
    useradd -m -s /bin/bash gl && \
    echo "gl ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/gl && \
    rm -rf /var/lib/apt/lists/*

USER gl
WORKDIR /home/gl

# Install Nix (single-user, no daemon required in containers)
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon
ENV PATH=/home/gl/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH

# Enable flakes
RUN mkdir -p ~/.config/nix && \
    echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf

# Copy config into container
COPY --chown=gl:gl . /home/gl/nixos-config

# Apply headless profile
RUN . /home/gl/.nix-profile/etc/profile.d/nix.sh && \
    nix run nixpkgs#home-manager -- switch --flake /home/gl/nixos-config#wsl

# Mount SSH keys at runtime: docker run -v ~/.ssh:/home/gl/.ssh:ro ...
CMD ["nu"]
```

Build and run:
```bash
docker build -f Dockerfile.dev -t dev .
docker run -it -v ~/.ssh:/home/gl/.ssh:ro dev
```

### Smoke testing

`scripts/test-smoke.sh` runs automatically inside both Docker builds and fails the build on any missing binary. Run it manually against a running container:

```bash
# WSL / headless image
podman run --rm dev-headless bash ~/nixos-config/scripts/test-smoke.sh

# Airgap image (includes work-tool checks)
podman run --rm dev-airgap bash ~/scripts/test-smoke.sh --airgap
```

The `--airgap` flag adds checks for: `glab`, `jf` (jfrog-cli), `oc`, `mc`, `git-lfs`, `gpg`, `pass`, `pass-git-helper`, `pinentry-tty`, git `credential.helper`, and the glab update-check config.

### RunAI CLI

Will be installed inside airgapped env, from the internal net specific RunAI instance.

---

## Airgapped deployment

### Option A: nix copy (preferred)

Requires Nix already installed on the airgapped target (one-time USB bootstrap).

```bash
# On connected machine: build and export (use airgap profile, not wsl)
nix build .#homeConfigurations.airgap.activationPackage
nix copy --to file:///media/usb/nix-store .#homeConfigurations.airgap.activationPackage

# On airgapped machine: import and activate
nix copy --from file:///media/usb/nix-store /nix/store/<hash>-home-manager-generation
/nix/store/<hash>-home-manager-generation/activate
```

### Option B: Docker with pre-baked store (airgapped)

Default (`gl` user, WSL/personal machine):

```bash
./scripts/build-airgap-closure.sh            # outputs airgap-artifacts/
podman build -f Dockerfile.airgap \
  --build-arg ACTIVATION_STORE_PATH=$(cat airgap-artifacts/activation-store-path) \
  -t dev-airgap .
podman save dev-airgap | gzip > dev-airgap.tar.gz
```

**RunAI pods (user: `jensen`)** — the `runai` profile builds the same tools but
activates under `/home/jensen`. Use this when injecting into a corporate RunAI
base image where the pre-existing user is `jensen`:

```bash
./scripts/build-airgap-closure.sh --runai    # builds homeConfigurations.runai
podman build -f Dockerfile.airgap \
  --build-arg ACTIVATION_STORE_PATH=$(cat airgap-artifacts/activation-store-path) \
  --build-arg USER_NAME=jensen \
  --build-arg SKIP_USERADD=true \            # base image already has jensen
  -t dev-airgap-runai .
```

> **Recon first** — before building, confirm the username inside the pod:
> `whoami` and `echo $HOME`. If it's not `jensen` / `/home/jensen`,
> adjust `USER_NAME` and rebuild the `runai` closure accordingly.

Build runs `test-smoke.sh --airgap` automatically — a failed build = broken image.

### Credential setup (airgap only)

The `airgap` profile ships `pass` + `pass-git-helper` as the git credential helper.
One-time setup after first activation:

```bash
# 1. Generate a GPG key (or import existing key from USB)
gpg --gen-key

# 2. Initialise the password store
pass init <gpg-key-id>

# 3. Store git token(s)
pass insert work/gitlab      # line 1: username, line 2: token

# 4. Tell pass-git-helper which entry maps to which host
mkdir -p ~/.config/pass-git-helper
cat > ~/.config/pass-git-helper/git-pass-mapping.ini << 'EOF'
[gitlab.company.com]
target=work/gitlab
EOF

# 5. In Docker (no systemd) — start gpg-agent manually
eval $(gpg-agent --daemon --pinentry-program $(which pinentry-tty))
```

After this, `git clone https://gitlab.company.com/...` will silently use the stored token.

### Option C: self-extracting bundle (no Nix required on target)

```bash
nix bundle --bundler github:NixOS/bundlers#toArx \
  .#homeConfigurations.wsl.activationPackage
# produces a self-extracting archive
```

Less composable — updates require re-bundling the full archive.

---

## Key decisions

| Decision | Choice | Rationale |
|---|---|---|
| WSL system config | nixosConfigurations.wsl (NixOS-WSL flake) | fully declarative: username, PATH, flakes, home-manager in one rebuild |
| WSL PATH | appendWindowsPath = false | Windows PATH over 9P bridge causes ~10x slower tab completion |
| RunAI username | homeConfigurations.runai (user: jensen) | RunAI pods have pre-existing 'jensen' user; activation paths must match |
| RunAI chown | user-only, no group (|| true) | jensen group absent in base image — group chown fails silently |
| Shell in WSL | nushell (via bash exec guard) | consistent with nixbox; guard already handles nix-shell |
| Python LSP | basedpyright (not pyright) | actively maintained fork, better defaults, same LSP protocol |
| Python formatter | ruff (+ black kept) | ruff covers lint+format; black kept for projects that require it |
| Git diffs | delta (programs.delta.enable) | syntax-highlighted diffs; catppuccin.delta themes it |
| Terminal multiplexer | tmux | essential for persistent sessions over SSH/WSL |
| Git credentials headless (wsl) | empty helper (SSH keys or prompt) | keepassxc requires a running GUI; base.nix avoids the assumption |
| Git credentials airgap | pass-git-helper (GPG-backed pass store) | fully offline, no GUI needed; configured in airgap.nix |
| Git credentials GUI | keepassxc (lib.mkForce in gui.nix) | overrides the empty helper from base.nix |
