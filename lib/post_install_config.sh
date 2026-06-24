#!/usr/bin/env bash
# post_install_config.sh — Wizard interactivo para configurar apps recién instaladas.
# Se ejecuta automáticamente al final de install.sh y puede re-ejecutarse con
# `post-install-config` (instalado en ~/.local/bin/ por install.sh).
#
# Comportamiento:
#   - Cada paso es opcional. Enter = sí.
#   - Skip automático si la herramienta no está instalada.
#   - Skip automático si ya está configurado.
#   - En modo no-TTY (sin terminal), imprime qué hacer y sale.
#   - Log en ~/.local/share/install-kde/config.log
#   - Ctrl+C → sale limpio, log marca "interrupted at step N"

set +e
shopt -s expand_aliases 2>/dev/null

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Sourcear dependencias (common.sh es suficiente; no necesita detect_distro ni packages)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/common.sh"

# ──────────────────────────────────────────────────────────────────────────────
# Configuración del log
# ──────────────────────────────────────────────────────────────────────────────
LOG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/install-kde"
LOG_FILE="$LOG_DIR/config.log"

log_to_file() {
    mkdir -p "$LOG_DIR" 2>/dev/null
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

WIZARD_INTERRUPTED_AT=0
CURRENT_STEP=0

# Trap para Ctrl+C limpio
trap 'on_interrupt' INT TERM
on_interrupt() {
    echo ""
    log_warn "Wizard interrumpido en el paso $CURRENT_STEP"
    log_to_file "INTERRUPTED at step $CURRENT_STEP"
    WIZARD_INTERRUPTED_AT=$CURRENT_STEP
    exit 130
}

# ──────────────────────────────────────────────────────────────────────────────
# Banner
# ──────────────────────────────────────────────────────────────────────────────
print_banner() {
    cat << 'EOF'

╔════════════════════════════════════════════════════════════════╗
║   CONFIGURACIÓN INICIAL — Apps recién instaladas              ║
║   Enter = sí. Cada paso es opcional.                          ║
╚════════════════════════════════════════════════════════════════╝

EOF
}

# ──────────────────────────────────────────────────────────────────────────────
# Helpers específicos del wizard
# ──────────────────────────────────────────────────────────────────────────────

# Salta un paso mostrando por qué.
step_skip() {
    skip "$1"
    log_to_file "SKIP: $1"
}

# Marca un paso como exitoso.
step_done() {
    log_ok "$1"
    log_to_file "DONE: $1"
}

# Verifica si git ya tiene user.name y user.email configurados.
git_is_configured() {
    git config --global user.name &>/dev/null \
        && [ -n "$(git config --global user.name)" ] \
        && git config --global user.email &>/dev/null \
        && [ -n "$(git config --global user.email)" ]
}

# Verifica si gh está autenticado.
gh_is_authed() {
    gh auth status &>/dev/null
}

# Verifica si tailscale está autenticado y conectado.
tailscale_is_up() {
    tailscale status &>/dev/null && tailscale status --json 2>/dev/null | grep -q '"BackendState": "Running"'
}

# ──────────────────────────────────────────────────────────────────────────────
# Pasos del wizard
# ──────────────────────────────────────────────────────────────────────────────

step_git() {
    CURRENT_STEP=1
    log_step "Paso 1/8 — Git (nombre y correo)"

    if git_is_configured; then
        step_skip "Git ya está configurado ($(git config --global user.name) <$(git config --global user.email)>)"
        return 0
    fi

    if ! confirm "¿Configurar Git ahora?"; then
        step_skip "Git — cancelado por el usuario"
        return 0
    fi

    local name email
    name=$(prompt_value "Tu nombre para Git" "$(git config --global user.name 2>/dev/null || echo '')")
    email=$(prompt_value "Tu email para Git" "$(git config --global user.email 2>/dev/null || echo '')")

    if [ -z "$name" ] || [ -z "$email" ]; then
        step_skip "Git — nombre o email vacíos, no se configuró"
        return 0
    fi

    git config --global user.name "$name"
    git config --global user.email "$email"
    git config --global init.defaultBranch main
    git config --global core.editor "code --wait"
    git config --global pull.rebase true
    git config --global push.autoSetupRemote true

    # .gitignore_global básico
    local gi="$HOME/.gitignore_global"
    if [ ! -f "$gi" ]; then
        cat > "$gi" << 'GIEOF'
# Sistema
.DS_Store
Thumbs.db
desktop.ini
*~

# IDEs
.vscode/
.idea/
*.swp
*.swo

# Node
node_modules/
npm-debug.log
.npm/

# Python
__pycache__/
*.pyc
.venv/
venv/

# Misc
*.log
.env
.env.local
GIEOF
        git config --global core.excludesFile "$gi"
    fi

    step_done "Git configurado: $name <$email>"
}

step_github() {
    CURRENT_STEP=2
    log_step "Paso 2/8 — GitHub CLI (autenticación)"

    if ! cmd_exists gh; then
        step_skip "GitHub CLI (gh) no está instalado"
        return 0
    fi

    if gh_is_authed; then
        local ghuser
        ghuser=$(gh api user --jq .login 2>/dev/null)
        step_skip "GitHub CLI ya autenticado como $ghuser"
        return 0
    fi

    if ! confirm "¿Autenticar GitHub CLI ahora? (abre el navegador)"; then
        step_skip "GitHub CLI — cancelado por el usuario"
        return 0
    fi

    log_info "Abriendo navegador para autenticación..."
    if gh auth login --git-protocol ssh --web; then
        gh auth setup-git 2>/dev/null
        local ghuser
        ghuser=$(gh api user --jq .login 2>/dev/null)
        step_done "GitHub CLI autenticado como $ghuser"
    else
        log_warn "GitHub CLI no se autenticó. Corré 'gh auth login' cuando puedas."
    fi
}

step_zsh_default() {
    CURRENT_STEP=3
    log_step "Paso 3/8 — Zsh como shell por defecto"

    if [ "$SHELL" = "$(which zsh 2>/dev/null)" ]; then
        step_skip "Zsh ya es tu shell por defecto"
        return 0
    fi

    if ! confirm "¿Cambiar tu shell por defecto a zsh?"; then
        step_skip "Zsh default — cancelado por el usuario"
        return 0
    fi

    local zsh_path
    zsh_path=$(which zsh)
    if [ -z "$zsh_path" ]; then
        log_warn "zsh no está en PATH. Saltando."
        return 0
    fi

    # Asegurar que zsh esté en /etc/shells
    if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
        log_info "Agregando $zsh_path a /etc/shells..."
        echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    fi

    if chsh -s "$zsh_path"; then
        step_done "Shell cambiado a $zsh_path (efectivo al próximo login)"
    else
        log_warn "chsh falló. Corré 'sudo chsh -s $zsh_path $USER' manualmente."
    fi
}

step_nvm_default() {
    CURRENT_STEP=4
    log_step "Paso 4/8 — NVM (fijar Node LTS como default)"

    export NVM_DIR="$HOME/.nvm"
    if [ ! -s "$NVM_DIR/nvm.sh" ]; then
        step_skip "NVM no está instalado (no se encontró $NVM_DIR/nvm.sh)"
        return 0
    fi

    # shellcheck source=/dev/null
    source "$NVM_DIR/nvm.sh" 2>/dev/null

    if ! cmd_exists nvm; then
        step_skip "NVM no se pudo cargar"
        return 0
    fi

    if [ "$(nvm alias default 2>/dev/null)" != "node" ]; then
        if ! confirm "¿Fijar Node LTS como default de NVM?"; then
            step_skip "NVM default — cancelado por el usuario"
            return 0
        fi
        nvm install --lts &>/dev/null
        nvm alias default node &>/dev/null
        nvm use --lts &>/dev/null
        step_done "NVM default: $(nvm current) ($(node --version 2>/dev/null))"
    else
        step_skip "NVM default ya es 'node' ($(nvm current))"
    fi
}

step_docker() {
    CURRENT_STEP=5
    log_step "Paso 5/8 — Docker (verificar que funciona sin sudo)"

    if ! cmd_exists docker; then
        step_skip "Docker no está instalado"
        return 0
    fi

    if ! id -nG "$USER" | grep -qw "docker"; then
        log_warn "Tu usuario no está en el grupo 'docker'. Reinstala Docker o corré: sudo usermod -aG docker \$USER"
        return 0
    fi

    if ! confirm "¿Probar Docker con 'docker run hello-world'?"; then
        step_skip "Docker test — cancelado por el usuario"
        return 0
    fi

    # newgrp docker en subshell para activar el grupo
    if sg docker -c "docker run --rm hello-world" &>/dev/null; then
        step_done "Docker funciona sin sudo"
    else
        log_warn "docker run hello-world falló. Reintentá después de reloguear."
    fi
}

step_tailscale() {
    CURRENT_STEP=6
    log_step "Paso 6/8 — Tailscale (conectar a tu red)"

    if ! cmd_exists tailscale; then
        step_skip "Tailscale no está instalado"
        return 0
    fi

    if tailscale_is_up; then
        local ts_ip
        ts_ip=$(tailscale ip -4 2>/dev/null | head -1)
        step_skip "Tailscale ya está conectado (IP: $ts_ip)"
        return 0
    fi

    if ! confirm "¿Conectar Tailscale ahora? (abre el navegador)"; then
        step_skip "Tailscale — cancelado por el usuario"
        return 0
    fi

    log_info "Abriendo navegador para autenticación..."
    if sudo tailscale up; then
        local ts_ip
        ts_ip=$(tailscale ip -4 2>/dev/null | head -1)
        step_done "Tailscale conectado (IP: $ts_ip)"
    else
        log_warn "Tailscale no se conectó. Corré 'sudo tailscale up' cuando puedas."
    fi
}

step_claude() {
    CURRENT_STEP=7
    log_step "Paso 7/8 — Claude Code CLI (autenticación)"

    if ! cmd_exists claude; then
        step_skip "Claude Code CLI no está instalado"
        return 0
    fi

    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        step_skip "Claude Code CLI: ANTHROPIC_API_KEY ya está seteada en el entorno"
        return 0
    fi

    if ! confirm "¿Autenticar Claude Code CLI ahora? (abre el navegador)"; then
        step_skip "Claude — cancelado por el usuario"
        return 0
    fi

    log_info "Iniciando Claude (abrirá navegador)..."
    # claude sin args entra en modo interactivo. Mandamos /exit automático.
    if echo "/exit" | timeout 30 claude 2>/dev/null; then
        step_done "Claude Code CLI autenticado"
    else
        # Si falla el timeout, igual puede haberse autenticado. Verificamos config.
        if [ -f "$HOME/.claude.json" ] || [ -d "$HOME/.claude" ]; then
            step_done "Claude Code CLI: archivos de config presentes (asumimos auth OK)"
        else
            log_warn "Claude no se autenticó. Corré 'claude' manualmente."
        fi
    fi
}

step_opencode() {
    CURRENT_STEP=8
    log_step "Paso 8/8 — opencode (autenticación)"

    if ! cmd_exists opencode; then
        step_skip "opencode no está instalado"
        return 0
    fi

    # opencode guarda su config en ~/.local/share/opencode/ o ~/.config/opencode/
    # Si ya existe, asumimos autenticado.
    if [ -d "$HOME/.local/share/opencode" ] || [ -d "$HOME/.config/opencode" ]; then
        step_skip "opencode ya está configurado"
        return 0
    fi

    if ! confirm "¿Autenticar opencode ahora? (abre el navegador)"; then
        step_skip "opencode — cancelado por el usuario"
        return 0
    fi

    log_info "Iniciando opencode (abrirá navegador)..."
    if echo "/exit" | timeout 30 opencode 2>/dev/null; then
        step_done "opencode autenticado"
    else
        if [ -d "$HOME/.local/share/opencode" ] || [ -d "$HOME/.config/opencode" ]; then
            step_done "opencode: archivos de config presentes (asumimos auth OK)"
        else
            log_warn "opencode no se autenticó. Corré 'opencode' manualmente."
        fi
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Ejecución del wizard
# ──────────────────────────────────────────────────────────────────────────────

run_post_install_wizard() {
    log_to_file "===== wizard started ====="

    if [ ! -t 0 ]; then
        log_warn "Wizard requiere TTY interactivo. Para configurarlo después:"
        log_warn "  - Git:    git config --global user.name \"Tu Nombre\" && git config --global user.email \"tu@email\""
        log_warn "  - GitHub: gh auth login --git-protocol ssh --web"
        log_warn "  - Tailscale: sudo tailscale up"
        log_warn "  - Claude: claude"
        log_warn "  - opencode: opencode"
        log_to_file "SKIP: no TTY, wizard abortado"
        return 0
    fi

    print_banner

    step_git
    step_github
    step_zsh_default
    step_nvm_default
    step_docker
    step_tailscale
    step_claude
    step_opencode

    echo ""
    log_step "Resumen"
    log_info "Log completo: $LOG_FILE"
    log_to_file "===== wizard completed (OK: $PASS_COUNT, SKIP: $SKIP_COUNT, WARN: $WARN_COUNT) ====="

    # Resetear trap
    trap - INT TERM
}

# Si se ejecuta directamente (no sourceado), correr el wizard
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    run_post_install_wizard "$@"
fi
