# Guía: Emulador PS2 (PCSX2) en CachyOS

---

## Instalación

```bash
sudo pacman -S pcsx2
```

---

## Requisitos

### BIOS de PS2
PCSX2 requiere el BIOS de una PS2 real. No se distribuye por razones legales — debes dumpearlo de tu propia consola.

1. Descarga **PS2 Dumper** en un USB
2. Cópialo a una memory card de PS2
3. Ejecútalo desde la consola — genera un archivo `.bin`
4. Copia ese archivo a `~/.config/PCSX2/bios/`

### Juegos
Los juegos deben ser ISOs dumpeadas de tus propios discos:
```bash
# Con un lector de discos físico:
sudo dd if=/dev/sr0 of=~/juego.iso bs=2048
```

O en formato `.iso` / `.bin` / `.chd` ya dumpeados.

---

## Configuración inicial

1. Abre PCSX2 desde el menú de apps
2. En el asistente inicial:
   - Selecciona el BIOS en `~/.config/PCSX2/bios/`
   - Configura el mando (USB o Bluetooth — se detecta automático)
3. Agrega tu carpeta de juegos: **Settings → Game List → Add Search Directory**

---

## Mejoras gráficas recomendadas

En **Settings → Graphics:**

| Opción | Valor recomendado |
|--------|-------------------|
| Renderer | Vulkan (mejor rendimiento en Linux) |
| Internal Resolution | 3x o 4x (1080p / 4K upscale) |
| Texture Filtering | Bilinear |
| Anisotropic Filtering | 16x |
| FXAA / Shader | Opcional |

---

## Mando

PCSX2 detecta mandos automáticamente (USB o Bluetooth).  
Para configurar botones: **Settings → Controllers**

Funciona con: DualShock 3/4/5, Xbox, y mandos genéricos USB.

---

## Verificación

```bash
pcsx2          # abrir desde terminal para ver errores si falla
```

O buscar **PCSX2** en el lanzador de apps de KDE.
