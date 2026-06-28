#!/usr/bin/env bash
# install_debian.sh — Instala y configura el entorno de desarrollo en familia Debian.
# Sourceado desde install.sh (que detecta la familia). NO ejecutar directamente.
#
# Familia soportada: debian, ubuntu, linuxmint, pop, elementary, zorin, kde-neon, ...
# Gestor: apt (sin AUR). Software externo se agrega por repos .deb firmados con GPG.
#
# Ejecutar como usuario normal (NO root). El script usa sudo internamente.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Sourcear dependencias
# shellcheck source=lib/detect_distro.sh
source "$SCRIPT_DIR/lib/detect_distro.sh"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/packages.sh
source "$SCRIPT_DIR/lib/packages.sh"

# Verificar que estamos en la familia correcta
if [ "$DISTRO_FAMILY" != "debian" ]; then
    log_error "Este script es para familia Debian, pero la distro detectada es '$DISTRO_ID' ($DISTRO_FAMILY)."
    log_error "Usa install_arch.sh en su lugar."
    exit 1
fi

# Precondiciones
check_not_root || exit 1
check_sudo_nopasswd || exit 1
check_internet || exit 1

# Detectar la versión de codename (bookworm, jammy, noble, ...)
if [ -z "${VERSION_CODENAME:-}" ]; then
    # fallback por si /etc/os-release no tiene VERSION_CODENAME
    case "$DISTRO_ID" in
        debian)        VERSION_CODENAME="bookworm" ;;
        ubuntu)        VERSION_CODENAME="jammy" ;;
        linuxmint)     VERSION_CODENAME="jammy" ;;
        pop)           VERSION_CODENAME="jammy" ;;
        kde-neon)      VERSION_CODENAME="noble" ;;
        *)             VERSION_CODENAME="bookworm" ;;
    esac
    export VERSION_CODENAME
fi

ARCH="$(dpkg --print-architecture)"

echo ""
log_step "Entorno detectado"
log_info "  Distro:    $DISTRO_NAME"
log_info "  Familia:   $DISTRO_FAMILY"
log_info "  Gestor:    $PKG_MGR"
log_info "  Codename:  $VERSION_CODENAME"
log_info "  Arch:      $ARCH"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
log_step "Actualizando sistema"
# ──────────────────────────────────────────────────────────────────────────────
sudo apt update
sudo apt upgrade -y

