-- conversation.lua
-- Lê o buffer de chat e reconstrói o histórico de mensagens para a API.
local M   = {}
local api = vim.api

-- Retorna o índice (0-based) da última linha que começa com o prompt do usuário.
M.find_last_user_line = function(buf)
    local name  = require('multi_context.config').options.user_name
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    for i = #lines, 1, -1 do
        if lines[i]:match("^## " .. name .. " >>") then
            return i - 1, lines[i]
        end
    end
    return nil
end

-- Percorre o buffer e monta o array {role, content}[] completo.
M.build_history = function(buf)
    local config    = require('multi_context.config')
    local user_name = config.options.user_name
    local lines     = api.nvim_buf_get_lines(buf, 0, -1, false)

    local messages  = {}
    local role      = nil
    local acc       = {}
    local user_pat  = "^## " .. user_name .. " >>"

    local function flush()
        if role and #acc > 0 then
            local text = table.concat(acc, "\n"):match("^%s*(.-)%s*$")
            if text ~= "" then
                table.insert(messages, { role = role, content = text })
            end
        end
        acc = {}
    end

    for _, line in ipairs(lines) do
        if line:match(user_pat) then
            flush()
            role     = "user"
            local body = line:gsub(user_pat .. "%s*", "")
            if body ~= "" then table.insert(acc, body) end
        elseif line:match("^## IA >>") then
            flush()
            role = "assistant"
        elseif line:match("^## API atual:") then
            -- metadado de rodapé, ignora
        else
            if role then table.insert(acc, line) end
        end
    end
    flush()
    return messages
end

return M
