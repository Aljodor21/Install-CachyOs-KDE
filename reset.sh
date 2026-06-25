#!/usr/bin/env bash
# reset.sh — Desinstalador de install-kde.
# Remueve todo lo que install.sh instaló: paquetes, repos, configs,
# servicios, fuentes, NVM, npm globals, OTD, Flatpak.
#
# Uso:
#   ./reset.sh                  # interactivo (Enter = sí por categoría)
#   ./reset.sh --yes            # unattended, todas las categorías "sí"
#   ./reset.sh --dry-run        # muestra qué haría, no toca nada
#   ./reset.sh --no-backup      # no respalda configs antes de borrar
#
# Por familia de distro detecta automáticamente (arch|deb).
# Solo remueve lo que el install puso. NO toca datos del usuario en ~/,
# /etc/fstab, /etc/samba/, ni el repo install-kde mismo.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/detect_distro.sh
source "$SCRIPT_DIR/lib/detect_distro.sh"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/packages.sh
source "$SCRIPT_DIR/lib/packages.sh"

# ──────────────────────────────────────────────────────────────────────────────
# Parse args
# ──────────────────────────────────────────────────────────────────────────────
YES=0
DRY_RUN=0
KEEP_BACKUP=1
BACKUP_DIR="$HOME/install-kde-backup-$(date +%Y%m%d-%H%M%S)"

print_usage() {
    cat << 'EOF'
Uso: ./reset.sh [opciones]

Opciones:
  --yes, -y         Automático: no pregunta, asume sí a todo
  --dry-run, -n     No ejecuta nada, solo muestra qué haría
  --no-backup       No crea backup antes de borrar configs
  --help, -h        Muestra esta ayuda

Categorías (en orden):
  1. Servicios systemd del sistema (docker, tailscaled, libvirtd, bluetooth)
  2. Servicio de usuario opentabletdriver
  3. Grupos (docker, libvirt)
  4. Shell por defecto (revierte zsh → bash)
  5. Repos externos /etc/apt/sources.list.d/ + keyrings (solo Debian)
  6. Paquetes del sistema (apt purge / pacman -Rns)
  7. Configs de usuario (~/.zshrc, oh-my-zsh, kitty, p10k, gitignore, etc.)
  8. Fuentes Nerd Font (~/.local/share/fonts/JetBrainsMonoNerdFont)
  9. NVM + npm globals + opencode + claude config
 10. Flatpak (Spotify)
 11. OTD tarball (/opt/opentabletdriver + systemd user service)

Antes de borrar configs, hace backup a ~/install-kde-backup-<timestamp>/.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y) YES=1; shift ;;
        --dry-run|-n) DRY_RUN=1; shift ;;
        --no-backup) KEEP_BACKUP=0; shift ;;
        --help|-h) print_usage; exit 0 ;;
        *) echo "Opción desconocida: $1"; print_usage; exit 1 ;;
    esac
done

# ──────────────────────────────────────────────────────────────────────────────
# Banner
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  reset.sh — Desinstalador de install-kde                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
log_info "Distro detectada: $DISTRO_NAME ($DISTRO_FAMILY)"
if [ "$DRY_RUN" = "1" ]; then
    log_info "Modo: DRY-RUN (no se modifica nada)"
elif [ "$YES" = "1" ]; then
    log_info "Modo: AUTOMÁTICO (--yes, no pregunta)"
else
    log_info "Modo: INTERACTIVO (Enter = sí por categoría)"
fi
if [ "$KEEP_BACKUP" = "1" ] && [ "$DRY_RUN" != "1" ]; then
    log_info "Backup: SÍ → $BACKUP_DIR"
else
    log_info "Backup: NO"
fi
echo ""

if [ "$DRY_RUN" != "1" ] && [ "$YES" != "1" ]; then
    echo "ATENCIÓN: este script borra paquetes del sistema, configs de usuario,"
    echo "          NVM, npm globals, OTD, repos externos, etc."
    echo ""
    if ! confirm "¿Continuar con el reset?"; then
        log_info "Cancelado por el usuario."
        exit 0
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

