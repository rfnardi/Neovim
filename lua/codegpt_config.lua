-- Configuração mínima do codegpt-ng.nvim
-- Funciona com Ollama local e CodeLlama-7B

local ok, codegpt = pcall(require, "codegpt")
if not ok then
  vim.notify("codegpt-ng.nvim não encontrado!", vim.log.levels.ERROR)
  return
end

odegpt.setup({
  providers = {
    ollama = {
      -- Endpoint do Ollama local
      endpoint = "http://127.0.0.1:11434/v1/chat/completions",
      model = "codellama:7b-instruct", -- modelo baixado
    },
  },
  default_provider = "ollama",
  -- Aqui você pode definir comandos personalizados, se quiser
  commands = {},
})

-- Teclas de atalho (opcional extra, mas garante compatibilidade)
-- ALT + g: Prompt
vim.api.nvim_set_keymap("n", "<A-g>", ":CodeGPT prompt<CR>", { noremap = true, silent = true })
-- ALT + x: Explain
vim.api.nvim_set_keymap("n", "<A-x>", ":CodeGPT explain<CR>", { noremap = true, silent = true })
-- ALT + r: Refactor
vim.api.nvim_set_keymap("n", "<A-r>", ":CodeGPT refactor<CR>", { noremap = true, silent = true })

-- Inicializa a UI manualmente
if codegpt.ui == nil and codegpt.init_ui then
  codegpt.init_ui()
end
