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
    log_info "Pineando apps GUI a la taskbar de KDE Plasma..."

    # 1) Buscar .desktop files de las apps a pinear (siempre, para reportar)
    # NOTA: algunos paquetes tienen nombres .desktop distintos al binario.
    # Ej: obs-studio en Debian instala org.obsproject.Studio.desktop.
    local apps=(
        "Brave:brave-browser.desktop"
        "VS Code:code.desktop"
        "Kitty:kitty.desktop"
        "VLC:vlc.desktop"
        "OBS Studio:com.obsproject.Studio.desktop:org.obsproject.Studio.desktop:obs.desktop"
        "virt-manager:virt-manager.desktop"
        "Spotify:com.spotify.Client.desktop"
        "WPS Office:wps-office-wps.desktop"
    )

    local found_paths=()
    local found_names=()
    while IFS=':' read -r display_name dt_name dt_name_alt; do
        # Algunas apps tienen varios nombres de .desktop (ej OBS)
        local candidates=("$dt_name")
        [ -n "$dt_name_alt" ] && candidates+=("$dt_name_alt")

        local found=""
        for cand in "${candidates[@]}"; do
            for d in "/var/lib/flatpak/exports/share/applications" \
                     "/usr/share/applications" \
                     "$HOME/.local/share/applications"; do
                if [ -f "$d/$cand" ]; then
                    found="$d/$cand"
                    break 2
                fi
            done
        done
        if [ -n "$found" ]; then
            found_paths+=("$found")
            found_names+=("$display_name")
            log_ok "  Encontrado: $display_name → $found"
        else
            log_info "  No encontrado: $display_name (${candidates[*]}) — skip"
        fi
    done < <(printf '%s\n' "${apps[@]}")

    if [ ${#found_paths[@]} -eq 0 ]; then
        log_warn "No se encontraron .desktop files de las apps a pinear"
        return 0
    fi

    # 2) Decidir si pineamos o no
    local config="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

    # No estamos en sesion grafica?
    if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
        log_warn "No hay sesion grafica activa (DISPLAY y WAYLAND_DISPLAY vacios)."
        log_warn "  Las apps SI estan instaladas pero no se pueden pinear al taskbar."
        log_warn "  Iniciá sesion grafica KDE y corré ./install.sh de nuevo, o pinea manualmente"
        log_warn "  (click derecho en app → 'Anclar a la taskbar')."
        return 0
    fi

    if [ ! -f "$config" ]; then
        log_warn "Panel config no existe: $config"
        log_warn "  Posiblemente KDE Plasma nunca arranco graficamente en este usuario."
        log_warn "  Login grafico + re-login + correr ./install.sh de nuevo pinea las apps."
        return 0
    fi

    if ! cmd_exists python3; then
        log_warn "python3 no encontrado, no se puede pinear a taskbar"
        log_info "  Apps instaladas igual. Pinealas manualmente con click derecho."
        return 0
    fi

    # 3) Modificar el panel config via Python (fallback) + DBus API (primario)
    log_info "Pineando via DBus API de Plasma..."

    # Construir lista de URIs (file:// para path absoluto)
    local uris=()
    for p in "${found_paths[@]}"; do
        uris+=("file://$p")
    done

    local pinned_count=0

    # METODO 1 (PRIMARIO): DBus API - agrega favoritos directamente a Plasma
    # Funciona aunque el panel config tenga estructura rara. Plasma escribe
    # el cambio en disco y notifica al panel taskbar.
    if cmd_exists qdbus; then
        for uri in "${uris[@]}"; do
            if qdbus org.kde.plasma /PlasmaShell org.kde.PlasmaShell.addFavorite "$uri" 2>/dev/null; then
                pinned_count=$((pinned_count + 1))
            fi
        done
        if [ $pinned_count -gt 0 ]; then
            log_ok "  $pinned_count apps pineadas via qdbus"
        fi
    fi

    # METODO 2: dbus-send (si qdbus no esta, ej: kde-cli-tools no instalado)
    if [ $pinned_count -eq 0 ] && cmd_exists dbus-send; then
        for uri in "${uris[@]}"; do
            if dbus-send --session --type=method_call \
                --dest=org.kde.plasma /PlasmaShell \
                org.kde.PlasmaShell.addFavorite \
                "string:$uri" 2>/dev/null; then
                pinned_count=$((pinned_count + 1))
            fi
        done
        if [ $pinned_count -gt 0 ]; then
            log_ok "  $pinned_count apps pineadas via dbus-send"
        fi
    fi

    # METODO 3 (FALLBACK): modificar el archivo de config directamente
    if [ $pinned_count -eq 0 ]; then
        log_info "DBus API no funciono, modificando config directamente..."
        local launchers_list=""
        for p in "${found_paths[@]}"; do
            launchers_list="${launchers_list}file://$p,"
        done
        launchers_list="${launchers_list%,}"

        # Pasamos el array de apps al Python via argv (mas seguro que heredoc)
        local apps_arg="${found_paths[*]}"

        python3 - "$config" << PYEOF
import sys
import re
import os

config_file = sys.argv[1]
apps = sys.argv[2:]

with open(config_file) as f:
    content = f.read()

# Encontrar TODAS las ocurrencias de [Applets][N] con plugin icontasks/taskmanager
# Plasma puede tener varios panels, queremos modificar el que tiene el taskbar real
matches = list(re.finditer(r'\[Applets\]\[(\d+)\]\s*\n(?:[^\[]*\n)*?plugin=org\.kde\.plasma\.(icontasks|taskmanager)', content, re.MULTILINE))

if not matches:
    print("INFO: No hay Icon Tasks applet", file=sys.stderr)
    sys.exit(0)

# Para cada applet encontrado, encontrar su containment parent
launchers_to_add = [f"file://{p}" for p in apps]

modified = False
for m in matches:
    applet_id = m.group(1)

    # Buscar el [Containments][M] que contiene este applet
    # Strategy: encontrar [Containments][M][Applets][N] en el contenido
    parent = re.search(r'\[Containments\]\[(\d+)\]\s*\n(?:[^\[]*\n)*?\[Applets\]\[' + applet_id + r'\]', content, re.MULTILINE)
    if not parent:
        continue
    containment_id = parent.group(1)

    section_header = f"[Containments][{containment_id}][Applets][{applet_id}][General]"

    # Extraer launchers existentes
    existing = []
    m3 = re.search(r'^' + re.escape(section_header) + r'\s*$', content, re.MULTILINE)
    if m3:
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
    for l in launchers_to_add + existing:
        if l not in seen:
            seen.add(l)
            final.append(l)

    new_value = ",".join(final)

    # Reemplazar o agregar la linea launchers
    if m3:
        content = re.sub(
            r'(^\[' + re.escape(section_header) + r'\s*\][^\[]*?^launchers=)[^\n]*',
            lambda mt: mt.group(1) + new_value,
            content,
            count=1,
            flags=re.MULTILINE | re.DOTALL,
        )
    else:
        # Agregar la seccion General al final del archivo
        content += f"\n{section_header}\nlaunchers={new_value}\n"
    modified = True
    print(f"OK: modificado [{containment_id}][{applet_id}] con {len(launchers_to_add)} apps")

if not modified:
    print("WARN: No se pudo modificar ninguna seccion", file=sys.stderr)
    sys.exit(1)

with open(config_file, 'w') as f:
    f.write(content)
PYEOF
    fi

    # 4) Refrescar el panel KDE para que tome los cambios
    log_info "Refrescando panel KDE (puede parpadear ~2s)..."
    local refreshed=0

    # Metodo 1: plasmashell restart (MAS confiable, lee config de disco)
    if pgrep -x plasmashell &>/dev/null; then
        if cmd_exists kquitapp6 && cmd_exists kstart6; then
            log_info "Reiniciando plasmashell para que lea config..."
            (kquitapp6 plasmashell 2>/dev/null; kstart6 plasmashell 2>/dev/null &)
            refreshed=1
            log_ok "plasmashell reiniciado"
        fi
    fi

    # Metodo 2: qdbus refresh
    if [ $refreshed -eq 0 ] && cmd_exists qdbus; then
        if qdbus org.kde.plasma /PlasmaShell org.kde.PlasmaShell.refreshCurrentDesktop 2>/dev/null; then
            refreshed=1
            log_ok "Panel refrescado via qdbus"
        fi
    fi

    # Metodo 3: dbus-send
    if [ $refreshed -eq 0 ] && cmd_exists dbus-send; then
        if dbus-send --session --type=signal /PlasmaShell org.kde.PlasmaShell.refreshCurrentDesktop 2>/dev/null; then
            refreshed=1
            log_ok "Panel refrescado via dbus-send"
        fi
    fi

    if [ $refreshed -eq 0 ]; then
        log_warn "No pude refrescar el panel automaticamente."
        log_info "Para ver las apps en la taskbar:"
        log_info "  1. Cerrá sesión KDE y volvé a entrar (re-login)"
        log_info "  2. O manualmente: kquitapp6 plasmashell && kstart6 plasmashell &"
    fi

    log_ok "${#found_paths[@]} apps disponibles para pinear (ver taskbar)"
}
