-- api_client.lua
-- Monta a fila de APIs, aplica fallback e delega a execução ao handler.
-- Não tem dependência de UI.
local M = {}

local function build_queue(cfg)
    local queue = {}
    -- API padrão sempre na frente
    for _, a in ipairs(cfg.apis) do
        if a.name == cfg.default_api then
            table.insert(queue, a)
            break
        end
    end
    -- Fallbacks na ordem do JSON
    if cfg.fallback_mode then
        for _, a in ipairs(cfg.apis) do
            if a['include_in_fall-back_mode'] and a.name ~= cfg.default_api then
                table.insert(queue, a)
            end
        end
    end
    return queue
end

-- M.execute(messages, on_chunk, on_done, on_error)
--
--   messages  : {role:string, content:string}[]
--   on_chunk  : function(text:string,  api_entry:table)
--   on_done   : function(api_entry:table)
--   on_error  : function(msg:string)
--
M.execute = function(messages, on_chunk, on_done, on_error)
    local config       = require('multi_context.config')
    local api_handlers = require('multi_context.api_handlers')

    local cfg = config.load_api_config()
    if not cfg then
        on_error("Configuração de APIs não encontrada.")
        return
    end

    local queue = build_queue(cfg)
    if #queue == 0 then
        on_error("Nenhuma API na fila. Configure com :ContextApis")
        return
    end

    local api_keys = config.load_api_keys()

    local function try(idx)
        if idx > #queue then
            on_error("Erro em todas as APIs da fila.")
            return
        end
        local entry   = queue[idx]
        local handler = api_handlers[entry.api_type or "openai"]
        if not handler then
            vim.notify(
                "Handler ausente para api_type: " .. (entry.api_type or "?"),
                vim.log.levels.WARN
            )
            try(idx + 1)
            return
        end
        handler.make_request(entry, messages, api_keys, nil, function(chunk, err, done)
            vim.schedule(function()
                if err   then try(idx + 1); return end
                if chunk then on_chunk(chunk, entry) end
                if done  then on_done(entry) end
            end)
        end)
    end

    try(1)
end

return M