# ──────────────────────────────────────────────────────────────────────────────
log_step "Prereqs — curl, wget, ca-certificates, gnupg"
# ──────────────────────────────────────────────────────────────────────────────
# El netinst de Debian NO trae curl (viene wget). Como este script usa curl
# para bajar keyrings y binarios, lo instalamos acá si falta.
# También ca-certificates y gnupg son necesarios para verificar HTTPS y
# dearmorar las claves GPG de los repos externos.
PREREQ_PKGS=()
cmd_exists curl || PREREQ_PKGS+=(curl)
cmd_exists wget || PREREQ_PKGS+=(wget)
dpkg -s ca-certificates >/dev/null 2>&1 || PREREQ_PKGS+=(ca-certificates)
dpkg -s gnupg >/dev/null 2>&1 || PREREQ_PKGS+=(gnupg)
if [ ${#PREREQ_PKGS[@]} -gt 0 ]; then
    log_info "Instalando prereqs: ${PREREQ_PKGS[*]}"
    sudo apt install -y "${PREREQ_PKGS[@]}"
else
    log_ok "Prereqs ya instalados (curl, wget, ca-certificates, gnupg)"
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "Habilitando non-free-firmware (recomendado para hardware moderno)"
# ──────────────────────────────────────────────────────────────────────────────
# Debian separa main, contrib, non-free, non-free-firmware. En Ubuntu todo viene en 'main'
# y universe/multiverse. Solo en Debian hace falta este paso.
if [ "$DISTRO_ID" = "debian" ]; then
    if ! grep -q "non-free-firmware" /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null; then
        log_info "Agregando componentes non-free y non-free-firmware..."
        sudo tee /etc/apt/sources.list.d/non-free-firmware.list >/dev/null << EOF
deb http://deb.debian.org/debian ${VERSION_CODENAME} main contrib non-free non-free-firmware
deb http://deb.debian.org/debian ${VERSION_CODENAME}-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security ${VERSION_CODENAME}-security main contrib non-free non-free-firmware
EOF
        sudo apt update
    else
        log_ok "non-free-firmware ya está habilitado"
    fi
else
    log_info "En Ubuntu-derivados no hace falta configurar non-free-firmware (ya está en main/universe)"
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "Agregando repos .deb externos firmados con GPG"
# ──────────────────────────────────────────────────────────────────────────────
# Helper: agrega un repo .deb externo con keyring firmado.
#   add_deb_repo <name> <keyring_url> <keyring_path> <repo_line> [keyring_format]
#     <repo_line> es la línea completa de repo, ej:
#       "deb [arch=amd64 signed-by=K] https://download.docker.com/linux/debian bookworm stable"
#     <keyring_format> = "armored" (default, ASCII, requiere gpg --dearmor)
#                     = "binary" (binario GPG ya, no dearmor)
#   Genera:  /etc/apt/sources.list.d/<name>.list
#            /etc/apt/keyrings/<name>.gpg (perm 0644)
add_deb_repo() {
    local name="$1"
    local keyring_url="$2"
    local keyring_path="$3"
    local repo_line="$4"
    local keyring_format="${5:-armored}"

    local sources_file="/etc/apt/sources.list.d/${name}.list"

    # No-op si ya está configurado
    if [ -f "$sources_file" ] && [ -f "$keyring_path" ]; then
        log_ok "Repo '$name' ya está configurado"
        return 0
    fi

    log_info "Configurando repo '$name'..."

    # 1. Instalar keyring firmado
    sudo install -m 0755 -d "$(dirname "$keyring_path")"
    if [ "$keyring_format" = "binary" ]; then
        # Keyring ya viene en formato binario GPG, descargar directo
        if ! sudo curl -fsSL -o "$keyring_path" "$keyring_url" 2>/dev/null; then
            log_error "Falló la descarga del keyring binario para '$name' (URL: $keyring_url)"
            return 1
        fi
    else
        # Formato armored (ASCII), dearmor antes de guardar
        if ! curl -fsSL "$keyring_url" | sudo gpg --dearmor -o "$keyring_path" --yes 2>/dev/null; then
            log_error "Falló la descarga/dearmor del keyring para '$name' (URL: $keyring_url)"
            return 1
        fi
    fi
    sudo chmod 0644 "$keyring_path"

    # 2. Escribir sources.list con la línea ya armada
    echo "$repo_line" | sudo tee "$sources_file" >/dev/null
}

# Helper: devuelve "ubuntu" o "debian" según la familia, para construir URLs
# de los repos que tienen rama por distro.
repo_flavor() {
    case "$DISTRO_ID" in
        ubuntu|linuxmint|pop|kde-neon|zorin|elementary) echo "ubuntu" ;;
        *) echo "debian" ;;
    esac
}

# Construir y agregar cada repo externo
declare -A PKG_DEBIAN_REPO_BUILT  # para tracking

for entry in "${PKG_DEBIAN_EXTERNAL_REPOS[@]}"; do
    IFS='|' read -r name keyring_url keyring_path <<< "$entry"
    flavor=$(repo_flavor)
    keyring_format="armored"

    case "$name" in
        docker)
            keyring_url="https://download.docker.com/linux/${flavor}/gpg"
            repo_line="deb [arch=$ARCH signed-by=$keyring_path] https://download.docker.com/linux/${flavor} $VERSION_CODENAME stable"
            ;;
        brave)
            repo_line="deb [arch=$ARCH signed-by=$keyring_path] https://brave-browser-apt-release.s3.brave.com/ stable main"
            ;;
        vscode)
            # Microsoft cambió la URL del keyring de microsoft-archive-keyring.gpg a microsoft.asc
            keyring_url="https://packages.microsoft.com/keys/microsoft.asc"
            repo_line="deb [arch=$ARCH signed-by=$keyring_path] https://packages.microsoft.com/repos/code stable main"
            ;;
        tailscale)
            # Tailscale nuevo formato: keyring binario .noarmor.gpg con codename en URL
            keyring_url="https://pkgs.tailscale.com/stable/${flavor}/${VERSION_CODENAME}.noarmor.gpg"
            keyring_format="binary"
            repo_line="deb [signed-by=$keyring_path] https://pkgs.tailscale.com/stable/${flavor} $VERSION_CODENAME main"
            ;;
        opentabletdriver)
            # OTD ya no tiene repo apt — se instala vía tarball binario más abajo.
            log_info "OpenTabletDriver: ya no hay repo apt upstream. Se instala por tarball binario (ver bloque dedicado)."
            continue
            ;;
        *)
            log_warn "Repo externo desconocido: $name"
            continue
            ;;
    esac

    if add_deb_repo "$name" "$keyring_url" "$keyring_path" "$repo_line"; then
        PKG_DEBIAN_REPO_BUILT["$name"]=1
    else
        log_warn "Repo '$name' no se pudo configurar, sus paquetes van a fallar"
    fi
