# Install-KDE — Post-install Toolkit (Arch + Debian)

Scripts y guías para configurar un entorno de desarrollo completo en KDE Plasma,
desde cero hasta listo para trabajar. **Funciona en familia Arch (CachyOS, Manjaro,
Endeavour, ...) y familia Debian (Debian puro, Ubuntu, Mint, Pop, KDE neon, ...)**.
El entry point detecta tu distro y aplica el script correspondiente.

---

## Tabla de contenido

- [¿Qué hace?](#qué-hace)
- [Por qué este repo (vs AUR)](#por-qué-este-repo-vs-aur)
- [Prerequisitos](#prerequisitos)
- [Orden de uso](#orden-de-uso)
- [Qué instala](#qué-instala)
- [Configuración inicial automática (wizard)](#configuración-inicial-automática-wizard)
- [Pasos manuales](#pasos-manuales)
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
# 1. Clonar o copiar los archivos a tu home
cd ~
git clone https://github.com/Aljodor21/Install-CachyOs-KDE.git
cd Install-CachyOs-KDE

# 2. Correr el entry point — detecta distro e instala
chmod +x install.sh install_arch.sh install_debian.sh validate_install.sh fix_post_install.sh
./install.sh

# 3. (Inmediato) Wizard de configuración inicial
# El script lo lanza automáticamente al final.
# Cada paso es opcional. Enter = sí.

# 4. Reiniciar sesión
# (Importante para grupos docker/libvirt y shell zsh)

# 5. Validar
./validate_install.sh

# 6. Si hay FAIL, correr el fix
./fix_post_install.sh
```

> El install tarda **15-30 min** dependiendo de la conexión. No necesita
> intervención (excepto el password de sudo si no tenés NOPASSWD).

---

## Qué instala

### Desarrollo
- Git, GitHub CLI (`gh`)
- VS Code
- Node.js via NVM (LTS)
- Python 3 + pip + venv
- Java JDK 17 (OpenJDK)
- Docker + Docker Compose plugin
- Angular CLI
- Claude Code CLI
- **opencode** (CLI agent)

### Multimedia
- OBS Studio
- FFmpeg + codecs
- VLC
- DaVinci Resolve ⚠️ — instalación manual (ver abajo)

### Productividad
- WPS Office (descarga .deb en Debian, AUR en Arch)
- Spotify (Flatpak)
- Brave Browser

### Sistema / Red
- **KVM/QEMU/libvirt/virt-manager** (reemplaza VirtualBox)
- Tailscale
- Bluetooth

### Hardware
- OpenTabletDriver (tablet Huion)

### Terminal / Entorno
- Zsh + Oh My Zsh + Powerlevel10k
- Plugins: autosuggestions, syntax-highlighting, history-substring-search
- Kitty con tema Tokyo Night
- JetBrains Mono Nerd Font

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

Claude Code CLI y opencode **no están en el wizard** — se instalan con el script
pero su auth es 100% manual: corré `claude` o `opencode` cuando quieras.

Cada paso:
- Es **opcional** (Enter = sí, `n` = skip).
- **Skip automático** si la herramienta no está instalada.
- **Skip automático** si ya está configurado (idempotente).
- Log en `~/.local/share/install-kde/config.log`.

Para re-ejecutar después: `post-install-config`

---

## Pasos manuales (no se pueden automatizar)

### Teclado con ñ
KDE → Ajustes del sistema → Teclado → Distribuciones
- Distribución: `English (US)`
- Variante: `English (intl., with dead keys)`

Con `us intl`: `~ + n` = ñ | `' + vocal` = tilde | `" + u` = ü

### DaVinci Resolve
| Familia | Comando |
|---|---|
| Arch | `sudo pacman -S --needed fuse2` |
| Debian | `sudo apt install libfuse2` (ya lo instala el script) |

Después descargar `.run` desde [blackmagicdesign.com](https://www.blackmagicdesign.com/products/davinciresolve):
```bash
chmod +x DaVinci_Resolve_*.run
./DaVinci_Resolve_*.run
```

### Tablet Huion
El servicio de usuario se habilita automáticamente. Abrir **OpenTabletDriver**
desde el menú de apps para configurar los botones.

### VPN + NAS
Ver [`guia_vpn_nas.md`](./guia_vpn_nas.md) para conectar Tailscale y montar el
NAS por SMB con automontaje.

### Monitores
KDE → Ajustes del sistema → Pantallas

---

## Archivos del repo

| Archivo | Descripción |
|---|---|
| `install.sh` | **Entry point.** Detecta distro y delega a `install_arch.sh` o `install_debian.sh`. |
| `install_arch.sh` | Instala todo para familia Arch (pacman + yay). |
| `install_debian.sh` | Instala todo para familia Debian (apt + repos `.deb` firmados). |
| `validate_install.sh` | Verifica instalación con checks distro-aware. Muestra OK/FAIL/WARN/SKIP. |
| `fix_post_install.sh` | Reinstala los ítems que fallaron. |
| `lib/detect_distro.sh` | Detecta familia desde `/etc/os-release`. |
| `lib/common.sh` | Logging, helpers, checks. |
| `lib/packages.sh` | Tablas de paquetes por familia + AUR + repos externos. |
| `lib/post_install_config.sh` | Wizard de configuración inicial. |
| `setup_terminal.sh` | Configura Zsh + Oh My Zsh + Powerlevel10k + Kitty (auxiliar). |
| `.zshrc` | Config de shell con plugins, aliases condicionales y carga lazy de NVM. |
| `kitty.conf` | Config del terminal Kitty con tema Tokyo Night. |
| `arch_cheatsheet.md` | Referencia rápida de comandos: pacman, yay, docker, git, KDE, SMB/NAS. |
| `debian_cheatsheet.md` | Equivalente para Debian: apt, dpkg, repos `.deb`, KVM/libvirt. |
| `checklist_instalacion.md` | Guía paso a paso con checklist de verificación. |
| `guia_vpn_nas.md` | Guía Tailscale + NAS por SMB. |
| `guia_pcsx2.md` | Guía emulador PS2. |

---

## Verificación final

```bash
./validate_install.sh
# Esperás ver:
#   OK: 40-45    FAIL: 0    WARN: 0-2    SKIP: 0

# Comandos clave para probar:
docker ps              # Docker sin sudo
node --version         # Node.js activo
ng version             # Angular CLI
tailscale status       # VPN
virsh net-list --all   # libvirt red default
wpctl status           # Audio (PipeWire)
```

---

## Troubleshooting

### `Tu usuario no tiene sudo NOPASSWD`
El script ahora avisa y continúa. Si querés unattended, configurá:
```bash
sudo visudo
# Agregar:  tu_usuario ALL=(ALL) NOPASSWD: ALL
# O el grupo wheel: %wheel ALL=(ALL) NOPASSWD: ALL
```

### `Docker falla sin sudo después de instalar`
Cerrá sesión y volvé a entrar (el grupo `docker` se aplica al nuevo login).
Alternativa inmediata: `newgrp docker`.

### `Node no aparece en la terminal`
```bash
source ~/.zshrc
nvm use --lts
```

### `Powerlevel10k no muestra iconos`
```bash
p10k configure
```

### `Bluetooth no detecta dispositivos`
```bash
sudo systemctl enable --now bluetooth
bluetoothctl
  power on
  scan on
```

### `libvirt: usuario sin acceso`
```bash
sudo usermod -aG libvirt $USER
# Reloguear
```

### `WPS no descarga el .deb`
La URL puede haber cambiado. Descargá manualmente desde [wps.com](https://www.wps.com/office/linux/)
y `sudo apt install ./wps-office_*.deb`.

### `Spotify no se instala por flatpak`
```bash
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub com.spotify.Client
```

---

## Licencia

Mismo que el repo original. Uso personal.
