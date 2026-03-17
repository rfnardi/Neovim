local api = vim.api

local M = {}

function M.ExecuteTools()
    local p = require('multi_context.ui.popup')
    local buf = p.popup_buf
    
    -- Detecta se o atalho foi chamado do Popup ou do Workspace
    if not buf or not api.nvim_buf_is_valid(buf) then
        buf = api.nvim_get_current_buf()
        if vim.bo[buf].filetype ~= "multicontext_chat" then return end
    end

    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    local content = table.concat(lines, "\n")
    local has_changes = false

    -- Faz o parse de qualquer bloco <tool_call> na tela
    local new_content = content:gsub('<tool_call name="(.-)"(.-)>(.-)
