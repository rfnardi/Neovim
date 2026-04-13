local M = {}
local api = vim.api

-- Regex hiper tolerantes para não quebrar em exports .mctx formatados de forma estranha
local user_pat = "^##%s*([%w_]+)%s*>>"
local ia_pat   = "^##%s*IA.*>>"

M.find_last_user_line = function(buf)
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    for i = #lines, 1, -1 do
        if lines[i]:match(user_pat) then return i - 1, lines[i] end
    end
    return nil
end

M.build_history = function(buf_or_lines)
    local lines = type(buf_or_lines) == "table" and buf_or_lines or api.nvim_buf_get_lines(buf_or_lines, 0, -1, false)
    local messages = {}; local role = nil; local acc = {}

    local function flush()
        if role and #acc > 0 then
            local text = table.concat(acc, "\n"):match("^%s*(.-)%s*$")
            if text ~= "" then table.insert(messages, { role = role, content = text }) end
        end
        acc = {}
    end

    for _, line in ipairs(lines) do
        if line:match(user_pat) then
            flush(); role = "user"
            local body = line:gsub(user_pat .. "%s*", "")
            if body ~= "" then table.insert(acc, body) end
        elseif line:match(ia_pat) then
            flush(); role = "assistant"
        elseif not line:match("^## API atual:") then
            if role then table.insert(acc, line) end
        end
    end
    flush()
    return messages
end
return M