# run_cmd: ejecuta o solo muestra
run_cmd() {
    if [ "$DRY_RUN" = "1" ]; then
        echo "[DRY-RUN] $*"
    else
        "$@"
    fi
}

# ask_action: pregunta antes de una acción (skip si YES o DRY_RUN)
ask_action() {
    local description="$1"
    if [ "$YES" = "1" ] || [ "$DRY_RUN" = "1" ]; then
        log_info "$( [ "$DRY_RUN" = "1" ] && echo "(dry-run)" || echo "(auto)" ) $description"
        return 0
    fi
    if confirm "$description"; then
        return 0
    fi
    log_info "Saltado por el usuario."
    return 1
}

# backup_path: respalda path a $BACKUP_DIR (preserva estructura relativa)
backup_path() {
    local path="$1"
    if [ "$KEEP_BACKUP" != "1" ] || [ "$DRY_RUN" = "1" ]; then
        return
    fi
    if [ ! -e "$path" ]; then
        return
    fi
    mkdir -p "$BACKUP_DIR"
    local rel="${path#$HOME/}"
    local dest="$BACKUP_DIR/$rel"
    mkdir -p "$(dirname "$dest")"
    cp -r "$path" "$dest"
    log_ok "Backup: $path → $dest"
}

# ──────────────────────────────────────────────────────────────────────────────
# CATEGORÍA 1: Servicios systemd del sistema
# ──────────────────────────────────────────────────────────────────────────────
log_step "1/11 — Servicios systemd del sistema"
SERVICES_SYSTEM=(docker tailscaled libvirtd bluetooth)
for svc in "${SERVICES_SYSTEM[@]}"; do
    if systemctl list-unit-files "${svc}.service" &>/dev/null; then
        if ask_action "¿Deshabilitar y detener servicio '$svc'?"; then
            run_cmd sudo systemctl disable --now "$svc" || log_warn "No se pudo deshabilitar $svc"
        fi
    else
        log_info "Servicio '$svc' no instalado, skip."
    fi
done

# ──────────────────────────────────────────────────────────────────────────────
# CATEGORÍA 2: Servicio de usuario opentabletdriver
# ──────────────────────────────────────────────────────────────────────────────
log_step "2/11 — Servicio de usuario OpenTabletDriver"
OTD_USER_SERVICE="$HOME/.config/systemd/user/opentabletdriver.service"
if [ -f "$OTD_USER_SERVICE" ]; then
    if ask_action "¿Deshabilitar y detener opentabletdriver.service?"; then
        run_cmd systemctl --user disable --now opentabletdriver.service 2>/dev/null \
            || log_warn "No se pudo deshabilitar opentabletdriver"
        run_cmd systemctl --user daemon-reload
    fi
elif [ "$DISTRO_FAMILY" = "arch" ] && pacman -Qi opentabletdriver &>/dev/null; then
    if ask_action "¿Deshabilitar y detener opentabletdriver (paquete AUR)?"; then
        run_cmd systemctl --user disable --now opentabletdriver 2>/dev/null \
            || log_warn "No se pudo deshabilitar opentabletdriver"
    fi
else
    log_info "Servicio opentabletdriver no configurado, skip."
fi

# ──────────────────────────────────────────────────────────────────────────────
# CATEGORÍA 3: Grupos (docker, libvirt)
# ──────────────────────────────────────────────────────────────────────────────
log_step "3/11 — Grupos del usuario"
for group in docker libvirt; do
    if id -nG "$USER" 2>/dev/null | grep -qw "$group"; then
        if ask_action "¿Sacar al usuario '$USER' del grupo '$group'?"; then
            run_cmd sudo gpasswd -d "$USER" "$group"
        fi
    else
        log_info "Usuario no está en grupo '$group', skip."
    fi
done

