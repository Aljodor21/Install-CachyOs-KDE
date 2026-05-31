#!/bin/bash
# Script de validación post-instalación CachyOS
# Ejecutar DESPUÉS de install_cachyos.sh y de reiniciar sesión

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

ok()   { echo -e "${GREEN}[OK]${NC}    $1"; ((PASS++)); }
fail() { echo -e "${RED}[FAIL]${NC}  $1"; ((FAIL++)); }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; ((WARN++)); }

check_cmd() {
    local label=$1
    local cmd=$2
    if command -v "$cmd" &>/dev/null; then
        ok "$label — $(command -v "$cmd")"
    else
        fail "$label — comando '$cmd' no encontrado"
    fi
}

check_service() {
    local label=$1
    local service=$2
    if systemctl is-active --quiet "$service"; then
        ok "$label — activo"
    else
        fail "$label — servicio '$service' no está corriendo"
    fi
}

check_group() {
    local label=$1
    local group=$2
    if id -nG "$USER" | grep -qw "$group"; then
        ok "$label — usuario en grupo '$group'"
    else
        fail "$label — usuario NO está en grupo '$group' (reinicia sesión)"
    fi
}

check_dir() {
    local label=$1
    local dir=$2
    if [ -d "$dir" ]; then
        ok "$label — $dir"
    else
        fail "$label — directorio no existe: $dir"
    fi
}

check_flatpak() {
    local label=$1
    local app=$2
    if flatpak list 2>/dev/null | grep -q "$app"; then
        ok "$label (Flatpak)"
    else
        fail "$label — no instalado vía Flatpak"
    fi
}

# ─────────────────────────────────────────────
echo ""
echo "========================================="
echo "  VALIDACIÓN INSTALACIÓN CachyOS"
echo "========================================="
echo ""

# Terminal / Entorno
echo "─── Terminal / Entorno ───────────────────"
check_cmd "Zsh"              zsh
check_cmd "Git"              git
check_cmd "Kitty"            kitty
check_dir "Oh My Zsh"        "$HOME/.oh-my-zsh"
check_dir "Powerlevel10k"    "$HOME/.oh-my-zsh/themes/powerlevel10k"
check_dir "Plugin autosuggestions"       "$HOME/.oh-my-zsh/plugins/zsh-autosuggestions"
check_dir "Plugin syntax-highlighting"   "$HOME/.oh-my-zsh/plugins/zsh-syntax-highlighting"
check_dir "Plugin history-substring"     "$HOME/.oh-my-zsh/plugins/zsh-history-substring-search"

if [ "$SHELL" = "$(which zsh)" ]; then
    ok "Shell por defecto — zsh"
else
    warn "Shell por defecto — es '$SHELL', no zsh (puede requerir logout)"
fi

if fc-list | grep -qi "JetBrainsMono"; then
    ok "JetBrains Mono Nerd Font"
else
    fail "JetBrains Mono Nerd Font — no encontrada"
fi

echo ""
echo "─── Desarrollo ───────────────────────────"
check_cmd "GitHub CLI"       gh
check_cmd "VS Code"          code
check_cmd "Python"           python
check_cmd "pip"              pip
check_cmd "Java 17"          java
check_cmd "Arduino IDE"      arduino-ide
check_cmd "Docker"           docker
check_cmd "Docker Compose"   docker-compose
check_group "Docker (sin sudo)" docker
check_service "Docker daemon"   docker

# NVM y Node
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
export PATH="$HOME/.local/bin:$PATH"
if command -v node &>/dev/null; then
    ok "Node.js — $(node --version)"
else
    fail "Node.js — no encontrado (verifica NVM)"
fi
if command -v npm &>/dev/null; then
    ok "npm — $(npm --version)"
else
    fail "npm — no encontrado"
fi
if npm list -g @angular/cli &>/dev/null 2>&1; then
    ok "Angular CLI"
else
    fail "Angular CLI — no instalado globalmente"
fi
if command -v claude &>/dev/null; then
    ok "Claude Code CLI — $(command -v claude)"
else
    fail "Claude Code CLI — no encontrado en PATH"
fi

echo ""
echo "─── Multimedia ───────────────────────────"
check_cmd "OBS Studio"       obs
check_cmd "FFmpeg"           ffmpeg
check_cmd "VLC"              vlc

if [ -f "/opt/resolve/bin/resolve" ] || command -v resolve &>/dev/null; then
    ok "DaVinci Resolve"
else
    warn "DaVinci Resolve — instalación manual requerida (descarga desde Blackmagic)"
fi

echo ""
echo "─── Productividad ────────────────────────"
check_cmd "WPS Office"       wps
check_flatpak "Spotify"      spotify

echo ""
echo "─── Sistema / Red ────────────────────────"
check_cmd "Brave"            brave
check_cmd "VirtualBox"       vboxmanage
check_group "VirtualBox"     vboxusers
check_cmd "Tailscale"        tailscale
check_service "Tailscale"    tailscaled

echo ""
echo "─── Hardware ─────────────────────────────"
if command -v otd &>/dev/null || systemctl --user is-active --quiet opentabletdriver 2>/dev/null; then
    ok "OpenTabletDriver (Huion)"
else
    warn "OpenTabletDriver — verifica si el servicio de usuario está activo: systemctl --user status opentabletdriver"
fi

# ─────────────────────────────────────────────
echo ""
echo "========================================="
echo -e "  ${GREEN}OK: $PASS${NC}   ${RED}FAIL: $FAIL${NC}   ${YELLOW}WARN: $WARN${NC}"
echo "========================================="
echo ""

if [ $FAIL -gt 0 ]; then
    echo -e "${RED}Hay $FAIL items que fallaron. Revísalos arriba.${NC}"
    exit 1
else
    echo -e "${GREEN}Todo instalado correctamente.${NC}"
fi
