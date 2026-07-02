#!/usr/bin/env bash
# common.sh — Funciones compartidas: logging, checks de precondición, helpers de color.
# Sourceado por install.sh, install_*.sh, validate_install.sh, fix_post_install.sh y el wizard.

# --- Colores (solo si la salida es TTY) ---
if [ -t 1 ]; then
    _C_RED='\033[0;31m'
    _C_GREEN='\033[0;32m'
    _C_YELLOW='\033[1;33m'
    _C_BLUE='\033[0;34m'
    _C_BOLD='\033[1m'
    _C_NC='\033[0m'
else
    _C_RED=''; _C_GREEN=''; _C_YELLOW=''; _C_BLUE=''; _C_BOLD=''; _C_NC=''
fi

# --- Logging ---
log_info()  { printf "${_C_BLUE}[INFO]${_C_NC}  %s\n"  "$*"; }
log_ok()    { printf "${_C_GREEN}[OK]${_C_NC}    %s\n" "$*"; }
log_warn()  { printf "${_C_YELLOW}[WARN]${_C_NC}  %s\n" "$*"; }
log_error() { printf "${_C_RED}[ERROR]${_C_NC} %s\n"   "$*" >&2; }
log_step()  { printf "\n${_C_BOLD}${_C_BLUE}=== %s ===${_C_NC}\n" "$*"; }

# --- Contadores (usados por validate_install.sh) ---
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0

ok()   { printf "${_C_GREEN}[OK]${_C_NC}    %s\n"   "$*"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { printf "${_C_RED}[FAIL]${_C_NC}  %s\n"     "$*"; FAIL_COUNT=$((FAIL_COUNT+1)); }
warn() { printf "${_C_YELLOW}[WARN]${_C_NC}  %s\n"  "$*"; WARN_COUNT=$((WARN_COUNT+1)); }
skip() { printf "${_C_BLUE}[SKIP]${_C_NC}  %s\n"    "$*"; SKIP_COUNT=$((SKIP_COUNT+1)); }

# --- Checks de precondición ---

# Verifica que se ejecute como usuario normal (no root).
check_not_root() {
    if [ "$(id -u)" -eq 0 ]; then
        log_error "Este script NO debe correrse como root."
        log_error "  Corréló como tu usuario normal. El script usa sudo internamente."
        return 1
    fi
    return 0
}

# Verifica si el usuario tiene sudo sin password. Si no, avisa pero deja continuar
# (los installs van a pausar para pedir password, pero funcionan).
check_sudo_nopasswd() {
    if sudo -n true 2>/dev/null; then
        log_ok "sudo NOPASSWD configurado para $USER"
        return 0
    fi

    # Si la variable de entorno INSECURE_SUDO_OK=1 está seteada, sigue silencioso.
    if [ "${INSECURE_SUDO_OK:-0}" = "1" ]; then
        log_warn "sudo requiere password. Continuando en modo interactivo (INSECURE_SUDO_OK=1)."
        return 0
    fi

    log_warn "Tu usuario no tiene sudo NOPASSWD. El install va a pausar para pedir password."
    log_warn "  Para unattended: configurar NOPASSWD en /etc/sudoers (visudo):"
    log_warn "    $USER ALL=(ALL) NOPASSWD: ALL"
    log_warn "  Para saltear este check: export INSECURE_SUDO_OK=1"
    return 0
}

# Verifica conectividad a internet.
check_internet() {
    if ! curl -fsSL -m 5 -o /dev/null https://github.com 2>/dev/null \
       && ! ping -c 1 -W 3 1.1.1.1 &>/dev/null; then
        log_error "Sin conectividad a internet. No se puede continuar."
        return 1
    fi
    log_ok "Conectividad a internet OK"
    return 0
}

# Verifica que la familia de distro ya fue detectada.
check_distro_detected() {
    if [ -z "${DISTRO_FAMILY:-}" ]; then
        log_error "DISTRO_FAMILY no está seteada. ¿Olvidaste sourcear lib/detect_distro.sh?"
        return 1
    fi
    return 0
}

# --- Helpers ---

# Pregunta al usuario sí/no. Default "sí" si la respuesta es vacía.
#   Uso: if confirm "¿Hacer X?"; then ...; fi
confirm() {
    local prompt="$1"
    local response
    # Si no es TTY, asumir "sí" (modo desatendido)
    if [ ! -t 0 ]; then
        return 0
    fi
    read -r -p "$(printf "${_C_BOLD}%s${_C_NC} [S/n] " "$prompt")" response
    case "${response:-s}" in
        [sSyY]|"") return 0 ;;
        [nN])      return 1 ;;
        *)         return 0 ;;
    esac
}

