local M = {}

M.defaults = {
    user_name = "Nardi",
    config_path = vim.fn.stdpath("config") .. "/context_apis.json",
    api_keys_path = vim.fn.stdpath("config") .. "/api_keys.json",
    default_api = nil, -- Se nil, usa o do JSON
    appearance = {
        border = "rounded",
        width = 0.7,
        height = 0.7,
        title = " MultiContext - Chat ",
    }
}

M.options = {}

function M.setup(user_opts)
    M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
