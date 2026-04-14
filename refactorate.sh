#!/bin/bash

# Define o caminho do arquivo do plugin
FILE="$HOME/.config/nvim/lua/multi_context/init.lua"

if [ ! -f "$FILE" ]; then
    echo "❌ Erro: Arquivo $FILE não encontrado."
    exit 1
fi

echo "🔍 Aplicando correções no init.lua..."

# 1. Substitui a tag das ferramentas REJEITADAS
sed -i 's|<tool_rejected name="%s">\\n%s\\n</tool_rejected>\\n\\n>\[Sistema\]: %s|<tool_call name="%s">\\n%s\\n</tool_call>\\n\\n>\[Sistema\]: ERRO - %s|g' "$FILE"

# 2. Substitui a tag das ferramentas EXECUTADAS
sed -i 's|<tool_executed name="%s" path="%s">\\n%s\\n</tool_executed>|<tool_call name="%s" path="%s">\\n%s\\n</tool_call>|g' "$FILE"

echo "✅ Pronto! Arquivo modificado com sucesso."
