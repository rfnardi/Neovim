local api = vim.api
local config = require('multi_context.config')
local utils = require('multi_context.utils')

local M = {}

M.popup_buf = nil
M.popup_win = nil

function M.create_popup()
    -- BUG FIX #2: quando o popup já existe, foca nele E retorna buf/win
    -- antes retornava nil implicitamente, quebrando chamadores que usam os valores
    if M.popup_win and api.nvim_win_is_valid(M.popup_win) then
        api.nvim_set_current_win(M.popup_win)
        return M.popup_buf, M.popup_win
    end

    local buf = api.nvim_create_buf(false, true)
    M.popup_buf = buf

    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].filetype = 'markdown'
    vim.bo[buf].bufhidden = 'hide'
    vim.bo[buf].swapfile = false

    local opts = { noremap = true, silent = true }

    api.nvim_buf_set_keymap(buf, "n", "<CR>", "<Cmd>lua require('multi_context').SendFromPopup()<CR>", opts)
    api.nvim_buf_set_keymap(buf, "n", "<A-b>", "<Cmd>lua require('multi_context.utils').copy_code_block()<CR>", opts)
    api.nvim_buf_set_keymap(buf, "i", "<A-b>", "<Esc><Cmd>lua require('multi_context.utils').copy_code_block()<CR>a", opts)
    api.nvim_buf_set_keymap(buf, "n", "q", "<Cmd>q<CR>", opts)
		api.nvim_buf_set_keymap(buf, "n", "<A-w>", "<Cmd>lua require('multi_context').ToggleWorkspaceView()<CR>", opts)
		api.nvim_buf_set_keymap(buf, "i", "<A-w>", "<Esc><Cmd>lua require('multi_context').ToggleWorkspaceView()<CR>", opts)

    local width = math.ceil(vim.o.columns * 0.8)
    local height = math.ceil(vim.o.lines * 0.8)
    local row = math.ceil((vim.o.lines - height) / 2)
    local col = math.ceil((vim.o.columns - width) / 2)

    -- Título dinâmico com a API atual
    local current_api = utils.get_current_api()
    local title = current_api ~= "" and (" " .. current_api .. " ") or " MultiContext Chat "

    local win = api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        title = title,
        title_pos = 'center'
    })

    M.popup_win = win

    local user_prefix = "## " .. config.options.user_name .. " >> "
    api.nvim_buf_set_lines(buf, 0, -1, false, { user_prefix })
    api.nvim_win_set_cursor(win, {1, #user_prefix})

    utils.apply_highlights(buf)
    M.create_folds(buf)

    return buf, win
end

function M.create_folds(buf)
    vim.wo[M.popup_win].foldmethod = 'marker'
    vim.wo[M.popup_win].foldmarker = '## IA >>,## API atual:'
    vim.wo[M.popup_win].foldlevel = 99
end

return M
