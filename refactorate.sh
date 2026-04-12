cat << 'EOF' >> ~/.config/nvim/lua/multi_context/init.lua

vim.cmd([[
  command! -range Context lua require('multi_context').ContextChatHandler(<line1>, <line2>)
  command! -nargs=0 ContextFolder lua require('multi_context').ContextChatFolder()
  command! -nargs=0 ContextRepo lua require('multi_context').ContextChatRepo()
  command! -nargs=0 ContextGit lua require('multi_context').ContextChatGit()
  command! -nargs=0 ContextApis lua require('multi_context').ContextApis()
  command! -nargs=0 ContextTree lua require('multi_context').ContextTree()
  command! -nargs=0 ContextBuffers lua require('multi_context').ContextBuffers()
  command! -nargs=0 ContextToggle lua require('multi_context').TogglePopup()
]])

return M
EOF
