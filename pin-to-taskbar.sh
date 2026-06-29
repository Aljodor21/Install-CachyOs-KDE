#!/usr/bin/env bash
# pin-to-taskbar.sh — Pinea apps al taskbar de KDE Plasma usando DBus API.
# DEBE correrse desde dentro de una sesion KDE Plasma grafica activa
# (no desde TTY/SSH sin DISPLAY).
#
# Uso:
#   ./pin-to-taskbar.sh              # pinea los 8 apps del repo
#   ./pin-to-taskbar.sh --dry-run    # solo lista, no hace nada

set -e

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

# Sanity check: estamos en sesion KDE grafica?
if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    echo "ERROR: no hay sesion grafica KDE activa."
    echo "  Necesitas estar dentro de KDE Plasma (no en TTY/SSH)."
    echo "  Abrí una terminal DENTRO de KDE y volvé a correr esto."
    exit 1
fi

# Verificar que Plasma responde a DBus
if ! command -v qdbus &>/dev/null && ! command -v dbus-send &>/dev/null; then
    echo "ERROR: ni qdbus ni dbus-send encontrados. Instalá 'kde-cli-tools'."
    exit 1
fi

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

echo "=== Pineando apps al taskbar de KDE Plasma ==="
echo ""

PINNED=0
SKIPPED=0
NOT_FOUND=0

for entry in "${APPS[@]}"; do
    IFS=':' read -r display_name dt_name <<< "$entry"

    # Buscar el .desktop
    found=""
    for d in /var/lib/flatpak/exports/share/applications \
             /usr/share/applications \
             "$HOME/.local/share/applications"; do
        if [ -f "$d/$dt_name" ]; then
            found="$d/$dt_name"
            break
        fi
    done

    if [ -z "$found" ]; then
        echo "  [SKIP]  $display_name ($dt_name) — no encontrado"
        NOT_FOUND=$((NOT_FOUND + 1))
        continue
    fi

    uri="file://$found"

    if [ $DRY_RUN -eq 1 ]; then
        echo "  [DRY]   $display_name → $uri"
        continue
    fi

    # Llamar al DBus API
    if command -v qdbus &>/dev/null; then
        if qdbus org.kde.plasma /PlasmaShell \
                org.kde.PlasmaShell.addFavorite "$uri" 2>/dev/null; then
            echo "  [OK]    $display_name pineada al taskbar"
            PINNED=$((PINNED + 1))
        else
            echo "  [FAIL]  $display_name — DBus rechazo la llamada"
            SKIPPED=$((SKIPPED + 1))
        fi
    else
        # Fallback con dbus-send
        if dbus-send --session --type=method_call \
            --dest=org.kde.plasma /PlasmaShell \
            org.kde.PlasmaShell.addFavorite \
            "string:$uri" 2>/dev/null; then
            echo "  [OK]    $display_name pineada al taskbar"
            PINNED=$((PINNED + 1))
        else
            echo "  [FAIL]  $display_name — dbus-send fallo"
            SKIPPED=$((SKIPPED + 1))
        fi
    fi
done

echo ""
echo "=== Resultado ==="
echo "  Pineadas:  $PINNED"
echo "  Fallidas:  $SKIPPED"
echo "  No encontradas: $NOT_FOUND"

if [ $DRY_RUN -eq 1 ]; then
    echo ""
    echo "(Modo dry-run, no se pineo nada. Sacale --dry-run para pinear.)"
fi