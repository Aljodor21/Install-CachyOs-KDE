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

# Wizard de configuración inicial (si hay TTY)
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Lanzando wizard de configuración inicial                     ║"
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

# Instalar el wrapper en ~/.local/bin para re-ejecutar el wizard
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/post-install-config" << EOF
#!/usr/bin/env bash
# Wrapper para re-ejecutar el wizard de configuración inicial
exec bash "$SCRIPT_DIR/lib/post_install_config.sh" "\$@"
EOF
chmod +x "$HOME/.local/bin/post-install-config"

# Asegurar que ~/.local/bin esté en PATH
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo ""
    echo "NOTA: agregá esto a tu ~/.zshrc o ~/.bashrc:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo "Después podés correr: post-install-config"
fi

echo ""
echo "Listo. Para validar la instalación:"
echo "  $SCRIPT_DIR/validate_install.sh"
echo ""