# ──────────────────────────────────────────────────────────────────────────────
# CATEGORÍA 4: Default shell
# ──────────────────────────────────────────────────────────────────────────────
log_step "4/11 — Shell por defecto"
if [ -n "${SHELL:-}" ] && [[ "$SHELL" == *"zsh" ]]; then
    if ask_action "¿Revertir shell por defecto a bash?"; then
        bash_path=$(which bash)
        # Asegurar que bash esté en /etc/shells
        if ! grep -qx "$bash_path" /etc/shells 2>/dev/null; then
            run_cmd sudo tee -a /etc/shells >/dev/null <<< "$bash_path" || true
        fi
        run_cmd chsh -s "$bash_path"
        log_info "Nuevo shell: $bash_path (efectivo al próximo login)"
    fi
else
    log_info "Shell actual ($SHELL) no es zsh, skip."
fi

# ──────────────────────────────────────────────────────────────────────────────
# CATEGORÍA 5: Repos externos (solo Debian)
# ──────────────────────────────────────────────────────────────────────────────
if [ "$DISTRO_FAMILY" = "debian" ]; then
    log_step "5/11 — Repos externos /etc/apt/sources.list.d/"
    REPOS_TO_REMOVE=(docker brave vscode tailscale non-free-firmware)
    for repo in "${REPOS_TO_REMOVE[@]}"; do
        list_file="/etc/apt/sources.list.d/${repo}.list"
        keyring_file="/etc/apt/keyrings/${repo}.gpg"
        if [ -f "$list_file" ] || [ -f "$keyring_file" ]; then
            if ask_action "¿Borrar repo '$repo' (sources.list + keyring)?"; then
                run_cmd sudo rm -f "$list_file" "$keyring_file"
            fi
        else
            log_info "Repo '$repo' no configurado, skip."
        fi
    done
    if [ "$DRY_RUN" != "1" ]; then
        run_cmd sudo apt update
    else
        echo "[DRY-RUN] sudo apt update"
    fi
else
    log_step "5/11 — Repos externos (skip, no aplica a familia $DISTRO_FAMILY)"
fi

# ──────────────────────────────────────────────────────────────────────────────
# CATEGORÍA 6: Paquetes del sistema
# ──────────────────────────────────────────────────────────────────────────────
log_step "6/11 — Paquetes del sistema"

# Construir lista de paquetes a remover según familia
PKGS_TO_REMOVE=()
case "$DISTRO_FAMILY" in
    debian)
        for key in git github-cli python kitty flatpak vlc codecs base-devel zsh \
                   cifs-utils screenshot audio system-tools bluetooth \
                   gtk-theme ffmpeg obs qemu libvirt ovmf; do
            pkg=$(pkg_for "$key")
            [ -n "$pkg" ] && PKGS_TO_REMOVE+=($pkg)
        done
        # Java (cualquiera que haya quedado instalado)
        PKGS_TO_REMOVE+=(openjdk-17-jdk openjdk-21-jdk default-jdk)
        # libfuse (cualquier variante)
        PKGS_TO_REMOVE+=(libfuse2 libfuse2t64)
        # Paquetes de repos externos
        PKGS_TO_REMOVE+=(docker-ce docker-ce-cli containerd.io
                          docker-buildx-plugin docker-compose-plugin
                          brave-browser code tailscale)
        # WPS
        PKGS_TO_REMOVE+=(wps-office)
        ;;
    arch)
        for key in git github-cli python kitty flatpak vlc codecs base-devel zsh \
                   nerd-font cifs-utils screenshot audio system-tools bluetooth \
                   gtk-theme ffmpeg docker obs java17 qemu libvirt ovmf tailscale; do
            pkg=$(pkg_for "$key")
            [ -n "$pkg" ] && PKGS_TO_REMOVE+=($pkg)
        done
        # AUR packages (todos los que estaban en PKG_ARCH_AUR)
        PKGS_TO_REMOVE+=("${PKG_ARCH_AUR[@]}")
        ;;
esac

# Filtrar vacíos (por si pkg_for devuelve "")
PKGS_TO_REMOVE=("${PKGS_TO_REMOVE[@]// /}")

