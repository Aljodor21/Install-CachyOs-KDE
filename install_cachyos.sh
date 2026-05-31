#!/bin/bash
# Script de instalación post-install CachyOS (Hyprland)
# Ejecutar como usuario normal, NO como root

echo "=== Actualizando sistema ==="
sudo pacman -Syu --noconfirm

echo "=== Instalando yay (AUR helper) si no está ==="
if ! command -v yay &> /dev/null; then
    sudo pacman -S --noconfirm git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm
    cd ~
fi

echo "=== Herramientas base ==="
sudo pacman -S --noconfirm \
    git \
    github-cli \
    ffmpeg \
    python \
    python-pip \
    kitty \
    flatpak \
    vlc \
    gst-plugins-ugly \
    gst-plugins-bad \
    base-devel \
    zsh \
    ttf-jetbrains-mono-nerd \
    cifs-utils \
    grim \
    slurp \
    wl-clipboard \
    pavucontrol \
    btop \
    brightnessctl \
    bluez \
    bluez-utils \
    nwg-look

echo "=== Terminal: Oh My Zsh ==="
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

echo "=== Terminal: Powerlevel10k ==="
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    ~/.oh-my-zsh/themes/powerlevel10k

echo "=== Terminal: Plugins Zsh ==="
git clone https://github.com/zsh-users/zsh-autosuggestions \
    ~/.oh-my-zsh/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting \
    ~/.oh-my-zsh/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-history-substring-search \
    ~/.oh-my-zsh/plugins/zsh-history-substring-search

echo "=== Terminal: Aplicando configuraciones ==="
cp "$(dirname "$0")/.zshrc" ~/.zshrc
mkdir -p ~/.config/kitty
cp "$(dirname "$0")/kitty.conf" ~/.config/kitty/kitty.conf
chsh -s $(which zsh)

echo "=== Brave ==="
yay -S --noconfirm brave-bin

echo "=== VS Code ==="
yay -S --noconfirm visual-studio-code-bin

echo "=== Node.js via NVM ==="
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install --lts

echo "=== Docker ==="
sudo pacman -S --noconfirm docker docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

echo "=== OBS Studio ==="
sudo pacman -S --noconfirm obs-studio

echo "=== VirtualBox ==="
sudo pacman -S --noconfirm virtualbox virtualbox-host-modules-arch
sudo modprobe vboxdrv
sudo usermod -aG vboxusers $USER

echo "=== Tailscale ==="
sudo pacman -S --noconfirm tailscale
sudo systemctl enable --now tailscaled

echo "=== WPS Office ==="
yay -S --noconfirm wps-office

echo "=== Spotify ==="
flatpak install -y flathub com.spotify.Client

echo "=== Claude CLI ==="
npm install -g @anthropic-ai/claude-code

echo "=== Angular CLI ==="
npm install -g @angular/cli

echo "=== Java JDK 17 ==="
sudo pacman -S --noconfirm jdk17-openjdk

echo "=== Arduino IDE ==="
yay -S --noconfirm arduino-ide-bin

echo "=== OpenTabletDriver (Huion tablet) ==="
yay -S --noconfirm opentabletdriver

echo "=== DaVinci Resolve ==="
echo ">>> DaVinci Resolve requiere descarga manual desde:"
echo ">>> https://www.blackmagicdesign.com/products/davinciresolve"
echo ">>> Descarga el instalador .run y ejecuta: chmod +x DaVinci*.run && ./DaVinci*.run"

echo ""
echo "=== INSTALACION COMPLETADA ==="
echo "IMPORTANTE: Reinicia la sesión para aplicar cambios de grupos (docker, vboxusers)"
