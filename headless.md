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
              #           fastfetch, k9s, helm, posting, harlequin, opencode
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
| WSL / Ubuntu standalone | `nix run nixpkgs#home-manager -- switch --flake /etc/nixos#wsl` | imports base.nix only |
| Docker dev container | See Dockerfile.dev below | Ubuntu + Nix + home-manager |
| Remote server | Same as WSL path | SSH only |

---

## WSL / Ubuntu standalone

The `homeConfigurations.wsl` output in `flake.nix` uses standalone home-manager
(no NixOS required). One-time setup on a fresh machine:

```bash
# 1. Install Nix (single-user, no daemon — works in WSL and Ubuntu)
curl -L https://nixos.org/nix/install | sh -s -- --no-daemon
. ~/.nix-profile/etc/profile.d/nix.sh

# 2. Enable flakes
mkdir -p ~/.config/nix
echo 'experimental-features = nix-flakes nix-command' >> ~/.config/nix/nix.conf

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
    echo 'experimental-features = nix-flakes nix-command' >> ~/.config/nix/nix.conf

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

### RunAI CLI

RunAI CLI is not in nixpkgs. Install it in the Dockerfile before the Nix step:

```dockerfile
# After useradd, before USER gl:
RUN curl -L https://app.run.ai/cli/linux/runai -o /usr/local/bin/runai && \
    chmod +x /usr/local/bin/runai
```

Or use a fetchurl derivation in a Nix overlay if a stable tarball URL exists.

---

## Airgapped deployment

### Option A: nix copy (preferred)

Requires Nix already installed on the airgapped target (one-time USB bootstrap).

```bash
# On connected machine: build and export
nix build .#homeConfigurations.wsl.activationPackage
nix copy --to file:///media/usb/nix-store .#homeConfigurations.wsl.activationPackage

# On airgapped machine: import and activate
nix copy --from file:///media/usb/nix-store /nix/store/<hash>-home-manager-generation
/nix/store/<hash>-home-manager-generation/activate
```

### Option B: Docker with pre-baked store (airgapped)

```bash
# On connected machine: build store closure into image
docker build -f Dockerfile.dev -t dev-connected .
docker save dev-connected | gzip > dev-connected.tar.gz

# Transfer to airgapped machine (USB / sneakernet)
docker load < dev-connected.tar.gz
docker run -it -v ~/.ssh:/home/gl/.ssh:ro dev-connected
```

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
| Shell in WSL | nushell (via bash exec guard) | consistent with nixbox; guard already handles nix-shell |
| Python LSP | basedpyright (not pyright) | actively maintained fork, better defaults, same LSP protocol |
| Python formatter | ruff (+ black kept) | ruff covers lint+format; black kept for projects that require it |
| Git diffs | delta (programs.git.delta.enable) | syntax-highlighted diffs; catppuccin.delta themes it |
| Terminal multiplexer | tmux | essential for persistent sessions over SSH/WSL |
| Git credentials headless | empty helper (SSH keys or prompt) | keepassxc requires a running GUI; base.nix avoids the assumption |
| Git credentials GUI | keepassxc (lib.mkForce in gui.nix) | overrides the empty helper from base.nix |
