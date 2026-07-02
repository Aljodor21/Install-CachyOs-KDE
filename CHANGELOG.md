# Changelog

Historial de cambios del repo Install-CachyOs-KDE.

## v2.1 — Pulido y robustez (Julio 2026)

Iteración sobre v2.0 con foco en:
- Estabilidad del pin a taskbar de KDE Plasma 6 + Wayland
- Toque visual personal (iconos Papirus, fastfetch colorido, kitty transparente)
- Bugs encontrados en uso real de la VM Debian 13 trixie
- Limpieza del flujo post-install

### Agregado
- `desktop-touch.sh` — script final con toque visual completo
  - Pinea apps al escritorio vía symlinks a `~/Desktop/` (alternativa confiable al taskbar pin)
  - Instala `papirus-icon-theme` y aplica `papirus-dark`
  - Descarga wallpaper de `picsum.photos` y lo aplica vía DBus
  - Flags: `--dry-run`, `--no-wallpaper`, `--no-theme`, `--no-taskbar`
- `lib/common.sh::add_desktop_icons()` — symlinks `.desktop` a `~/Desktop/`
- `lib/common.sh::fix_zsh_history_corruption()` — detecta y resetea `~/.zsh_history` corrupto
- `lib/common.sh::check_socket_service()` — helper que acepta socket-activated services
- Sección visual en `kitty.conf` (opacity 0.85, blur 30, font 12.5)
- `~/.config/fastfetch/config.jsonc` con modulos coloreados por categoría + paleta
- Bloque en `.zshrc` que corre `fastfetch` en shell interactiva (con flag `FASTFETCH_SHOWN` para no repetir)

### Cambiado
- `lib/common.sh::check_service()` ya no aborta — solo avisa
- `install_debian.sh` agrega `apt install -y` solo si necesita `sudo` para flatpak
- `install.sh` corre `desktop-touch.sh` automáticamente al final (con `--no-taskbar`, ya pineado a escritorio)
- `validate_install.sh` usa `check_socket_service` para `libvirtd` (soporta socket activation)
- `fix_post_install.sh` separa servicios normales de socket-activated (libvirtd, bluetooth)
- `install_arch.sh` y `install_debian.sh` llaman `fix_zsh_history_corruption` antes de copiar `.zshrc`
- Tabla resumen del wizard chequea Zsh con `getent passwd | grep -q zsh` (no matchea paths exactos)

### Bugs arreglados en v2.1
- **Wizard: opencode/claude auth se colgaban** → quitados del wizard (siempre manuales, los corrés vos con `claude` / `opencode`)
- **Zsh check mostraba PEND cuando estaba OK** → regex buscaba path exacto (`/bin/zsh` vs `/usr/bin/zsh`); ahora matchea cualquier `*zsh*`
- **libvirtd "no está corriendo"** aunque el daemon funciona → usa socket activation; `check_socket_service` acepta `.service` o sus `.socket`
- **bluetooth idem** → idem
- **OBS Studio .desktop no encontrado** → Debian 13 usa `com.obsproject.Studio.desktop`, no `org.obsproject.Studio.desktop`
- **fastfetch sin colores** → config linda con módulos por categoría + paleta al final
- **kitty opaco** → opacity 0.85 + blur 30 (se ve el wallpaper detrás)
- **NVM no tenía alias default** → wizard lo configura
- **`zsh: corrupt history file`** durante install → fix automático al inicio del bloque de configs
- **Desktop icons no aparecían tras re-login** → fallback con `add_desktop_icons` (symlinks a `~/Desktop/`, KDE los renderiza siempre, sin DBus ni re-login)

### Decisión de diseño: pineo de taskbar vs desktop
El pineo automático a taskbar de KDE Plasma 6 + Wayland es **frágil**:
- DBus API `org.kde.plasma/PlasmaShell.addFavorite` solo funciona dentro de la sesión gráfica activa
- `kquitapp6 plasmashell && kstart6 plasmashell` no limpia el cache de Wayland → `libEGL: failed to create dri2 screen` y el panel queda roto
- Necesita re-login COMPLETO que a veces no toma los cambios
- Regex para parsear el config INI tiene bugs sutiles (matchea applet equivocado)

