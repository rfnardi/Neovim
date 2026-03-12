local M = {}
local api, popup, utils = vim.api, require('multi_context.popup'), require('multi_context.utils')
local function start(content)
    local buf, win = popup.create_popup()
    local lines = utils.split_lines(content)
    api.nvim_buf_set_lines(buf, 0, 0, false, lines)
    api.nvim_win_set_cursor(win, {api.nvim_buf_line_count(buf), 0})
end
M.ContextChatHandler = function()
    local buf = api.nvim_get_current_buf()
    local mode = api.nvim_get_mode().mode
    if mode == 'v' or mode == 'V' then
        local s, e = vim.fn.getpos("v")[2], vim.fn.getpos(".")[2]
        if s > e then s, e = e, s end
        start("=== SELEÇÃO ===\n" .. table.concat(api.nvim_buf_get_lines(buf, s-1, e, false), "\n"))
    else start("=== BUFFER ATUAL ===\n" .. table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")) end
end
M.ContextChatFull = function() start("") end
M.ContextBuffers = function() start(utils.get_all_buffers_content()) end
M.ContextTree = function() start(utils.get_tree_context()) end
M.ContextChatGit = function() start(utils.get_git_diff()) end
M.ContextApis = function()
    local cfg = utils.load_api_config()
    local names = {}
    for _, a in ipairs(cfg.apis) do table.insert(names, a.name) end
    vim.ui.select(names, {prompt='API Principal:'}, function(c) if c then require('multi_context.utils').set_selected_api(c); vim.notify("API: "..c) end end)
end
return M
