local M = {}

M.openai = {
    make_request = function(api_config, messages, api_keys, callback)
        local json_payload = vim.fn.json_encode({
            model = api_config.model,
            messages = messages
        })

        local headers = {}
        for k, v in pairs(api_config.headers or {}) do
            if v == "{API_KEY}" then
                v = api_keys[api_config.name] or ""
            end
            table.insert(headers, "-H")
            table.insert(headers, k .. ": " .. v)
        end

        local cmd = vim.list_extend({"curl", "-s", "-X", "POST", api_config.url}, headers)
        table.insert(cmd, "-d")
        table.insert(cmd, json_payload)

        local stdout_accum = {}
        local stderr_accum = {}

        vim.fn.jobstart(cmd, {
            stdout_buffered = true,
            on_stdout = function(_, data, _)
                if data then
                    for _, d in ipairs(data) do
                        if d and d ~= "" then
                            table.insert(stdout_accum, d)
                        end
                    end
                end
            end,
            on_stderr = function(_, data, _)
                if data then
                    for _, d in ipairs(data) do
                        if d and d ~= "" then
                            table.insert(stderr_accum, d)
                        end
                    end
                end
            end,
            on_exit = function(_, code, _)
                if code == 0 then
                    callback(true, table.concat(stdout_accum, "\n"))
                else
                    callback(false, table.concat(stderr_accum, "\n"))
                end
            end
        })
    end,
    
    parse_response = function(response_text)
        local ok, decoded = pcall(vim.fn.json_decode, response_text)
        if not ok or not decoded or not decoded.choices or not decoded.choices[1] then
            return nil, "Erro ao decodificar resposta OpenAI"
        end
        return decoded.choices[1].message.content or "", nil
    end
}

M.gemini = {
    make_request = function(api_config, messages, api_keys, callback)
        -- Converter mensagens para formato Gemini
        local gemini_messages = {}
        for _, msg in ipairs(messages) do
            if msg.role == "user" then
                table.insert(gemini_messages, {
                    parts = {
                        {
                            text = msg.content
                        }
                    }
                })
            end
        end

        local json_payload = vim.fn.json_encode({
            contents = gemini_messages
        })

        local headers = {}
        for k, v in pairs(api_config.headers or {}) do
            if v == "{API_KEY}" then
                v = api_keys[api_config.name] or ""
            end
            table.insert(headers, "-H")
            table.insert(headers, k .. ": " .. v)
        end

        local cmd = vim.list_extend({"curl", "-s", "-X", "POST", api_config.url}, headers)
        table.insert(cmd, "-d")
        table.insert(cmd, json_payload)

        local stdout_accum = {}
        local stderr_accum = {}

        vim.fn.jobstart(cmd, {
            stdout_buffered = true,
            on_stdout = function(_, data, _)
                if data then
                    for _, d in ipairs(data) do
                        if d and d ~= "" then
                            table.insert(stdout_accum, d)
                        end
                    end
                end
            end,
            on_stderr = function(_, data, _)
                if data then
                    for _, d in ipairs(data) do
                        if d and d ~= "" then
                            table.insert(stderr_accum, d)
                        end
                    end
                end
            end,
            on_exit = function(_, code, _)
                if code == 0 then
                    callback(true, table.concat(stdout_accum, "\n"))
                else
                    callback(false, table.concat(stderr_accum, "\n"))
                end
            end
        })
    end,
    
    parse_response = function(response_text)
        local ok, decoded = pcall(vim.fn.json_decode, response_text)
        if not ok or not decoded or not decoded.candidates or not decoded.candidates[1] then
            return nil, "Erro ao decodificar resposta Gemini"
        end
        return decoded.candidates[1].content.parts[1].text or "", nil
    end
}

M.cloudflare = {
    make_request = function(api_config, messages, api_keys, callback)
        local json_payload = vim.fn.json_encode({
            messages = messages
        })

        local headers = {}
        for k, v in pairs(api_config.headers or {}) do
            if v == "{API_KEY}" then
                v = api_keys[api_config.name] or ""
            end
            table.insert(headers, "-H")
            table.insert(headers, k .. ": " .. v)
        end

        local cmd = vim.list_extend({"curl", "-s", "-X", "POST", api_config.url}, headers)
        table.insert(cmd, "-d")
        table.insert(cmd, json_payload)

        local stdout_accum = {}
        local stderr_accum = {}

        vim.fn.jobstart(cmd, {
            stdout_buffered = true,
            on_stdout = function(_, data, _)
                if data then
                    for _, d in ipairs(data) do
                        if d and d ~= "" then
                            table.insert(stdout_accum, d)
                        end
                    end
                end
            end,
            on_stderr = function(_, data, _)
                if data then
                    for _, d in ipairs(data) do
                        if d and d ~= "" then
                            table.insert(stderr_accum, d)
                        end
                    end
                end
            end,
            on_exit = function(_, code, _)
                if code == 0 then
                    callback(true, table.concat(stdout_accum, "\n"))
                else
                    callback(false, table.concat(stderr_accum, "\n"))
                end
            end
        })
    end,
    
    parse_response = function(response_text)
        local ok, decoded = pcall(vim.fn.json_decode, response_text)
        if not ok or not decoded or not decoded.result then
            return nil, "Erro ao decodificar resposta Cloudflare"
        end
        return decoded.result.response or "", nil
    end
}

return M
