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

# Pinea apps GUI a la taskbar de KDE Plasma (panel).
# Modifica ~/.config/plasma-org.kde.plasma.desktop-appletsrc para que el
# Icon Tasks applet tenga estas apps como favoritas. No-op si no estamos
# en KDE Plasma o si el panel config no existe (ej: VM sin sesión gráfica
# iniciada).
#   pin_apps_to_taskbar
pin_apps_to_taskbar() {
    local config="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

    if [ ! -f "$config" ]; then
        log_info "Panel config no existe (sesión KDE no iniciada o KDE no es el DE). Skip pin a taskbar."
        return 0
    fi

    if ! cmd_exists python3; then
        log_warn "python3 no encontrado, no se puede pinear a taskbar"
        return 0
    fi

    python3 << 'PYEOF'
import os
import re
import sys

config_file = os.path.expanduser("~/.config/plasma-org.kde.plasma.desktop-appletsrc")
with open(config_file) as f:
    content = f.read()

# Encontrar el applet ID del Icon Tasks
m = re.search(r'\[Applets\]\[(\d+)\][^\[]*?plugin=org\.kde\.icontasks', content, re.DOTALL)
if not m:
    print("INFO: No hay Icon Tasks applet en el panel", file=sys.stderr)
    sys.exit(0)
applet_id = m.group(1)

# Encontrar el containment ID que contiene ese applet
m2 = re.search(r'\[Containments\]\[(\d+)\][^\[]*?\[Applets\]\[' + applet_id + r'\]', content, re.DOTALL)
if not m2:
    print("INFO: No hay containment para el applet", file=sys.stderr)
    sys.exit(0)
containment_id = m2.group(1)

# Apps a pinear (en orden: izq a der en taskbar)
apps = [
    ("brave-browser", "brave-browser.desktop"),
    ("code", "code.desktop"),
    ("kitty", "kitty.desktop"),
    ("vlc", "vlc.desktop"),
    ("obs", "obs.desktop"),
    ("virt-manager", "virt-manager.desktop"),
    ("Spotify", "com.spotify.Client.desktop"),
    ("WPS Office", "wps-office-wps.desktop"),
]

search_dirs = [
    "/var/lib/flatpak/exports/share/applications",
    "/usr/share/applications",
    os.path.expanduser("~/.local/share/applications"),
]

launchers = []
for name, dt in apps:
    found = None
    for d in search_dirs:
        p = os.path.join(d, dt)
        if os.path.exists(p):
            found = p
            break
    if found:
        launchers.append(f"file://{found}")
    else:
        print(f"  No encontrado: {dt}", file=sys.stderr)

if not launchers:
    print("INFO: No se encontraron apps para pinear", file=sys.stderr)
    sys.exit(0)

# Sección general del panel: 'Containments][N][Applets][M][General'
section_header = f"[Containments][{containment_id}][Applets][{applet_id}][General]"

# Extraer launchers existentes
existing = []
m3 = re.search(r'^' + re.escape(section_header) + r'\s*$', content, re.MULTILINE)
if m3:
    # Encontrar la sección y leer sus claves hasta el próximo [
    start = m3.end()
    next_section = re.search(r'^\[', content[start:], re.MULTILINE)
    end = start + next_section.start() if next_section else len(content)
    section_body = content[start:end]
    launchers_match = re.search(r'^launchers=(.*)$', section_body, re.MULTILINE)
    if launchers_match:
        existing = [l for l in launchers_match.group(1).split(',') if l]

# Combinar: nuestros primero, luego existentes, sin duplicados
seen = set()
final = []
for l in launchers + existing:
    if l not in seen:
        seen.add(l)
        final.append(l)

new_value = ",".join(final)

# Reemplazar launchers en la sección (o agregar si no existe)
if m3:
    # Reemplazar la línea launchers= existente
    new_content = re.sub(
        r'(^\[' + re.escape(section_header) + r'\s*\][^\[]*?^launchers=)[^\n]*',
        lambda m: m.group(1) + new_value,
        content,
        count=1,
        flags=re.MULTILINE | re.DOTALL,
    )
else:
    # Agregar la sección completa al final del archivo
    new_content = content + f"\n{section_header}\nlaunchers={new_value}\n"

with open(config_file, 'w') as f:
    f.write(new_content)

print(f"OK: {len(launchers)} apps pineadas ({', '.join(l.split('/')[-1].replace('.desktop','') for l in launchers)})")
PYEOF

    # Refrescar Plasma para que tome los cambios sin re-login
    if qdbus org.kde.plasma /PlasmaShell org.kde.PlasmaShell.refreshCurrentDesktop 2>/dev/null; then
        log_ok "Panel KDE refrescado"
    fi
}
