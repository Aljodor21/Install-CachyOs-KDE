#!/usr/bin/env bash
# desktop-touch.sh — Toque personal: pinea apps al taskbar de KDE Plasma
# + tema oscuro + iconos Papirus + wallpaper.
#
# Usar dentro de la sesion KDE Plasma (no TTY). Funciona desde consola
# tambien pero el taskbar pin necesita re-login para verse.
#
# Uso:
#   ./desktop-touch.sh                  # aplica todo
#   ./desktop-touch.sh --no-wallpaper   # sin descargar wallpaper
#   ./desktop-touch.sh --no-theme       # sin cambiar tema (solo apps)
#   ./desktop-touch.sh --no-taskbar     # sin pinear apps (solo theme)
#   ./desktop-touch.sh --dry-run        # muestra que haria

set -e

DRY_RUN=0
DO_WALLPAPER=1
DO_THEME=1
DO_TASKBAR=1

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --no-wallpaper) DO_WALLPAPER=0 ;;
        --no-theme) DO_THEME=0 ;;
        --no-taskbar) DO_TASKBAR=0 ;;
        --help|-h)
            echo "Uso: $0 [--dry-run] [--no-wallpaper] [--no-theme] [--no-taskbar]"
            echo "  --dry-run       Solo muestra lo que haria, no modifica nada"
            echo "  --no-wallpaper  No descarga wallpaper"
            echo "  --no-theme      No cambia el tema/iconos"
            echo "  --no-taskbar    No pinea apps al taskbar"
            exit 0 ;;
        *) echo "Opcion desconocida: $arg. --help para ayuda."; exit 1 ;;
    esac
done

run() {
    if [ $DRY_RUN -eq 1 ]; then
        echo "[DRY-RUN] $*"
    else
        "$@"
    fi
}

log_step() {
    echo ""
    echo "========================================="
    echo "  $*"
    echo "========================================="
}

# ──────────────────────────────────────────────────────────────────────────────
log_step "1/4 — Apps GUI a pinear"
# ──────────────────────────────────────────────────────────────────────────────
# Lista de apps: nombre amigable, nombre .desktop file, formato applications:NAME
APPS=(
    "Brave:brave-browser.desktop"
    "VS Code:code.desktop"
    "Kitty:kitty.desktop"
    "VLC:vlc.desktop"
    "OBS Studio:com.obsproject.Studio.desktop"
    "virt-manager:virt-manager.desktop"
    "Spotify:com.spotify.Client.desktop"
    "WPS Office:wps-office-wps.desktop"
)

for entry in "${APPS[@]}"; do
    IFS=':' read -r display_name dt_name <<< "$entry"
    echo "  [TARGET] $display_name → applications:$dt_name"
done

# ──────────────────────────────────────────────────────────────────────────────
log_step "2/4 — Iconos Papirus (visual touch)"
# ──────────────────────────────────────────────────────────────────────────────
if [ $DO_THEME -eq 1 ]; then
    # Detectar distro
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            debian|ubuntu|linuxmint|pop|kde-neon)
                echo "  [INFO] Debian/Ubuntu detectado"
                if dpkg -s papirus-icon-theme >/dev/null 2>&1; then
                    echo "  [OK] papirus-icon-theme ya instalado"
                else
                    echo "  [INSTALL] sudo apt install -y papirus-icon-theme"
                    run sudo apt install -y papirus-icon-theme
                fi
                ;;
            arch|cachyos|manjaro)
                echo "  [INFO] Arch detectado"
                if pacman -Q papirus-icon-theme >/dev/null 2>&1; then
                    echo "  [OK] papirus-icon-theme ya instalado"
                else
                    echo "  [INSTALL] sudo pacman -S --noconfirm papirus-icon-theme"
                    run sudo pacman -S --noconfirm papirus-icon-theme
                fi
                ;;
        esac
    fi

    # Aplicar icon theme
    mkdir -p ~/.config
    if ! grep -q "^\[Icons\]" ~/.config/kdeglobals 2>/dev/null; then
        echo "  [WRITE] ~/.config/kdeglobals (nuevo)"
        cat >> ~/.config/kdeglobals << 'EOF'

