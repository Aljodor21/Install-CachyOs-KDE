# Install-KDE — Post-install Toolkit (Arch + Debian)

Scripts y guías para configurar un entorno de desarrollo completo en KDE Plasma,
desde cero hasta listo para trabajar. **Funciona en familia Arch (CachyOS, Manjaro,
Endeavour, ...) y familia Debian (Debian puro, Ubuntu, Mint, Pop, KDE neon, ...)**.
El entry point detecta tu distro y aplica el script correspondiente.

> **Historial de cambios**: mirá [CHANGELOG.md](CHANGELOG.md) para ver todos los
> fixes y features por versión.

---

## Tabla de contenido

- [¿Qué hace?](#qué-hace)
- [Por qué este repo (vs AUR)](#por-qué-este-repo-vs-aur)
- [Prerequisitos](#prerequisitos)
- [Orden de uso](#orden-de-uso)
- [Qué instala](#qué-instala)
- [Toque visual](#toque-visual)
- [Configuración inicial automática (wizard)](#configuración-inicial-automática-wizard)
- [Archivos del repo](#archivos-del-repo)
- [Verificación final](#verificación-final)
- [Troubleshooting](#troubleshooting)

---

## ¿Qué hace?

Detecta tu distro desde `/etc/os-release` y aplica uno de dos scripts:

| Distro detectada | Script invocado | Gestor de paquetes |
|---|---|---|
| `cachyos`, `arch`, `manjaro`, `endeavouros`, `garuda`, ... | `install_arch.sh` | `pacman` + `yay` (AUR) |
| `debian`, `ubuntu`, `linuxmint`, `pop`, `kde-neon`, ... | `install_debian.sh` | `apt` + repos `.deb` externos firmados |

Después corre el wizard de configuración inicial (6 pasos) que te pregunta por
Git, GitHub CLI, Zsh default, NVM, Docker y Tailscale. (Claude y opencode son
siempre manuales — los corrés vos cuando quieras.)

Al final también aplica un **toque visual**: iconos Papirus + apps como
symlinks en `~/Desktop/` (visibles al login KDE) + wallpaper random de picsum.

---

## Por qué este repo (vs AUR)

AUR es mantenido por la comunidad, sin revisión centralizada. En 2024-2025
varios paquetes AUR fueron comprometidos para distribuir malware. Este repo:

- **En Debian**: cero AUR. Todo lo externo es un repo `.deb` upstream firmado con GPG
  (Brave, VS Code, Docker, Tailscale, OpenTabletDriver).
- **En Arch**: usa AUR solo para software que NO está en repos oficiales (Brave,
  VS Code, WPS, OTD). Todo lo demás viene de repos oficiales firmados.
- **Verificable**: cada repo externo tiene un `keyring` GPG en `/etc/apt/keyrings/`
  (Debian) o verificación de `makepkg` (Arch).
- **.zshrc condicional**: los aliases `update`/`install`/`remove` se setean al
  cargar el shell según la familia.
- **Touch visual out-of-the-box**: iconos Papirus, apps en `~/Desktop/`, fastfetch con
  colores y wallpaper random. Sin clicks manuales.

---

## Prerequisitos

- **Familia Arch**: CachyOS / Arch / Manjaro / Endeavour / Garuda con KDE Plasma instalado.
- **Familia Debian**: Debian 12 netinst (con task `kde-plasma`) **o** Ubuntu con KDE.
  Activar `non-free-firmware` durante el install para hardware moderno.
- Conexión a internet.
- Sesión iniciada como usuario normal (no root).
- Tu usuario con `sudo` (puede pedir password; el script avisa y continúa).

---

## Orden de uso

```bash
# 1. Clonar el repo
cd ~
git clone https://github.com/Aljodor21/Install-CachyOs-KDE.git
cd Install-CachyOs-KDE

# 2. Correr el install (auto-detecta distro e instala todo)
chmod +x *.sh
./install.sh

# 3. Al final corre el wizard (6 pasos) automaticamente
# Cada paso es opcional. Enter = sí.

# 4. El install.sh tambien aplica toque visual al final:
#    - Iconos Papirus-dark
#    - Symlinks de apps a ~/Desktop/ (visibles en el escritorio KDE)
#    - Wallpaper random de picsum.photos

# 5. Login KDE (recomendado: sesion X11 en VMs para mejor compatibilidad)

# 6. Validar
./validate_install.sh

# 7. Si hay FAIL, correr el fix
./fix_post_install.sh
```

> El install tarda **15-30 min** dependiendo de la conexión. No necesita
> intervención (excepto el password de sudo si no tenés NOPASSWD).

---

## Qué instala

### Desarrollo
- Git, GitHub CLI (`gh`)
- VS Code (repo firmado en Debian, AUR en Arch)
- Node.js via NVM (LTS)
- Python 3 + pip + venv
- Java JDK 17 (OpenJDK), con fallback a JDK 21 si 17 no está (Debian 13)
- Docker + Docker Compose plugin
- Angular CLI (npm)
- Claude Code CLI (npm)
- **opencode** (CLI agent, instalador oficial)

### Multimedia
- OBS Studio
- FFmpeg + codecs gstreamer
- VLC
- DaVinci Resolve ⚠️ — instalación manual (ver abajo)

### Productividad
- WPS Office (descarga `.deb` desde wps.com en Debian, AUR en Arch)
- Spotify (Flatpak)

### Sistema / Red
- **KVM/QEMU/libvirt/virt-manager** (reemplaza VirtualBox)
- Tailscale
- Bluetooth
- **Guest tools para VM**: `spice-vdagent` (clipboard, drag&drop, resolución dinámica), `qemu-guest-agent` (comunicación host↔VM)

### Hardware
- OpenTabletDriver (tablet Huion)

### Terminal / Entorno
- Zsh + Oh My Zsh + Powerlevel10k
- Plugins: autosuggestions, syntax-highlighting, history-substring-search
- Kitty con tema Tokyo Night, opacity 0.85, blur 30
- JetBrains Mono Nerd Font
- **fastfetch** con config lindo (colores por categoría, paleta al final)

---

## Toque visual

Al final del install, el script aplica automáticamente:

| Toque | Detalle |
|---|---|
| **Iconos Papirus-dark** | `papirus-icon-theme` instalado, theme en `~/.config/kdeglobals` |
| **Apps en el escritorio** | Symlinks de los 8 `.desktop` a `~/Desktop/`. KDE Plasma los renderiza como iconos automáticamente. Sin DBus, sin re-login. |
| **Wallpaper** | Imagen random 1920x1080 de `picsum.photos`, aplicada via DBus si hay sesión gráfica |
| **Fix de zsh_history** | Detecta y resetea `~/.zsh_history` corrupto |

Si querés pinear al taskbar ADEMÁS (no recomendado, frágil en Plasma 6 + Wayland):
- Click derecho en cada app del menú Kickoff → "Pin to Taskbar"

---

## Configuración inicial automática (wizard)

Al final del install corre `lib/post_install_config.sh` (también disponible como
`post-install-config` en `~/.local/bin/`). Son **6 pasos opcionales**:

| # | Paso | Qué hace |
|---|---|---|
| 1 | Git | Pregunta nombre+email y aplica `git config --global`. Setea `init.defaultBranch main`, `core.editor "code --wait"`, `pull.rebase true`, `push.autoSetupRemote true`, `~/.gitignore_global`. |
| 2 | GitHub CLI | `gh auth login --git-protocol ssh --web` (abre navegador) |
| 3 | Zsh default | `chsh -s $(which zsh)` |
| 4 | NVM default | `nvm alias default node && nvm use --lts` |
| 5 | Docker test | `docker run --rm hello-world` con `sg docker` |
| 6 | Tailscale | `sudo tailscale up` (abre navegador) |

**Claude Code CLI y opencode NO están en el wizard** — se instalan con el script
pero su auth es 100% manual: corré `claude` o `opencode` cuando quieras.

Cada paso:
- Es **opcional** (Enter = sí, `n` = skip).
- **Skip automático** si la herramienta no está instalada.
- **Skip automático** si ya está configurado (idempotente).
- Log en `~/.local/share/install-kde/config.log`.
- **Tabla resumen al final** con estado OK/PEND por paso (chequeado en vivo).

Para re-ejecutar después: `post-install-config`

---

## Archivos del repo

| Archivo | Descripción |
|---|---|
| `install.sh` | **Entry point.** Detecta distro y delega a `install_arch.sh` o `install_debian.sh`. Al final corre wizard + desktop-touch.sh. |
| `install_arch.sh` | Instala todo para familia Arch (pacman + yay). |
| `install_debian.sh` | Instala todo para familia Debian (apt + repos `.deb` firmados). |
| `desktop-touch.sh` | Toque visual: pinea apps al escritorio (symlinks), iconos Papirus, wallpaper. |
| `validate_install.sh` | Verifica instalación con 46 checks distro-aware. |
| `fix_post_install.sh` | Reinstala los ítems que fallaron. |
| `reset.sh` | Desinstalador con 11 categorías, `--dry-run`, `--yes`, `--no-backup`. |
| `lib/detect_distro.sh` | Detecta familia desde `/etc/os-release`. |
| `lib/common.sh` | Logging, helpers, `add_desktop_icons`, `fix_zsh_history_corruption`, checks. |
| `lib/packages.sh` | Tablas de paquetes por familia + AUR + repos externos. |
| `lib/post_install_config.sh` | Wizard de 6 pasos con tabla resumen. |
| `.zshrc` | Config de shell con plugins, aliases condicionales, carga lazy de NVM, fastfetch. |
| `kitty.conf` | Config del terminal Kitty con tema Tokyo Night, opacity 0.85, blur 30. |
| `~/.config/fastfetch/config.jsonc` | Config del system info (lo crea `desktop-touch.sh`). |
| `arch_cheatsheet.md` | Referencia rápida de comandos: pacman, yay, docker, git, KDE, SMB/NAS. |
| `debian_cheatsheet.md` | Equivalente para Debian: apt, dpkg, repos `.deb`, KVM/libvirt. |
| `checklist_instalacion.md` | Guía paso a paso con checklist de verificación. |
| `CHANGELOG.md` | Historial de cambios del repo. |
| `guia_vpn_nas.md` | Guía Tailscale + NAS por SMB. |
| `guia_pcsx2.md` | Guía emulador PS2. |

---

## Verificación final

```bash
./validate_install.sh
# Esperado: 46 OK, 0 FAIL, 1 WARN (DaVinci, que es instalación manual)
```

Comandos clave para probar:
```bash
docker ps              # Docker sin sudo (necesita re-login)
node --version         # Node.js activo
ng version             # Angular CLI
tailscale status       # VPN
virsh net-list --all   # libvirt red default
fastfetch              # system info con colores
ls ~/Desktop/          # 8 iconos de apps
```

---

## Troubleshooting

### `Tu usuario no tiene sudo NOPASSWD`
El script avisa y continúa. Si querés unattended, configurá:
```bash
sudo visudo
# Agregar:  tu_usuario ALL=(ALL) NOPASSWD: ALL
# O el grupo wheel: %wheel ALL=(ALL) NOPASSWD: ALL
```

### `Docker falla sin sudo después de instalar`
Cerrá sesión y volvé a entrar (el grupo `docker` se aplica al nuevo login).
Alternativa inmediata: `newgrp docker`.

### `libvirtd muestra "inactive" en validate`
Es normal — `libvirtd` usa socket activation. El daemon arranca on-demand
cuando algo se conecta al socket. Usá `virsh -c qemu:///system list` para
verificar que funciona. Los sockets `libvirtd.socket`, `-ro.socket` y
`-admin.socket` son los que importan.

### `Pinear apps al taskbar no funciona`
El pineo automático a taskbar de Plasma 6 + Wayland es frágil. Por eso
el install hace symlinks a `~/Desktop/` que es 100% confiable. Si querés
adicional pineo al taskbar: click derecho en cada app del menú Kickoff →
"Anclar a la barra de tareas" (manual, 30 segundos, siempre funciona).

### `zsh: corrupt history file /home/<user>/.zsh_history`
El install.sh lo resetea automáticamente. Si te pasa de nuevo: `> ~/.zsh_history`

### `Bluetooth no detecta dispositivos`
```bash
sudo systemctl enable --now bluetooth
bluetoothctl
  power on
  scan on
```

### `NVM no tiene el alias default`
```bash
source ~/.zshrc
nvm alias default node
```

### `WPS no descarga el .deb`
La URL puede haber cambiado. Descargá manualmente desde [wps.com](https://www.wps.com/office/linux/)
y `sudo apt install ./wps-office_*.deb`.

### `Spotify no se instala por flatpak`
```bash
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub com.spotify.Client
```

### `kquitapp6 plasmashell` rompe el rendering Wayland
No uses `kquitapp6` desde SSH. Para refrescar el panel: re-login completo
o `qdbus org.kde.KWin /Session logout 0 0 0 0 0` para logout limpio.

---

## Licencia

Mismo que el repo original. Uso personal.
