#!/usr/bin/env bash
# Linux package installation.
#
# Three passes, in this order:
#   1. native package manager  — fast, signed, integrates with the distro
#   2. Homebrew-on-Linux       — the tools the distro does not carry
#   3. vendor installers       — docker, gcloud, terraform: upstream repos only
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

detect_pkg_mgr
detect_arch
init_sudo

# ---------------------------------------------------------------------------
# Pass 1 — native packages
# ---------------------------------------------------------------------------

install_native() {
  local manifest pkgs
  case "$PKG_MGR" in
    apt)    manifest="$DOTFILES_DIR/packages/linux/apt.txt" ;;
    dnf)    manifest="$DOTFILES_DIR/packages/linux/dnf.txt" ;;
    pacman) manifest="$DOTFILES_DIR/packages/linux/pacman.txt" ;;
    *)      warn "unsupported package manager '${PKG_MGR:-none}' — skipping native pass"
            return 0 ;;
  esac

  mapfile -t pkgs < <(read_manifest "$manifest")
  [[ ${#pkgs[@]} -gt 0 ]] || { warn "no packages in $manifest"; return 0; }

  log "installing ${#pkgs[@]} native packages via $PKG_MGR"
  case "$PKG_MGR" in
    apt)
      run $SUDO apt-get update -y
      # One at a time: a package renamed or absent on this release should not
      # take the whole transaction down with it.
      local p
      for p in "${pkgs[@]}"; do
        run $SUDO apt-get install -y --no-install-recommends "$p" \
          || warn "apt: $p unavailable on this release — skipping"
      done
      ;;
    dnf)
      run $SUDO dnf install -y --skip-broken "${pkgs[@]}" || warn "dnf reported failures"
      ;;
    pacman)
      run $SUDO pacman -Sy --needed --noconfirm "${pkgs[@]}" || warn "pacman reported failures"
      ;;
  esac
  ok "native packages done"
}

# ---------------------------------------------------------------------------
# Pass 2 — Homebrew parity set
# ---------------------------------------------------------------------------

install_brew_parity() {
  if [[ "${SKIP_BREW:-0}" == "1" ]]; then
    skip "homebrew parity set (SKIP_BREW=1)"
    return 0
  fi
  if [[ "$ARCH" != "x86_64" && "$ARCH" != "arm64" ]]; then
    warn "homebrew does not support $ARCH on Linux — skipping parity set"
    return 0
  fi

  # Homebrew refuses to run as root, so a root shell (containers, fresh VPS)
  # gets the native + vendor passes only instead of a hard failure.
  if [[ "$(id -u)" -eq 0 ]]; then
    warn "running as root — Homebrew does not support root; skipping parity set"
    return 0
  fi
  install_brew || { warn "skipping homebrew parity set"; return 0; }

  log "tapping third-party formulae"
  local tap
  for tap in tinygo-org/tools mutagen-io/mutagen; do
    run brew tap "$tap" || warn "tap $tap failed"
  done

  warn_untrusted_taps tinygo-org/tools mutagen-io/mutagen

  log "installing homebrew parity set"
  brew_install_each "$DOTFILES_DIR/packages/brew-linux.txt"
  ok "homebrew parity set done"
}

# ---------------------------------------------------------------------------
# Pass 3 — vendor installers
# ---------------------------------------------------------------------------

# Distro id and codename from /etc/os-release (lsb_release is often absent).
os_release() { (. /etc/os-release 2>/dev/null && eval "echo \${$1:-}"); }

install_docker() {
  has docker && { ok "docker already installed"; return 0; }
  # Docker publishes separate apt repos per distro; derivatives (Mint, Pop!_OS)
  # fall back to the one they are built on via ID_LIKE.
  local distro
  case "$(os_release ID) $(os_release ID_LIKE)" in
    *ubuntu*) distro=ubuntu ;;
    *debian*) distro=debian ;;
  esac
  if [[ "$PKG_MGR" != "apt" || -z "${distro:-}" ]]; then
    warn "docker: install manually for this distro — https://docs.docker.com/engine/install/"
    return 0
  fi
  local codename
  codename="$(os_release UBUNTU_CODENAME)"; [[ -n "$codename" ]] || codename="$(os_release VERSION_CODENAME)"
  log "installing docker engine from the upstream repo ($distro $codename)"
  run $SUDO install -m 0755 -d /etc/apt/keyrings
  # --yes: overwrite a key left by an earlier, interrupted run instead of prompting.
  run bash -c "curl -fsSL https://download.docker.com/linux/$distro/gpg | $SUDO gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg" \
    || { warn "docker: could not fetch the repo key"; return 0; }
  run $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
  run bash -c "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$distro $codename stable\" | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null"
  run $SUDO apt-get update -y
  run $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin || warn "docker install failed"
  # Without this, every docker command needs sudo. Takes effect on next login.
  run $SUDO usermod -aG docker "$USER" || true
  warn "log out and back in for docker group membership to apply"
}

install_gcloud() {
  # The installer puts it in ~/google-cloud-sdk, which is only on PATH once the
  # shell config loads it, so check the directory too or every run reinstalls.
  if has gcloud || [[ -x "$HOME/google-cloud-sdk/bin/gcloud" ]]; then
    ok "gcloud already installed"; return 0
  fi
  log "installing google cloud sdk"
  run bash -c "curl -fsSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir=\"\$HOME\"" \
    || warn "gcloud install failed"
}

install_terraform() {
  has terraform && { ok "terraform already installed"; return 0; }
  if [[ "$PKG_MGR" != "apt" ]]; then
    warn "terraform: install manually for $PKG_MGR — https://developer.hashicorp.com/terraform/install"
    return 0
  fi
  log "installing terraform from the hashicorp repo"
  local codename
  codename="$(os_release UBUNTU_CODENAME)"; [[ -n "$codename" ]] || codename="$(os_release VERSION_CODENAME)"
  run bash -c "curl -fsSL https://apt.releases.hashicorp.com/gpg | $SUDO gpg --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg" \
    || { warn "terraform: could not fetch the repo key"; return 0; }
  run bash -c "echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $codename main\" | $SUDO tee /etc/apt/sources.list.d/hashicorp.list >/dev/null"
  run $SUDO apt-get update -y
  run $SUDO apt-get install -y terraform || warn "terraform install failed"
}

main() {
  install_native
  install_brew_parity
  install_docker
  install_gcloud
  install_terraform
  ok "linux packages done"
}

main "$@"
