-- context_builders.lua
-- Coleta dados do editor/sistema para montar o contexto enviado à IA.
-- Módulo puramente de coleta: sem efeitos colaterais em UI ou API.
local M   = {}
local api = vim.api

local function strip_ansi(s)
    return s:gsub("\27%[[%d;]*m", ""):gsub("\27%[[%d;]*[A-Za-z]", "")
end

M.get_git_diff = function()
    vim.fn.system("git rev-parse --show-toplevel")
    if vim.v.shell_error ~= 0 then return "=== Não é um repositório Git ===" end
    local diff = vim.fn.system("git -c color.ui=never -c color.diff=never diff HEAD")
    return "=== GIT DIFF ===\n" .. strip_ansi(diff)
end

M.get_tree_context = function()
    local dir   = vim.fn.expand('%:p:h')
    local tree  = strip_ansi(vim.fn.system("tree -f --noreport " .. vim.fn.shellescape(dir)))
    local ctx   = { "=== TREE E CONTEÚDO ===", tree }
    local found = vim.fn.split(
        vim.fn.system("find " .. vim.fn.shellescape(dir) .. " -maxdepth 2 -type f"), "\n"
    )
    for _, f in ipairs(found) do
        if not f:match("/%.git/") and f ~= "" then
            table.insert(ctx, "")
            table.insert(ctx, "== Arquivo: " .. f .. " ==")
            local ok, lines = pcall(vim.fn.readfile, f)
            if ok then
                for _, l in ipairs(lines) do table.insert(ctx, l) end
            end
        end
    end
    return table.concat(ctx, "\n")
end

M.get_all_buffers_content = function()
    local result = {}
    for _, bufnr in ipairs(api.nvim_list_bufs()) do
        if api.nvim_buf_is_loaded(bufnr) then
            local name  = api.nvim_buf_get_name(bufnr)
            local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
            if #lines > 0 and name ~= "" then
                table.insert(result, "=== Buffer: " .. name .. " ===")
                vim.list_extend(result, lines)
                table.insert(result, "")
            end
        end
    end
    return table.concat(result, "\n")
end

M.get_current_buffer = function()
    local buf = api.nvim_get_current_buf()
    return "=== BUFFER ATUAL ===\n"
        .. table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

-- line1/line2: números de linha (1-indexed). Se omitidos, usa a seleção visual.
M.get_visual_selection = function(line1, line2)
    local buf = api.nvim_get_current_buf()
    local s   = tonumber(line1) or vim.fn.getpos("'<")[2]
    local e   = tonumber(line2) or vim.fn.getpos("'>")[2]
    if s > e then s, e = e, s end
    return "=== SELEÇÃO (linhas " .. s .. "-" .. e .. ") ===\n"
        .. table.concat(api.nvim_buf_get_lines(buf, s - 1, e, false), "\n")
end

-- Pega os arquivos apenas na pasta atual de trabalho (sem subpastas/árvore)
M.get_folder_context = function()
    local dir = vim.fn.getcwd()
    local found = vim.fn.split(
        vim.fn.system("find " .. vim.fn.shellescape(dir) .. " -maxdepth 1 -type f"), "\n"
    )
    
    local ctx = { "=== CONTEÚDO DA PASTA ATUAL (" .. dir .. ") ===" }
    for _, f in ipairs(found) do
        if not f:match("/%.git/") and f ~= "" then
            table.insert(ctx, "")
            table.insert(ctx, "== Arquivo: " .. f .. " ==")
            local ok, lines = pcall(vim.fn.readfile, f)
            if ok then
                for _, l in ipairs(lines) do table.insert(ctx, l) end
            end
        end
    end
    return table.concat(ctx, "\n")
end

-- Pega TODOS os arquivos trackeados pelo repositório Git atual
M.get_repo_context = function()
    vim.fn.system("git rev-parse --show-toplevel")
    if vim.v.shell_error ~= 0 then return "=== Não é um repositório Git ===" end
    
    -- Descobre a raiz do repo
    local root = vim.fn.system("git rev-parse --show-toplevel"):gsub("\n", "")
    -- Usa ls-files para pegar os arquivos gerenciados pelo Git (ignora node_modules/binários ignorados, etc)
    local tracked_files = vim.fn.split(vim.fn.system("git -C " .. vim.fn.shellescape(root) .. " ls-files"), "\n")
    
    local ctx = { "=== CONTEÚDO DE TODO O REPOSITÓRIO GIT ===" }
    for _, f in ipairs(tracked_files) do
        if f ~= "" then
            local full_path = root .. "/" .. f
            table.insert(ctx, "")
            table.insert(ctx, "== Arquivo: " .. f .. " ==")
            local ok, lines = pcall(vim.fn.readfile, full_path)
            if ok then
                for _, l in ipairs(lines) do table.insert(ctx, l) end
            end
        end
    end
    return table.concat(ctx, "\n")
end

return M
