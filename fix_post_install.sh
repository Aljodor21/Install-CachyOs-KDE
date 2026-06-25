#!/usr/bin/env bash
# fix_post_install.sh — Arregla los FAILs comunes que valida_install.sh detecta.
# Distro-aware: detecta Arch/Debian y adapta los fixes.
# Ejecutar como usuario normal, NO como root.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/detect_distro.sh
source "$SCRIPT_DIR/lib/detect_distro.sh"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Precondición
check_not_root || exit 1

echo ""
log_step "fix_post_install.sh — $DISTRO_NAME ($DISTRO_FAMILY)"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
log_step "Node.js / NVM"
# ──────────────────────────────────────────────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    log_warn "NVM no está instalado. Reinstalando..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
# shellcheck source=/dev/null
source "$NVM_DIR/nvm.sh"
log_info "Instalando Node LTS..."
nvm install --lts
nvm alias default node
log_ok "Node $(node --version) listo"

# ──────────────────────────────────────────────────────────────────────────────
log_step "npm globals — Angular CLI, Claude Code, opencode"
# ──────────────────────────────────────────────────────────────────────────────
if ! cmd_exists ng; then
    log_info "Instalando Angular CLI..."
    npm install -g @angular/cli
else
    log_ok "Angular CLI ya está instalado"
fi

if ! cmd_exists claude; then
    log_info "Instalando Claude Code CLI..."
    curl -fsSL https://claude.ai/install.sh | bash
else
    log_ok "Claude Code CLI ya está instalado"
fi

if ! cmd_exists opencode; then
    log_info "Instalando opencode..."
    curl -fsSL https://opencode.ai/install | bash
    # Recargar PATH para que el subshell actual lo vea
    if [ -d "$HOME/.opencode/bin" ]; then
        export PATH="$HOME/.opencode/bin:$PATH"
    fi
else
    log_ok "opencode ya está instalado"
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "Servicios systemd"
# ──────────────────────────────────────────────────────────────────────────────
for service in docker tailscaled; do
    if ! systemctl is-active --quiet "$service" 2>/dev/null; then
        log_warn "Servicio '$service' no está activo. Habilitando..."
        sudo systemctl enable --now "$service" || log_error "  No se pudo habilitar $service"
    else
        log_ok "Servicio '$service' activo"
    fi
done

# libvirtd y bluetooth usan socket activation: enable --now activa los sockets
# pero el daemon solo arranca cuando hay clientes. Para que el check is-active
# pase, también hacemos un start explicito.
for service in libvirtd bluetooth; do
    if ! systemctl is-active --quiet "$service" 2>/dev/null \
       && ! systemctl is-active --quiet "${service}.socket" 2>/dev/null; then
        log_warn "Servicio '$service' no está activo. Habilitando..."
        sudo systemctl enable --now "$service" || true
        sudo systemctl start "$service" 2>/dev/null || true
    else
        log_ok "Servicio '$service' activo (o socket activo)"
    fi
done

# ──────────────────────────────────────────────────────────────────────────────
log_step "Grupos del usuario (docker, libvirt)"
# ──────────────────────────────────────────────────────────────────────────────
for group in docker libvirt; do
    if ! id -nG "$USER" | grep -qw "$group"; then
        log_warn "Usuario no está en grupo '$group'. Agregando..."
        sudo usermod -aG "$group" "$USER"
    else
        log_ok "Usuario en grupo '$group'"
    fi
done
log_warn "Si acabamos de agregar a algún grupo, CERRÁ SESIÓN y volvé a entrar."

# ──────────────────────────────────────────────────────────────────────────────
log_step "Red libvirt 'default' (NAT para VMs)"
# ──────────────────────────────────────────────────────────────────────────────
if ! sudo virsh net-list --all 2>/dev/null | grep -q " default "; then
    log_info "Definiendo red libvirt 'default'..."
    sudo virsh net-define /usr/share/libvirt/networks/default.xml 2>/dev/null || true
    sudo virsh net-start default 2>/dev/null || true
    sudo virsh net-autostart default 2>/dev/null || true
else
    log_ok "Red libvirt 'default' ya existe"
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "Daemon reload (KDE / SDDM por si reinstalaste algo)"
# ──────────────────────────────────────────────────────────────────────────────
sudo systemctl daemon-reload

echo ""
log_step "Listo"
log_info "Ahora corré: ./validate_install.sh para verificar."
echo ""
