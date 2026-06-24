#!/usr/bin/env bash
# packages.sh — Tablas de paquetes por familia de distro y comandos distro-agnostic.
# Sourceado por install_arch.sh e install_debian.sh.
#
# Estructura:
#   - Array asociativo por familia con paquetes de los repos oficiales.
#   - Array con la lista de "repos .deb externos" que install_debian.sh debe agregar.
#   - Función helper que devuelve el nombre correcto de un paquete en cada familia.
#
# Nota: paquetes que solo se instalan en una familia (ej. AUR) NO viven acá; los maneja
#       directamente install_arch.sh con un bloque yay dedicado.

# Asegurar bash para arrays asociativos
if [ -z "${BASH_VERSION:-}" ]; then
    echo "packages.sh: requiere bash para arrays asociativos" >&2
    return 1 2>/dev/null || exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# Paquetes de repos oficiales — Familia Arch
# ──────────────────────────────────────────────────────────────────────────────
declare -A PKG_ARCH=(
    # Herramientas base
    [git]="git"
    [github-cli]="github-cli"
    [python]="python python-pip"
    [kitty]="kitty"
    [flatpak]="flatpak"
    [vlc]="vlc"
    [codecs]="gst-plugins-ugly gst-plugins-bad gst-libav"
    [base-devel]="base-devel"
    [zsh]="zsh"
    [nerd-font]="ttf-jetbrains-mono-nerd"
    [cifs-utils]="cifs-utils"
    [screenshot]="grim slurp wl-clipboard"
    [audio]="pavucontrol"
    [system-tools]="btop brightnessctl"
    [bluetooth]="bluez bluez-utils"
    [gtk-theme]="nwg-look"
    [ffmpeg]="ffmpeg"
    [docker]="docker docker-compose"
    [obs]="obs-studio"
    [java17]="jdk17-openjdk"
    # Virtualización KVM/QEMU
    [qemu]="qemu-full"
    [libvirt]="libvirt virt-manager virt-viewer dnsmasq vde2 bridge-utils ebtables iptables-nft swtpm"
    [ovmf]="edk2-ovmf"
    # Tailscale (está en repos oficiales de Arch)
    [tailscale]="tailscale"
)

# Paquetes de AUR — solo familia Arch
# install_arch.sh itera esta lista con yay.
PKG_ARCH_AUR=(
    "brave-bin"
    "visual-studio-code-bin"
    "wps-office"
    "opentabletdriver"
)

# ──────────────────────────────────────────────────────────────────────────────
# Paquetes de repos oficiales — Familia Debian
# ──────────────────────────────────────────────────────────────────────────────
declare -A PKG_DEBIAN=(
    # Herramientas base
    [git]="git"
    [github-cli]="gh"
    [python]="python3 python3-pip python3-venv"
    [kitty]="kitty"
    [flatpak]="flatpak"
    [vlc]="vlc"
    [codecs]="gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav"
    [base-devel]="build-essential"
    [zsh]="zsh"
    # JetBrains Mono Nerd Font: NO está en Debian. Ver PKG_DEBIAN_FONTS en install_debian.sh
    [cifs-utils]="cifs-utils"
    [screenshot]="grim slurp wl-clipboard"
    [audio]="pavucontrol"
    [system-tools]="btop brightnessctl"
    [bluetooth]="bluez bluez-tools"
    [gtk-theme]="nwg-look"
    [ffmpeg]="ffmpeg"
    [obs]="obs-studio"
    [java17]="openjdk-17-jdk"
    # libfuse2 para DaVinci Resolve AppImage/.run
    [libfuse]="libfuse2"
    # Virtualización KVM/QEMU
    [qemu]="qemu-system-x86 qemu-utils"
    [libvirt]="libvirt-daemon-system libvirt-clients virt-manager virt-viewer dnsmasq bridge-utils ebtables iptables swtpm"
    [ovmf]="ovmf"
    # Tailscale lo agrega el repo externo (ver PKG_DEBIAN_EXTERNAL_REPOS)
    # Docker CE lo agrega el repo externo
)

# Repos .deb externos firmados con GPG — solo familia Debian.
# install_debian.sh usa esto para poblar /etc/apt/sources.list.d/ y /etc/apt/keyrings/.
# Formato: "nombre|keyring_url|keyring_path|codename_token|repo_suite|repo_components|arch_aware"
#   - codename_token: "version_codename" o "suite_codename" (lo expande install_debian.sh)
#   - arch_aware: "1" si hay que poner [arch=...] en la línea, "0" si no
PKG_DEBIAN_EXTERNAL_REPOS=(
    "docker|https://download.docker.com/linux/debian/gpg|/etc/apt/keyrings/docker.gpg|version_codename|stable||1"
    "brave|https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg|/etc/apt/keyrings/brave-browser.gpg|||stable main|1"
    "vscode|https://packages.microsoft.com/keys/microsoft-archive-keyring.gpg|/etc/apt/keyrings/microsoft.gpg|||stable main|1"
    "tailscale|https://pkgs.tailscale.com/stable/debian/tailscale-archive-keyring.gpg|/etc/apt/keyrings/tailscale.gpg|version_codename|main||0"
    "opentabletdriver|https://opentabletdriver.net/OldTuxedo/release/deb/OtdRelease.asc|/etc/apt/keyrings/opentabletdriver.gpg|version_codename|contrib||0"
)

# Paquetes de los repos externos — familia Debian
declare -A PKG_DEBIAN_FROM_REPO=(
    [docker]="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    [brave]="brave-browser"
    [vscode]="code"
    [tailscale]="tailscale"
    [opentabletdriver]="opentabletdriver"
)

# Paquetes de flatpak — ambas familias
PKG_FLATPAK=(
    "com.spotify.Client"
)

# ──────────────────────────────────────────────────────────────────────────────
# Paquetes distro-agnostic (NVM/npm/curl scripts) — id\u00e9nticos en ambas familias
# ──────────────────────────────────────────────────────────────────────────────

# Función helper: dado un nombre lógico, devuelve el nombre del paquete en la familia actual.
#   Uso: pkg=$(pkg_for "docker")
# Si la familia no tiene ese paquete (porque viene de AUR o repo externo), retorna vacío
# y el caller decide qué hacer.
pkg_for() {
    local key="$1"
    case "$DISTRO_FAMILY" in
        arch)
            [ -n "${PKG_ARCH[$key]:-}" ] && echo "${PKG_ARCH[$key]}" || echo ""
            ;;
        debian)
            [ -n "${PKG_DEBIAN[$key]:-}" ] && echo "${PKG_DEBIAN[$key]}" || echo ""
            ;;
        *)
            return 1
            ;;
    esac
}

# Devuelve paquetes de repo externo para la familia Debian.
#   Uso: pkg=$(pkg_from_repo "docker")
pkg_from_repo() {
    local key="$1"
    [ "${DISTRO_FAMILY:-}" = "debian" ] || { echo ""; return 0; }
    [ -n "${PKG_DEBIAN_FROM_REPO[$key]:-}" ] && echo "${PKG_DEBIAN_FROM_REPO[$key]}" || echo ""
}
