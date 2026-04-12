#!/bin/bash

PLUGIN_DIR="$HOME/.config/nvim/lua/multi_context"
echo "🛠️ Corrigindo utils.lua (split_lines)..."

# Substitui a função `split_lines` no utils.lua usando o `awk` de forma segura
awk '/M\.split_lines = function\(s\)/{
  print "M.split_lines = function(s)"
  print "    if not s or s == \"\" then return {} end"
  print "    -- Usa a API nativa e otimizada do Neovim (não gera arrays com posições vazias fantasmas)"
  print "    return vim.split(s, \"\\n\", { plain = true })"
  print "end"
  skip=1
  next
}
skip && /^end$/{skip=0;next}
skip{next}
1' "$PLUGIN_DIR/utils.lua" > "$PLUGIN_DIR/utils.tmp" && mv "$PLUGIN_DIR/utils.tmp" "$PLUGIN_DIR/utils.lua"

echo "🛠️ Silenciando o aviso do Plenary no minimal_init.lua..."
cat << 'EOF' > "$PLUGIN_DIR/tests/minimal_init.lua"
vim.cmd([[set runtimepath+=. ]])

-- Tenta adicionar Plenary via vim-plug silenciosamente, se existir
local plenary_dir = vim.fn.expand("~/.config/nvim/plugged/plenary.nvim")
if vim.fn.isdirectory(plenary_dir) == 1 then
    vim.cmd("set runtimepath+=" .. plenary_dir)
end

require('multi_context.config').setup({ user_name = "Nardi" })
EOF

echo "✅ Correção aplicada! Pode rodar 'make test' novamente!"
