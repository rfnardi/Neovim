local M = {}
local config, utils, popup, commands, api_handlers = require('multi_context.config'), require('multi_context.utils'), require('multi_context.popup'), require('multi_context.commands'), require('multi_context.api_handlers')
M.setup = function(opts) config.setup(opts) end
M.Context = commands.ContextChatHandler
M.ContextChatFull = commands.ContextChatFull
M.ContextChatHandler = commands.ContextChatHandler
M.ContextBuffers = commands.ContextBuffers
M.ContextChatFolder = commands.ContextTree
M.ContextFolder = commands.ContextTree
M.ContextChatGit = commands.ContextChatGit
M.ContextGit = commands.ContextChatGit
M.ContextTree = commands.ContextTree
M.ContextRepo = commands.ContextTree
M.ContextChatRepo = commands.ContextTree
M.ContextApis = commands.ContextApis
M.ContextQueue = function() require('multi_context.queue_editor').open_editor() end
M.TogglePopup = function() if popup.popup_win and vim.api.nvim_win_is_valid(popup.popup_win) then vim.api.nvim_win_close(popup.popup_win, true) else M.ContextChatHandler() end end
M.SendFromPopup = function()
    local buf = popup.popup_buf
    local user_prefix = "## " .. config.options.user_name .. " >>"
    local start_idx = utils.find_last_user_line(buf)
    local user_text = table.concat(vim.api.nvim_buf_get_lines(buf, start_idx, -1, false), "\n"):gsub("^"..user_prefix.."%s*", "")
    if user_text == "" then return end
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "", "## IA >> ", "" })
    local resp_line = vim.api.nvim_buf_line_count(buf) - 1
    local cfg = utils.load_api_config()
    local queue = {}
    for _, a in ipairs(cfg.apis) do if a.name == cfg.default_api then table.insert(queue, a) break end end
    if cfg.fallback_mode then for _, a in ipairs(cfg.apis) do if a['include_in_fall-back_mode'] and a.name ~= cfg.default_api then table.insert(queue, a) end end end
    local function execute(idx)
        if idx > #queue then vim.notify("❌ Erro em todas as APIs.", 4) return end
        local current, current_resp = queue[idx], ""
        api_handlers[current.api_type or "openai"].make_request(current, {{role="user", content=user_text}}, utils.load_api_keys(), nil, function(content, err, done)
            vim.schedule(function()
                if err then execute(idx + 1) return end
                if content then current_resp = current_resp .. content; vim.api.nvim_buf_set_lines(buf, resp_line, -1, false, utils.split_lines(current_resp)) end
                if done then utils.insert_after(buf, -1, { "", "## API atual: " .. current.name, user_prefix .. " " }) end
            end)
        end)
    end
    execute(1)
end
vim.cmd([[
  command! Context lua require('multi_context').Context()
  command! ContextBuffers lua require('multi_context').ContextBuffers()
  command! ContextTree lua require('multi_context').ContextTree()
  command! ContextRepo lua require('multi_context').ContextRepo()
  command! ContextApis lua require('multi_context').ContextApis()
  command! ContextQueue lua require('multi_context').ContextQueue()
]])
return M
