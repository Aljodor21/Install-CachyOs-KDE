#!/bin/bash
# setup_terminal.sh — Configura Kitty + Zsh + Oh My Zsh + Tokyo Night
# Ejecutar como usuario normal, NO como root

echo "=== Aplicando .zshrc ==="
cat > ~/.zshrc << 'EOF'
# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-history-substring-search
)

source $ZSH/oh-my-zsh.sh

# History substring search — flechas arriba/abajo
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# NVM (lazy load para no ralentizar zsh)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" --no-use
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# PATH
export PATH="$HOME/.local/bin:$PATH"

# Aliases
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias update='sudo pacman -Syu && yay -Syu'
alias install='yay -S'
alias remove='sudo pacman -Rns'
alias search='yay -Ss'
alias cls='clear'
alias zshrc='${EDITOR:-nano} ~/.zshrc && source ~/.zshrc'
alias kittyconf='${EDITOR:-nano} ~/.config/kitty/kitty.conf'

# Powerlevel10k
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF
echo "  [OK] .zshrc aplicado"

echo "=== Aplicando kitty.conf (Tokyo Night) ==="
mkdir -p ~/.config/kitty
cat > ~/.config/kitty/kitty.conf << 'EOF'
# Kitty — Tokyo Night

# Fuente
font_family      JetBrainsMono Nerd Font
bold_font        JetBrainsMono Nerd Font Bold
italic_font      JetBrainsMono Nerd Font Italic
font_size        12.0

# Colores Tokyo Night
foreground              #c0caf5
background              #1a1b26
selection_foreground    #1a1b26
selection_background    #33467c

color0  #15161e
color1  #f7768e
color2  #9ece6a
color3  #e0af68
color4  #7aa2f7
color5  #bb9af7
color6  #7dcfff
color7  #a9b1d6
color8  #414868
color9  #f7768e
color10 #9ece6a
color11 #e0af68
color12 #7aa2f7
color13 #bb9af7
color14 #7dcfff
color15 #c0caf5

# Cursor
cursor            #c0caf5
cursor_text_color #1a1b26
cursor_shape      beam
cursor_blink_interval 0.5

# Ventana
background_opacity 0.95
window_padding_width 8
hide_window_decorations yes

# Tab bar
tab_bar_style powerline
tab_powerline_style slanted
active_tab_foreground   #1a1b26
active_tab_background   #7aa2f7
inactive_tab_foreground #545c7e
inactive_tab_background #1a1b26

# Tamaño inicial
remember_window_size  no
initial_window_width  1200
initial_window_height 700

# Scroll
scrollback_lines 10000

# URLs
url_color #7aa2f7
url_style curly
EOF
echo "  [OK] kitty.conf aplicado"

echo "=== Configurando Kitty como terminal por defecto ==="
# KDE — archivo de configuración de apps por defecto
mkdir -p ~/.config
if grep -q "TerminalApplication" ~/.config/kdeglobals 2>/dev/null; then
    sed -i 's/TerminalApplication=.*/TerminalApplication=kitty/' ~/.config/kdeglobals
else
    echo -e "\n[General]\nTerminalApplication=kitty" >> ~/.config/kdeglobals
fi

# Alternativas del sistema
if command -v update-alternatives &>/dev/null; then
    sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/kitty 50
    sudo update-alternatives --set x-terminal-emulator /usr/bin/kitty
fi
echo "  [OK] Kitty configurado como terminal por defecto"

echo "=== Verificando plugins de Oh My Zsh ==="
plugins=(
    "$HOME/.oh-my-zsh/plugins/zsh-autosuggestions"
    "$HOME/.oh-my-zsh/plugins/zsh-syntax-highlighting"
    "$HOME/.oh-my-zsh/plugins/zsh-history-substring-search"
)
missing=0
for p in "${plugins[@]}"; do
    if [ ! -d "$p" ]; then
        echo "  [WARN] Falta: $p"
        missing=1
    else
        echo "  [OK] $(basename $p)"
    fi
done

if [ $missing -eq 1 ]; then
    echo "=== Reinstalando plugins faltantes ==="
    git clone https://github.com/zsh-users/zsh-autosuggestions \
        ~/.oh-my-zsh/plugins/zsh-autosuggestions 2>/dev/null || true
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
        ~/.oh-my-zsh/plugins/zsh-syntax-highlighting 2>/dev/null || true
    git clone https://github.com/zsh-users/zsh-history-substring-search \
        ~/.oh-my-zsh/plugins/zsh-history-substring-search 2>/dev/null || true
fi

echo ""
echo "========================================="
echo "  LISTO"
echo "========================================="
echo ""
echo "Cierra esta terminal y abre Kitty de nuevo."
echo "Si el prompt no tiene estilo, corre: p10k configure"
echo ""
