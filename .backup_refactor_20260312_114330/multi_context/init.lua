local M = {}
local config = require('multi_context.config')
local utils = require('multi_context.utils')
local popup = require('multi_context.popup')
local commands = require('multi_context.commands')
local api_handlers = require('multi_context.api_handlers')

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
M.TogglePopup = function()
    if popup.popup_win and vim.api.nvim_win_is_valid(popup.popup_win) then
        vim.api.nvim_win_close(popup.popup_win, true)
    else
        M.ContextChatHandler()
    end
end

-- BUG FIX #4: constrói o histórico completo de conversas a partir do buffer
-- Antes enviava apenas a última mensagem, tornando a IA sem memória de contexto
local function build_conversation_history(buf, user_name)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local messages = {}
    local current_role = nil
    local current_lines = {}
    local user_prefix = "## " .. user_name .. " >>"
    local ia_prefix = "## IA >>"
    local api_prefix = "## API atual:"

    local function flush()
        if current_role and #current_lines > 0 then
            local text = table.concat(current_lines, "\n"):match("^%s*(.-)%s*$")
            if text ~= "" then
                table.insert(messages, { role = current_role, content = text })
            end
        end
        current_lines = {}
    end

    for _, line in ipairs(lines) do
        if line:match("^" .. user_prefix) then
            flush()
            current_role = "user"
            local content = line:gsub("^" .. user_prefix .. "%s*", "")
            if content ~= "" then table.insert(current_lines, content) end
        elseif line:match("^" .. ia_prefix) then
            flush()
            current_role = "assistant"
        elseif line:match("^" .. api_prefix) then
            -- linha de metadado, ignora
        else
            if current_role then
                table.insert(current_lines, line)
            end
        end
    end
    flush()
    return messages
end

M.SendFromPopup = function()
    local buf = popup.popup_buf
    if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

    local user_name = config.options.user_name
    local user_prefix = "## " .. user_name .. " >>"

    -- BUG FIX #4: constrói histórico completo
    local messages = build_conversation_history(buf, user_name)

    -- A última mensagem deve ser do usuário e não pode estar vazia
    if #messages == 0 or messages[#messages].role ~= "user" or messages[#messages].content == "" then
        return
    end

    -- Adiciona bloco de resposta da IA
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "", "## IA >> ", "" })
    local resp_line = vim.api.nvim_buf_line_count(buf) - 1

    local cfg = utils.load_api_config()
    local queue = {}
    for _, a in ipairs(cfg.apis) do
        if a.name == cfg.default_api then
            table.insert(queue, a)
            break
        end
    end
    if cfg.fallback_mode then
        for _, a in ipairs(cfg.apis) do
            if a['include_in_fall-back_mode'] and a.name ~= cfg.default_api then
                table.insert(queue, a)
            end
        end
    end

    local function execute(idx)
        if idx > #queue then
            vim.notify("❌ Erro em todas as APIs.", 4)
            return
        end
        local current = queue[idx]
        local current_resp = ""
        local handler = api_handlers[current.api_type or "openai"]
        if not handler then
            vim.notify("⚠️ Handler não encontrado para api_type: " .. (current.api_type or "?"), 3)
            execute(idx + 1)
            return
        end
        -- BUG FIX #4: passa o histórico completo, não só a última mensagem
        handler.make_request(current, messages, utils.load_api_keys(), nil, function(content, err, done)
            vim.schedule(function()
                if err then
                    execute(idx + 1)
                    return
                end
                if content then
                    current_resp = current_resp .. content
                    vim.api.nvim_buf_set_lines(buf, resp_line, -1, false, utils.split_lines(current_resp))
                end
                if done then
                    utils.insert_after(buf, -1, { "", "## API atual: " .. current.name, user_prefix .. " " })
                end
            end)
        end)
    end
    execute(1)
end


-- FIX: ToggleWorkspaceView estava ausente (causava erro no <A-w>)
M.ToggleWorkspaceView = function()
    -- Abre o contexto do diretório atual como workspace view
    M.ContextTree()
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