done

# Refrescar índice
sudo apt update

# ──────────────────────────────────────────────────────────────────────────────
log_step "Instalando paquetes de repos oficiales"
# ──────────────────────────────────────────────────────────────────────────────
apt_install() {
    local pkgs=()
    for p in "$@"; do
        [ -n "$p" ] && pkgs+=("$p")
    done
    if [ ${#pkgs[@]} -gt 0 ]; then
        sudo apt install -y "${pkgs[@]}"
    fi
}

# Helper: instalar un paquete probando varias alternativas en orden.
#   try_install <preferido> [alternativa1] [alternativa2] ...
# Útil para paquetes que cambian de nombre entre releases de Debian
# (libfuse2 → libfuse2t64, openjdk-17-jdk → openjdk-21-jdk).
try_install() {
    local pkg
    for pkg in "$@"; do
        [ -z "$pkg" ] && continue
        if apt-cache show "$pkg" >/dev/null 2>&1; then
            log_info "  Instalando $pkg..."
            if sudo apt install -y "$pkg" >/dev/null 2>&1; then
                log_ok "  $pkg instalado"
                return 0
            fi
        else
            log_info "  $pkg no disponible en los repos, probando siguiente..."
        fi
    done
    log_warn "  Ninguno disponible de: $*"
    return 1
}

apt_install $(
    for key in git github-cli python kitty flatpak vlc codecs base-devel zsh \
               cifs-utils screenshot audio system-tools bluetooth \
               gtk-theme ffmpeg obs fastfetch qemu libvirt ovmf; do
        pkg_for "$key"
    done
)

# Java JDK: openjdk-17-jdk existe en Debian 12 (bookworm) pero NO en Debian 13
# (trixie). Si no está, caemos a openjdk-21-jdk o default-jdk.
log_step "Java JDK (con fallback para Debian 13 / trixie)"
JAVA_PREFERRED=$(pkg_for java17)   # openjdk-17-jdk
try_install "$JAVA_PREFERRED" openjdk-21-jdk default-jdk

# libfuse: libfuse2 fue renombrado a libfuse2t64 en Debian 13 (transición 64-bit time_t).
log_step "libfuse2 (con fallback libfuse2t64 para trixie)"
LIBFUSE_PREFERRED=$(pkg_for libfuse)   # libfuse2
try_install "$LIBFUSE_PREFERRED" libfuse2t64

# ──────────────────────────────────────────────────────────────────────────────
log_step "Instalando paquetes de repos externos"
# ──────────────────────────────────────────────────────────────────────────────
apt_install $(pkg_from_repo docker) $(pkg_from_repo brave) $(pkg_from_repo vscode) $(pkg_from_repo tailscale)

# ──────────────────────────────────────────────────────────────────────────────
log_step "WPS Office — descarga .deb"
# ──────────────────────────────────────────────────────────────────────────────
# WPS no tiene repo apt. Descargamos el .deb más reciente de su sitio.
if ! cmd_exists wps; then
    log_info "Descargando WPS Office .deb..."
    wps_url="https://wdl1.pcfg.cache.wpscdn.com/wpsdl/wpsoffice/download/linux/11723/wps-office_11.1.0.11723.XA_amd64.deb"
    wps_tmp=$(mktemp -d)
    if curl -fsSL -o "$wps_tmp/wps.deb" "$wps_url"; then
        log_info "Instalando WPS Office..."
        sudo apt install -y "$wps_tmp/wps.deb"
    else
        log_warn "Descarga de WPS falló (URL puede haber cambiado). Descargá manualmente desde wps.com."
    fi
    rm -rf "$wps_tmp"
else
    log_ok "WPS Office ya está instalado"
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "JetBrains Mono Nerd Font — descarga a ~/.local/share/fonts"
# ──────────────────────────────────────────────────────────────────────────────
# Debian no tiene paquete para la versión Nerd. Descargamos el release zip.
font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
if [ ! -d "$font_dir" ] || [ -z "$(ls -A "$font_dir" 2>/dev/null)" ]; then
    log_info "Descargando JetBrainsMono Nerd Font..."
    font_tmp=$(mktemp -d)
    nerd_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    if curl -fsSL -L -o "$font_tmp/JetBrainsMono.zip" "$nerd_url"; then
        mkdir -p "$font_dir"
        unzip -q -o "$font_tmp/JetBrainsMono.zip" -d "$font_dir"
        fc-cache -fv >/dev/null 2>&1
        log_ok "JetBrains Mono Nerd Font instalada"
    else
        log_warn "Descarga de Nerd Font falló. Instalá manualmente desde github.com/ryanoasis/nerd-fonts."
    fi
    rm -rf "$font_tmp"
else
    log_ok "JetBrains Mono Nerd Font ya está en $font_dir"
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "Habilitando servicios"
# ──────────────────────────────────────────────────────────────────────────────
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

sudo systemctl enable --now tailscaled
# libvirtd: enable --now activa el socket pero el daemon solo se inicia
# on-demand. Para que arranque YA, hacemos un 'start' explícito además.
sudo systemctl enable --now libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket
sudo systemctl start libvirtd 2>/dev/null || true
sudo usermod -aG libvirt "$USER"

# Bluetooth
sudo systemctl enable --now bluetooth

# ──────────────────────────────────────────────────────────────────────────────
log_step "Virtualización KVM/QEMU — red default"
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
log_step "Terminal — Oh My Zsh + Powerlevel10k + plugins"
# ──────────────────────────────────────────────────────────────────────────────
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    log_ok "Oh My Zsh ya está instalado"
fi

if [ ! -d "$HOME/.oh-my-zsh/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "$HOME/.oh-my-zsh/themes/powerlevel10k"
else
    log_ok "Powerlevel10k ya está clonado"
fi

for plugin_pair in \
    "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions" \
    "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting" \
    "zsh-history-substring-search|https://github.com/zsh-users/zsh-history-substring-search"; do
    name="${plugin_pair%%|*}"
    url="${plugin_pair##*|}"
    if [ ! -d "$HOME/.oh-my-zsh/plugins/$name" ]; then
        git clone "$url" "$HOME/.oh-my-zsh/plugins/$name"
    else
        log_ok "Plugin $name ya está clonado"
    fi
done

# ──────────────────────────────────────────────────────────────────────────────
log_step "Aplicando configs (.zshrc, kitty.conf)"
# ──────────────────────────────────────────────────────────────────────────────
cp -f "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
mkdir -p "$HOME/.config/kitty"
cp -f "$SCRIPT_DIR/kitty.conf" "$HOME/.config/kitty/kitty.conf"

# Kitty como terminal por defecto
if grep -q "TerminalApplication" "$HOME/.config/kdeglobals" 2>/dev/null; then
    sed -i 's/TerminalApplication=.*/TerminalApplication=kitty/' "$HOME/.config/kdeglobals"
else
    mkdir -p "$HOME/.config"
    printf "\n[General]\nTerminalApplication=kitty\n" >> "$HOME/.config/kdeglobals"
fi
if cmd_exists update-alternatives; then
    sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/kitty 50 2>/dev/null || true
    sudo update-alternatives --set x-terminal-emulator /usr/bin/kitty 2>/dev/null || true
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "Node.js — NVM + LTS"
# ──────────────────────────────────────────────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
# shellcheck source=/dev/null
source "$NVM_DIR/nvm.sh"
nvm install --lts
nvm alias default node

# ──────────────────────────────────────────────────────────────────────────────
log_step "npm globals — Claude Code, Angular CLI, opencode"
# ──────────────────────────────────────────────────────────────────────────────
npm install -g @anthropic-ai/claude-code
npm install -g @angular/cli

# opencode: installer oficial
if ! cmd_exists opencode; then
    log_info "Instalando opencode..."
    curl -fsSL https://opencode.ai/install | bash
    if [ -d "$HOME/.opencode/bin" ]; then
        export PATH="$HOME/.opencode/bin:$PATH"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "Flatpak — Spotify"
# ──────────────────────────────────────────────────────────────────────────────
if ! cmd_exists flatpak; then
    log_warn "flatpak no está disponible, saltando Spotify."
else
    # Agregar Flathub si no está
    if ! flatpak remote-list 2>/dev/null | grep -q flathub; then
        log_info "Agregando Flathub remote..."
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi

    # Spotify: instalar con sudo. flatpak install necesita 'Deploy' en /var/lib/flatpak,
    # que sin polkit agent corriendo (típico en VMs/TTY) falla con:
    #   'Flatpak system operation Deploy not allowed for user'
    # En sesiones gráficas con KDE + polkit agent, podría andar sin sudo.
    # Después de la install inicial, el usuario puede instalar flatpaks normales sin sudo.
    if flatpak list 2>/dev/null | grep -q "com.spotify.Client"; then
        log_ok "Spotify (Flatpak) ya está instalado"
    else
        log_info "Instalando Spotify via flatpak (puede pedir sudo)..."
        if sudo flatpak install -y flathub com.spotify.Client 2>&1 | tail -15; then
            log_ok "Spotify instalado"
        else
            log_warn "No se pudo instalar Spotify. Reintentá manualmente después:"
            log_warn "  sudo flatpak install -y flathub com.spotify.Client"
        fi
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "OpenTabletDriver — instalación desde GitHub releases"
# ──────────────────────────────────────────────────────────────────────────────
# OTD ya no provee un repo apt upstream. Descargamos el tarball binario desde
# GitHub releases y lo dejamos en /opt/opentabletdriver. La activación del
# servicio de usuario se hace en el bloque siguiente.
OTD_BIN="/usr/local/bin/otd"
if [ -x "$OTD_BIN" ]; then
    log_ok "OpenTabletDriver ya instalado ($OTD_BIN)"
else
    log_info "Descargando OpenTabletDriver desde GitHub releases..."
    otd_tmp=$(mktemp -d)
    # Tomamos la versión más reciente del release "stable" de GitHub API
    otd_release_url=$(curl -fsSL https://api.github.com/repos/OpenTabletDriver/OpenTabletDriver/releases/latest \
        | grep -E '"browser_download_url".*linux-x64_binary.tar.gz"' \
        | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$otd_release_url" ]; then
        log_error "No se pudo obtener URL de release desde GitHub API"
    else
        log_info "Descargando $(basename "$otd_release_url")..."
        if curl -fsSL -o "$otd_tmp/otd.tar.gz" "$otd_release_url"; then
            log_info "Extrayendo a / (FHS-correcto: todo va a /usr/local/)..."
            # El tarball tiene un top-level 'opentabletdriver/' que strippeamos.
            # Asi /usr/local/bin/otd, /usr/local/share/applications/opentabletdriver.desktop, etc.
            sudo tar -xzf "$otd_tmp/otd.tar.gz" -C / --strip-components=1
            if [ -x "$OTD_BIN" ]; then
                log_ok "OpenTabletDriver instalado (binario: $OTD_BIN)"
                log_info "  Entrada KDE: opentabletdriver.desktop en /usr/local/share/applications/"
            else
                log_warn "Extracción completó pero $OTD_BIN no apareció"
                ls -la /usr/local/bin/otd* 2>/dev/null
            fi
            # El .service viene en /usr/local/lib/systemd/user/ (no estándar para systemd).
            # Lo copiamos a /etc/systemd/user/ para que systemd lo encuentre a nivel sistema.
            if [ -f /usr/local/lib/systemd/user/opentabletdriver.service ]; then
                sudo mkdir -p /etc/systemd/user
                sudo cp /usr/local/lib/systemd/user/opentabletdriver.service /etc/systemd/user/
                log_ok "systemd user service copiado a /etc/systemd/user/"
            fi
        else
            log_error "Descarga de OTD falló. Si tenés tablet Huion, instalá manualmente desde"
            log_error "  https://opentabletdriver.net/Wiki/Install/Linux"
        fi
    fi
    rm -rf "$otd_tmp"

    # Activar el servicio de usuario
    if [ -x "$OTD_BIN" ]; then
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable --now opentabletdriver.service 2>/dev/null \
            && log_ok "Servicio de usuario opentabletdriver habilitado e iniciado" \
            || log_info "Servicio creado pero no activado (corrélo manualmente: systemctl --user enable --now opentabletdriver.service)"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "DaVinci Resolve — recordatorio manual"
# ──────────────────────────────────────────────────────────────────────────────
echo ""
log_info "DaVinci Resolve requiere descarga manual:"
log_info "  1. libfuse2 / libfuse2t64 (ya instalado por este script)"
log_info "  2. Descargar .run desde https://www.blackmagicdesign.com/products/davinciresolve"
log_info "  3. chmod +x DaVinci_Resolve_*.run && ./DaVinci_Resolve_*.run"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
log_step "fastfetch — config personalizado"
# ──────────────────────────────────────────────────────────────────────────────
# Instala fastfetch y escribe una config linda para que aparezca al abrir terminal.
if cmd_exists fastfetch; then
    mkdir -p "$HOME/.config/fastfetch"
    if [ ! -f "$HOME/.config/fastfetch/config.jsonc" ]; then
        cat > "$HOME/.config/fastfetch/config.jsonc" << 'FFEOF'
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "type": "auto",
        "padding": {
            "top": 0,
            "left": 2,
            "right": 4
        }
    },
    "display": {
        "separator": " │ ",
        "color": {
            "title": "magenta",
            "key": "cyan",
            "value": "default"
        }
    },
    "modules": [
        "title",
        "separator",
        {
            "type": "os",
            "key": "   OS       "
        },
        {
            "type": "host",
            "key": "   HOST     "
        },
        {
            "type": "kernel",
            "key": "   KERNEL   "
        },
        {
            "type": "uptime",
            "key": "   UPTIME   "
        },
        {
            "type": "packages",
            "key": "   PKGS     "
        },
        {
            "type": "shell",
            "key": "   SHELL    "
        },
        {
            "type": "display",
            "key": "   DISPLAY  "
        },
        {
            "type": "de",
            "key": "   DE       "
        },
        {
            "type": "wm",
            "key": "   WM       "
        },
        {
            "type": "terminal",
            "key": "   TERM     "
        },
        "break",
        {
            "type": "cpu",
            "key": "   CPU      ",
            "keyColor": "yellow"
        },
        {
            "type": "gpu",
            "key": "   GPU      ",
            "keyColor": "yellow"
        },
        {
            "type": "memory",
            "key": "   MEM      ",
            "keyColor": "green"
        },
        {
            "type": "disk",
            "key": "   DISK     ",
            "keyColor": "green"
        },
        {
            "type": "local-ip",
            "key": "   IP       ",
            "keyColor": "magenta"
        },
        "break",
        {
            "type": "colors",
            "symbol": "circle"
        }
    ]
}
FFEOF
        log_ok "fastfetch config creado en ~/.config/fastfetch/config.jsonc"
    else
        log_info "fastfetch config ya existe, skip"
    fi
else
    log_warn "fastfetch no instalado (skip config)"
fi

# ──────────────────────────────────────────────────────────────────────────────
log_step "KDE Plasma — pineando apps a la taskbar"
# ──────────────────────────────────────────────────────────────────────────────
# Agrega Brave, VS Code, Kitty, VLC, OBS, virt-manager, Spotify y WPS al
# panel/taskbar de KDE Plasma. Idempotente: si ya estan pineadas, las deja.
# No-op si KDE no es el DE activo o si no hay sesion grafica iniciada.
pin_apps_to_taskbar

# ──────────────────────────────────────────────────────────────────────────────
log_step "Instalación completada"
# ──────────────────────────────────────────────────────────────────────────────
echo ""
log_ok "Paquetes instalados y servicios habilitados."
log_info "  Cierra sesión y volvé a entrar para que tomen efecto:"
log_info "    - grupo docker (docker sin sudo)"
log_info "    - grupo libvirt (virt-manager sin sudo)"
log_info "    - zsh como shell por defecto"
log_info "  Después corré: ./validate_install.sh"
echo ""
