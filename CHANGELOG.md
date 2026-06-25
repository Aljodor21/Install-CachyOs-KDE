# Changelog

Historial de cambios del repo Install-CachyOs-KDE.

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
- Brave binary se llama `brave-browser` en Debian, `brave` en Arch
- Keyring paths: `brave.gpg` vs `brave-browser.gpg`, `vscode.gpg` vs `microsoft.gpg`
- `libvirtd` usa socket activation → `enable --now` no arranca el daemon solo
- Wizard: pasos opencode/claude se colgaban intentando auto-auth
- Wizard: denominadores `1/8` mezclados con `2/6` → unificados a `X/6`
- Wizard: tabla resumen decía "Zsh PEND" cuando estaba OK → check robusto

### Wizard post-install
- **6 pasos locales**: Git, GitHub CLI, Zsh, NVM, Docker, Tailscale
- **NO incluye**: Claude Code CLI, opencode (siempre manuales, los corrés vos)
- **Tabla resumen** al final con estado OK/PEND por paso, chequeado en vivo
- Re-ejecutable con `post-install-config` desde `~/.local/bin/`

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
./validate_install.sh # validar (46 checks)
./fix_post_install.sh # reintentar fallos
./reset.sh           # desinstalar todo (--dry-run, --yes, --no-backup)
post-install-config  # wizard standalone
```
