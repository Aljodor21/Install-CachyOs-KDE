#!/usr/bin/env bash
# install.sh — Entry point. Detecta la familia de distro y delega al script correcto.
# Este es el ÚNICO script que necesitás correr como usuario.
#
# Uso:
#   ./install.sh
#
# Detecta:
#   - Familia Arch (arch, cachyos, manjaro, ...) → install_arch.sh
#   - Familia Debian (debian, ubuntu, mint, pop, ...) → install_debian.sh
#   - Otras: aborta con mensaje

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Banner
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Install-KDE — Post-install toolkit                            ║"
echo "║  Auto-detecta Arch/Debian y aplica el install correspondiente ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Sourcear el detector
# shellcheck source=lib/detect_distro.sh
source "$SCRIPT_DIR/lib/detect_distro.sh"

# Mostrar detección
echo "  Distro detectada: $DISTRO_NAME"
echo "  ID:              $DISTRO_ID"
echo "  Familia:         $DISTRO_FAMILY"
echo "  Gestor:          $PKG_MGR"
echo ""

# Verificar que existe el script correspondiente
case "$DISTRO_FAMILY" in
    arch)
        if [ ! -x "$SCRIPT_DIR/install_arch.sh" ]; then
            echo "ERROR: install_arch.sh no existe o no es ejecutable."
            echo "  Corré: chmod +x $SCRIPT_DIR/install_arch.sh"
            exit 1
        fi
        # shellcheck source=install_arch.sh
        source "$SCRIPT_DIR/install_arch.sh"
        ;;
    debian)
        if [ ! -x "$SCRIPT_DIR/install_debian.sh" ]; then
            echo "ERROR: install_debian.sh no existe o no es ejecutable."
            echo "  Corré: chmod +x $SCRIPT_DIR/install_debian.sh"
            exit 1
        fi
        # shellcheck source=install_debian.sh
        source "$SCRIPT_DIR/install_debian.sh"
        ;;
    *)
        echo "ERROR: distro '$DISTRO_ID' no soportada por este repo."
        echo "  Familias conocidas:"
        echo "    Arch:    arch, cachyos, manjaro, endeavour, garuda, ..."
        echo "    Debian:  debian, ubuntu, mint, pop, kde-neon, ..."
        exit 1
        ;;
esac

# Wizard de configuración inicial (6 pasos locales, sin opencode/claude).
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Lanzando wizard de configuración inicial                     ║"
echo "║  (6 pasos: Git, GitHub, Zsh, NVM, Docker, Tailscale)         ║"
echo "║  Claude y opencode NO se incluyen: son siempre manuales     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

if [ -t 0 ]; then
    # shellcheck source=lib/post_install_config.sh
    source "$SCRIPT_DIR/lib/post_install_config.sh"
    run_post_install_wizard
else
    echo "[SKIP] No es TTY interactivo. Para configurar después, corré:"
    echo "       post-install-config"
    echo "       (o bash $SCRIPT_DIR/lib/post_install_config.sh)"
fi

# Instalar el wrapper 'post-install-config' en ~/.local/bin para re-ejecutar
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/post-install-config" << EOF
#!/usr/bin/env bash
# Wizard de configuración inicial post-install.
# Cubre: git user.name/email, GitHub CLI auth, zsh shell default,
#        NVM default, docker test, Tailscale connect.
# NO incluye Claude/opencode (esos son manuales: corré 'claude' / 'opencode').
exec bash "$SCRIPT_DIR/lib/post_install_config.sh" "\$@"
EOF
chmod +x "$HOME/.local/bin/post-install-config"

# Asegurar que ~/.local/bin esté en PATH
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo ""
    echo "OPCIONAL: para usar 'post-install-config' desde cualquier lado, agregá a tu ~/.bashrc o ~/.zshrc:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo ""
echo "Listo. Para validar la instalación:"
echo "  $SCRIPT_DIR/validate_install.sh"
echo ""
