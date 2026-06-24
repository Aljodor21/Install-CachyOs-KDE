# Chuleta Debian / Ubuntu

Referencia rápida para familia Debian (Debian, Ubuntu, Mint, Pop, KDE neon, ...).

## APT básico

```bash
apt update                        # actualizar índice de paquetes
apt upgrade -y                    # actualizar paquetes instalados
apt full-upgrade -y               # upgrade con cambios de dependencias
apt install paquete               # instalar
apt remove paquete                # desinstalar (deja configs)
apt purge paquete                 # desinstalar y borrar configs
apt autoremove -y                 # borrar dependencias huérfanas
apt autoclean                     # borrar .deb viejos del cache
apt search paquete                # buscar en repos
apt show paquete                  # ver info de un paquete
apt list --installed              # listar todos los instalados
apt list --installed | grep -i x  # buscar uno en particular
```

## dpkg (bajo nivel)

```bash
dpkg -l                           # listar paquetes instalados
dpkg -l | grep -i paquete         # buscar uno
dpkg -L paquete                   # archivos que instaló
dpkg -S /ruta/archivo             # qué paquete es dueño de un archivo
dpkg -i archivo.deb               # instalar un .deb local
dpkg -r paquete                   # remover (equivale a apt remove)
dpkg --print-architecture         # ver arch (amd64, arm64, ...)
dpkg --configure -a               # arreglar instalaciones a medias
```

## Repos .deb externos (firmados con GPG)

> **No usar `apt-key add`** (deprecado en Debian 12). Usar `/etc/apt/keyrings/`.

```bash
# 1. Crear directorio de keyrings
sudo install -m 0755 -d /etc/apt/keyrings

# 2. Descargar y dearmor la clave
curl -fsSL https://example.com/key.gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/example.gpg --yes
sudo chmod 0644 /etc/apt/keyrings/example.gpg

# 3. Agregar el repo a /etc/apt/sources.list.d/
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/example.gpg] \
  https://example.com/debian bookworm main" | \
  sudo tee /etc/apt/sources.list.d/example.list

# 4. Refrescar
sudo apt update
```

**Estado actual de los repos**:
```bash
ls /etc/apt/sources.list.d/
ls /etc/apt/keyrings/
apt policy           # muestra prioridad y origen de cada repo
```

## Snap (Ubuntu y derivados)

> En Debian puro snap no viene por default. Si lo necesitás: `sudo apt install snapd`.

```bash
snap list                          # listar snaps instalados
snap install nombre                # instalar
snap remove nombre                 # desinstalar
snap refresh                       # actualizar todos
snap refresh nombre                # actualizar uno
snap find nombre                   # buscar en snap store
```

## Systemd (servicios)

| Acción                    | Comando                          |
|--------------------------|----------------------------------|
| Iniciar servicio          | sudo systemctl start servicio    |
| Detener servicio          | sudo systemctl stop servicio     |
| Reiniciar servicio        | sudo systemctl restart servicio  |
| Activar al inicio         | sudo systemctl enable servicio   |
| Activar e iniciar ya      | sudo systemctl enable --now serv |
| Desactivar al inicio      | sudo systemctl disable servicio  |
| Ver estado                | systemctl status servicio        |
| Ver logs en tiempo real   | sudo journalctl -u servicio -f   |
| Ver logs recientes        | sudo journalctl -u servicio -n 50|

## Red

```bash
ip a                          # ver IPs e interfaces
ip r                          # ver rutas
ping google.com               # probar conexión
nmcli device status           # ver dispositivos de red (NetworkManager)
nmcli connection show         # ver conexiones
nmtui                         # TUI para WiFi
cat /etc/resolv.conf          # ver DNS
resolvectl status             # ver DNS systemd-resolved
```

## Archivos y sistema

```bash
df -h                         # espacio en disco
du -sh carpeta/               # tamaño de carpeta
free -h                       # uso de RAM
htop                          # monitor de procesos
lsblk                         # ver discos y particiones
mount /dev/sdX1 /mnt/punto    # montar unidad
umount /mnt/punto             # desmontar unidad
ls -lah                       # listar con detalles
uname -r                      # versión del kernel
lsmod | grep kvm               # módulos cargados (KVM)
lspci | grep -i vga            # GPU
lsusb                         # dispositivos USB
```

## Audio (PipeWire / WirePlumber)

