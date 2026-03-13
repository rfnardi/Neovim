local api = vim.api
local M = {}

M.ns_id = api.nvim_create_namespace("multi_context_highlights")

M.define_groups = function()
    -- Grupos do seletor
    vim.cmd("highlight default ContextSelectorTitle    gui=bold guifg=#FFA500 guibg=NONE")
    vim.cmd("highlight default ContextSelectorCurrent  gui=bold guifg=#B22222 guibg=NONE")
    vim.cmd("highlight default ContextSelectorSelected gui=bold guifg=#FFFF00 guibg=NONE")
    
    -- Grupos avançados do chat (recuperados)
    vim.cmd("highlight default ContextHeader gui=bold guifg=#FF4500 guibg=NONE")
    vim.cmd("highlight default ContextUserAI gui=bold guifg=#0000CD guibg=NONE")
    vim.cmd("highlight default ContextUser gui=bold guifg=#B22222 guibg=NONE")
    vim.cmd("highlight default ContextCurrentBuffer gui=bold guifg=#FFA500 guibg=NONE")
    vim.cmd("highlight default ContextUpdateMessages gui=bold guifg=#FFA500 guibg=NONE")
    vim.cmd("highlight default ContextBoldText gui=bold guifg=#FFA500 guibg=NONE")
    vim.cmd("highlight default ContextApiInfo gui=bold guifg=#FFA500 guibg=NONE")
end

M.apply_chat = function(buf)
    if not api.nvim_buf_is_valid(buf) then return end
    local config = require('multi_context.config')
    local user_name = config.options.user_name or "User"
    
    api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)
    M.define_groups()

    local total_lines = api.nvim_buf_line_count(buf)
    for i = 0, total_lines - 1 do
        local line = api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
        if not line then goto continue end

        if line:match("^===") or line:match("^==") then
            api.nvim_buf_add_highlight(buf, M.ns_id, "ContextHeader", i, 0, -1)
        end
        if line:match("## buffer atual ##") then
            local s, e = line:find("## buffer atual ##")
            if s then api.nvim_buf_add_highlight(buf, M.ns_id, "ContextCurrentBuffer", i, s-1, e) end
        end
        if line:match("%[mensagem enviada%]") then
            local s, e = line:find("%[mensagem enviada%]")
            if s then api.nvim_buf_add_highlight(buf, M.ns_id, "ContextUpdateMessages", i, s-1, e) end
        end
        if line:match("%*%*.*%*%*") then
            local s, e = line:find("%*%*.*%*%*")
            if s then api.nvim_buf_add_highlight(buf, M.ns_id, "ContextBoldText", i, s-1, e) end
        end
        if line:match("^## " .. user_name .. " >>") then
            local s, e = line:find("## " .. user_name .. " >>")
            if s then api.nvim_buf_add_highlight(buf, M.ns_id, "ContextUser", i, s-1, e) end
        end
        if line:match("^## IA") then
            local s, e = line:find("## IA.*>>")
            if not s then s, e = line:find("## IA") end
            if s then api.nvim_buf_add_highlight(buf, M.ns_id, "ContextUserAI", i, s-1, e) end
        end
        if line:match("^## API atual:") then
            local s, e = line:find("## API atual:")
            if s then api.nvim_buf_add_highlight(buf, M.ns_id, "ContextApiInfo", i, s-1, e) end
        end

        ::continue::
    end
end

M.apply_selector = function(buf, api_list)
    if not api.nvim_buf_is_valid(buf) then return end
    api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)
    M.define_groups()

    api.nvim_buf_add_highlight(buf, M.ns_id, "ContextSelectorTitle", 0, 0, -1)
    api.nvim_buf_add_highlight(buf, M.ns_id, "ContextSelectorTitle", 1, 0, -1)

    for i = 3, 3 + #api_list - 1 do
        local line = api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
        if line then
            if line:match("^❯") then
                api.nvim_buf_add_highlight(buf, M.ns_id, "ContextSelectorCurrent", i, 0, -1)
            end
            if line:match("%(selecionada%)$") then
                api.nvim_buf_add_highlight(buf, M.ns_id, "ContextSelectorSelected", i, 0, -1)
            end
        end
    end

    local total = api.nvim_buf_line_count(buf)
    if total >= 2 then
        api.nvim_buf_add_highlight(buf, M.ns_id, "ContextSelectorTitle", total - 2, 0, -1)
    end
end

return M
