# Checklist Instalación CachyOS + KDE Plasma

## Orden de instalación

1. Bootear USB de CachyOS
2. En el installer elegir perfil **KDE Plasma**
3. Reiniciar al terminar
4. Copiar carpeta `CachyOS install` al home desde el USB
5. Correr `install_cachyos.sh`
6. Reiniciar sesión
7. Correr `validate_install.sh` para verificar

---

## Paso 1 — Copiar scripts desde el USB

```bash
lsblk   # identificar nombre del USB (ej: sdb1)
cp -r /run/media/$USER/NOMBRE_USB/CachyOS\ install ~/
```

---

## Paso 2 — Correr el script de instalación

```bash
cd ~/CachyOS\ install
chmod +x install_cachyos.sh
./install_cachyos.sh
```

> Tarda ~15-30 min dependiendo de la conexión. No necesita intervención.
> Al terminar, **reinicia la sesión** para que los grupos de docker y vboxusers queden activos.

---

## Paso 3 — Validar instalación

```bash
chmod +x validate_install.sh
./validate_install.sh
```

Revisa que todo quede en verde. Los [WARN] amarillos son cosas manuales.

---

## Apps instaladas por el script

### Navegador
- Brave

### Desarrollo
- GitHub CLI
- VS Code
- Node.js (via NVM, versión LTS)
- Python + pip
- Arduino IDE 2
- Docker + Docker Compose
- Angular CLI
- Claude Code CLI
- Java JDK 17

### Multimedia
- OBS Studio
- FFmpeg
- VLC + codecs
- DaVinci Resolve ⚠️ — instalación manual (ver abajo)

### Productividad
- WPS Office
- Spotify (Flatpak)

### Sistema / Red
- VirtualBox
- Tailscale

### Hardware
- OpenTabletDriver (tablet Huion)

### Terminal / Entorno
- Zsh + Oh My Zsh + Powerlevel10k
- Plugins: autosuggestions, syntax-highlighting, history-substring-search
- Kitty con config personalizada
- JetBrains Mono Nerd Font

---

## DaVinci Resolve — instalación manual

1. Descarga el instalador `.run` desde [blackmagicdesign.com](https://www.blackmagicdesign.com/products/davinciresolve)
2. Instala `fuse2` (requerido por el AppImage, Arch no lo trae por defecto):
```bash
sudo pacman -S fuse2
```
3. Ejecuta:
```bash
chmod +x DaVinci_Resolve_*.run
./DaVinci_Resolve_*.run
```

---

## Configuración post-instalación

### Teclado con ñ (layout inglés)

En KDE: **Ajustes del sistema → Teclado → Distribuciones**
- Distribución: `English (US)`
- Variante: `English (intl., with dead keys)`

Con `us intl`: `~ + n` = ñ | `' + vocal` = tilde | `" + u` = ü

### Monitores

En KDE: **Ajustes del sistema → Pantallas** — configuración visual, sin tocar archivos.

### Tablet Huion

```bash
systemctl --user enable --now opentabletdriver
```

Luego abre **OpenTabletDriver** desde el menú de apps para configurar los botones.

---

## Verificación final

- [ ] `./validate_install.sh` sin errores rojos
- [ ] Docker funciona sin sudo: `docker ps`
- [ ] Node activo: `node --version`
- [ ] Angular CLI: `ng version`
- [ ] Tailscale conectado: `tailscale status`
- [ ] Tablet Huion reconocida en OpenTabletDriver
- [ ] DaVinci Resolve abre correctamente
- [ ] Audio funciona: `wpctl status`
- [ ] Bluetooth funciona: `bluetoothctl`
- [ ] Capturas de pantalla: `Print Screen` o `Spectacle`
- [ ] Teclado con ñ funciona
