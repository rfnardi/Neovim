local M = {}

-- FASE 1: Tracker global de arquivos temporários para limpeza na saída
_G.MultiContextTempFiles = _G.MultiContextTempFiles or {}

local function decode_json_string(s)
    s = s:gsub("\\n", "\n"):gsub("\\t", "\t"):gsub("\\r", "\r"):gsub('\\"', '"')
    s = s:gsub("\\u(%x%x%x%x)", function(hex) return vim.fn.nr2char(tonumber(hex, 16)) end)
    s = s:gsub("\\\\", "\\")
    return s
end

local function extract_text_chunks(buffer)
    local results = {}; local remaining = buffer
    while true do
        local pos_start, pos_end = remaining:find('"text"%s*:%s*"')
        if not pos_start then break end
        local str_start = pos_end + 1
        local str_end = nil
        local i = str_start
        while i <= #remaining do
            local ch = remaining:sub(i, i)
            if ch == '\\' then i = i + 2
            elseif ch == '"' then str_end = i; break
            else i = i + 1 end
        end
        if not str_end then break end
        local inner_str = remaining:sub(str_start, str_end - 1)
        local ok, decoded = pcall(vim.fn.json_decode, '"' .. inner_str .. '"')
        if ok and type(decoded) == "string" then table.insert(results, decoded) else table.insert(results, decode_json_string(inner_str)) end
        remaining = remaining:sub(str_end + 1)
    end
    return results, remaining
end

local function header_args(api_config, api_key)
    local args = {}
    for k, v in pairs(api_config.headers or {}) do
        table.insert(args, "-H"); table.insert(args, k .. ": " .. v:gsub("{API_KEY}", api_key))
    end
    return args
end

local function write_payload_to_tmp(payload)
    local tmp_file = os.tmpname()
    table.insert(_G.MultiContextTempFiles, tmp_file)
    local f = io.open(tmp_file, "w")
    if f then f:write(vim.fn.json_encode(payload)); f:close() end
    return tmp_file
end

local function remove_tmp(file)
    os.remove(file)
    for i, f in ipairs(_G.MultiContextTempFiles) do
        if f == file then table.remove(_G.MultiContextTempFiles, i); break end
    end
end

M.gemini = {
    make_request = function(api_config, messages, api_keys, last_sig, callback)
        local api_key = api_keys[api_config.name] or ""
        if api_key == "" then callback("\n[ERRO]: Chave não encontrada para " .. api_config.name, nil, false); callback(nil, nil, true); return end
        local contents = {}; local system_instruction = nil
        for _, msg in ipairs(messages) do
            if msg.role == "system" then system_instruction = { parts = { { text = msg.content } } }
            else table.insert(contents, { role = (msg.role == "user") and "user" or "model", parts = { { text = msg.content } } }) end
        end
        local payload = { contents = contents }
        if system_instruction then payload.systemInstruction = system_instruction end
        local tmp_file = write_payload_to_tmp(payload)
        local cmd = { "curl", "-s", "-N", "-L", "-X", "POST", api_config.url:gsub(":generateContent", ":streamGenerateContent") .. "?key=" .. api_key, "-H", "Content-Type: application/json", "-d", "@" .. tmp_file }
        local buffer = ""; local full_response = ""
        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                if not data then return end
                local raw = table.concat(data, "\n")
                if raw == "" then return end
                buffer = buffer .. raw; full_response = full_response .. raw
                local chunks, rest = extract_text_chunks(buffer)
                for _, txt in ipairs(chunks) do callback(txt, nil, false) end
                buffer = rest
            end,
            on_exit = function()
                remove_tmp(tmp_file)
                if full_response:match('"error"') then
                    local ok, dec = pcall(vim.fn.json_decode, full_response)
                    if ok and dec.error and dec.error.message then callback("\n\n**[ERRO GEMINI]:** " .. dec.error.message .. "\n", nil, false) end
                end
                callback(nil, nil, true)
            end,
        })
    end,
}

