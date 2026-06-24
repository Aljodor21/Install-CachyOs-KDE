#!/usr/bin/env bash
# detect_distro.sh — Detecta la familia de distribución a partir de /etc/os-release.
# Sourceado por install.sh y por los demás scripts de la familia install_*.
#
# Salida:
#   DISTRO_FAMILY  -> "arch" o "debian"
#   DISTRO_ID      -> ID de /etc/os-release (debian, ubuntu, arch, cachyos, ...)
#   DISTRO_NAME    -> nombre legible
#   PKG_MGR        -> "pacman" o "apt"
#   NEEDS_AUR      -> "1" si requiere AUR (Arch family), "0" si no (Debian family)
#
# Exit codes:
#   0  distro soportada
#   1  distro no soportada

if [ -z "${BASH_VERSION:-}" ] && [ -z "${ZSH_VERSION:-}" ]; then
    echo "detect_distro.sh: necesita ejecutarse con bash o zsh" >&2
    return 1 2>/dev/null || exit 1
fi

# Cargar /etc/os-release de forma segura
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
else
    echo "detect_distro.sh: /etc/os-release no encontrado, distro no soportada" >&2
    return 1 2>/dev/null || exit 1
fi

DISTRO_ID="${ID:-unknown}"
DISTRO_NAME="${PRETTY_NAME:-${ID:-unknown}}"

case "$DISTRO_ID" in
    # --- Familia Arch ---
    arch|archlinux)
        DISTRO_FAMILY="arch"
        PKG_MGR="pacman"
        NEEDS_AUR="1"
        ;;
    cachyos)
        DISTRO_FAMILY="arch"
        PKG_MGR="pacman"
        NEEDS_AUR="1"
        ;;
    manjaro|endeavouros|garuda|artix|archlabs|rebornos)
        DISTRO_FAMILY="arch"
        PKG_MGR="pacman"
        NEEDS_AUR="1"
        ;;
    # --- Familia Debian ---
    debian)
        DISTRO_FAMILY="debian"
        PKG_MGR="apt"
        NEEDS_AUR="0"
        ;;
    ubuntu|kubuntu|xubuntu|lubuntu|ubuntu-budgie|ubuntu-mate|ubuntu-studio)
        DISTRO_FAMILY="debian"
        PKG_MGR="apt"
        NEEDS_AUR="0"
        ;;
    linuxmint|pop|elementary|zorin|kde-neon|deepin|peppermint|mx|knoppix|antix|raspbian)
        DISTRO_FAMILY="debian"
        PKG_MGR="apt"
        NEEDS_AUR="0"
        ;;
    *)
        echo "detect_distro.sh: distro '$DISTRO_ID' no soportada todavía" >&2
        echo "  Familias conocidas: arch (arch, cachyos, manjaro, ...) y debian (debian, ubuntu, mint, ...)" >&2
        return 1 2>/dev/null || exit 1
        ;;
esac

export DISTRO_FAMILY DISTRO_ID DISTRO_NAME PKG_MGR NEEDS_AUR
