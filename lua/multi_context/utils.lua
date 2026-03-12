local api = vim.api
local M = {}
M.ns_id = api.nvim_create_namespace("multi_context_highlights")

M.load_api_config = function()
    local path = require('multi_context.config').options.config_path
    local file = io.open(path, 'r')
    if not file then return nil end
    local content = file:read('*a'); file:close()
    return vim.fn.json_decode(content)
end

M.load_api_keys = function()
    local path = require('multi_context.config').options.api_keys_path
    local file = io.open(path, 'r')
    if not file then return {} end
    local content = file:read('*a'); file:close()
    return vim.fn.json_decode(content) or {}
end

M.set_selected_api = function(api_name)
    local cfg = M.load_api_config()
    if not cfg then return false end
    cfg.default_api = api_name
    local raw = vim.fn.json_encode(cfg)
    local formatted = vim.fn.system(string.format("echo %s | jq .", vim.fn.shellescape(raw)))
    local f = io.open(require('multi_context.config').options.config_path, 'w')
    if f then f:write(formatted); f:close(); return true end
    return false
end

M.split_lines = function(s)
    local t = {}
    if not s or s == "" then return t end
    for l in s:gmatch("([^\n]*)\n?") do table.insert(t, l) end
    return t
end

-- A FUNÇÃO QUE FALTAVA
M.get_git_diff = function()
    local root = vim.fn.system("git rev-parse --show-toplevel"):gsub("\n", "")
    if vim.v.shell_error ~= 0 then return "=== Não é um repositório Git ===" end
    return "=== GIT DIFF ===\n" .. vim.fn.system("git diff HEAD")
end

M.get_tree_context = function()
    local dir = vim.fn.expand('%:p:h')
    local tree = vim.fn.system("tree -f " .. vim.fn.shellescape(dir))
    local ctx = { "=== TREE E CONTEÚDO ===\n", tree }
    local files = vim.fn.split(vim.fn.system("find " .. vim.fn.shellescape(dir) .. " -maxdepth 2 -type f"), "\n")
    for _, f in ipairs(files) do
        if not f:match("/%.git/") then
            table.insert(ctx, "== Arquivo: " .. f)
            local ok, content = pcall(vim.fn.readfile, f)
            if ok then for _, l in ipairs(content) do table.insert(ctx, l) end end
        end
    end
    return table.concat(ctx, "\n")
end

M.find_last_user_line = function(buf)
    local name = require('multi_context.config').options.user_name
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    for i = #lines, 1, -1 do if lines[i]:match("^## " .. name .. " >>") then return i - 1, lines[i] end end
    return nil
end

M.apply_highlights = function(buf)
    api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    for i, l in ipairs(lines) do if l:match("^## IA") then api.nvim_buf_set_extmark(buf, M.ns_id, i-1, 0, { end_col = #l, hl_group = "DiagnosticInfo" }) end end
end

M.copy_code_block = function()
    local buf = api.nvim_get_current_buf()
    local cursor = api.nvim_win_get_cursor(0)[1]
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    local s, e = nil, nil
    for i = cursor, 1, -1 do if lines[i] and lines[i]:match("^```") then s = i break end end
    for i = cursor, #lines do if lines[i] and lines[i]:match("^```") and i ~= s then e = i break end end
    if s and e then
        vim.fn.setreg('+', table.concat(api.nvim_buf_get_lines(buf, s, e - 1, false), "\n"))
        vim.notify("🚀 Código copiado!")
    end
end

return M
