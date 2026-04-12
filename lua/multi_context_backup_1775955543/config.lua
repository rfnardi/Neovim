-- lua/multi_context/config.lua
-- Responsabilidade única: opções do plugin e I/O de configuração JSON.
local M = {}

M.defaults = {
    user_name     = "Nardi",
    config_path   = vim.fn.expand("~/.config/nvim/context_apis.json"),
    api_keys_path = vim.fn.expand("~/.config/nvim/api_keys.json"),
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
    
    -- Garante que caminhos com "~" sejam sempre expandidos
    if M.options.config_path then
        M.options.config_path = vim.fn.expand(M.options.config_path)
    end
    if M.options.api_keys_path then
        M.options.api_keys_path = vim.fn.expand(M.options.api_keys_path)
    end
end

-- ── Leitura ───────────────────────────────────────────────────────────────────

M.load_api_config = function()
    local path = M.options.config_path
    local file = io.open(path, 'r')
    
    if not file then 
        vim.notify("MultiContext: Não foi possível abrir o arquivo:\n" .. tostring(path), vim.log.levels.ERROR)
        return nil 
    end
    
    local content = file:read('*a')
    file:close()
    
    -- Usa pcall para evitar que um JSON mal formatado quebre o Neovim
    local ok, parsed = pcall(vim.fn.json_decode, content)
    if not ok then
        vim.notify("MultiContext: Erro de sintaxe no JSON em:\n" .. tostring(path), vim.log.levels.ERROR)
        return nil
    end
    
    return parsed
end

M.load_api_keys = function()
    local path = M.options.api_keys_path
    local file = io.open(path, 'r')
    
    if not file then 
        -- API Keys é opcional em alguns fluxos, então apenas avisa (WARN)
        vim.notify("MultiContext: Não encontrou arquivo de chaves:\n" .. tostring(path), vim.log.levels.WARN)
        return {} 
    end
    
    local content = file:read('*a')
    file:close()
    
    local ok, parsed = pcall(vim.fn.json_decode, content)
    if not ok then
        vim.notify("MultiContext: Erro de sintaxe no JSON de chaves", vim.log.levels.ERROR)
        return {}
    end
    
    return parsed or {}
end

-- ── Escrita ───────────────────────────────────────────────────────────────────

M.save_api_config = function(cfg)
    local raw       = vim.fn.json_encode(cfg)
    -- Tenta usar o jq para salvar o JSON bonitinho, formatado
    local formatted = vim.fn.system(string.format("echo %s | jq .", vim.fn.shellescape(raw)))
    
    -- Fallback: se o comando falhar (ex: jq não instalado), salva o raw mesmo
    if vim.v.shell_error ~= 0 then
        formatted = raw
    end
    
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
