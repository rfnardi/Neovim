local api = vim.api
local M = {}

M.define_groups = function()
    -- Grupos do seletor
    vim.cmd("highlight default ContextSelectorTitle    gui=bold guifg=#FFA500 guibg=NONE")
    vim.cmd("highlight default ContextSelectorCurrent  gui=bold guifg=#B22222 guibg=NONE")
    vim.cmd("highlight default ContextSelectorSelected gui=bold guifg=#FFFF00 guibg=NONE")
    
    -- Nossos Grupos de Chat Customizados
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
    
    vim.api.nvim_buf_call(buf, function()
        M.define_groups()
        
        -- Aplica regras NATIVAS usando Regex do Neovim. 
        -- Isso colore o texto em tempo real (mesmo durante streaming) sem pesar a CPU!
        vim.cmd("syntax match ContextHeader '^===.*'")
        vim.cmd("syntax match ContextHeader '^== Arquivo:.*'")
        vim.cmd("syntax match ContextCurrentBuffer '^## buffer atual ##'")
        vim.cmd("syntax match ContextUpdateMessages '\\[mensagem enviada\\]'")
        vim.cmd("syntax match ContextUpdateMessages '\\[Enviando requisição.*\\]'")
        vim.cmd(string.format("syntax match ContextUser '^## %s >>.*'", user_name))
        vim.cmd("syntax match ContextUserAI '^## IA.*'")
        vim.cmd("syntax match ContextApiInfo '^## API atual:.*'")
        
        -- Pinta o texto entre ** ** com cor de destaque
        vim.cmd("syntax region ContextBold matchgroup=ContextBoldText start='\\*\\*' end='\\*\\*'")
        
        -- Colore blocos de código com a cor de Strings do seu tema Gruvbox
        vim.cmd("syntax region ContextCodeBlock start='^```' end='^```'")
        vim.cmd("highlight default link ContextCodeBlock String")
        vim.cmd("highlight default link ContextBold ContextBoldText")
    end)
end

M.apply_selector = function(buf, api_list)
    -- (Mantido inalterado)
    if not api.nvim_buf_is_valid(buf) then return end
    M.define_groups()
    api.nvim_buf_add_highlight(buf, -1, "ContextSelectorTitle", 0, 0, -1)
    api.nvim_buf_add_highlight(buf, -1, "ContextSelectorTitle", 1, 0, -1)

    for i = 3, 3 + #api_list - 1 do
        local line = api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
        if line then
            if line:match("^❯") then api.nvim_buf_add_highlight(buf, -1, "ContextSelectorCurrent", i, 0, -1) end
            if line:match("%(selecionada%)$") then api.nvim_buf_add_highlight(buf, -1, "ContextSelectorSelected", i, 0, -1) end
        end
    end

    local total = api.nvim_buf_line_count(buf)
    if total >= 2 then api.nvim_buf_add_highlight(buf, -1, "ContextSelectorTitle", total - 2, 0, -1) end
end

return M
