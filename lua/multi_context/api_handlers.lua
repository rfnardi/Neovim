-- api_handlers.lua
-- Adaptadores de protocolo HTTP para cada provider.
-- Recebe um payload pronto e devolve chunks via callback(text, err, done).
local M = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function decode_json_string(s)
    s = s:gsub("\\n",  "\n")
    s = s:gsub("\\t",  "\t")
    s = s:gsub("\\r",  "\r")
    s = s:gsub('\\"',  '"')
    s = s:gsub("\\\\", "\\")
    return s
end

-- Extrai todos os valores de "text" de um chunk SSE parcial,
-- respeitando escapes JSON internos. Retorna (chunks[], buffer_restante).
local function extract_text_chunks(buffer)
    local results   = {}
    local remaining = buffer
    while true do
        local pos = remaining:find('"text"%s*:%s*"')
        if not pos then break end
        local str_start = remaining:find('"', pos + 1) + 1
        local str_end   = nil
        local i = str_start
        while i <= #remaining do
            local ch = remaining:sub(i, i)
            if     ch == '\\' then i = i + 2
            elseif ch == '"'  then str_end = i; break
            else                   i = i + 1
            end
        end
        if not str_end then break end
        table.insert(results, decode_json_string(remaining:sub(str_start, str_end - 1)))
        remaining = remaining:sub(str_end + 1)
    end
    return results, remaining
end

-- Constrói args -H para curl a partir dos headers do config,
-- substituindo {API_KEY} pela chave real.
local function header_args(api_config, api_key)
    local args = {}
    for k, v in pairs(api_config.headers or {}) do
        table.insert(args, "-H")
        table.insert(args, k .. ": " .. v:gsub("{API_KEY}", api_key))
    end
    return args
end

-- ── Gemini ────────────────────────────────────────────────────────────────────

-- ── Gemini ────────────────────────────────────────────────────────────────────

M.gemini = {
    make_request = function(api_config, messages, api_keys, last_sig, callback)
        local api_key  = api_keys[api_config.name] or ""
        
        -- DEBUG: Verificar se a chave está chegando
        if api_key == "" then 
            vim.notify("ERRO: Chave para " .. api_config.name .. " está vazia!", 3) 
        end

        local contents = {}
        for _, msg in ipairs(messages) do
            if msg.role ~= "system" then
                table.insert(contents, {
                    role  = (msg.role == "user") and "user" or "model",
                    parts = { { text = msg.content } },
                })
            end
        end

        local payload = { contents = contents }
        local url = api_config.url:gsub(":generateContent", ":streamGenerateContent")
        
        local cmd = {
            "curl", "-s", "-N", "-L", "-X", "POST",
            url .. "?key=" .. api_key,
            "-H", "Content-Type: application/json",
            "-d", vim.fn.json_encode(payload),
        }

        local buffer = ""
        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                if not data then return end
                local raw = table.concat(data, "")
                if raw == "" then return end
                buffer = buffer .. raw
                local chunks, rest = extract_text_chunks(buffer)
                for _, txt in ipairs(chunks) do
                    callback(txt, nil, false)
                end
                buffer = rest
            end,
            on_stderr = function(_, data)
                local err = table.concat(data, "")
                if err ~= "" and not err:match("%%") then
                    print("DEBUG CURL ERR: " .. err)
                end
            end,
            on_exit = function(_, code)
                -- print("DEBUG JOB EXIT: " .. code)
                callback(nil, nil, true)
            end,
        })
    end,
}

-- ── OpenAI-compatible (OpenAI, Moonshot/Kimi, DeepSeek, Groq, OpenRouter…) ────

M.openai = {
    make_request = function(api_config, messages, api_keys, _, callback)
        local api_key = api_keys[api_config.name] or ""
        local cmd     = { "curl", "-s", "-N", "-L", "-X", "POST", api_config.url }
        for _, h in ipairs(header_args(api_config, api_key)) do
            table.insert(cmd, h)
        end
        table.insert(cmd, "-d")
        table.insert(cmd, vim.fn.json_encode({
            model    = api_config.model,
            messages = messages,
            stream   = true,
        }))

        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                if not data then return end
                local raw = table.concat(data, "")
                if raw == "" then return end
                buffer = buffer .. raw
                local chunks, rest = extract_text_chunks(buffer)
                for _, txt in ipairs(chunks) do
                    callback(txt, nil, false)
                end
                buffer = rest
            end,
            on_exit = function() callback(nil, nil, true) end,
        })
    end,
}

-- ── Cloudflare Workers AI ─────────────────────────────────────────────────────

M.cloudflare = {
    make_request = function(api_config, messages, api_keys, _, callback)
        local api_key = api_keys[api_config.name] or ""
        local cmd = {
            "curl", "-s", "-L", "-X", "POST", api_config.url,
            "-H", "Content-Type: application/json",
            "-H", "Authorization: Bearer " .. api_key,
            "-d", vim.fn.json_encode({ messages = messages }),
        }
        local output = ""
        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                if not data then return end
                local raw = table.concat(data, "")
                if raw == "" then return end
                buffer = buffer .. raw
                local chunks, rest = extract_text_chunks(buffer)
                for _, txt in ipairs(chunks) do
                    callback(txt, nil, false)
                end
                buffer = rest
            end,
            on_exit = function()
                local ok, dec = pcall(vim.fn.json_decode, output)
                if ok and dec and dec.result and dec.result.response then
                    callback(dec.result.response, nil, false)
                else
                    local err = ok and dec and dec.errors
                              and dec.errors[1] and dec.errors[1].message
                              or "Erro Cloudflare"
                    callback(nil, err, false)
                end
                callback(nil, nil, true)
            end,
        })
    end,
}

return M
