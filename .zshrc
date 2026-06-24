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

# opencode (si está instalado por el script oficial, lo agrega a ~/.opencode/bin)
[ -d "$HOME/.opencode/bin" ] && export PATH="$HOME/.opencode/bin:$PATH"

# Aliases comunes
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias cls='clear'
alias zshrc='${EDITOR:-nano} ~/.zshrc && source ~/.zshrc'
alias kittyconf='${EDITOR:-nano} ~/.config/kitty/kitty.conf'

# Aliases distro-aware (pacman/yay vs apt)
# Detección de familia leyendo /etc/os-release.
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        arch|cachyos|manjaro|endeavouros|garuda|artix|archlabs|rebornos)
            # --- Familia Arch ---
            if command -v yay &>/dev/null; then
                alias update='sudo pacman -Syu && yay -Syu'
                alias install='yay -S'
                alias remove='sudo pacman -Rns'
                alias search='yay -Ss'
                alias pkglist='pacman -Q | grep -i'
            else
                alias update='sudo pacman -Syu'
                alias install='sudo pacman -S'
                alias remove='sudo pacman -Rns'
                alias search='pacman -Ss'
            fi
            alias pkginfo='pacman -Si'
            alias pkgfiles='pacman -Ql'
            ;;
        debian|ubuntu|linuxmint|pop|elementary|zorin|kde-neon|deepin|peppermint|mx|antix|raspbian)
            # --- Familia Debian ---
            alias update='sudo apt update && sudo apt upgrade -y'
            alias install='sudo apt install'
            alias remove='sudo apt remove'
            alias search='apt search'
            alias pkginfo='apt show'
            alias pkglist='dpkg -l | grep -i'
            alias pkgfiles='dpkg -L'
            alias aptclean='sudo apt autoremove -y && sudo apt autoclean'
            ;;
        *)
            # Distro no reconocida: aliases genéricos
            alias update='echo "Distro no reconocida, configurá tus aliases de update manualmente"'
            alias install='echo "Distro no reconocida"'
            ;;
    esac
fi

# Powerlevel10k
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
