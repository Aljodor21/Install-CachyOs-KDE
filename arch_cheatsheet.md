# Chuleta Arch Linux / CachyOS

## Pacman vs APT

| APT (Debian/Ubuntu)            | Pacman (Arch)               |
|-------------------------------|------------------------------|
| apt update                    | pacman -Sy                   |
| apt upgrade                   | pacman -Su                   |
| apt update && apt upgrade     | pacman -Syu                  |
| apt install paquete           | pacman -S paquete            |
| apt remove paquete            | pacman -R paquete            |
| apt purge paquete             | pacman -Rns paquete          |
| apt autoremove                | pacman -Rns $(pacman -Qdtq)  |
| apt search paquete            | pacman -Ss paquete           |
| apt show paquete              | pacman -Si paquete           |
| dpkg -l                       | pacman -Q                    |
| dpkg -l \| grep paquete       | pacman -Q \| grep paquete    |
| apt-cache depends paquete     | pacman -Si paquete           |

## YAY (AUR Helper) — para programas que no están en repos oficiales

```bash
yay -S paquete        # instala desde AUR o repos oficiales
yay -Syu              # actualiza todo, incluyendo AUR
yay -Ss paquete       # busca en AUR y repos
yay -R paquete        # elimina paquete
yay -Rns paquete      # elimina paquete + dependencias huérfanas
```

> Usa yay igual que pacman, pero busca también en AUR.

## Flatpak

```bash
flatpak install flathub nombre.app    # instalar
flatpak update                        # actualizar todo
flatpak uninstall nombre.app          # eliminar
flatpak list                          # listar instalados
```

## Systemd (servicios)

| Acción                    | Comando                          |
|--------------------------|----------------------------------|
| Iniciar servicio          | systemctl start servicio         |
| Detener servicio          | systemctl stop servicio          |
| Reiniciar servicio        | systemctl restart servicio       |
| Activar al inicio         | systemctl enable servicio        |
| Activar e iniciar ya      | systemctl enable --now servicio  |
| Desactivar al inicio      | systemctl disable servicio       |
| Ver estado                | systemctl status servicio        |
| Ver logs en tiempo real   | journalctl -u servicio -f        |
| Ver logs recientes        | journalctl -u servicio -n 50     |

## Red

```bash
ip a                          # ver IPs e interfaces
ip r                          # ver rutas
ping google.com               # probar conexión
nmcli device status           # ver dispositivos de red
nmcli connection show         # ver conexiones
nmtui                         # interfaz gráfica en terminal para WiFi
```

## Archivos y sistema

```bash
df -h                         # espacio en disco
du -sh carpeta/               # tamaño de carpeta
free -h                       # uso de RAM
htop                          # monitor de procesos (o btop)
lsblk                         # ver discos y particiones
mount /dev/sdX1 /mnt/punto    # montar unidad
umount /mnt/punto             # desmontar unidad
ls -lah                       # listar archivos con detalles
```

## Audio (PipeWire / WirePlumber)

```bash
wpctl status                        # ver dispositivos de audio
wpctl set-volume @DEFAULT_SINK@ 5%+ # subir volumen 5%
wpctl set-volume @DEFAULT_SINK@ 5%- # bajar volumen 5%
wpctl set-mute @DEFAULT_SINK@ toggle # mutear/desmutear
pavucontrol                         # control de audio visual
```

## Brillo

```bash
brightnessctl get                   # ver brillo actual
brightnessctl set 50%               # poner brillo al 50%
brightnessctl set +10%              # subir brillo 10%
brightnessctl set 10%-              # bajar brillo 10%
```

## Bluetooth

```bash
bluetoothctl                        # abrir consola bluetooth
  power on                          # encender bluetooth
  scan on                           # buscar dispositivos
  pair XX:XX:XX:XX:XX:XX            # emparejar dispositivo
  connect XX:XX:XX:XX:XX:XX         # conectar dispositivo
  disconnect XX:XX:XX:XX:XX:XX      # desconectar
  devices                           # ver dispositivos guardados
  paired-devices                    # ver solo los ya emparejados
```

## Teclado — layout us international (para la ñ)

En KDE: **Ajustes del sistema → Teclado → Distribuciones**
- Distribución: `English (US)`
- Variante: `English (intl., with dead keys)`

| Carácter   | Cómo escribirlo   |
|------------|-------------------|
| ñ          | ~ luego n         |
| á é í ó ú  | ' luego vocal     |
| ü          | " luego u         |
| ¿          | AltGr + Shift + / |
| ¡          | AltGr + Shift + 1 |

## Git

