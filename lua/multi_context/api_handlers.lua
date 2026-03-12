local M = {}
M.gemini = {
    make_request = function(api_config, messages, api_keys, last_signature, callback)
        local api_key = api_keys[api_config.name] or ""
        local contents, system_instruction = {}, nil
        for _, msg in ipairs(messages) do
            if msg.role == "system" then system_instruction = { parts = {{ text = msg.content }} }
            else
                local part = { text = msg.content }
                if msg.role == "model" and last_signature then part.thoughtSignature = last_signature end
                table.insert(contents, { role = msg.role == "user" and "user" or "model", parts = { part } })
            end
        end
        local payload = { contents = contents, system_instruction = system_instruction, generationConfig = { thinkingConfig = { thinkingLevel = "medium" } } }
        local url = api_config.url:gsub(":generateContent", ":streamGenerateContent")
        local cmd = {"curl", "-s", "-N", "-L", "-X", "POST", url .. "?key=" .. api_key, "-H", "Content-Type: application/json", "-d", vim.fn.json_encode(payload)}
        local partial_buffer = ""
        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                if not data then return end
                partial_buffer = partial_buffer .. table.concat(data, "")
                if partial_buffer:match('"error":') then
                    local msg = partial_buffer:match('"message":%s*"([^"]+)"') or "Erro de Cota"
                    callback(nil, msg, false) return
                end
                while true do
                    local start_idx, end_idx, text_match = partial_buffer:find('"text":%s*"([^"]+)"')
                    if not start_idx then break end
                    callback(text_match:gsub("\\n", "\n"):gsub("\\\"", "\""), nil, false)
                    partial_buffer = partial_buffer:sub(end_idx + 1)
                end
            end,
            on_exit = function() callback(nil, nil, true) end
        })
    end
}
M.openai = {
    make_request = function(api_config, messages, api_keys, _, callback)
        local api_key = api_keys[api_config.name] or ""
        local cmd = {"curl", "-s", "-N", "-L", "-X", "POST", api_config.url, "-H", "Content-Type: application/json", "-H", "Authorization: Bearer " .. api_key, "-d", vim.fn.json_encode({ model = api_config.model, messages = messages, stream = true })}
        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                for _, line in ipairs(data) do
                    if line:match("^data: ") and not line:match("%[DONE%]") then
                        local ok, decoded = pcall(vim.fn.json_decode, line:gsub("^data: ", ""))
                        if ok and decoded.choices then callback(decoded.choices[1].delta.content, nil, false) end
                    end
                end
            end,
            on_exit = function() callback(nil, nil, true) end
        })
    end
}
return M
