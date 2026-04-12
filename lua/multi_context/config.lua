-- lua/multi_context/config.lua
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
        title  = " 🤖 MultiContext AI ",
    },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(user_opts)
    M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
    if M.options.config_path then M.options.config_path = vim.fn.expand(M.options.config_path) end
    if M.options.api_keys_path then M.options.api_keys_path = vim.fn.expand(M.options.api_keys_path) end
end

M.load_api_config = function()
    local f = io.open(M.options.config_path, 'r')
    if not f then 
        vim.notify("MultiContext: Não foi possível abrir o arquivo:\n" .. tostring(M.options.config_path), vim.log.levels.ERROR)
        return nil 
    end
    local content = f:read('*a'); f:close()
    local ok, parsed = pcall(vim.fn.json_decode, content)
    if not ok then return nil end
    return parsed
end

M.load_api_keys = function()
    local f = io.open(M.options.api_keys_path, 'r')
    if not f then return {} end
    local content = f:read('*a'); f:close()
    local ok, parsed = pcall(vim.fn.json_decode, content)
    return ok and parsed or {}
end

M.save_api_config = function(cfg)
    local raw = vim.fn.json_encode(cfg)
    local formatted = vim.fn.system(string.format("echo %s | jq .", vim.fn.shellescape(raw)))
    if vim.v.shell_error ~= 0 then formatted = raw end
    local f = io.open(M.options.config_path, 'w')
    if not f then return false end
    f:write(formatted); f:close()
    return true
end

M.set_selected_api = function(api_name)
    local cfg = M.load_api_config()
    if not cfg then return false end
    cfg.default_api = api_name
    return M.save_api_config(cfg)
end

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
