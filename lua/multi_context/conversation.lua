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
    local orphaned_text = {} -- NOVO: Guarda o texto injetado pelos comandos :Context

    local function flush()
        if role and #acc > 0 then
            local text = table.concat(acc, "\n"):match("^%s*(.-)%s*$")
            if text ~= "" then 
                -- MÁGICA 1: Se houver texto injetado no topo (ex: git diff), mescla na 1ª msg do usuário
                if role == "user" and #orphaned_text > 0 then
                    text = table.concat(orphaned_text, "\n") .. "\n\n" .. text
                    orphaned_text = {}
                end
                
                -- MÁGICA 2: Previne 2 mensagens seguidas com mesmo papel (evita crash na Anthropic)
                if #messages > 0 and messages[#messages].role == role then
                    messages[#messages].content = messages[#messages].content .. "\n\n" .. text
                else
                    table.insert(messages, { role = role, content = text })
                end
            end
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
            if role then 
                table.insert(acc, line) 
            else
                -- Coleta texto antes da primeira tag (o contexto injetado pelos comandos :Context*)
                if line:match("%S") then table.insert(orphaned_text, line) end
            end
        end
    end
    flush()
    
    -- Fallback: Se sobrou texto órfão e não havia NENHUMA tag anterior no histórico
    if #orphaned_text > 0 then
        local text = table.concat(orphaned_text, "\n"):match("^%s*(.-)%s*$")
        if text ~= "" then
            table.insert(messages, { role = "user", content = text })
        end
    end
    
    return messages
end
return M
