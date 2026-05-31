# CachyOS KDE — Post-install Toolkit

Scripts y guías para configurar un entorno de desarrollo completo en CachyOS con KDE Plasma, desde cero hasta listo para trabajar.

---

## Prerequisitos

- CachyOS instalado con el perfil **KDE Plasma**
- Conexión a internet
- Sesión iniciada como usuario normal (no root)

---

## Orden de uso

```
1. install_cachyos.sh     ← instala todo (~20 min)
2. Reinicia la sesión
3. validate_install.sh    ← verifica que todo quedó bien
4. fix_post_install.sh    ← si hay ítems en rojo
5. Pasos manuales         ← ver checklist_instalacion.md
```

---

## Archivos

| Archivo | Descripción |
|--------|-------------|
| `install_cachyos.sh` | Script principal. Instala todos los paquetes y configura el entorno. |
| `validate_install.sh` | Verifica que cada herramienta esté instalada y activa. Muestra [OK] / [FAIL] / [WARN]. |
| `fix_post_install.sh` | Reinstala los ítems que fallaron (Node, Angular CLI, Claude CLI). |
| `setup_terminal.sh` | Configura Zsh + Oh My Zsh + Powerlevel10k + Kitty por separado. |
| `.zshrc` | Config de shell con plugins, aliases y carga lazy de NVM. |
| `kitty.conf` | Config del terminal Kitty con tema Tokyo Night. |
| `arch_cheatsheet.md` | Referencia rápida de comandos: pacman, yay, docker, git, KDE, SMB/NAS. |
| `checklist_instalacion.md` | Guía paso a paso con checklist de verificación final. |
| `guia_vpn_nas.md` | Guía para conectar Tailscale y montar el NAS por SMB. |

---

## Qué instala `install_cachyos.sh`

### Desarrollo
- Git, GitHub CLI
- VS Code
- Node.js via NVM (LTS)
- Python + pip
- Java JDK 17
- Docker + Docker Compose
- Angular CLI
- Arduino IDE 2
- Claude Code CLI

### Multimedia
- OBS Studio
- FFmpeg + codecs
- VLC

### Productividad
- WPS Office
- Spotify (Flatpak)
- Brave Browser

### Sistema
- VirtualBox
- Tailscale
- OpenTabletDriver (tablet Huion)

### Terminal
- Zsh + Oh My Zsh + Powerlevel10k
- Plugins: autosuggestions, syntax-highlighting, history-substring-search
- Kitty con tema Tokyo Night
- JetBrains Mono Nerd Font

---

## Pasos manuales (el script no puede hacerlos)

### Teclado con ñ
KDE → Ajustes del sistema → Teclado → Distribuciones
- Distribución: `English (US)`
- Variante: `English (intl., with dead keys)`

### DaVinci Resolve
```bash
# 1. Instalar fuse2 (requerido por el AppImage)
sudo pacman -S fuse2

# 2. Descargar el .run desde blackmagicdesign.com y ejecutar
chmod +x DaVinci_Resolve_*.run
./DaVinci_Resolve_*.run
```

### Tablet Huion
```bash
systemctl --user enable --now opentabletdriver
# Luego abrir OpenTabletDriver desde el menú de apps
```

### VPN + NAS
Ver [`guia_vpn_nas.md`](./guia_vpn_nas.md) para conectar Tailscale y montar el NAS por SMB con automontaje.

### Monitores
KDE → Ajustes del sistema → Pantallas

---

## Verificación final

```bash
docker ps              # Docker sin sudo
node --version         # Node.js activo
ng version             # Angular CLI
tailscale status       # VPN conectada
ls /mnt/nas            # NAS montado
wpctl status           # Audio (PipeWire)
```

---

## Notas

- Si Docker falla sin sudo después de instalar: `newgrp docker` o reiniciar sesión.
- Si Node no aparece: `source ~/.zshrc && nvm use --lts`.
- El script de instalación tarda ~20 min dependiendo de la conexión.
