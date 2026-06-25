#!/usr/bin/env bash
# validate_install.sh — Verifica que toda la instalación quedó correcta.
# Distro-aware: detecta si estamos en Arch o Debian y adapta los checks.
# Ejecutar DESPUÉS de install.sh y de reiniciar sesión.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Sourcear dependencias
# shellcheck source=lib/detect_distro.sh
source "$SCRIPT_DIR/lib/detect_distro.sh"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# ──────────────────────────────────────────────────────────────────────────────
# Banner
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "========================================="
echo "  VALIDACIÓN INSTALACIÓN"
echo "  $DISTRO_NAME ($DISTRO_FAMILY)"
echo "========================================="
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Sección: Terminal / Entorno
# ──────────────────────────────────────────────────────────────────────────────
echo "─── Terminal / Entorno ───────────────────"
check_cmd "Zsh"              zsh
check_cmd "Git"              git
check_cmd "Kitty"            kitty
check_dir "Oh My Zsh"        "$HOME/.oh-my-zsh"
check_dir "Powerlevel10k"    "$HOME/.oh-my-zsh/themes/powerlevel10k"
check_dir "Plugin autosuggestions"       "$HOME/.oh-my-zsh/plugins/zsh-autosuggestions"
check_dir "Plugin syntax-highlighting"   "$HOME/.oh-my-zsh/plugins/zsh-syntax-highlighting"
check_dir "Plugin history-substring"     "$HOME/.oh-my-zsh/plugins/zsh-history-substring-search"

if [ "$SHELL" = "$(which zsh 2>/dev/null)" ]; then
    ok "Shell por defecto — zsh"
else
    warn "Shell por defecto — es '$SHELL', no zsh (puede requerir logout)"
fi

# Nerd Font: en Arch es ttf-jetbrains-mono-nerd (paquete), en Debian está en ~/.local/share/fonts
if fc-list 2>/dev/null | grep -qi "JetBrainsMono"; then
    ok "JetBrains Mono Nerd Font"
else
    fail "JetBrains Mono Nerd Font — no encontrada"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Sección: Desarrollo
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "─── Desarrollo ───────────────────────────"
check_cmd "GitHub CLI"       gh
check_cmd "VS Code"          code

# Python: en Arch es 'python' (symlink), en Debian es 'python3'
if cmd_exists python3; then
    ok "Python — $(python3 --version) ($(command -v python3))"
else
    fail "Python 3 — no encontrado"
fi
check_cmd "pip"              pip3

# Java
if cmd_exists java; then
    ok "Java — $(java -version 2>&1 | head -1)"
else
    fail "Java — no encontrado"
fi

check_cmd "Docker"           docker

# docker compose: v1 era `docker-compose`, v2 es plugin `docker compose`
if docker compose version &>/dev/null; then
    ok "Docker Compose (v2 plugin) — $(docker compose version --short)"
elif cmd_exists docker-compose; then
    ok "Docker Compose (v1) — $(docker-compose --version)"
else
    fail "Docker Compose — no encontrado"
fi

check_group "Docker (sin sudo)"     docker
check_service "Docker daemon"        docker

# NVM y Node
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
if cmd_exists node; then
    ok "Node.js — $(node --version)"
else
    fail "Node.js — no encontrado (verifica NVM)"
fi
if cmd_exists npm; then
    ok "npm — $(npm --version)"
else
    fail "npm — no encontrado"
fi
if npm list -g @angular/cli --depth=0 2>/dev/null | grep -q "@angular/cli"; then
    ok "Angular CLI"
else
    fail "Angular CLI — no instalado globalmente"
fi
if cmd_exists claude; then
    ok "Claude Code CLI — $(command -v claude)"
else
    fail "Claude Code CLI — no encontrado en PATH"
fi
if cmd_exists opencode; then
    ok "opencode — $(command -v opencode) ($(opencode --version 2>/dev/null || echo '?'))"
else
    warn "opencode — no encontrado (puede requerir logout para que ~/.opencode/bin esté en PATH)"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Sección: Multimedia
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "─── Multimedia ───────────────────────────"
check_cmd "OBS Studio"       obs
check_cmd "FFmpeg"           ffmpeg
check_cmd "VLC"              vlc

if [ -f "/opt/resolve/bin/resolve" ] || cmd_exists resolve; then
    ok "DaVinci Resolve"
else
    warn "DaVinci Resolve — instalación manual requerida (descarga desde Blackmagic)"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Sección: Productividad
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "─── Productividad ────────────────────────"
if cmd_exists wps; then
    ok "WPS Office"
else
    warn "WPS Office — no encontrado"
fi
if cmd_exists flatpak && flatpak list 2>/dev/null | grep -q "com.spotify.Client"; then
    ok "Spotify (Flatpak)"
