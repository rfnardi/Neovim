local M = {}

local function decode_json_string(s)
    -- Fallback manual (agora suporta unicode também)
    s = s:gsub("\\n",  "\n")
    s = s:gsub("\\t",  "\t")
    s = s:gsub("\\r",  "\r")
    s = s:gsub('\\"',  '"')
    s = s:gsub("\\u(%x%x%x%x)", function(hex)
        return vim.fn.nr2char(tonumber(hex, 16))
    end)
    s = s:gsub("\\\\", "\\")
    return s
end

local function extract_text_chunks(buffer)
    local results   = {}
    local remaining = buffer
    while true do
        local pos_start, pos_end = remaining:find('"text"%s*:%s*"')
        if not pos_start then break end
        
        local str_start = pos_end + 1
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
        
        local inner_str = remaining:sub(str_start, str_end - 1)
        
        -- O TRUQUE DE MESTRE: Devolve o conteúdo para o formato string JSON ("...") 
        -- e pede para o motor C do Neovim decodificar todos os \n, \t e \uXXXX nativamente!
        local ok, decoded = pcall(vim.fn.json_decode, '"' .. inner_str .. '"')
        
        if ok and type(decoded) == "string" then
            table.insert(results, decoded)
        else
            -- Em caso de falha bizarra, usa nosso fallback manual
            table.insert(results, decode_json_string(inner_str))
        end
        
        remaining = remaining:sub(str_end + 1)
    end
    return results, remaining
end

local function header_args(api_config, api_key)
    local args = {}
    for k, v in pairs(api_config.headers or {}) do
        table.insert(args, "-H")
        table.insert(args, k .. ": " .. v:gsub("{API_KEY}", api_key))
    end
    return args
end

-- Função central que escreve payloads gigantes em arquivos temporários
-- BURLANDO O LIMITE DE LINHA DE COMANDO (ARG_MAX) DO SISTEMA OPERACIONAL
local function write_payload_to_tmp(payload)
    local tmp_file = os.tmpname()
    local f = io.open(tmp_file, "w")
    if f then
        f:write(vim.fn.json_encode(payload))
        f:close()
    end
    return tmp_file
end

-- ── Gemini ────────────────────────────────────────────────────────────────────
M.gemini = {
    make_request = function(api_config, messages, api_keys, last_sig, callback)
        local api_key  = api_keys[api_config.name] or ""
        if api_key == "" then 
            callback("\n[ERRO INTERNO]: Chave de API não encontrada para " .. api_config.name, nil, false)
            callback(nil, nil, true)
            return
        end

        local contents = {}
        local system_instruction = nil

        for _, msg in ipairs(messages) do
            if msg.role == "system" then
                system_instruction = { parts = { { text = msg.content } } }
            else
                table.insert(contents, {
                    role  = (msg.role == "user") and "user" or "model",
                    parts = { { text = msg.content } },
                })
            end
        end

        local payload = { contents = contents }
        if system_instruction then
            payload.systemInstruction = system_instruction
        end
        
        local url = api_config.url:gsub(":generateContent", ":streamGenerateContent")
        local tmp_file = write_payload_to_tmp(payload)
        
        local cmd = {
            "curl", "-s", "-N", "-L", "-X", "POST",
            url .. "?key=" .. api_key,
            "-H", "Content-Type: application/json",
            "-d", "@" .. tmp_file, -- O curl agora lê direto do disco infinito!
        }

        local buffer = ""
        local full_response = ""

        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                if not data then return end
                local raw = table.concat(data, "\n")
                if raw == "" then return end
                buffer = buffer .. raw
                full_response = full_response .. raw
                local chunks, rest = extract_text_chunks(buffer)
                for _, txt in ipairs(chunks) do
                    callback(txt, nil, false)
                end
                buffer = rest
            end,
            on_exit = function(_, code)
                os.remove(tmp_file) -- Limpa o rastro de disco
                if full_response:match('"error"') then
                    local ok, dec = pcall(vim.fn.json_decode, full_response)
                    if ok and dec.error and dec.error.message then
                        callback("\n\n**[ERRO DA API GEMINI]:** " .. dec.error.message .. "\n", nil, false)
                    else
                        callback("\n\n**[ERRO DA API GEMINI - RAW]:**\n" .. full_response .. "\n", nil, false)
                    end
                elseif full_response == "" then
                    callback("\n\n**[ERRO]:** Resposta vazia do servidor.\n", nil, false)
                end
                callback(nil, nil, true)
            end,
        })
    end,
}

-- ── OpenAI-compatible ────────────────────────────────────────────────────────
M.openai = {
    make_request = function(api_config, messages, api_keys, _, callback)
        local api_key = api_keys[api_config.name] or ""
        
        local tmp_file = write_payload_to_tmp({
            model    = api_config.model,
            messages = messages,
            stream   = true,
        })

        local cmd = { "curl", "-s", "-N", "-L", "-X", "POST", api_config.url }
        for _, h in ipairs(header_args(api_config, api_key)) do
            table.insert(cmd, h)
        end
        table.insert(cmd, "-d")
        table.insert(cmd, "@" .. tmp_file)

        local full_response = ""
        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                if not data then return end
                for _, line in ipairs(data) do
                    full_response = full_response .. line .. "\n"
                    if line:match("^data: ") and not line:match("%[DONE%]") then
                        local ok, dec = pcall(vim.fn.json_decode, line:sub(7))
                        if ok and dec.choices and dec.choices[1].delta and dec.choices[1].delta.content then
                            callback(dec.choices[1].delta.content, nil, false)
                        end
                    end
                end
            end,
            on_exit = function() 
                os.remove(tmp_file)
                if full_response:match('"error"') and not full_response:match('"content"') then
                    local ok, dec = pcall(vim.fn.json_decode, full_response)
                    if ok and dec.error and dec.error.message then
                        callback("\n\n**[ERRO DA API OPENAI]:** " .. dec.error.message .. "\n", nil, false)
                    end
                end
                callback(nil, nil, true) 
            end,
        })
    end,
}

-- ── Cloudflare Workers AI ─────────────────────────────────────────────────────
M.cloudflare = {
    make_request = function(api_config, messages, api_keys, _, callback)
        local api_key = api_keys[api_config.name] or ""
        local tmp_file = write_payload_to_tmp({ messages = messages })
        local output  = ""
        
        local cmd = {
            "curl", "-s", "-L", "-X", "POST", api_config.url,
            "-H", "Content-Type: application/json",
            "-H", "Authorization: Bearer " .. api_key,
            "-d", "@" .. tmp_file,
        }
        
        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                if data then output = output .. table.concat(data, "\n") end
            end,
            on_exit = function()
                os.remove(tmp_file)
                local ok, dec = pcall(vim.fn.json_decode, output)
                if ok and dec and dec.result and dec.result.response then
                    callback(dec.result.response, nil, false)
                elseif output:match('"errors"') or (ok and dec and not dec.success) then
                    local err_msg = "Erro Desconhecido"
                    if ok and dec and dec.errors and dec.errors[1] then
                        err_msg = dec.errors[1].message
                    end
                    callback("\n\n**[ERRO CLOUDFLARE]:** " .. err_msg .. "\n", nil, false)
                end
                callback(nil, nil, true)
            end,
        })
    end,
}

return M