# Lee una variable con prompt. Si está vacía y se le pasa default, usa el default.
#   Uso: name=$(prompt_value "Tu nombre" "anonimo")
prompt_value() {
    local label="$1"
    local default="${2:-}"
    local value
    if [ -t 0 ]; then
        if [ -n "$default" ]; then
            read -r -p "$(printf "${_C_BOLD}%s${_C_NC} [$default]: " "$label")" value
            echo "${value:-$default}"
        else
            read -r -p "$(printf "${_C_BOLD}%s${_C_NC}: " "$label")" value
            echo "${value:-}"
        fi
    else
        echo "$default"
    fi
}

# Verifica si un comando existe.
cmd_exists() {
    command -v "$1" &>/dev/null
}

# Verifica si un grupo existe.
group_exists() {
    getent group "$1" &>/dev/null
}

# --- Checks de validación (usados por validate_install.sh) ---

# Verifica que un comando exista.
#   check_cmd "label visible" nombre_comando
check_cmd() {
    local label="$1"
    local cmd="$2"
    if cmd_exists "$cmd"; then
        ok "$label — $(command -v "$cmd")"
    else
        fail "$label — comando '$cmd' no encontrado"
    fi
}

# Verifica que un servicio systemd esté activo.
#   check_service "label" nombre_servicio
check_service() {
    local label="$1"
    local service="$2"
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        ok "$label — activo"
    else
        fail "$label — servicio '$service' no está corriendo"
    fi
}

# Verifica que un servicio esté funcional. Acepta socket-activated services
# (libvirtd, bluetooth, etc.) donde el daemon solo corre cuando hay clientes.
# Retorna 0 (success) si CUALQUIERA de los siguientes está activo:
#   - el servicio .service
#   - cualquiera de sus sockets asociados (.socket)
#   check_socket_service "label" servicio [socket1] [socket2] ...
check_socket_service() {
    local label="$1"
    local service="$2"
    shift 2
    local -a units=("$service" "$@")
    for unit in "${units[@]}"; do
        if systemctl is-active --quiet "$unit" 2>/dev/null; then
            ok "$label — activo (via $unit)"
            return 0
        fi
    done
    fail "$label — ni el servicio ni sus sockets están activos"
    return 1
}

# Verifica que el usuario esté en un grupo.
#   check_group "label" nombre_grupo
check_group() {
    local label="$1"
    local group="$2"
    if id -nG "$USER" 2>/dev/null | grep -qw "$group"; then
        ok "$label — usuario en grupo '$group'"
    else
        fail "$label — usuario NO está en grupo '$group' (reinicia sesión)"
    fi
}

# Verifica que un directorio exista.
#   check_dir "label" /ruta/al/dir
check_dir() {
    local label="$1"
    local dir="$2"
    if [ -d "$dir" ]; then
        ok "$label — $dir"
    else
        fail "$label — directorio no existe: $dir"
    fi
}


