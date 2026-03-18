-- utils.lua
-- Utilitários de texto e buffer sem domínio próprio.
-- Funções de domínio foram movidas para módulos específicos:
--   config.lua           → I/O de configuração JSON
--   context_builders.lua → coleta de contexto do editor
--   conversation.lua     → histórico de mensagens
--   ui/highlights.lua    → destaques visuais
local M   = {}
local api = vim.api

-- Gera um buffer de workspace com o conteúdo atual do popup
-- Em lua/multi_context/utils.lua

M.export_to_workspace = function(content, existing_filename)
    local filename = existing_filename
    if not filename then
        local timestamp = os.date("%Y%m%d_%H%M%S")
        
        -- NOVO COMPORTAMENTO: Salva os chats no diretório atual do projeto
        local cwd = vim.fn.getcwd()
        local chat_dir = cwd .. "/.mctx_chats"
        
        -- Cria a pasta oculta .mctx_chats na raiz do projeto, se não existir
        if vim.fn.isdirectory(chat_dir) == 0 then
            vim.fn.mkdir(chat_dir, "p")
        end
        
        -- Usa extensão própria .mctx
        filename = chat_dir .. "/chat_" .. timestamp .. ".mctx"
    end
    
    vim.cmd("edit " .. filename)
    
    local new_buf = vim.api.nvim_get_current_buf()
    
    -- Define o NOSSO ecossistema
    vim.bo[new_buf].filetype = "multicontext_chat"
    
    local lines = M.split_lines(content)
    vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, lines)
    vim.bo[new_buf].modified = true
    
    local last_line = vim.api.nvim_buf_line_count(new_buf)
    vim.api.nvim_win_set_cursor(0, { last_line, 0 })
    vim.cmd("stopinsert")
    
    -- Chama as cores e as dobras
    require('multi_context.ui.highlights').apply_chat(new_buf)
    require('multi_context.ui.popup').create_folds(new_buf)
    
    -- Adiciona os atalhos no Workspace
    local km = { noremap = true, silent = true }
    vim.api.nvim_buf_set_keymap(new_buf, "i", "@", "@<Esc><Cmd>lua require('multi_context.agents').open_agent_selector()<CR>", km)
    vim.api.nvim_buf_set_keymap(new_buf, "n", "<A-x>", "<Cmd>lua require('multi_context').ExecuteTools()<CR>", km)
    vim.api.nvim_buf_set_keymap(new_buf, "i", "<A-x>", "<Esc><Cmd>lua require('multi_context').ExecuteTools()<CR>", km)

    return filename
end

M.split_lines = function(s)
    local t = {}
    if not s or s == "" then return t end
    for l in s:gmatch("([^\n]*)\n?") do table.insert(t, l) end
    return t
end

-- Insere linhas no buffer. line_idx == -1 significa ao final.
M.insert_after = function(buf, line_idx, lines)
    local target = (line_idx == -1) and api.nvim_buf_line_count(buf) or line_idx
    api.nvim_buf_set_lines(buf, target, target, false, lines)
end

-- Copia o bloco de código delimitado por ``` mais próximo do cursor.
M.copy_code_block = function()
    local buf    = api.nvim_get_current_buf()
    local cursor = api.nvim_win_get_cursor(0)[1]
    local lines  = api.nvim_buf_get_lines(buf, 0, -1, false)
    local s, e   = nil, nil
    for i = cursor, 1, -1 do
        if lines[i] and lines[i]:match("^```") then s = i; break end
    end
    for i = cursor, #lines do
        if lines[i] and lines[i]:match("^```") and i ~= s then e = i; break end
    end
    if s and e then
        vim.fn.setreg('+', table.concat(api.nvim_buf_get_lines(buf, s, e - 1, false), "\n"))
        vim.notify("Código copiado!")
    else
        vim.notify("Nenhum bloco de código encontrado.", vim.log.levels.WARN)
    end
end

-- ── Wrappers de compatibilidade retroativa ────────────────────────────────────
-- Permitem que código externo ainda use os nomes antigos durante a transição.

M.apply_highlights        = function(b) require('multi_context.ui.highlights').apply_chat(b) end
M.get_git_diff            = function()  return require('multi_context.context_builders').get_git_diff() end
M.get_tree_context        = function()  return require('multi_context.context_builders').get_tree_context() end
M.get_all_buffers_content = function()  return require('multi_context.context_builders').get_all_buffers_content() end
M.find_last_user_line     = function(b) return require('multi_context.conversation').find_last_user_line(b) end
M.load_api_config         = function()  return require('multi_context.config').load_api_config() end
M.load_api_keys           = function()  return require('multi_context.config').load_api_keys() end
M.set_selected_api        = function(n) return require('multi_context.config').set_selected_api(n) end
M.get_api_names           = function()  return require('multi_context.config').get_api_names() end
M.get_current_api         = function()  return require('multi_context.config').get_current_api() end

return M