M.openai = {
    make_request = function(api_config, messages, api_keys, _, callback)
        local api_key = api_keys[api_config.name] or ""
        -- Injeção do stream_options para capturar métricas de cache (OpenAI / DeepSeek)
        local payload = { model = api_config.model, messages = messages, stream = true, stream_options = { include_usage = true } }
        local tmp_file = write_payload_to_tmp(payload)
        local cmd = { "curl", "-s", "-N", "-L", "-X", "POST", api_config.url }
        for _, h in ipairs(header_args(api_config, api_key)) do table.insert(cmd, h) end
        table.insert(cmd, "-d"); table.insert(cmd, "@" .. tmp_file)
        local full_response = ""
        local metrics = nil
        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                if not data then return end
                for _, line in ipairs(data) do
                    full_response = full_response .. line .. "\n"
                    if line:match("^data: ") and not line:match("%[DONE%]") then
                        local ok, dec = pcall(vim.fn.json_decode, line:sub(7))
                        if ok then
                            if dec.choices and dec.choices[1] and dec.choices[1].delta and dec.choices[1].delta.content then
                                callback(dec.choices[1].delta.content, nil, false)
                            end
                            if dec.usage then
                                metrics = metrics or {}
                                -- Suporta tanto o padrao OpenAI quanto o DeepSeek
                                metrics.cache_read_input_tokens = (dec.usage.prompt_tokens_details and dec.usage.prompt_tokens_details.cached_tokens) or dec.usage.prompt_cache_hit_tokens or 0
                            end
                        end
                    end
                end
            end,
            on_exit = function() 
                remove_tmp(tmp_file)
                if full_response:match('"error"') and not full_response:match('"content"') then
                    local ok, dec = pcall(vim.fn.json_decode, full_response)
                    if ok and dec.error and dec.error.message then callback("\n\n**[ERRO OPENAI]:** " .. dec.error.message .. "\n", nil, false) end
                end
                callback(nil, nil, true, metrics) 
            end,
        })
    end,
}

M.anthropic = {
    make_request = function(api_config, messages, api_keys, _, callback)
        local api_key = api_keys[api_config.name] or ""
        local system_text = ""
        local anthropic_msgs = {}
        for _, msg in ipairs(messages) do
            if msg.role == "system" then
                system_text = system_text .. msg.content .. "\n"
            else
                table.insert(anthropic_msgs, {role = msg.role, content = msg.content})
            end
        end
        local payload = {
            model = api_config.model,
            messages = anthropic_msgs,
            system = {
                -- AQUI ESTÁ A MÁGICA: O cache_control inserido no último bloco do system_prompt
                { type = "text", text = vim.trim(system_text), cache_control = { type = "ephemeral" } }
            },
            stream = true,
            max_tokens = 4096
        }
        local tmp_file = write_payload_to_tmp(payload)
        local cmd = {
            "curl", "-s", "-N", "-L", "-X", "POST", api_config.url,
            "-H", "x-api-key: " .. api_key,
            "-H", "anthropic-version: 2023-06-01",
            "-H", "anthropic-beta: prompt-caching-2024-07-31",
            "-H", "content-type: application/json",
            "-d", "@" .. tmp_file
        }
        local full_response = ""
        local metrics = nil
        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                if not data then return end
                for _, line in ipairs(data) do
                    full_response = full_response .. line .. "\n"
                    if line:match("^data: ") then
                        local ok, dec = pcall(vim.fn.json_decode, line:sub(7))
                        if ok then
                            if dec.type == "content_block_delta" and dec.delta and dec.delta.text then
                                callback(dec.delta.text, nil, false)
                            elseif dec.type == "message_start" and dec.message and dec.message.usage then
                                metrics = metrics or {}
                                metrics.cache_read_input_tokens = dec.message.usage.cache_read_input_tokens or 0
                            end
                        end
                    end
                end
            end,
            on_exit = function()
                remove_tmp(tmp_file)
                if full_response:match('"error"') and not full_response:match('"type": "message_start"') then
                    local ok, dec = pcall(vim.fn.json_decode, full_response)
                    if ok and dec.error and dec.error.message then
                        callback("\n\n**[ERRO ANTHROPIC]:** " .. dec.error.message .. "\n", nil, false)
                    end
                end
                callback(nil, nil, true, metrics)
            end
        })
    end,
}

M.cloudflare = {
    make_request = function(api_config, messages, api_keys, _, callback)
        local api_key = api_keys[api_config.name] or ""
        local tmp_file = write_payload_to_tmp({ messages = messages })
        local output = ""
        local cmd = { "curl", "-s", "-L", "-X", "POST", api_config.url, "-H", "Content-Type: application/json", "-H", "Authorization: Bearer " .. api_key, "-d", "@" .. tmp_file }
        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data) if data then output = output .. table.concat(data, "\n") end end,
            on_exit = function()
                remove_tmp(tmp_file)
                local ok, dec = pcall(vim.fn.json_decode, output)
                if ok and dec and dec.result and dec.result.response then callback(dec.result.response, nil, false)
                elseif output:match('"errors"') then callback("\n\n**[ERRO CLOUDFLARE]:** Falha na API\n", nil, false) end
                callback(nil, nil, true)
            end,
        })
    end,
}

return M
