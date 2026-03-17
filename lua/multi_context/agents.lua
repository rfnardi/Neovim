-- lua/multi_context/agents.lua
local api = vim.api
local M = {}

M.agents_file = vim.fn.expand("~/.config/nvim/lua/multi_context/agents/agents.json")

M.load_agents = function()
    local file = io.open(M.agents_file, 'r')
    if not file then return {} end
    local content = file:read('*a')
    file:close()
    
    local ok, parsed = pcall(vim.fn.json_decode, content)
    if not ok then return {} end
    return parsed
end

M.get_agent_names = function()
    local agents = M.load_agents()
    local names = {}
    for name, _ in pairs(agents) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

-- Variáveis de controle da interface
M.selector_buf = nil
M.selector_win = nil
M.current_selection = 1
M.api_list = {}
M.parent_win = nil

M.open_agent_selector = function()
    M.api_list = M.get_agent_names()
    if #M.api_list == 0 then
        vim.notify("Nenhum agente encontrado no JSON.", vim.log.levels.WARN)
        -- Se não tiver agente, apenas volta a digitar normalmente
        api.nvim_feedkeys("a", "n", true)
        return
    end

    M.parent_win = api.nvim_get_current_win()
    M.current_selection = 1
    M.selector_buf = api.nvim_create_buf(false, true)

    local width = 30
    local height = #M.api_list

    -- Abre uma janela flutuante ancorada exatamente no cursor do mouse
    M.selector_win = api.nvim_open_win(M.selector_buf, true, {
        relative = "cursor",
        row = 1,
        col = 0,
        width = width,
        height = height,
        style = "minimal",
        border = "rounded",
    })

    vim.bo[M.selector_buf].buftype = "nofile"
    vim.bo[M.selector_buf].modifiable = true

    M._render()
    M._keymaps()
end

M._render = function()
    if not M.selector_buf or not api.nvim_buf_is_valid(M.selector_buf) then return end
    local lines = {}
    for i, name in ipairs(M.api_list) do
        local cursor = (i == M.current_selection) and "❯ " or "  "
        table.insert(lines, cursor .. name)
    end
    vim.bo[M.selector_buf].modifiable = true
    api.nvim_buf_set_lines(M.selector_buf, 0, -1, false, lines)
    
    -- Colore a linha selecionada (Aproveita a cor do seu próprio highlight de API)
    local ns = api.nvim_create_namespace("mc_agents")
    api.nvim_buf_clear_namespace(M.selector_buf, ns, 0, -1)
    api.nvim_buf_add_highlight(M.selector_buf, ns, "ContextSelectorCurrent", M.current_selection - 1, 0, -1)
end

M._keymaps = function()
    if not M.selector_buf or not api.nvim_buf_is_valid(M.selector_buf) then return end
    local function mk(k, fn)
        api.nvim_buf_set_keymap(M.selector_buf, "n", k, "", { callback = fn, noremap = true, silent = true })
    end
    mk("j", function() M._move(1) end)
    mk("k", function() M._move(-1) end)
    mk("<CR>", M._select)
    mk("<Esc>", M._close)
    mk("q", M._close)
end

M._move = function(dir)
    local n = M.current_selection + dir
    if n >= 1 and n <= #M.api_list then
        M.current_selection = n
        M._render()
    end
end

M._select = function()
    local name = M.api_list[M.current_selection]
    M._close_win_only()
    
    -- Volta para o chat, insere o nome do agente e te deixa continuar digitando
    if M.parent_win and api.nvim_win_is_valid(M.parent_win) then
        api.nvim_set_current_win(M.parent_win)
        
        local row, col = unpack(api.nvim_win_get_cursor(0))
        local line = api.nvim_get_current_line()
        
        -- Adiciona o nome do agente logo após o '@'
        local new_line = string.sub(line, 1, col + 1) .. name .. string.sub(line, col + 2)
        api.nvim_set_current_line(new_line)
        
        -- Move o cursor pro final da palavra inserida
        api.nvim_win_set_cursor(0, {row, col + 1 + #name})
        
        -- Aciona o 'a' (append) para você continuar digitando perfeitamente
        api.nvim_feedkeys("a", "n", true)
    end
end

M._close_win_only = function()
    if M.selector_win and api.nvim_win_is_valid(M.selector_win) then
        api.nvim_win_close(M.selector_win, true)
    end
    M.selector_buf = nil
    M.selector_win = nil
end

M._close = function()
    M._close_win_only()
    if M.parent_win and api.nvim_win_is_valid(M.parent_win) then
        api.nvim_set_current_win(M.parent_win)
        api.nvim_feedkeys("a", "n", true)
    end
end

return M
