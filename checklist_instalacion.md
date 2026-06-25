# Checklist de instalación — Arch o Debian con KDE Plasma

El repo es **distro-aware**: detecta tu familia y aplica el install correcto.
Hay dos caminos posibles según tu distro base.

---

## Camino A — Familia Arch (CachyOS, Arch, Manjaro, Endeavour, Garuda)

### 1. Instalar la distro base

1. Bajar la ISO de [cachyos.org](https://cachyos.org/) (recomendado) o Arch / Manjaro.
2. En el installer, elegir perfil **KDE Plasma**.
3. Reiniciar al terminar.
4. Verificar que tenés internet y sudo (ya lo hizo el installer).

### 2. Correr el install

```bash
# Clonar o copiar los scripts a tu home
cd ~
git clone https://github.com/Aljodor21/Install-CachyOs-KDE.git
cd Install-CachyOs-KDE
chmod +x install.sh install_arch.sh validate_install.sh fix_post_install.sh

# Correr el entry point (auto-detecta cachyos/arch/...)
./install.sh
```

> Tarda 15-30 min dependiendo de la conexión. El script avisa si tu sudo
> no es NOPASSWD y pausa para pedir password en cada sudo.

### 3. Wizard de configuración inicial (auto)

Al final del install, se lanza `lib/post_install_config.sh`. Son 7 pasos:

- [ ] Git (nombre + email + config global)
- [ ] GitHub CLI (`gh auth login --web`)
- [ ] Zsh como shell por defecto
- [ ] NVM default → Node LTS
- [ ] Docker test (`docker run hello-world`)
- [ ] Tailscale connect
- [ ] opencode auth (instrucciones; siempre manual)

Enter = sí. Decí `n` para skipear.

> Nota: Claude Code CLI se instala con el script pero la auth es 100% manual.
> Después de instalar, corré `claude` y seguí las instrucciones.

### 4. Reiniciar sesión (importante)

Para que `docker`, `libvirt` y `zsh` tomen efecto al 100%:
```bash
# Logout desde KDE, o:
loginctl terminate-user $USER
# Volvé a loguear
```

### 5. Validar
```bash
./validate_install.sh
```

### 6. Si hay FAIL
```bash
./fix_post_install.sh
```

### 7. Pasos manuales Arch-específicos
- [ ] (Arch) `sudo pacman -S --needed fuse2` para DaVinci Resolve
- [ ] Descargar `.run` desde blackmagicdesign.com para DaVinci Resolve
- [ ] Configurar tablet Huion con OpenTabletDriver (GUI desde menú de apps)

---

## Camino B — Familia Debian (Debian 12, Ubuntu, Mint, Pop, KDE neon)

### 1. Instalar la distro base

#### Opción B.1 — Debian netinst (recomendado, "desde cero")

1. Bajar ISO de [debian.org](https://www.debian.org/download) → `debian-12.x-amd64-netinst.iso`.
2. Bootear USB.
3. En el particionado: manual, una partición `ext4` `/` + swap.
4. En "Software selection", **marcar solo KDE Plasma**. NO marcar "Debian desktop
   environment" (eso mete GNOME también). NO marcar "print server", "web server", etc.
5. **Importante**: cuando pregunta por firmware, decir SÍ a "non-free firmware"
   si tu hardware lo necesita (WiFi/Bluetooth modernos).
6. Instalar GRUB y reiniciar.

#### Opción B.2 — KDE neon (Ubuntu LTS + KDE preinstalado)

1. Bajar ISO de [neon.kde.org](https://neon.kde.org/).
2. Instalar normal.
3. KDE Plasma ya viene por default.

### 2. Verificar sudo

```bash
sudo whoami
# Si pide password, está OK. Si dice 'root', está OK.
```

### 3. Correr el install

```bash
cd ~
git clone https://github.com/Aljodor21/Install-CachyOs-KDE.git
cd Install-CachyOs-KDE
chmod +x install.sh install_debian.sh validate_install.sh fix_post_install.sh
./install.sh
```

> El script:
> - Habilita `non-free-firmware` (si estás en Debian puro)
> - Agrega 5 repos `.deb` externos firmados: docker, brave, vscode, tailscale, opentabletdriver
> - Instala todo el stack de paqutes
> - Descarga WPS Office `.deb` desde wps.com
> - Descarga JetBrains Mono Nerd Font a `~/.local/share/fonts`
> - Define red libvirt 'default' para NAT de VMs

### 4. Wizard de configuración inicial (auto)

Mismo wizard de 7 pasos (ver Camino A, sección 3).

### 5. Reiniciar sesión
(Logout + login, para que `docker`, `libvirt` y `zsh` apliquen.)

### 6. Validar
```bash
./validate_install.sh
```

### 7. Si hay FAIL
```bash
./fix_post_install.sh
```

### 8. Pasos manuales Debian-específicos
- [ ] (Debian) `libfuse2` ya está instalado por el script
- [ ] Descargar `.run` de DaVinci Resolve desde blackmagicdesign.com
- [ ] Si usás KDE neon: `libfuse2` ya viene, no hace falta instalarlo
- [ ] Configurar tablet Huion con OpenTabletDriver (GUI desde menú)

---

## Apps instaladas (común a ambos caminos)

### Navegador
- [ ] Brave (repo externo firmado, no AUR)

### Desarrollo
- [ ] GitHub CLI (`gh auth login`)
- [ ] VS Code (repo externo firmado)
- [ ] Node.js (NVM, versión LTS)
- [ ] Python 3 + pip + venv
- [ ] Java JDK 17 (OpenJDK)
- [ ] Docker + Docker Compose plugin
- [ ] Angular CLI
- [ ] Claude Code CLI
- [ ] opencode

### Multimedia
- [ ] OBS Studio
- [ ] FFmpeg
- [ ] VLC + codecs
- [ ] DaVinci Resolve ⚠️ manual

### Productividad
- [ ] WPS Office
- [ ] Spotify (Flatpak)

### Sistema / Red
- [ ] Tailscale
- [ ] Bluetooth

### Virtualización
- [ ] QEMU/KVM/libvirt/virt-manager (reemplaza VirtualBox)

### Hardware
- [ ] OpenTabletDriver (tablet Huion)

### Terminal / Entorno
- [ ] Zsh + Oh My Zsh + Powerlevel10k
- [ ] Plugins: autosuggestions, syntax-highlighting, history-substring-search
- [ ] Kitty con config Tokyo Night
- [ ] JetBrains Mono Nerd Font

---

## Verificación final

- [ ] `./validate_install.sh` sin errores rojos
- [ ] Docker funciona sin sudo: `docker ps`
- [ ] Node activo: `node --version`
- [ ] Angular CLI: `ng version`
- [ ] Claude Code: `claude --version`
- [ ] opencode: `opencode --version`
- [ ] Tailscale conectado: `tailscale status`
- [ ] VMs funcionan: `virt-manager` (debería abrir GUI)
- [ ] DaVinci Resolve abre correctamente (si lo instalaste a mano)
- [ ] Audio funciona: `wpctl status`
- [ ] Bluetooth funciona: `bluetoothctl` → `scan on`
- [ ] Capturas de pantalla: `Print Screen` o `Spectacle`
- [ ] Teclado con ñ funciona (configurar layout si no)

---

## Wizard de configuración inicial — qué pregunta

| # | Paso | Si decís que sí | Si decís que no |
|---|---|---|---|
| 1 | Git | Lee nombre+email, configura git config --global | No hace nada |
| 2 | GitHub CLI | `gh auth login --web` (abre navegador) | Lo corrés manual después |
| 3 | Zsh default | `chsh -s $(which zsh)` | No cambia shell |
| 4 | NVM default | Fija Node LTS como default | No toca NVM |
| 5 | Docker test | `docker run hello-world` | No prueba |
| 6 | Tailscale | `sudo tailscale up` (abre navegador) | Lo corrés manual |
| 7 | opencode | Muestra instrucciones para `opencode` | Lo corrés manual |

> Claude Code CLI NO está en el wizard. Se instala con el script pero su
> auth es 100% manual: corré `claude` cuando quieras y seguí las instrucciones.

> Si interrumpís con Ctrl+C, el wizard marca "interrupted at step N" en el log
> y sale limpio. Lo podés re-ejecutar cuando quieras con `post-install-config`.

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

Luego abrir **OpenTabletDriver** desde el menú de apps para configurar los botones.

### VPN + NAS

Ver [`guia_vpn_nas.md`](./guia_vpn_nas.md) para conectar Tailscale y montar el
NAS por SMB con automontaje.
