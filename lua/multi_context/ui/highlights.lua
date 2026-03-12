-- ui/highlights.lua
-- Centraliza namespace, definição de grupos e aplicação de destaques visuais.
local M   = {}
local api = vim.api

M.ns_id = api.nvim_create_namespace("multi_context_highlights")

M.define_groups = function()
    vim.cmd("highlight ContextSelectorTitle    gui=bold guifg=#FFA500 guibg=NONE")
    vim.cmd("highlight ContextSelectorCurrent  gui=bold guifg=#B22222 guibg=NONE")
    vim.cmd("highlight ContextSelectorSelected gui=bold guifg=#FFFF00 guibg=NONE")
end

-- Destaca linhas "## IA >>" no buffer de chat (azul diagnóstico)
M.apply_chat = function(buf)
    api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    for i, l in ipairs(lines) do
        if l:match("^## IA") then
            api.nvim_buf_set_extmark(buf, M.ns_id, i - 1, 0, {
                end_col  = #l,
                hl_group = "DiagnosticInfo",
            })
        end
    end
end

-- Destaca o seletor de APIs (cabeçalho, item selecionado, item atual)
M.apply_selector = function(buf, api_list)
    api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)
    M.define_groups()

    -- Cabeçalho (linhas 0 e 1, 0-indexed)
    api.nvim_buf_add_highlight(buf, -1, "ContextSelectorTitle", 0, 0, -1)
    api.nvim_buf_add_highlight(buf, -1, "ContextSelectorTitle", 1, 0, -1)

    -- Itens: começam na linha 3 (0-indexed) — linha 0/1 = cabeçalho, 2 = vazia
    for i = 3, 3 + #api_list - 1 do
        local line = api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
        if line then
            if line:match("^❯") then
                api.nvim_buf_add_highlight(buf, -1, "ContextSelectorCurrent", i, 0, -1)
            end
            if line:match("%(selecionada%)$") then
                api.nvim_buf_add_highlight(buf, -1, "ContextSelectorSelected", i, 0, -1)
            end
        end
    end

    -- Rodapé "API atual: …" (penúltima linha, 0-indexed = total - 2)
    local total = api.nvim_buf_line_count(buf)
    if total >= 2 then
        api.nvim_buf_add_highlight(buf, -1, "ContextSelectorTitle", total - 2, 0, -1)
    end
end

return M
