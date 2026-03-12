-- config.lua
-- Responsabilidade única: opções do plugin e I/O de configuração JSON.
local M = {}

M.defaults = {
    user_name     = "Nardi",
    config_path   = vim.fn.stdpath("config") .. "/context_apis.json",
    api_keys_path = vim.fn.stdpath("config") .. "/api_keys.json",
    default_api   = nil,
    appearance    = {
        border = "rounded",
        width  = 0.7,
        height = 0.7,
        title  = " MultiContext - Chat ",
    },
}

M.options = {}

function M.setup(user_opts)
    M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

-- ── Leitura ───────────────────────────────────────────────────────────────────

M.load_api_config = function()
    local file = io.open(M.options.config_path, 'r')
    if not file then return nil end
    local content = file:read('*a')
    file:close()
    return vim.fn.json_decode(content)
end

M.load_api_keys = function()
    local file = io.open(M.options.api_keys_path, 'r')
    if not file then return {} end
    local content = file:read('*a')
    file:close()
    return vim.fn.json_decode(content) or {}
end

-- ── Escrita ───────────────────────────────────────────────────────────────────

M.save_api_config = function(cfg)
    local raw       = vim.fn.json_encode(cfg)
    local formatted = vim.fn.system(string.format("echo %s | jq .", vim.fn.shellescape(raw)))
    local f = io.open(M.options.config_path, 'w')
    if not f then return false end
    f:write(formatted)
    f:close()
    return true
end

M.set_selected_api = function(api_name)
    local cfg = M.load_api_config()
    if not cfg then return false end
    cfg.default_api = api_name
    return M.save_api_config(cfg)
end

-- ── Consultas ─────────────────────────────────────────────────────────────────

M.get_api_names = function()
    local cfg = M.load_api_config()
    if not cfg then return {} end
    local names = {}
    for _, a in ipairs(cfg.apis) do table.insert(names, a.name) end
    return names
end

M.get_current_api = function()
    local cfg = M.load_api_config()
    if not cfg then return "" end
    return cfg.default_api or ""
end

return M