```bash
git init                            # iniciar repo
git clone URL                       # clonar repo
git status                          # ver estado
git add .                           # agregar todos los cambios
git add archivo                     # agregar archivo específico
git commit -m "mensaje"             # hacer commit
git push                            # subir cambios
git pull                            # bajar cambios
git branch                          # ver ramas
git checkout -b rama                # crear y cambiar de rama
git merge rama                      # fusionar rama al actual
git stash                           # guardar cambios temporalmente
git stash pop                       # recuperar cambios guardados
git log --oneline                   # ver historial resumido
git diff                            # ver cambios no staged
```

## Docker

```bash
docker ps                           # ver contenedores corriendo
docker ps -a                        # ver todos los contenedores
docker images                       # ver imágenes
docker run -d imagen                # correr contenedor en background
docker stop id                      # detener contenedor
docker rm id                        # eliminar contenedor
docker rmi imagen                   # eliminar imagen
docker logs id                      # ver logs de contenedor
docker logs -f id                   # ver logs en tiempo real
docker exec -it id bash             # entrar a contenedor
docker compose up -d                # levantar con compose
docker compose down                 # bajar con compose
docker compose logs -f              # ver logs de compose
docker system prune                 # limpiar todo lo no usado
```

## NVM (Node Version Manager)

```bash
nvm list                            # ver versiones instaladas
nvm install --lts                   # instalar LTS más reciente
nvm install 20                      # instalar versión específica
nvm use 20                          # usar versión específica
nvm alias default 20                # establecer versión por defecto
node -v                             # ver versión activa
npm -v                              # ver versión de npm
```

## Unidad de red (SMB/NAS)

```bash
# Prerequisito: crear smb.conf mínimo si no existe
sudo mkdir -p /etc/samba
sudo bash -c 'printf "[global]\n   workgroup = WORKGROUP\n" > /etc/samba/smb.conf'

# Listar shares del NAS (solo el host, sin nombre del share)
smbclient -L //IP_SERVER -U usuario

# Conectarse a un share interactivo
smbclient "//IP_SERVER/nombre share" -U usuario   # comillas si tiene espacios

# Montar manualmente
sudo mount -t cifs "//IP_SERVER/nombre share" /mnt/nas \
  -o username=usuario,password=clave,uid=$(id -u),gid=$(id -g)

# Desmontar
sudo umount /mnt/nas
```

> Si el nombre del share tiene espacios, siempre usar comillas dobles.

### Montaje automático (fstab con credenciales seguras)

```bash
# 1. Crear archivo de credenciales
sudo nano /etc/samba/credentials_nas
#    username=usuario
#    password=clave

sudo chmod 600 /etc/samba/credentials_nas

# 2. Agregar en /etc/fstab (escapar espacios con \040):
"//IP_SERVER/nombre\040share"  /mnt/nas  cifs  credentials=/etc/samba/credentials_nas,uid=1000,gid=1000,_netdev,x-systemd.automount  0  0

# 3. Aplicar sin reiniciar
sudo systemctl daemon-reload && sudo mount -a
```

## KDE Plasma — atajos útiles

### Ventanas
| Atajo                     | Acción                              |
|--------------------------|-------------------------------------|
| Alt + F4                 | Cerrar ventana                      |
| Super + Arriba           | Maximizar ventana                   |
| Super + Abajo            | Restaurar / minimizar               |
| Super + Izq / Der        | Anclar a mitad izquierda/derecha    |
| Super + Shift + Izq/Der  | Mover a monitor anterior/siguiente  |
| Alt + Tab                | Cambiar entre ventanas              |
| Meta (Super)             | Abrir lanzador de apps (KRunner)    |
| Alt + F2 / Alt + Space   | KRunner (búsqueda rápida)           |

### Escritorios virtuales
| Atajo                     | Acción                              |
|--------------------------|-------------------------------------|
| Ctrl + F1/F2/F3/F4       | Cambiar escritorio virtual          |
| Ctrl + Shift + F1-F4     | Mover ventana a ese escritorio      |
| Super + Tab              | Vista general de escritorios        |

### Apps y sistema
| Atajo                     | Acción                              |
|--------------------------|-------------------------------------|
| Super + E                | Explorador de archivos (Dolphin)    |
| Print Screen             | Captura de pantalla (Spectacle)     |
| Shift + Print Screen     | Captura de área                     |
| Ctrl + Alt + T           | Terminal                            |
| Super + L                | Bloquear pantalla                   |

### KDE — configuración rápida

```bash
# Abrir ajustes del sistema
systemsettings

# Ver logs del sistema gráfico
journalctl --user -f

# Reiniciar Plasma sin cerrar sesión
kquitapp5 plasmashell && kstart5 plasmashell

# Ver info de monitores conectados
kscreen-doctor -o

# Cambiar resolución/monitores por terminal
kscreen-doctor output.1.mode.1920x1080@60
```