**Solución adoptada**: en vez de pinear al taskbar, hacer symlinks a `~/Desktop/`. KDE Plasma automáticamente muestra cualquier `.desktop` en `~/Desktop/` como icono. Sin DBus, sin config plasma, sin re-login, sin nada raro. Funciona desde TTY.

Si querés pinear al taskbar ADEMÁS, lo hacés manual: click derecho en cada app del menú Kickoff → "Anclar a la barra de tareas".

### Wizard post-install (estado final)
- **6 pasos locales** (Enter = sí, cada uno opcional):
  1. Git (nombre/email + config global + `~/.gitignore_global`)
  2. GitHub CLI (`gh auth login --git-protocol ssh --web`)
  3. Zsh como shell default (`chsh -s $(which zsh)`)
  4. NVM default → Node LTS (`nvm alias default node`)
  5. Docker test (`docker run hello-world` con `sg docker`)
  6. Tailscale connect (`sudo tailscale up`)
- **NO en el wizard** (siempre manuales):
  - Claude Code CLI → corré `claude`
  - opencode → corré `opencode`
- **Tabla resumen al final** con estado OK/PEND por paso (chequeado en vivo)
- Re-ejecutable con `post-install-config` desde `~/.local/bin/`

### Servicios (estado final)
- Habilitados durante install: `docker`, `tailscaled`, `libvirtd` (con socket activation: `.socket`, `-ro.socket`, `-admin.socket` + `start` explícito), `bluetooth`
- VM guest tools: `spice-vdagent`, `qemu-guest-agent` (servicios `spice-vdagentd`, `qemu-guest-agent`)

### Repos externos (firmados con GPG en `/etc/apt/keyrings/`, solo Debian)
| Repo | Keyring file | Paquetes |
|---|---|---|
| Docker CE | `docker.gpg` | `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin` |
| Brave | `brave-browser.gpg` | `brave-browser` |
| VS Code | `microsoft.gpg` | `code` |
| Tailscale | `tailscale.gpg` (binario) | `tailscale` |
| (no-firmware) | nativo en main | `firmware-*` etc. (ya viene en `non-free-firmware.list`) |

En Arch, esos paquetes vienen vía AUR (`yay`) o repos oficiales.

## v2.0 — Multi-distro con auto-detección (Junio 2026)

Reescritura completa del repo para soportar Arch y Debian con detección automática.

### Agregado
- `install.sh` — entry point único que detecta distro y delega
- `lib/detect_distro.sh` — lee `/etc/os-release` y setea `DISTRO_FAMILY` (arch|deb)
- `lib/common.sh` — logging con colores, contadores, helpers, checks de precondición
- `lib/packages.sh` — tablas asociativas de paquetes por familia + AUR + repos externos
- `lib/post_install_config.sh` — wizard de 6 pasos con tabla resumen al final
- `install_debian.sh` — implementación para Debian/Ubuntu/Mint/Pop/KDE neon
- `install_arch.sh` — renombrado de `install_cachyos.sh`, limpio de VBox/Arduino, agregado KVM/libvirt
- `debian_cheatsheet.md` — apt/dpkg, repos `.deb` firmados, KVM/libvirt completo
- `validate_install.sh` — distro-aware, 46 checks
- `fix_post_install.sh` — reintenta pasos fallidos con fallbacks
- `reset.sh` — desinstalador con 11 categorías, `--dry-run`, `--yes`, backup automático

### Cambiado
- `setup_terminal.sh` — reemplazado por configs inline en install_*.sh
- `arch_cheatsheet.md` — agrega aviso AUR y cross-refs
- `.zshrc` — aliases condicionales (apt vs pacman/yay)
- README reescrito

