#!/usr/bin/env bash
# install_arch.sh — Instala y configura el entorno de desarrollo en familia Arch.
# Sourceado desde install.sh (que detecta la familia). NO ejecutar directamente.
#
# Familia soportada: arch, cachyos, manjaro, endeavour, garuda, artix, archlabs, ...
# Gestor: pacman + yay (AUR)
#
# Ejecutar como usuario normal (NO root). El script usa sudo internamente.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Sourcear dependencias
# shellcheck source=lib/detect_distro.sh
source "$SCRIPT_DIR/lib/detect_distro.sh"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/packages.sh
source "$SCRIPT_DIR/lib/packages.sh"

# Verificar que estamos en la familia correcta
if [ "$DISTRO_FAMILY" != "arch" ]; then
    log_error "Este script es para familia Arch, pero la distro detectada es '$DISTRO_ID' ($DISTRO_FAMILY)."
    log_error "Usa install_debian.sh en su lugar."
    exit 1
fi

# Precondiciones
check_not_root || exit 1
check_sudo_nopasswd || exit 1
check_internet || exit 1

echo ""
log_step "Entorno detectado"
log_info "  Distro:    $DISTRO_NAME"
log_info "  Familia:   $DISTRO_FAMILY"
log_info "  Gestor:    $PKG_MGR + AUR"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
log_step "Actualizando sistema"
# ──────────────────────────────────────────────────────────────────────────────
sudo pacman -Syu --noconfirm

