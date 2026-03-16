-- commands.lua
-- Handlers dos comandos expostos pelo plugin.
-- Conecta :Context*, :ContextGit, etc. aos context_builders e ao popup.
local M = {}

-- Abre o popup com um conteúdo inicial e entra em modo de inserção.
local function open_with(content)
    local buf, win = require('multi_context.ui.popup').create_popup(content)
    if buf and win then vim.cmd("startinsert!") end
end

M.ContextChatHandler = function(line1, line2)
    local ctx = require('multi_context.context_builders')
    -- Chamado com range explícito (comando -range ou vnoremap)
    if line1 and line2 and tonumber(line1) ~= tonumber(line2) then
        open_with(ctx.get_visual_selection(line1, line2))
        return
    end
    -- Chamado sem range: detecta modo visual ou usa buffer inteiro
    local mode = vim.api.nvim_get_mode().mode
    if mode == 'v' or mode == 'V' then
        open_with(ctx.get_visual_selection())
    else
        open_with(ctx.get_current_buffer())
    end
end

M.ContextChatFull = function() open_with("") end

-- :ContextFolder -> APENAS a pasta onde o nvim foi aberto
M.ContextChatFolder = function()
    open_with(require('multi_context.context_builders').get_folder_context())
end

-- :ContextTree -> Árvore (tree) + Conteúdo (maxdepth 2)
M.ContextTree = function()
    open_with(require('multi_context.context_builders').get_tree_context())
end

-- :ContextRepo -> Todos os arquivos do repositório Git
M.ContextChatRepo = function()
    open_with(require('multi_context.context_builders').get_repo_context())
end

-- :ContextGit -> Diff de alterações não commitadas (git diff)
M.ContextChatGit = function()
    open_with(require('multi_context.context_builders').get_git_diff())
end

M.ContextApis = function()
    require('multi_context.api_selector').open_api_selector()
end

M.ContextBuffers  = function()
    open_with(require('multi_context.context_builders').get_all_buffers_content())
end

return M
