local handlers = require('multi_context.api_handlers')

describe("API Handlers Module (Prompt Caching)", function()
    local original_jobstart
    local intercepted_cmd
    local intercepted_opts
    local payload_content

    before_each(function()
        -- Mockamos a execução do terminal para não fazer chamadas reais de rede
        original_jobstart = vim.fn.jobstart
        vim.fn.jobstart = function(cmd, opts)
            intercepted_cmd = cmd
            intercepted_opts = opts
            
            -- O payload é salvo em um arquivo temp no formato "@"/tmp/..."
            -- Vamos encontrá-lo, ler o JSON gerado e jogar na variável para o teste auditar
            for _, arg in ipairs(cmd) do
                if type(arg) == "string" and arg:match("^@") then
                    local filepath = arg:sub(2)
                    local f = io.open(filepath, "r")
                    if f then
                        payload_content = f:read("*a")
                        f:close()
                    end
                end
            end
            return 1
        end
    end)

    after_each(function()
        vim.fn.jobstart = original_jobstart
        intercepted_cmd = nil
        intercepted_opts = nil
        payload_content = nil
    end)

    it("Deve incluir stream_options e extrair metricas de cache (OpenAI / DeepSeek)", function()
        local callback_metrics = nil
        local callback_done = false

        handlers.openai.make_request(
            { name = "ds", url = "http://ds", model = "deepseek-coder" },
            { {role="user", content="hello"} },
            { ds = "key123" },
            nil,
            function(chunk, err, done, metrics)
                if done then
                    callback_done = true
                    callback_metrics = metrics
                end
            end
        )

        -- 1. Verifica se a flag de obter o uso via stream foi injetada no payload
        local parsed_payload = vim.fn.json_decode(payload_content)
        assert.is_not_nil(parsed_payload.stream_options)
        assert.is_true(parsed_payload.stream_options.include_usage)

        -- 2. Simula o recebimento do chunk final de "usage" do DeepSeek
        intercepted_opts.on_stdout(1, {
            'data: {"choices":[{"delta":{"content":""}}], "usage": {"prompt_cache_hit_tokens": 1280}}'
        })
        intercepted_opts.on_exit(1, 0)

        -- 3. Valida se os dados chegaram limpos no callback final
        assert.is_true(callback_done)
        assert.is_not_nil(callback_metrics)
        assert.are.same(1280, callback_metrics.cache_read_input_tokens)
    end)

    it("Deve estruturar o payload Anthropic com cache_control e capturar os metadados", function()
        local callback_metrics = nil

        handlers.anthropic.make_request(
            { name = "claude", url = "http://claude", model = "claude-3.5" },
            {
                {role="system", content="Você é um assistente dev."},
                {role="user", content="hello"}
            },
            { claude = "key123" },
            nil,
            function(chunk, err, done, metrics)
                if done then callback_metrics = metrics end
            end
        )

        -- 1. Verifica se o Header BETA obrigatório da Anthropic foi passado no curl
        local has_beta_header = false
        for _, v in ipairs(intercepted_cmd) do
            if type(v) == "string" and v:match("anthropic%-beta: prompt%-caching") then
                has_beta_header = true
            end
        end
        assert.is_true(has_beta_header)

        -- 2. Verifica se o bloco 'system' foi montado em Array e possui a tag de cache
        local parsed_payload = vim.fn.json_decode(payload_content)
        assert.is_not_nil(parsed_payload.system)
        assert.are.same("Você é um assistente dev.", parsed_payload.system[1].text)
        assert.are.same("ephemeral", parsed_payload.system[1].cache_control.type)

        -- 3. Simula o evento inicial "message_start" da Anthropic e garante o parse dos tokens
        intercepted_opts.on_stdout(1, {
            'data: {"type": "message_start", "message": {"usage": {"cache_read_input_tokens": 4048}}}'
        })
        intercepted_opts.on_exit(1, 0)

        assert.is_not_nil(callback_metrics)
        assert.are.same(4048, callback_metrics.cache_read_input_tokens)
    end)
end)
