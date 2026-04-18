#!/bin/bash

REPO_DIR="$HOME/repos/multi_context_plugin"
NVIM_DIR="$HOME/.config/nvim"

echo "🚀 Iniciando a migração do plugin para repositório independente..."

# 1. Cria a estrutura do repositório
mkdir -p "$REPO_DIR/lua"

# 2. Move a pasta lua (Código Fonte)
if [ -d "$NVIM_DIR/lua/multi_context" ]; then
    mv "$NVIM_DIR/lua/multi_context" "$REPO_DIR/lua/"
    echo "✅ Código fonte movido com sucesso!"
else
    echo "⚠️ Pasta lua/multi_context não encontrada no Neovim."
fi

# 3. Move os arquivos de documentação e testes
for file in README.md CONTEXT.md Makefile; do
    if [ -f "$NVIM_DIR/$file" ]; then
        mv "$NVIM_DIR/$file" "$REPO_DIR/"
        echo "✅ $file movido com sucesso!"
    fi
done

# 4. Cria um .gitignore padrão para segurança
cat << 'EOF' > "$REPO_DIR/.gitignore"
# Ignora arquivos temporários e chaves vazadas
*.json
!agents/agents.json
.DS_Store
.luarc.json
mctx_backup_*.mctx
.mctx_chats/
EOF
echo "✅ .gitignore de segurança criado!"

# 5. Inicializa o repositório Git
cd "$REPO_DIR" || exit
git init
git add .
git commit -m "chore: projeto extraido para repositorio independente"
echo "✅ Repositório Git inicializado em $REPO_DIR"

echo "🎉 Migração concluída!"
