-- api_selector.lua
-- Popup flutuante para selecionar a API padrão.
-- Usa config para leitura/escrita e ui/highlights para visuais.
local api = vim.api
local M   = {}

M.selector_buf      = nil
M.selector_win      = nil
M.api_list          = {}
M.current_selection = 1

M.open_api_selector = function()
    local config = require('multi_context.config')
    M.api_list   = config.get_api_names()
    if #M.api_list == 0 then
        vim.notify("Nenhuma API configurada.", vim.log.levels.WARN)
        return
    end

    local current = config.get_current_api()
    M.current_selection = 1
    for i, name in ipairs(M.api_list) do
        if name == current then M.current_selection = i; break end
    end

    M.selector_buf = api.nvim_create_buf(false, true)

    local width  = 60
    local height = math.min(#M.api_list + 5, 22)
    local row    = math.floor((vim.o.lines   - height) / 2)
    local col    = math.floor((vim.o.columns - width)  / 2)

    M.selector_win = api.nvim_open_win(M.selector_buf, true, {
        relative  = "editor",
        width     = width,
        height    = height,
        row       = row,
        col       = col,
        style     = "minimal",
        border    = "rounded",
        title     = " Selecionar API ",
        title_pos = "center",
    })

    vim.bo[M.selector_buf].buftype    = "nofile"
    vim.bo[M.selector_buf].modifiable = true

    M._render()
    M._keymaps()
end

M._render = function()
    if not M.selector_buf or not api.nvim_buf_is_valid(M.selector_buf) then return end

    local config  = require('multi_context.config')
    local hl      = require('multi_context.ui.highlights')
    local current = config.get_current_api()

    local lines = {
        "Selecione a API para usar nas requisições:",
        "  j/k navegar   Enter selecionar   q sair",
        "",
    }
    for i, name in ipairs(M.api_list) do
        local cursor = (i == M.current_selection) and "❯ " or "  "
        local tag    = (name == current)           and " (selecionada)" or ""
        table.insert(lines, cursor .. name .. tag)
    end
    table.insert(lines, "")
    table.insert(lines, "  API atual: " .. current)

    vim.bo[M.selector_buf].modifiable = true
    api.nvim_buf_set_lines(M.selector_buf, 0, -1, false, lines)
    hl.apply_selector(M.selector_buf, M.api_list)
end

M._keymaps = function()
    if not M.selector_buf or not api.nvim_buf_is_valid(M.selector_buf) then return end
    local function mk(k, fn)
        api.nvim_buf_set_keymap(M.selector_buf, "n", k, "",
            { callback = fn, noremap = true, silent = true })
    end
    mk("j",     function() M._move(1)  end)
    mk("k",     function() M._move(-1) end)
    mk("<CR>",  M._select)
    mk("q",     M._close)
    mk("<Esc>", M._close)
end

M._move = function(dir)
    local n = M.current_selection + dir
    if n >= 1 and n <= #M.api_list then
        M.current_selection = n
        M._render()
    end
end

M._select = function()
    local config = require('multi_context.config')
    local name   = M.api_list[M.current_selection]
    if config.set_selected_api(name) then
        vim.notify("API selecionada: " .. name, vim.log.levels.INFO)
        require('multi_context.ui.popup').update_title()
        M._close()
    else
        vim.notify("Erro ao selecionar: " .. name, vim.log.levels.ERROR)
    end
end

M._close = function()
    if M.selector_win and api.nvim_win_is_valid(M.selector_win) then
        api.nvim_win_close(M.selector_win, true)
    end
    M.selector_buf      = nil
    M.selector_win      = nil
    M.api_list          = {}
    M.current_selection = 1
end

return M
