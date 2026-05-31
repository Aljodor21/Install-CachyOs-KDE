# Guía: Tailscale + NAS + Verificación final

---

## 1. Conectar Tailscale (VPN)

```bash
sudo tailscale up
```

- Se genera un link en el terminal → ábrelo en el navegador → inicia sesión → autoriza el equipo.

Verificar:
```bash
tailscale status
```

Debe aparecer este equipo y el NAS (si está en tu tailnet). Anota la IP del NAS que aparece ahí (algo como `100.x.x.x`).

---

## 2. Montar el NAS (SMB)

### Prerequisito: crear smb.conf si no existe
```bash
sudo mkdir -p /etc/samba
sudo bash -c 'printf "[global]\n   workgroup = WORKGROUP\n" > /etc/samba/smb.conf'
```

### Crear el punto de montaje
```bash
sudo mkdir -p /mnt/nas
```

### Probar la conexión primero (solo el host, sin nombre del share)
```bash
smbclient -L //uburoom -U alejo
```

### Conectarse al share interactivo
```bash
# Si el nombre tiene espacios: comillas obligatorias
smbclient "//uburoom/Mi espacio" -U alejo
```

### Montar manualmente (para probar)
```bash
sudo mount -t cifs "//uburoom/Mi espacio" /mnt/nas \
  -o username=alejo,uid=$(id -u),gid=$(id -g)
```

Verificar que montó:
```bash
ls /mnt/nas
df -h | grep nas
```

### Montaje automático al inicio (fstab)

**Paso 1** — Crear archivo de credenciales:
```bash
sudo mkdir -p /etc/samba
sudo nano /etc/samba/credentials_nas
```

Contenido del archivo:
```
username=tu_usuario
password=tu_clave
```

Asegurar permisos:
```bash
sudo chmod 600 /etc/samba/credentials_nas
```

**Paso 2** — Agregar al final de `/etc/fstab`:
```bash
sudo nano /etc/fstab
```

Línea a agregar (reemplaza IP y carpeta):
```
//uburoom/Mi\040espacio  /mnt/nas  cifs  credentials=/etc/samba/credentials_nas,uid=1000,gid=1000,_netdev,x-systemd.automount  0  0
```

> `_netdev` = espera a que haya red antes de montar  
> `x-systemd.automount` = monta al primer acceso, no al boot (más seguro con VPN)

**Paso 3** — Aplicar sin reiniciar:
```bash
sudo systemctl daemon-reload
sudo mount -a
ls /mnt/nas   # debe mostrar el contenido
```

---

## 3. Pendientes manuales (checklist)

### Teclado con ñ
KDE → Ajustes del sistema → Teclado → Distribuciones  
- Distribución: `English (US)`  
- Variante: `English (intl., with dead keys)`  

Combos: `~ + n` = ñ | `' + vocal` = tilde | `AltGr + Shift + /` = ¿

### Tablet Huion
```bash
systemctl --user enable --now opentabletdriver
```
Luego abrir **OpenTabletDriver** desde el menú de apps para mapear los botones.

### DaVinci Resolve
1. Descarga el `.run` desde [blackmagicdesign.com](https://www.blackmagicdesign.com/products/davinciresolve)
2. Instala `fuse2` (requerido — Arch no lo trae por defecto, sin esto falla con `libfuse.so.2`):
```bash
sudo pacman -S fuse2
```
3. Instala DaVinci:
```bash
chmod +x DaVinci_Resolve_*.run
./DaVinci_Resolve_*.run
```

### Monitores
KDE → Ajustes del sistema → Pantallas — ordenar y escalar visualmente.

---

## 4. Verificación final completa

```bash
# Sistema
docker ps                        # Docker sin sudo (si falla: newgrp docker)
node --version                   # Node.js
ng version                       # Angular CLI
java -version                    # Java 17
python --version                 # Python

# Red / VPN / NAS
tailscale status                 # Tailscale conectado
ls /mnt/nas                      # NAS montado y accesible

# Audio / hardware
wpctl status                     # Audio (PipeWire)
bluetoothctl show                # Bluetooth activo

# Terminal
echo $SHELL                      # debe decir /bin/zsh
p10k version                     # Powerlevel10k instalado
```

Si Docker falla sin sudo:
```bash
newgrp docker
# o reinicia sesión
```

Si Node no aparece:
```bash
source ~/.zshrc
nvm use --lts
```

---

## Resumen de orden

1. `sudo tailscale up` → autorizar en el navegador
2. `tailscale status` → anotar IP del NAS
3. `sudo mkdir -p /mnt/nas`
4. Montar manualmente para probar
5. Crear `/etc/samba/credentials_nas`
6. Editar `/etc/fstab` para automontaje
7. `sudo systemctl daemon-reload && sudo mount -a`
8. Configurar teclado, Huion, monitores en KDE
9. Instalar DaVinci Resolve si lo necesitas
10. Correr los comandos de verificación final
