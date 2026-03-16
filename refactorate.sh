#!/bin/bash

echo "Registrando os comandos no Neovim..."

cat << 'EOF' > patch_commands.awk
/^return M/ {
    print "vim.cmd([["
    print "  command! -range Context lua require('multi_context').ContextChatHandler(<line1>, <line2>)"
    print "  command! -nargs=0 ContextFolder lua require('multi_context').ContextChatFolder()"
    print "  command! -nargs=0 ContextRepo lua require('multi_context').ContextChatRepo()"
    print "  command! -nargs=0 ContextGit lua require('multi_context').ContextChatGit()"
    print "  command! -nargs=0 ContextApis lua require('multi_context').ContextApis()"
    print "  command! -nargs=0 ContextTree lua require('multi_context').ContextTree()"
    print "  command! -nargs=0 ContextBuffers lua require('multi_context').ContextBuffers()"
    print "  command! -nargs=0 ContextToggle lua require('multi_context').TogglePopup()"
    print "]])"
    print ""
    print "return M"
    next
}
{ print }
EOF

awk -f patch_commands.awk lua/multi_context/init.lua > tmp_init.lua && mv tmp_init.lua lua/multi_context/init.lua
rm patch_commands.awk

echo "[OK] Comandos ativados! Pode testar o <A-c>."