### Eliminado
- Soporte para VirtualBox (reemplazado por KVM/QEMU/libvirt/virt-manager)
- Arduino IDE 2 (no lo usás)
- Dependencia de AUR para software crítico (Brave, VS Code, Docker, Tailscale en Debian ahora son repos firmados)
- Soporte para Hyprland (estabas en KDE)

### Bugs encontrados y arreglados durante testing en VM Debian 13
- `curl` no incluido en netinst → agregado bloque Prereqs
- `openjdk-17-jdk` removido de trixie → helper `try_install` con fallback a JDK 21
- `libfuse2` renombrado a `libfuse2t64` → fallback en `try_install`
- VS Code keyring URL nueva (`microsoft.asc`)
- Tailscale keyring en formato binario (`.noarmor.gpg`), sin dearmor
- OpenTabletDriver: repo apt descontinuado → descarga desde GitHub releases
- OTD tarball: extrae a `/` (FHS), no a `/opt/opentabletdriver`
- Flatpak: sin polkit agent, `install` y `uninstall` necesitan `sudo`

## v1.0 — Original (CachyOS only)
- `install_cachyos.sh` con yay para AUR
- VirtualBox para VMs
- Arduino IDE 2
- Solo KDE Plasma en CachyOS

---

## Distros soportadas

### Familia Arch (probado en CachyOS)
- arch, cachyos, manjaro, endeavour, garuda, artix, archlabs, rebornos

### Familia Debian (probado en Debian 13 trixie)
- debian (12 bookworm, 13 trixie)
- ubuntu, linuxmint, pop, kde-neon, zorin, elementary

## Comandos principales

```bash
./install.sh         # instalar (auto-detecta distro)
./validate_install.sh # validar (46 OK, 0 FAIL, 1 WARN típico)
./fix_post_install.sh # reintentar fallos
./reset.sh           # desinstalar todo (--dry-run, --yes, --no-backup)
post-install-config  # wizard standalone (desde ~/.local/bin)
desktop-touch.sh     # toque visual (iconos, tema, wallpaper)
```

## Estructura del repo

```
Install-CachyOs-KDE/
├── install.sh                 # entry point (auto-detecta distro)
├── install_arch.sh            # implementación Arch (pacman + yay)
├── install_debian.sh          # implementación Debian (apt + repos .deb firmados)
├── validate_install.sh        # 46 checks distro-aware
├── fix_post_install.sh        # reintenta pasos fallidos
├── reset.sh                   # desinstalador con 11 categorías
├── desktop-touch.sh           # toque visual (iconos escritorio, tema, wallpaper)
├── lib/
│   ├── detect_distro.sh       # lee /etc/os-release
│   ├── common.sh              # logging, helpers, add_desktop_icons, fix_zsh_history
│   ├── packages.sh            # tablas de paquetes por familia
│   └── post_install_config.sh # wizard 6 pasos + tabla resumen
├── .zshrc                     # Oh My Zsh + p10k + plugins + NVM + aliases condicionales
├── kitty.conf                 # Tokyo Night, opacity 0.85, blur 30
├── README.md                  # doc principal
├── CHANGELOG.md               # este archivo
├── checklist_instalacion.md   # pasos detallados
├── arch_cheatsheet.md         # chuleta comandos Arch
├── debian_cheatsheet.md       # chuleta comandos Debian + KVM/libvirt
├── guia_vpn_nas.md            # Tailscale + NAS por SMB
└── guia_pcsx2.md              # emulador PS2
```

## Lecciones aprendidas del proyecto

1. **El pineo a taskbar de KDE Plasma 6 + Wayland es frágil**: usar `add_desktop_icons` con symlinks es 100x más confiable
2. **El DBus API de Plasma solo funciona dentro de la sesión gráfica activa**: install.sh corre desde TTY → DBus call falla silenciosamente
3. **`kquitapp6 plasmashell` no limpia cache de Wayland**: necesario re-login completo
4. **Parsear config INI de Plasma con regex es propenso a errores**: mejor usar DBus API oficial cuando se pueda
5. **Scripts idempotentes son clave**: el usuario corre `./install.sh` múltiples veces durante testing, debe ser seguro
