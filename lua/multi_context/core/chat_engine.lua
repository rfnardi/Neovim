local api = vim.api
local popup = require('multi_context.ui.popup')
local utils = require('multi_context.utils')
local config = require('multi_context.config')
local agents_module = require('multi_context.agents')
local pipeline = require('multi_context.core.agent_pipeline')
local api_client = require('multi_context.api_client')

local M = {}

function M.SendFromPopup()
    if not popup.popup_buf or not api.nvim_buf_is_valid(popup.popup_buf) then
        vim.notify("Popup não está aberto.", vim.log.levels.WARN)
        return
    end

    local buf = popup.popup_buf
    local start_idx, _ = utils.find_last_user_line(buf)
    
    if not start_idx then
        vim.notify("Nenhuma linha de usuário encontrada.", vim.log.levels.WARN)
        return
    end

    local user_prefix = "## " .. (config.options.user_name or "Nardi") .. " >>"
    local lines = api.nvim_buf_get_lines(buf, start_idx, -1, false)
    
    if lines[1] then
        lines[1] = lines[1]:gsub("^" .. user_prefix .. "%s*", "")
    end

    local agents = agents_module.load_agents()
    
    -- Utilizando o novo motor de parsing da pipeline
    local parsed_pipeline = pipeline.parse_pipeline(lines, agents)

    if parsed_pipeline.current_user_text == "" then
        vim.notify("Digite algo antes de enviar.", vim.log.levels.WARN)
        return
    end

    local sending_msg = "[Enviando requisição" .. (parsed_pipeline.active_agent_name and (" via @" .. parsed_pipeline.active_agent_name) or "") .. "...]"
    api.nvim_buf_set_lines(buf, -1, -1, false, { "", sending_msg })

    -- ==========================================
    -- MONTAGEM DO CONTEXTO (Histórico + Prompt)
    -- ==========================================
    
    -- Pega tudo que estava ANTES do prompt do usuário atual (arquivos de contexto e histórico do chat)
    local history_lines = api.nvim_buf_get_lines(buf, 0, start_idx, false)
    local history_text = table.concat(history_lines, "\n")
    
    -- SYSTEM PROMPT: Recebe apenas a regra do Agente e a base
    local system_prompt = "Você é um Engenheiro de Software Autônomo operando dentro do Neovim. Você tem acesso ao código do projeto no histórico do chat e pode interagir com o sistema do usuário."
    if parsed_pipeline.active_agent_prompt ~= "" then
        system_prompt = system_prompt .. "\n\n" .. parsed_pipeline.active_agent_prompt
    end
    
    -- USER PROMPT: Recebe os arquivos de contexto + O seu pedido atual
    local full_user_content = ""
    if history_text ~= "" then
        full_user_content = history_text .. "\n\n"
    end
    full_user_content = full_user_content .. user_prefix .. " " .. parsed_pipeline.text_to_send
    
    local messages = {
        { role = "system", content = system_prompt },
        { role = "user", content = full_user_content }
    }

    local response_started = false

    local function remove_sending_msg()
        local count = api.nvim_buf_line_count(buf)
        local last_line = api.nvim_buf_get_lines(buf, count - 1, count, false)[1]
        if last_line:match("%[Enviando requisi") then
            api.nvim_buf_set_lines(buf, count - 2, count, false, {})
        end
    end

    api_client.execute(messages, 
        function(chunk, api_entry)
            if not response_started then
                remove_sending_msg()
                local ia_title = "## IA (" .. api_entry.model .. ")"
                if parsed_pipeline.active_agent_name then
                    ia_title = ia_title .. "[@" .. parsed_pipeline.active_agent_name .. "]"
                end
                ia_title = ia_title .. " >> "
                api.nvim_buf_set_lines(buf, -1, -1, false, { "", ia_title, "" })
                response_started = true
            end
            
            if chunk and chunk ~= "" then
                local lines_to_add = vim.split(chunk, "\n", {plain = true})
                local count = api.nvim_buf_line_count(buf)
                local last_line = api.nvim_buf_get_lines(buf, count - 1, count, false)[1]
                
                lines_to_add[1] = last_line .. lines_to_add[1]
                api.nvim_buf_set_lines(buf, count - 1, count, false, lines_to_add)
                
                if popup.popup_win and api.nvim_win_is_valid(popup.popup_win) then
                    local new_count = api.nvim_buf_line_count(buf)
                    api.nvim_win_set_cursor(popup.popup_win, { new_count, 0 })
                    vim.cmd("normal! zz")
                end
            end
        end,
        function(api_entry)
            if not response_started then remove_sending_msg() end
            
            -- Monta o prompt da próxima interação
            local next_prompt_lines = { "", "## API atual: " .. api_entry.name, user_prefix .. " " }
            
            -- Se sobrou alguma tarefa na fila, preenche o buffer automaticamente para o usuário
            if parsed_pipeline.queued_user_text ~= "" then
                table.insert(next_prompt_lines, "> [Checkpoint] Avalie a resposta acima. Pressione <CR> para continuar a fila:")
                local queued_split = vim.split(parsed_pipeline.queued_user_text, "\n")
                for _, q_line in ipairs(queued_split) do
                    table.insert(next_prompt_lines, q_line)
                end
            end
            
            api.nvim_buf_set_lines(buf, -1, -1, false, next_prompt_lines)
            
            require('multi_context.ui.highlights').apply_chat(buf)
            popup.create_folds(buf)
            
            if popup.popup_win and api.nvim_win_is_valid(popup.popup_win) then
                local count = api.nvim_buf_line_count(buf)
                -- Coloca o cursor no final, pronto para o próximo Enter
                api.nvim_win_set_cursor(popup.popup_win, { count, #next_prompt_lines[#next_prompt_lines] })
                vim.cmd("normal! zz")
                vim.cmd("startinsert!")
            end
        end,
        function(err_msg)
            remove_sending_msg()
            api.nvim_buf_set_lines(buf, -1, -1, false, { 
                "", "**[ERRO]** " .. err_msg, "", user_prefix .. " " 
            })
            if popup.popup_win and api.nvim_win_is_valid(popup.popup_win) then
                local count = api.nvim_buf_line_count(buf)
                api.nvim_win_set_cursor(popup.popup_win, { count, #user_prefix + 1 })
            end
        end
    )
end

return M
