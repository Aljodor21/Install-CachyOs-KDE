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