# ──────────────────────────────────────────────────────────────────────────────
log_step "Instalando yay (AUR helper) si no está"
# ──────────────────────────────────────────────────────────────────────────────
if ! cmd_exists yay; then
    log_info "yay no encontrado, instalando desde AUR..."
    sudo pacman -S --noconfirm --needed git base-devel
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
else
    log_ok "yay ya está instalado"
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "Instalando paquetes de repos oficiales"
# ──────────────────────────────────────────────────────────────────────────────
# Helper: instala una lista de paquetes (ignorando los vacíos) usando pacman.
pacman_install() {
    local pkgs=()
    for p in "$@"; do
        [ -n "$p" ] && pkgs+=("$p")
    done
    if [ ${#pkgs[@]} -gt 0 ]; then
        sudo pacman -S --noconfirm --needed "${pkgs[@]}"
    fi
}

# Resolver e instalar todos los paquetes de PKG_ARCH (excepto tailscale que va separado)
pacman_install $(
    for key in git github-cli python kitty flatpak vlc codecs base-devel zsh \
               nerd-font cifs-utils screenshot audio system-tools bluetooth \
               gtk-theme ffmpeg docker obs java17 fastfetch qemu libvirt ovmf; do
        pkg_for "$key"
    done
)

# ──────────────────────────────────────────────────────────────────────────────
log_step "Instalando paquetes de AUR"
# ──────────────────────────────────────────────────────────────────────────────
# Filtrar los que ya estén instalados
aur_to_install=()
for pkg in "${PKG_ARCH_AUR[@]}"; do
    if pacman -Qi "$pkg" &>/dev/null; then
        log_ok "AUR $pkg ya está instalado"
    else
        aur_to_install+=("$pkg")
    fi
done
if [ ${#aur_to_install[@]} -gt 0 ]; then
    yay -S --noconfirm "${aur_to_install[@]}"
else
    log_ok "Todos los paquetes de AUR ya están instalados"
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "Habilitando servicios"
# ──────────────────────────────────────────────────────────────────────────────
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

sudo systemctl enable --now tailscaled
# libvirtd: enable --now activa el socket pero el daemon solo se inicia
# on-demand. Para que arranque YA, hacemos un 'start' explícito.
sudo systemctl enable --now libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket
sudo systemctl start libvirtd 2>/dev/null || true
sudo usermod -aG libvirt "$USER"

# Bluetooth
sudo systemctl enable --now bluetooth

# ──────────────────────────────────────────────────────────────────────────────
log_step "Virtualización KVM/QEMU — red default"
# ──────────────────────────────────────────────────────────────────────────────
# La red 'default' de libvirt permite que las VMs tengan NAT y salida a internet.
# Si ya está definida no la sobreescribimos.
if ! sudo virsh net-list --all 2>/dev/null | grep -q " default "; then
    log_info "Definiendo red libvirt 'default'..."
    sudo virsh net-define /usr/share/libvirt/networks/default.xml 2>/dev/null || true
    sudo virsh net-start default 2>/dev/null || true
    sudo virsh net-autostart default 2>/dev/null || true
else
    log_ok "Red libvirt 'default' ya existe"
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "Terminal — Oh My Zsh + Powerlevel10k + plugins"
# ──────────────────────────────────────────────────────────────────────────────
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    log_ok "Oh My Zsh ya está instalado"
fi

if [ ! -d "$HOME/.oh-my-zsh/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "$HOME/.oh-my-zsh/themes/powerlevel10k"
else
    log_ok "Powerlevel10k ya está clonado"
fi

# Plugins
for plugin_pair in \
    "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions" \
    "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting" \
    "zsh-history-substring-search|https://github.com/zsh-users/zsh-history-substring-search"; do
    name="${plugin_pair%%|*}"
    url="${plugin_pair##*|}"
    if [ ! -d "$HOME/.oh-my-zsh/plugins/$name" ]; then
        git clone "$url" "$HOME/.oh-my-zsh/plugins/$name"
    else
        log_ok "Plugin $name ya está clonado"
    fi
done

# ──────────────────────────────────────────────────────────────────────────────
log_step "Aplicando configs (.zshrc, kitty.conf)"
# ──────────────────────────────────────────────────────────────────────────────
cp -f "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
mkdir -p "$HOME/.config/kitty"
cp -f "$SCRIPT_DIR/kitty.conf" "$HOME/.config/kitty/kitty.conf"

# Kitty como terminal por defecto
if grep -q "TerminalApplication" "$HOME/.config/kdeglobals" 2>/dev/null; then
    sed -i 's/TerminalApplication=.*/TerminalApplication=kitty/' "$HOME/.config/kdeglobals"
else
    mkdir -p "$HOME/.config"
    printf "\n[General]\nTerminalApplication=kitty\n" >> "$HOME/.config/kdeglobals"
fi
if cmd_exists update-alternatives; then
    sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/kitty 50 2>/dev/null || true
    sudo update-alternatives --set x-terminal-emulator /usr/bin/kitty 2>/dev/null || true
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "Node.js — NVM + LTS"
# ──────────────────────────────────────────────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
# shellcheck source=/dev/null
source "$NVM_DIR/nvm.sh"
nvm install --lts
nvm alias default node

# ──────────────────────────────────────────────────────────────────────────────
log_step "npm globals — Claude Code, Angular CLI, opencode"
# ──────────────────────────────────────────────────────────────────────────────
npm install -g @anthropic-ai/claude-code
npm install -g @angular/cli

# opencode: installer oficial
if ! cmd_exists opencode; then
    log_info "Instalando opencode..."
    curl -fsSL https://opencode.ai/install | bash
    # El installer pone el binario en ~/.opencode/bin
    if [ -d "$HOME/.opencode/bin" ]; then
        export PATH="$HOME/.opencode/bin:$PATH"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "Flatpak — Spotify"
# ──────────────────────────────────────────────────────────────────────────────
if ! cmd_exists flatpak; then
    log_warn "flatpak no está disponible, saltando Spotify."
else
    flatpak install -y flathub com.spotify.Client 2>/dev/null || log_warn "No se pudo instalar Spotify (¿Flathub no configurado?)"
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "OpenTabletDriver — habilitando servicio de usuario"
# ──────────────────────────────────────────────────────────────────────────────
if cmd_exists otd || pacman -Qi opentabletdriver &>/dev/null; then
    systemctl --user enable --now opentabletdriver 2>/dev/null || log_warn "No se pudo habilitar opentabletdriver (¿sesión de usuario sin systemd?)"
else
    log_info "OpenTabletDriver no instalado (skip)"
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "DaVinci Resolve — recordatorio manual"
# ──────────────────────────────────────────────────────────────────────────────
echo ""
log_info "DaVinci Resolve requiere descarga manual:"
log_info "  1. sudo pacman -S --needed fuse2"
log_info "  2. Descargar .run desde https://www.blackmagicdesign.com/products/davinciresolve"
log_info "  3. chmod +x DaVinci_Resolve_*.run && ./DaVinci_Resolve_*.run"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
log_step "fastfetch — config personalizado"
# ──────────────────────────────────────────────────────────────────────────────
# Instala fastfetch y escribe una config linda para que aparezca al abrir terminal.
if cmd_exists fastfetch; then
    mkdir -p "$HOME/.config/fastfetch"
    if [ ! -f "$HOME/.config/fastfetch/config.jsonc" ]; then
        cat > "$HOME/.config/fastfetch/config.jsonc" << 'FFEOF'
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "type": "auto",
        "padding": {
            "top": 0,
            "left": 2,
            "right": 4
        }
    },
    "display": {
        "separator": " │ ",
        "color": {
            "title": "magenta",
            "key": "cyan",
            "value": "default"
        }
    },
    "modules": [
        "title",
        "separator",
        {
            "type": "os",
            "key": "   OS       "
        },
        {
            "type": "host",
            "key": "   HOST     "
        },
        {
            "type": "kernel",
            "key": "   KERNEL   "
        },
        {
            "type": "uptime",
            "key": "   UPTIME   "
        },
        {
            "type": "packages",
            "key": "   PKGS     "
        },
        {
            "type": "shell",
            "key": "   SHELL    "
        },
        {
            "type": "display",
            "key": "   DISPLAY  "
        },
        {
            "type": "de",
            "key": "   DE       "
        },
        {
            "type": "wm",
            "key": "   WM       "
        },
        {
            "type": "terminal",
            "key": "   TERM     "
        },
        "break",
        {
            "type": "cpu",
            "key": "   CPU      ",
            "keyColor": "yellow"
        },
        {
            "type": "gpu",
            "key": "   GPU      ",
            "keyColor": "yellow"
        },
        {
            "type": "memory",
            "key": "   MEM      ",
            "keyColor": "green"
        },
        {
            "type": "disk",
            "key": "   DISK     ",
            "keyColor": "green"
        },
        {
            "type": "local-ip",
            "key": "   IP       ",
            "keyColor": "magenta"
        },
        "break",
        {
            "type": "colors",
            "symbol": "circle"
        }
    ]
}
FFEOF
        log_ok "fastfetch config creado en ~/.config/fastfetch/config.jsonc"
    else
        log_info "fastfetch config ya existe, skip"
    fi
else
    log_warn "fastfetch no instalado (skip config)"
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "KDE Plasma — pineando apps a la taskbar"
# ──────────────────────────────────────────────────────────────────────────────
# Agrega Brave, VS Code, Kitty, VLC, OBS, virt-manager, Spotify y WPS al
# panel/taskbar de KDE Plasma. Idempotente: si ya estan pineadas, las deja.
# No-op si KDE no es el DE activo o si no hay sesion grafica iniciada.
pin_apps_to_taskbar

# ──────────────────────────────────────────────────────────────────────────────
log_step "Instalación completada"
# ──────────────────────────────────────────────────────────────────────────────
echo ""
log_ok "Paquetes instalados y servicios habilitados."
log_info "  Cierra sesión y volvé a entrar para que tomen efecto:"
log_info "    - grupo docker (docker sin sudo)"
log_info "    - grupo libvirt (virt-manager sin sudo)"
log_info "    - zsh como shell por defecto"
log_info "  Después corré: ./validate_install.sh"
echo ""