```bash
wpctl status                        # ver dispositivos de audio
wpctl set-volume @DEFAULT_SINK@ 5%+ # subir volumen 5%
wpctl set-volume @DEFAULT_SINK@ 5%- # bajar volumen 5%
wpctl set-mute @DEFAULT_SINK@ toggle # mutear/desmutear
pavucontrol                         # GUI de audio
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

> **Permisos sin sudo**: tu usuario debe estar en el grupo `docker`. Después: `newgrp docker` o reloguear.

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

# Listar shares del NAS
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

## KVM / QEMU / libvirt (virtualización nativa Linux)

> En este repo reemplazamos VirtualBox por esta stack. Es nativa, más rápida y bien integrada con Linux.

```bash
# Ver estado del daemon
sudo systemctl status libvirtd
sudo virsh net-list --all

# VMs
sudo virt-manager                   # GUI principal
sudo virsh list --all               # listar VMs (todas)
sudo virsh list                     # listar VMs corriendo
sudo virsh start nombre-vm          # iniciar VM
sudo virsh shutdown nombre-vm       # apagar limpio
sudo virsh destroy nombre-vm        # forzar apagado
sudo virsh undefine nombre-vm       # borrar definición
sudo virsh edit nombre-vm           # editar XML de la VM
sudo virsh console nombre-vm        # consola serial

# Redes
sudo virsh net-list --all           # listar redes
sudo virsh net-start default        # iniciar red NAT por defecto
sudo virsh net-autostart default    # auto-iniciar al boot
sudo virsh net-dhcp-leases default  # ver DHCP leases

# Storage pools
sudo virsh pool-list --all
sudo virsh pool-start default
sudo virsh vol-list default         # listar discos en el pool

# Imágenes y creación
sudo virt-install \
  --name win11 \
  --ram 8192 \
  --vcpus 4 \
  --disk size=100 \
  --cdrom /ruta/a/win11.iso \
  --os-variant win11 \
  --network default \
  --graphics spice

# Imágenes cloud (rápido)
sudo virt-install \
  --name ubuntu-cloud \
  --ram 2048 --vcpus 2 \
  --disk size=20,backing_store=/var/lib/libvirt/images/ubuntu-22.04.qcow2 \
  --import \
  --network default \
  --graphics none \
  --noautoconsole

# Acceso a archivos de VM
sudo ls /var/lib/libvirt/images/
```

### Solución de problemas KVM

```bash
# /dev/kvm no existe → CPU no soporta virtualización o está deshabilitada en BIOS
ls -la /dev/kvm
egrep -c '(vmx|svm)' /proc/cpuinfo   # > 0 = soportado

# Usuario sin acceso a libvirt
sudo usermod -aG libvirt $USER      # reloguear después
sudo usermod -aG kvm $USER          # algunos sistemas lo necesitan

# Ver XML de una VM o red
sudo virsh dumpxml nombre-vm
sudo virsh net-dumpxml default

# Cambiar resolución de una VM desde afuera
sudo virsh domdisplay nombre-vm     # te da URI para SPICE/VNC
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
| Alt + F2 / Alt + Space   | KRunner (búsqueda rápida)          |

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
kquitapp6 plasmashell && kstart6 plasmashell

# Ver info de monitores conectados
kscreen-doctor -o

# Cambiar resolución/monitores por terminal
kscreen-doctor output.1.mode.1920x1080@60
```

## Diferencias Debian vs Ubuntu (resumen rápido)

| Tema | Debian | Ubuntu |
|---|---|---|
| Repos | main + contrib + non-free + non-free-firmware (hay que habilitarlos) | main + universe + multiverse (ya todo habilitado) |
| Snap | No incluido (instalar snapd manual) | Incluido por default |
| Versiones | Estables (Debian 12 bookworm LTS hasta 2028) | LTS cada 2 años (Ubuntu 24.04 noble) |
| NetworkManager | A veces no incluido; en netinst hay que marcarlo | Incluido por default |
| Codecs | gstreamer1.0-plugins-bad/ugly/libav | gstreamer1.0-plugins-bad/ugly/libav |
| WiFi firmware | non-free-firmware (hay que agregar) | Vienen en linux-firmware |

## Firmware / hardware

Si algo no funciona (WiFi, GPU, sonido), el log de dmesg es el primer lugar:

```bash
dmesg | grep -i error | tail -20
dmesg | grep -i firmware | tail -20
lspci -k                          # ver qué driver usa cada dispositivo
lshw -C network                   # info detallada de la red
```

En Debian puro, el firmware se habilita así:

```bash
# /etc/apt/sources.list debe tener 'non-free-firmware'
sudo apt update
sudo apt install firmware-iwlwifi    # ejemplo para Intel WiFi
sudo apt install firmware-realtek    # ejemplo para Realtek
sudo apt install firmware-misc-nonfree firmware-atheros
sudo reboot
```