# Crea symlinks de .desktop files a ~/Desktop/ para que aparezcan como
# iconos en el escritorio de KDE Plasma. Mucho mas confiable que pinear
# al taskbar (que requiere DBus API + re-login + Plasma 6 + Wayland quirks).
#   add_desktop_icons
add_desktop_icons() {
    local desktop_dir="$HOME/Desktop"
    mkdir -p "$desktop_dir"

    # Apps: nombre amigable, nombre del .desktop file
    local apps=(
        "Brave:brave-browser.desktop"
        "VS Code:code.desktop"
        "Kitty:kitty.desktop"
        "VLC:vlc.desktop"
        "OBS Studio:com.obsproject.Studio.desktop"
        "virt-manager:virt-manager.desktop"
        "Spotify:com.spotify.Client.desktop"
        "WPS Office:wps-office-wps.desktop"
    )

    local search_dirs=(
        /var/lib/flatpak/exports/share/applications
        /usr/share/applications
        "$HOME/.local/share/applications"
    )

    local added=0
    local skipped=0

    for entry in "${apps[@]}"; do
        IFS=':' read -r display_name dt_name <<< "$entry"

        # Buscar el .desktop (Flatpak primero, luego sistema)
        local found=""
        for d in "${search_dirs[@]}"; do
            if [ -f "$d/$dt_name" ]; then
                found="$d/$dt_name"
                break
            fi
        done

        if [ -z "$found" ]; then
            log_info "  No encontrado: $display_name ($dt_name) — skip"
            skipped=$((skipped + 1))
            continue
        fi

        # Symlink (no copiar) para que se actualice si el .desktop cambia
        ln -sf "$found" "$desktop_dir/$dt_name"
        log_ok "  $display_name → $desktop_dir/$dt_name"
        added=$((added + 1))
    done

    log_ok "$added iconos en el escritorio, $skipped no encontrados"

    # Habilitar que el escritorio muestre iconos via DBus (si hay sesion)
    if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
        log_info "Habilitando iconos en el escritorio via DBus..."
        # Cambiar el 'DesktopContainment' para que muestre icons
        # (en vez de folder-view-only-preview)
        # Esto es via plasma session; si falla no importa
        if command -v qdbus &>/dev/null; then
            # Para todos los Containments tipo desktop folder
            for containment in $(qdbus org.kde.plasma / org.kde.plasma ShellInterface 2>/dev/null \
                | rg -o 'Containments/[0-9]+' | sort -u || true); do
                # Activar icons: inConfigureApplets=false, inFace=true
                qdbus org.kde.plasma "/${containment}" \
                    org.kde.plasma.faceless.showInFace true 2>/dev/null || true
            done
            log_ok "Iconos en escritorio habilitados"
        fi
    fi
}

# Resetea ~/.zsh_history si esta corrupto o si causo error al cargar.
# El error tipico es:
#   zsh: corrupt history file /home/<user>/.zsh_history
# Causa: Ctrl+C durante sesiones anteriores, escritura interrumpida, etc.
# Solucion: backup del archivo corrupto + crear uno vacio (zsh lo recrea).
#   fix_zsh_history_corruption
fix_zsh_history_corruption() {
    local hist_file="$HOME/.zsh_history"

    # Si no existe, no hay nada que arreglar (zsh lo crea vacio la 1ra vez)
    [ ! -f "$hist_file" ] && return 0

    # Intentar leer el historial sin cargar zsh. Si falla, esta corrupto.
    # Usamos 'fc -p' para cargar historial en modo read-only sin ejecutarlo,
    # pero eso requiere shell interactivo. Alternativa: validar con
    # strings/awk buscando inicio valido (: start_time: número).
    # El formato de zsh_history empieza con ': <unix_timestamp>:0;...'
    # Si la primera linea no matchea ese patron, probablemente esta corrupto.
    local first_line
    first_line=$(head -n 1 "$hist_file" 2>/dev/null)

    # Patron valido: empieza con ':' seguido de digitos y ':'
    if [[ "$first_line" =~ ^:[[:space:]]*[0-9]+: ]]; then
        # Esta sano, no tocar
        return 0
    fi

    # Si llegamos aca, el archivo esta corrupto (o no es un historial zsh).
    log_warn "  ~/.zsh_history corrupto o formato invalido. Backup + reset."
    mv "$hist_file" "$hist_file.bak.$(date +%s)" 2>/dev/null
    : > "$hist_file"  # crear archivo vacio
    log_ok "  ~/.zsh_history reseteado (backup en $hist_file.bak.<timestamp>)"
}
