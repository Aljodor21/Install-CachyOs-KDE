#!/bin/bash
# fix_post_install.sh — Arregla los FAILs del validate_install.sh
# Ejecutar como usuario normal, NO como root

echo "=== Cargando NVM ==="
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"

echo "=== Instalando Node LTS ==="
nvm install --lts
nvm alias default node

echo "=== Angular CLI ==="
npm install -g @angular/cli

echo "=== Claude Code CLI ==="
curl -fsSL https://claude.ai/install.sh | bash

echo ""
echo "=== LISTO — corre ./validate_install.sh para verificar ==="
