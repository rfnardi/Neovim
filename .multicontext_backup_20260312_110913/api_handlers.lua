local M = {}

-- BUG FIX #6: parser de texto Gemini melhorado
-- O padrão original [^"]+ falha com escapes como \\, \t, \r, etc.
-- A nova versão processa escapes JSON corretamente
local function decode_json_string(s)
    return s
        :gsub('\\n', '\n')
        :gsub('\\t', '\t')
        :gsub('\\r', '\r')
        :gsub('\\"', '"')
        :gsub('\\\\', '\\')
end

-- Extrai todos os valores de "text" de um chunk JSON parcial de forma robusta
local function extract_text_chunks(buffer)
    local results = {}
    local remaining = buffer
    while true do
        -- Encontra "text": seguido de string JSON (suporta escapes internos)
        local start_q = remaining:find('"text"%s*:%s*"')
        if not start_q then break end
        local str_start = remaining:find('"', start_q + 1) + 1  -- posição após a " de abertura
        local str_end = nil
        local i = str_start
        while i <= #remaining do
            local ch = remaining:sub(i, i)
            if ch == '\\' then
                i = i + 2  -- pula o caractere escapado
            elseif ch == '"' then
                str_end = i
                break
            else
                i = i + 1
            end
        end
        if not str_end then break end
        local raw = remaining:sub(str_start, str_end - 1)
        table.insert(results, decode_json_string(raw))
        remaining = remaining:sub(str_end + 1)
    end
    return results, remaining
end

M.gemini = {
    make_request = function(api_config, messages, api_keys, last_signature, callback)
        local api_key = api_keys[api_config.name] or ""
        local contents, system_instruction = {}, nil
        for _, msg in ipairs(messages) do
            if msg.role == "system" then
                system_instruction = { parts = {{ text = msg.content }} }
            else
                local part = { text = msg.content }
                if msg.role == "model" and last_signature then
                    part.thoughtSignature = last_signature
                end
                table.insert(contents, {
                    role = msg.role == "user" and "user" or "model",
                    parts = { part }
                })
            end
        end
        local payload = {
            contents = contents,
            system_instruction = system_instruction,
            generationConfig = { thinkingConfig = { thinkingLevel = "medium" } }
        }
        local url = api_config.url:gsub(":generateContent", ":streamGenerateContent")
        local cmd = {
            "curl", "-s", "-N", "-L", "-X", "POST",
            url .. "?key=" .. api_key,
            "-H", "Content-Type: application/json",
            "-d", vim.fn.json_encode(payload)
        }
        local partial_buffer = ""
        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                if not data then return end
                partial_buffer = partial_buffer .. table.concat(data, "")
                if partial_buffer:match('"error":') then
                    local msg = partial_buffer:match('"message":%s*"([^"]+)"') or "Erro de Cota"
                    callback(nil, msg, false)
                    return
                end
                -- BUG FIX #6: usa o novo extrator robusto
                local chunks, remaining = extract_text_chunks(partial_buffer)
                partial_buffer = remaining
                for _, chunk in ipairs(chunks) do
                    callback(chunk, nil, false)
                end
            end,
            on_exit = function() callback(nil, nil, true) end
        })
    end
}

-- BUG FIX #5: handler OpenAI agora respeita o header Authorization do config
-- Em vez de sempre adicionar "Bearer ", usa o valor do header definido na config,
-- substituindo {API_KEY} pela chave real
local function build_headers(api_config, api_key)
    local headers = {}
    for k, v in pairs(api_config.headers or {}) do
        local resolved = v:gsub("{API_KEY}", api_key)
        table.insert(headers, "-H")
        table.insert(headers, k .. ": " .. resolved)
    end
    return headers
end

M.openai = {
    make_request = function(api_config, messages, api_keys, _, callback)
        local api_key = api_keys[api_config.name] or ""
        local cmd = {
            "curl", "-s", "-N", "-L", "-X", "POST", api_config.url,
        }
        -- BUG FIX #5: injeta headers do config em vez de hardcodar Bearer
        for _, h in ipairs(build_headers(api_config, api_key)) do
            table.insert(cmd, h)
        end
        table.insert(cmd, "-d")
        table.insert(cmd, vim.fn.json_encode({
            model = api_config.model,
            messages = messages,
            stream = true
        }))
        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                for _, line in ipairs(data) do
                    if line:match("^data: ") and not line:match("%[DONE%]") then
                        local ok, decoded = pcall(vim.fn.json_decode, line:gsub("^data: ", ""))
                        if ok and decoded.choices and decoded.choices[1].delta then
                            callback(decoded.choices[1].delta.content, nil, false)
                        end
                    end
                end
            end,
            on_exit = function() callback(nil, nil, true) end
        })
    end
}

-- BUG FIX #3: handler Cloudflare ausente adicionado
-- A API Cloudflare não usa streaming SSE padrão; usa resposta JSON simples
M.cloudflare = {
    make_request = function(api_config, messages, api_keys, _, callback)
        local api_key = api_keys[api_config.name] or ""
        local cmd = {
            "curl", "-s", "-L", "-X", "POST", api_config.url,
            "-H", "Content-Type: application/json",
            "-H", "Authorization: Bearer " .. api_key,
            "-d", vim.fn.json_encode({ messages = messages })
        }
        local output = ""
        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                if data then output = output .. table.concat(data, "") end
            end,
            on_exit = function()
                local ok, decoded = pcall(vim.fn.json_decode, output)
                if ok and decoded and decoded.result and decoded.result.response then
                    callback(decoded.result.response, nil, false)
                else
                    local err = (ok and decoded and decoded.errors and decoded.errors[1] and decoded.errors[1].message) or "Erro Cloudflare"
                    callback(nil, err, false)
                end
                callback(nil, nil, true)
            end
        })
    end
}

return M
