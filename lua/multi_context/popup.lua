local api = vim.api
local config = require('multi_context.config')
local utils = require('multi_context.utils')

local M = {}

M.popup_buf = nil
M.popup_win = nil

function M.create_popup()
    -- Se o popup já existir e for válido, apenas foca nele
    if M.popup_win and api.nvim_win_is_valid(M.popup_win) then
        api.nvim_set_current_win(M.popup_win)
        return
    end

    -- Cria um novo buffer para o chat
    local buf = api.nvim_create_buf(false, true)
    M.popup_buf = buf

    -- Configurações do buffer
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].filetype = 'markdown'
    vim.bo[buf].bufhidden = 'hide'
    vim.bo[buf].swapfile = false

    -- Atalhos específicos do Popup
    local opts = { noremap = true, silent = true }
    
    -- <Enter> envia a mensagem (implementado no init.lua)
    api.nvim_buf_set_keymap(buf, "n", "<CR>", "<Cmd>lua require('multi_context').SendFromPopup()<CR>", opts)
    
    -- <A-b> copia o bloco de código (Novo!)
    api.nvim_buf_set_keymap(buf, "n", "<A-b>", "<Cmd>lua require('multi_context.utils').copy_code_block()<CR>", opts)
    api.nvim_buf_set_keymap(buf, "i", "<A-b>", "<Esc><Cmd>lua require('multi_context.utils').copy_code_block()<CR>a", opts)

    -- Atalho para fechar (opcional, já que temos o Toggle)
    api.nvim_buf_set_keymap(buf, "n", "q", "<Cmd>q<CR>", opts)

    -- Dimensões da janela
    local width = math.ceil(vim.o.columns * 0.8)
    local height = math.ceil(vim.o.lines * 0.8)
    local row = math.ceil((vim.o.lines - height) / 2)
    local col = math.ceil((vim.o.columns - width) / 2)

    local win = api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        title = ' Gemini 3.1 Chat ',
        title_pos = 'center'
    })
    
    M.popup_win = win

    -- Inicia o buffer com o prefixo do usuário
    local user_prefix = "## " .. config.options.user_name .. " >> "
    api.nvim_buf_set_lines(buf, 0, -1, false, { user_prefix })
    api.nvim_win_set_cursor(win, {1, #user_prefix})
    
    -- Aplica destaques iniciais
    utils.apply_highlights(buf)
    
    -- Ativa as dobras (folds)
    M.create_folds(buf)
    
    return buf, win
end

function M.create_folds(buf)
    vim.wo[M.popup_win].foldmethod = 'marker'
    vim.wo[M.popup_win].foldmarker = '## IA >>,## API atual:'
    vim.wo[M.popup_win].foldlevel = 99
end

return M