log_info "Total paquetes a remover: ${#PKGS_TO_REMOVE[@]}"
if [ ${#PKGS_TO_REMOVE[@]} -gt 0 ]; then
    # Mostrar lista resumida
    preview=$(printf "%s " "${PKGS_TO_REMOVE[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
    log_info "Lista: ${preview:0:200}$( [ ${#preview} -gt 200 ] && echo '...' )"
    echo ""
    if ask_action "¿Purgar ${#PKGS_TO_REMOVE[@]} paquetes del sistema? (operación lenta)"; then
        case "$DISTRO_FAMILY" in
            debian)
                run_cmd sudo apt purge -y "${PKGS_TO_REMOVE[@]}" 2>&1 | tail -30 || true
                run_cmd sudo apt autoremove --purge -y
                run_cmd sudo apt clean
                ;;
            arch)
                run_cmd sudo pacman -Rns --noconfirm "${PKGS_TO_REMOVE[@]}" 2>&1 | tail -30 || true
                orphans=$(pacman -Qdtq 2>/dev/null || true)
                if [ -n "$orphans" ]; then
                    log_info "Limpiando huérfanos: $orphans"
                    run_cmd sudo pacman -Rns --noconfirm $orphans 2>&1 | tail -20 || true
                fi
                ;;
        esac
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# CATEGORÍA 7: Configs de usuario (con backup)
# ──────────────────────────────────────────────────────────────────────────────
log_step "7/11 — Configs de usuario"
USER_CONFIGS=(
    "$HOME/.zshrc"
    "$HOME/.oh-my-zsh"
    "$HOME/.p10k.zsh"
    "$HOME/.gitignore_global"
    "$HOME/.config/kitty"
    "$HOME/.local/share/install-kde"
    "$HOME/.local/bin/post-install-config"
)
for cfg in "${USER_CONFIGS[@]}"; do
    if [ -e "$cfg" ]; then
        if ask_action "¿Borrar $cfg? (con backup)"; then
            backup_path "$cfg"
            run_cmd rm -rf "$cfg"
        fi
    else
        log_info "No existe $cfg, skip."
    fi
done

# kdeglobals: revertir la línea TerminalApplication si la modificamos
if [ -f "$HOME/.config/kdeglobals" ] && grep -q "TerminalApplication=kitty" "$HOME/.config/kdeglobals" 2>/dev/null; then
    if ask_action "¿Revertir 'TerminalApplication=kitty' en ~/.config/kdeglobals?"; then
        backup_path "$HOME/.config/kdeglobals"
        run_cmd sed -i '/TerminalApplication=kitty/d' "$HOME/.config/kdeglobals"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# CATEGORÍA 8: Fuentes Nerd Font
# ──────────────────────────────────────────────────────────────────────────────
log_step "8/11 — Fuentes Nerd Font"
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
if [ -d "$FONT_DIR" ]; then
    if ask_action "¿Borrar fuentes JetBrains Mono Nerd Font?"; then
        run_cmd rm -rf "$FONT_DIR"
        run_cmd fc-cache -fv >/dev/null 2>&1
        log_ok "Font cache actualizado"
    fi
else
    log_info "Fuentes no encontradas, skip."
fi

# ──────────────────────────────────────────────────────────────────────────────
# CATEGORÍA 9: NVM, npm globals, opencode, claude
# ──────────────────────────────────────────────────────────────────────────────
log_step "9/11 — Node / NVM / npm globals / opencode / claude"

# NVM
if [ -d "$HOME/.nvm" ]; then
    if ask_action "¿Borrar ~/.nvm/ (NVM y todas las versiones de Node)?"; then
        backup_path "$HOME/.nvm"
        run_cmd rm -rf "$HOME/.nvm"
    fi
else
    log_info "NVM no instalado, skip."
fi

# npm globals: solo si hay npm disponible
NPM_CMD=""
if cmd_exists npm; then
    NPM_CMD="npm"
elif [ -x "$HOME/.nvm/versions/node"/*/bin/npm ] 2>/dev/null; then
    # NVM aún existe pero PATH no lo tiene cargado
    NPM_CMD=$(ls -t "$HOME/.nvm/versions/node"/*/bin/npm 2>/dev/null | head -1)
fi

if [ -n "$NPM_CMD" ]; then
    for npm_pkg in @anthropic-ai/claude-code @angular/cli; do
        if $NPM_CMD list -g "$npm_pkg" --depth=0 2>/dev/null | grep -q "$npm_pkg"; then
            if ask_action "¿Desinstalar npm global '$npm_pkg'?"; then
                run_cmd $NPM_CMD uninstall -g "$npm_pkg"
            fi
        fi
    done
fi

# opencode (instalado por curl installer oficial en ~/.opencode/bin/)
if [ -x "$HOME/.opencode/bin/opencode" ] || [ -d "$HOME/.opencode" ]; then
    if ask_action "¿Borrar opencode (~/.opencode/)?"; then
        backup_path "$HOME/.opencode"
        run_cmd rm -rf "$HOME/.opencode"
        run_cmd rm -rf "$HOME/.config/opencode"
    fi
else
    log_info "opencode no instalado, skip."
fi

# Claude config
if [ -d "$HOME/.claude" ] || [ -f "$HOME/.claude.json" ]; then
    if ask_action "¿Borrar configs de Claude (~/.claude, ~/.claude.json)?"; then
        backup_path "$HOME/.claude"
        backup_path "$HOME/.claude.json"
        run_cmd rm -rf "$HOME/.claude" "$HOME/.claude.json"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# CATEGORÍA 10: Flatpak (Spotify)
# ──────────────────────────────────────────────────────────────────────────────
log_step "10/11 — Flatpak (Spotify)"
if cmd_exists flatpak && flatpak list 2>/dev/null | grep -q "com.spotify.Client"; then
    if ask_action "¿Desinstalar Spotify (Flatpak)?"; then
        run_cmd flatpak uninstall -y com.spotify.Client
    fi
else
    log_info "Spotify Flatpak no instalado, skip."
fi

# ──────────────────────────────────────────────────────────────────────────────
# CATEGORÍA 11: OTD tarball install (solo Debian)
# ──────────────────────────────────────────────────────────────────────────────
log_step "11/11 — OpenTabletDriver (tarball install)"
OTD_INSTALLED=0
if [ -d "/opt/opentabletdriver" ] || [ -x "/usr/local/bin/otd" ]; then
    OTD_INSTALLED=1
fi

if [ "$OTD_INSTALLED" = "1" ]; then
    if ask_action "¿Borrar OpenTabletDriver (/opt/opentabletdriver, symlink, service)?"; then
        # Detener servicio si aún está activo
        if [ -f "$HOME/.config/systemd/user/opentabletdriver.service" ]; then
            run_cmd systemctl --user disable --now opentabletdriver.service 2>/dev/null || true
            run_cmd rm -f "$HOME/.config/systemd/user/opentabletdriver.service"
            run_cmd systemctl --user daemon-reload
        fi
        run_cmd sudo rm -rf /opt/opentabletdriver
        run_cmd sudo rm -f /usr/local/bin/otd
        log_ok "OpenTabletDriver desinstalado"
    fi
else
    log_info "OpenTabletDriver no instalado vía tarball, skip."
fi

# ──────────────────────────────────────────────────────────────────────────────
# Resumen
# ──────────────────────────────────────────────────────────────────────────────
echo ""
log_step "Reset completado"
echo ""
if [ "$DRY_RUN" = "1" ]; then
    log_info "Esto fue un DRY-RUN. Nada se modificó."
    log_info "Para ejecutar de verdad: ./reset.sh --yes"
else
    if [ -d "$BACKUP_DIR" ] && [ -n "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        log_ok "Backups guardados en: $BACKUP_DIR"
    fi
    log_ok "Reset completo."
    echo ""
    log_info "Verificá con: ./validate_install.sh"
    log_info "Para reinstalar: ./install.sh"
fi
echo ""
