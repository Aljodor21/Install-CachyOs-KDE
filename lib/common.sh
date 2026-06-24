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
