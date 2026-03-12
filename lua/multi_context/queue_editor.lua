local api = vim.api
local utils = require('multi_context.utils')
local M = {}

M.save_queue = function(buf, win, api_config)
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    local reordered = {}
    for _, name in ipairs(lines) do
        for _, a in ipairs(api_config.apis) do if a.name == name then table.insert(reordered, a) break end end
    end
    api_config.apis = reordered
    local path = require('multi_context.config').options.config_path
    local raw = vim.fn.json_encode(api_config)
    local formatted = vim.fn.system(string.format("echo %s | jq .", vim.fn.shellescape(raw)))
    local f = io.open(path, 'w')
    if f then 
        f:write(formatted); f:close(); 
        vim.notify("✅ Fila Salva!"); 
        vim.bo[buf].modified = false; 
        api.nvim_win_close(win, true) 
    end
end

M.open_editor = function()
    local cfg = utils.load_api_config()
    local buf = api.nvim_create_buf(false, true)
    local names = {}
    for _, a in ipairs(cfg.apis) do table.insert(names, a.name) end
    api.nvim_buf_set_lines(buf, 0, -1, false, names)
    
    -- O SEGREDO CONTRA O E32: acwrite e nome fictício
    vim.bo[buf].buftype = 'acwrite'
    api.nvim_buf_set_name(buf, "MultiContext_Queue_Editor")
    
    local win = api.nvim_open_win(buf, true, { relative='editor', width=45, height=#names+2, row=5, col=10, border='rounded', title=' Ordenar Fila ' })
    
    api.nvim_create_autocmd("BufWriteCmd", { 
        buffer = buf, 
        callback = function() M.save_queue(buf, win, cfg) end 
    })
    
    api.nvim_buf_set_keymap(buf, "n", "q", ":q!<CR>", { noremap = true, silent = true })
end
return M