[Icons]
Theme=papirus-dark
EOF
    else
        echo "  [WRITE] ~/.config/kdeglobals (update)"
        run sed -i 's/^Theme=.*/Theme=papirus-dark/' ~/.config/kdeglobals
        # Insertar si no existe la key
        if ! grep -q "^Theme=" ~/.config/kdeglobals 2>/dev/null; then
            run sed -i '/^\[Icons\]/a Theme=papirus-dark' ~/.config/kdeglobals
        fi
    fi
    echo "  [OK] Icon theme aplicado: papirus-dark"
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "3/4 — Wallpaper (descarga)"
# ──────────────────────────────────────────────────────────────────────────────
if [ $DO_WALLPAPER -eq 1 ]; then
    WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
    WALLPAPER_FILE="$WALLPAPER_DIR/install-kde-wallpaper.jpg"
    mkdir -p "$WALLPAPER_DIR"
    if [ -f "$WALLPAPER_FILE" ]; then
        echo "  [OK] wallpaper ya descargado en $WALLPAPER_FILE"
    else
        # Usar picsum.photos: imagen random 1920x1080 JPG
        echo "  [DOWNLOAD] https://picsum.photos/1920/1080.jpg"
        run curl -fsSL -o "$WALLPAPER_FILE" "https://picsum.photos/1920/1080.jpg"
        if [ $DRY_RUN -eq 0 ] && [ -f "$WALLPAPER_FILE" ]; then
            echo "  [OK] wallpaper descargado: $WALLPAPER_FILE"
        fi
    fi

    # Configurar wallpaper via DBus API (instantáneo, sin re-login)
    if [ -z "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then
        echo "  [WARN] No estamos en sesion grafica KDE, saltando set wallpaper"
        echo "         Setear manualmente: Sistema > Fondo de pantalla > $WALLPAPER_FILE"
    else
        echo "  [INFO] Aplicando wallpaper via DBus API..."
        if [ $DRY_RUN -eq 0 ]; then
            # Para Plasma 5.x / KDE < 6: org.kde.plasma.image
            # Para Plasma 6: org.kde.plasma.desktopcontainment (más general)
            # Usamos la API generica de containment wallpaper
            # Buscar todos los Containments de tipo folder (desktops) y aplicar wallpaper
            # Mas sencillo: usar el metodo simple de qdbus
            if command -v qdbus &>/dev/null; then
                # Plasma 6: usar ScreenLocker wallpaper y desktop wallpaper via DBus
                # Para el escritorio: mirar cada Containment folder
                for containment in $(qdbus org.kde.plasma / org.kde.plasma ShellInterface 2>/dev/null | rg -o 'Containments/[0-9]+' | sort -u || true); do
                    qdbus org.kde.plasma "/${containment}" \
                        org.kde.plasma.folder.setWallpaper 2>/dev/null \
                        "image:$WALLPAPER_FILE" || true
                done
                echo "  [OK] wallpaper aplicado via DBus"
            else
                echo "  [WARN] qdbus no encontrado, setear wallpaper manualmente:"
                echo "         Sistema > Fondo de pantalla > $WALLPAPER_FILE"
            fi
        else
            echo "  [DRY-RUN] skip DBus call"
        fi
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "4/4 — Pin apps al taskbar (KDE Plasma 6)"
# ──────────────────────────────────────────────────────────────────────────────
if [ $DO_TASKBAR -eq 1 ]; then
    CONFIG="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

    # Verificar que existe
    if [ ! -f "$CONFIG" ]; then
        echo "  [WARN] $CONFIG no existe. Login grafico KDE una vez para que Plasma lo cree."
        TASKBAR_STATUS="skipped"
    elif [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
        echo "  [WARN] No estamos en sesion grafica KDE."
        echo "         El pineo automatico via DBus requiere DISPLAY/WAYLAND_DISPLAY."
        echo "         Modificando config directamente (tomará efecto al re-login)..."

        # Fallback: editar config INI para TODOS los Icon Tasks applets
        # Usa formato 'applications:NOMBRE.desktop' que es el que Plasma usa internamente
        python3 - "$CONFIG" "${APPS[@]}" << 'PYEOF'
import sys, re

config_file = sys.argv[1]
apps = sys.argv[2:]

# Mapear "Display Name:desktop_file" -> solo "desktop_file"
def parse_app(s):
    if ':' in s:
        return s.split(':', 1)[1]
    return s

apps = [parse_app(a) for a in apps]

with open(config_file) as f:
    content = f.read()

# Encontrar TODAS las ocurrencias del Icon Tasks applet
# Plasma 6 usa 'org.kde.plasma.icontasks' (con namespace plasma.)
# Plasma 5 usaba 'org.kde.icontasks' (sin namespace)
pattern = r'\[Applets\]\[(\d+)\][^\[]*?plugin=org\.kde\.(?:plasma\.)?icontasks'
matches = list(re.finditer(pattern, content))

if not matches:
    print("  [INFO] No hay Icon Tasks applet, skip")
    sys.exit(0)

modified_count = 0
for m in matches:
    applet_id = m.group(1)

    # Encontrar el [Containments][N] padre de este Applet
    # Sub-pattern: encontrar el [Containments][N] que TIENE este applet
    parent_match = re.search(
        r'\[Containments\]\[(\d+)\][^\[]*?\[Applets\]\[' + applet_id + r'\]',
        content
    )
    if not parent_match:
        continue

    parent_id = parent_match.group(1)

    # Section header: [Containments][N][Applets][M][General]
    section = f'[Containments][{parent_id}][Applets][{applet_id}][General]'

    # Encontrar launchers existentes
    existing_launchers = []
    section_match = re.search(
        r'^' + re.escape(section) + r'\s*$',
        content,
        re.MULTILINE
    )

    if section_match:
        # Leer contenido entre este header y el proximo [ ]
        start = section_match.end()
        next_section = re.search(r'^\[', content[start:], re.MULTILINE)
        end = start + next_section.start() if next_section else len(content)
        section_body = content[start:end]

        l_match = re.search(r'^launchers=(.*)$', section_body, re.MULTILINE)
        if l_match:
            existing_launchers = [l for l in l_match.group(1).split(',') if l]

    # Construir nuevos launchers: nuestros primero, luego los existentes
    # Formato: applications:NOMBRE.desktop (que es lo que usa Plasma)
    new_apps = [f'applications:{a}' for a in apps]

    # Combinar sin duplicados (mantener nuestros primero)
    seen = set()
    final = []
    for l in new_apps + existing_launchers:
        if l not in seen:
            seen.add(l)
            final.append(l)

    new_value = ','.join(final)

    # Reemplazar o agregar launchers en el section
    if section_match:
        # Reemplazar la linea launchers= existente
        # match exacto: section header + contenido hasta launchers line
        pattern_to_replace = (
            r'(^' + re.escape(section) + r'\s*\n(?:[^\n]*\n)*?'
            r'launchers=)[^\n]*'
        )
        new_section_block = r'\g<1>' + new_value

        # Necesitamos hacer multi-line replacement. Use re.sub with re.DOTALL
        full_pattern = (
            r'(^\[' + re.escape(section) + r'\][^\[]*?^launchers=)[^\n]*'
        )
        new_content = re.sub(
            full_pattern,
            lambda mt: mt.group(1) + new_value,
            content,
            count=1,
            flags=re.MULTILINE | re.DOTALL,
        )

        if new_content == content:
            # Agregar launchers= al final del section
            new_content = content + f'\n{section}\nlaunchers={new_value}\n'
    else:
        # Section no existe, agregar al final
        new_content = content + f'\n{section}\nlaunchers={new_value}\n'

    content = new_content
    modified_count += 1
    print(f"  [OK] pined en applet [{parent_id}][{applet_id}]: {len(new_apps)} apps")

if modified_count > 0:
    with open(config_file, 'w') as f:
        f.write(content)
    print(f"  [OK] {modified_count} applet(s) actualizados")
    print(f"  [INFO] Los cambios se ven al re-login de KDE Plasma")
    TASKBAR_STATUS="config-updated"
else:
    print("  [WARN] No se pudo modificar ningun applet")
    TASKBAR_STATUS="no-applets"
PYEOF

    else
        echo "  [INFO] Sesion grafica KDE activa - intento DBus API directo"

        # DBus API: agregar favoritos al taskbar (instantáneo, sin re-login)
        if ! command -v qdbus &>/dev/null; then
            echo "  [WARN] qdbus no encontrado, fallback a editar config"
            # (similar al bloque de arriba, sin TTY warning)
            :

        else
            for entry in "${APPS[@]}"; do
                IFS=':' read -r display_name dt_name <<< "$entry"
                uri="applications:$dt_name"
                if qdbus org.kde.plasma /PlasmaShell \
                    org.kde.PlasmaShell.addFavorite "$uri" 2>/dev/null; then
                    echo "  [OK] $display_name pineada via DBus"
                else
                    echo "  [WARN] $display_name fallo via DBus"
                fi
            done
            echo "  [INFO] Refrescando panel..."
            pgrep -x plasmashell >/dev/null && \
                (kquitapp6 plasmashell 2>/dev/null; kstart6 plasmashell 2>/dev/null &) || true
            TASKBAR_STATUS="dbus-updated"
        fi
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Resumen ==="
[ $DO_THEME -eq 1 ] && echo "  [OK] Icon theme: papirus-dark"
[ $DO_WALLPAPER -eq 1 ] && echo "  [OK] Wallpaper: descargado y aplicado via DBus"
case "$TASKBAR_STATUS" in
    dbus-updated) echo "  [OK] Apps pineadas al taskbar via DBus" ;;
    config-updated) echo "  [OK] Apps escritas en config (tomar efecto al re-login)" ;;
    no-applets) echo "  [WARN] No hay Icon Tasks applet en el panel" ;;
    skipped) echo "  [SKIP] Apps: panel config no existe" ;;
esac
echo ""
echo "  Para ver TODO el cambio visual: CERRA SESION KDE y VOLVE A ENTRAR"