else
    warn "Spotify — no instalado vía Flatpak"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Sección: Sistema / Red
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "─── Sistema / Red ────────────────────────"
check_cmd "Brave"            "$( [ "$DISTRO_FAMILY" = "debian" ] && echo brave-browser || echo brave )"
check_cmd "Tailscale"        tailscale
check_service "Tailscale"    tailscaled

# Docker en /etc/docker/daemon.json (config opcional pero útil)
# (No es un check obligatorio, lo dejo comentado por si querés activarlo)
# if [ -f /etc/docker/daemon.json ]; then
#     ok "Docker daemon.json presente"
# else
#     warn "Docker daemon.json no existe (usá si querés configurar storage driver, mirrors, etc.)"
# fi

# ──────────────────────────────────────────────────────────────────────────────
# Sección: Virtualización KVM/libvirt (reemplaza a VirtualBox)
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "─── Virtualización (KVM/QEMU/libvirt) ────"
check_cmd "QEMU"             qemu-system-x86_64
check_cmd "libvirt client"   virsh
check_cmd "virt-manager"     virt-manager
check_service "libvirtd"      libvirtd
check_group "libvirt"         libvirt

if [ -e /dev/kvm ]; then
    ok "/dev/kvm disponible"
else
    fail "/dev/kvm no existe — KVM no disponible (¿CPU sin soporte de virtualización?)"
fi

if sudo virsh net-list --all 2>/dev/null | grep -q " default "; then
    ok "Red libvirt 'default' definida"
else
    warn "Red libvirt 'default' no definida (las VMs no tendrán NAT)"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Sección: Hardware
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "─── Hardware ─────────────────────────────"
if cmd_exists otd || systemctl --user is-active --quiet opentabletdriver 2>/dev/null; then
    ok "OpenTabletDriver (Huion)"
else
    warn "OpenTabletDriver — verificá: systemctl --user status opentabletdriver"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Sección: Distro-específico
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "─── Distro-específico ($DISTRO_FAMILY) ───"
case "$DISTRO_FAMILY" in
    arch)
        # yay solo aplica a Arch
        if cmd_exists yay; then
            ok "yay (AUR helper)"
        else
            warn "yay no encontrado (AUR no disponible)"
        fi
        if cmd_exists pacman; then
            ok "pacman — gestor de paquetes"
        else
            fail "pacman no encontrado"
        fi
        ;;
    debian)
        if cmd_exists apt; then
            ok "apt — gestor de paquetes"
        else
            fail "apt no encontrado"
        fi
        # Repos externos firmados (OTD se instala por tarball, no por apt).
        # Los keyrings tienen nombres distintos a los repos:
        #   docker   → docker.gpg
        #   brave    → brave-browser.gpg
        #   vscode   → microsoft.gpg
        #   tailscale → tailscale.gpg
        declare -A REPO_KEYRINGS=(
            [docker]="/etc/apt/keyrings/docker.gpg"
            [brave]="/etc/apt/keyrings/brave-browser.gpg"
            [vscode]="/etc/apt/keyrings/microsoft.gpg"
            [tailscale]="/etc/apt/keyrings/tailscale.gpg"
        )
        for repo in docker brave vscode tailscale; do
            list_file="/etc/apt/sources.list.d/${repo}.list"
            keyring_file="${REPO_KEYRINGS[$repo]}"
            if [ -f "$list_file" ] && [ -f "$keyring_file" ]; then
                ok "Repo externo: $repo"
            else
                warn "Repo externo: $repo (sources.list o keyring faltante)"
            fi
        done
        # OpenTabletDriver: instalado por tarball binario, no por apt
        if [ -x /usr/local/bin/otd ] || [ -d /opt/opentabletdriver ]; then
            ok "OpenTabletDriver (tarball en /opt/opentabletdriver)"
        else
            warn "OpenTabletDriver no instalado (¿tenés tablet Huion?)"
        fi
        ;;
esac

# ──────────────────────────────────────────────────────────────────────────────
# Resumen final
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "========================================="
echo -e "  ${_C_GREEN}OK: $PASS_COUNT${_C_NC}   ${_C_RED}FAIL: $FAIL_COUNT${_C_NC}   ${_C_YELLOW}WARN: $WARN_COUNT${_C_NC}   ${_C_BLUE}SKIP: $SKIP_COUNT${_C_NC}"
echo "========================================="
echo ""

if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${_C_RED}Hay $FAIL_COUNT items que fallaron. Revísalos arriba.${_C_NC}"
    echo "  Si no encontrás la causa, corré ./fix_post_install.sh para reintentar los pasos que fallaron."
    exit 1
else
    echo -e "${_C_GREEN}Todo instalado correctamente.${_C_NC}"
fi
