local api = vim.api
local utils = require('multi_context.utils')
local popup = require('multi_context.ui.popup')
local commands = require('multi_context.commands')
local api_handlers = require('multi_context.api_handlers')
local config = require('multi_context.config')

local M = {}

M.popup_buf = popup.popup_buf
M.popup_win = popup.popup_win
M.history = {}
M.context_text = nil
M.current_workspace_file = nil

-- === 1. A FUNÇÃO SETUP QUE FALTAVA ===
M.setup = function(opts)
    if config and config.setup then
        config.setup(opts)
    end
end

-- Expor funções públicas
M.ContextChatFull = commands.ContextChatFull
M.ContextChatSelection = commands.ContextChatSelection
M.ContextChatFolder = commands.ContextChatFolder
M.ContextChatHandler = commands.ContextChatHandler
M.ContextChatRepo = commands.ContextChatRepo
M.ContextChatGit = commands.ContextChatGit
M.ContextApis = commands.ContextApis
M.ContextTree = commands.ContextTree
M.ContextBuffers = commands.ContextBuffers

-- === 2. LÓGICA DO TOGGLE (<A-h>) À PROVA DE BALAS ===
M.TogglePopup = function()
    local p = require('multi_context.ui.popup')
    
    if p.popup_win and api.nvim_win_is_valid(p.popup_win) then
        api.nvim_win_hide(p.popup_win)
        return
    end
    
    if p.popup_buf and api.nvim_buf_is_valid(p.popup_buf) then
        local width = math.floor(vim.o.columns * 0.7)
        local height = math.floor(vim.o.lines * 0.7)
        local row = math.floor((vim.o.lines - height) / 2)
        local col = math.floor((vim.o.columns - width) / 2)

        p.popup_win = api.nvim_open_win(p.popup_buf, true, {
            relative = "editor",
            width = width,
            height = height,
            row = row,
            col = col,
            style = "minimal",
            border = "rounded",
            title = " Multi_Context_Chat ",
            title_pos = "center",
        })
        
        local lines = vim.api.nvim_buf_get_lines(p.popup_buf, 0, -1, false)
        api.nvim_win_set_cursor(p.popup_win, { #lines, #"## Nardi >> " })
        vim.cmd('normal! zz')
        return
    end
    
    vim.notify("Nenhum chat aberto! Use :ContextTree ou :Context para criar um novo.", vim.log.levels.WARN)
end
commands.TogglePopup = M.TogglePopup

-- === 3. LÓGICA DO WORKSPACE (<A-w>) QUE FALTAVA ===
M.ToggleWorkspaceView = function()
    local ui_popup = require('multi_context.ui.popup')
    local is_popup = (ui_popup.popup_win and vim.api.nvim_win_is_valid(ui_popup.popup_win) and vim.api.nvim_get_current_win() == ui_popup.popup_win)

    if is_popup then
        -- Se estiver no popup, pega o conteúdo, fecha o popup e abre o arquivo .mctx em tela cheia
        local lines = vim.api.nvim_buf_get_lines(ui_popup.popup_buf, 0, -1, false)
        local content = table.concat(lines, "\n")
        vim.api.nvim_win_hide(ui_popup.popup_win)
        M.current_workspace_file = utils.export_to_workspace(content, M.current_workspace_file)
    else
        -- Se estiver em tela cheia (workspace), não copia o texto.
        -- Apenas manda o popup FLUTUAR SOBRE o buffer atual do .mctx!
        local cur_buf = vim.api.nvim_get_current_buf()
        local name = vim.api.nvim_buf_get_name(cur_buf)
        if name:match("multi_context_chats.*%.mctx$") then
            M.current_workspace_file = name
            
            -- Passa o ID numérico do buffer para reutilizar o buffer vivo!
            ui_popup.create_popup(cur_buf)
        else
            vim.notify("Você não está em um arquivo de workspace (.mctx).", vim.log.levels.WARN)
        end
    end
end

local original_open_popup = popup.create_popup
popup.create_popup = function(initial_content)
    -- Agora o retorno (buf, win) é capturado e repassado corretamente
    local b, w = original_open_popup(initial_content)
    M.popup_buf = popup.popup_buf
    M.popup_win = popup.popup_win
    return b, w
end

-- ======================================================
-- Envio para LLM (Com Suporte a Pipeline de Agentes)
-- ======================================================
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

    local config = require('multi_context.config')
    local user_prefix = "## " .. (config.options.user_name or "Nardi") .. " >>"
    local lines = api.nvim_buf_get_lines(buf, start_idx, -1, false)
    
    if lines[1] then
        lines[1] = lines[1]:gsub("^" .. user_prefix .. "%s*", "")
    end

    local agents = require('multi_context.agents').load_agents()
    
    -- ==========================================
    -- PARSER DA FILA DE AGENTES (PIPELINE)
    -- ==========================================
    local current_task_lines = {}
    local queued_tasks_lines = {}
    local found_agent_count = 0

    for _, line in ipairs(lines) do
        if not line:match("^> %[Checkpoint%]") then
            -- CORREÇÃO 1: Regex agora inclui '_' para encontrar nomes como inspetor_semantico
            local possible_agent = line:match("^@([%w_]+)") or line:match("%s+@([%w_]+)")
            if possible_agent and agents[possible_agent] then
                found_agent_count = found_agent_count + 1
            end
            
            if found_agent_count <= 1 then
                table.insert(current_task_lines, line)
            else
                table.insert(queued_tasks_lines, line)
            end
        end
    end

    local current_user_text = table.concat(current_task_lines, "\n"):gsub("^%s*", ""):gsub("%s*$", "")
    local queued_user_text = table.concat(queued_tasks_lines, "\n")

    if current_user_text == "" then
        vim.notify("Digite algo antes de enviar.", vim.log.levels.WARN)
        return
    end

    local active_agent_name = nil
    local active_agent_prompt = ""
    local text_to_send = current_user_text

    -- CORREÇÃO 1 (Continuação)
    local agent_match = current_user_text:match("@([%w_]+)")
    if agent_match and agents[agent_match] then
        active_agent_name = agent_match
        active_agent_prompt = "\n\n=== INSTRUÇÕES DO AGENTE: " .. string.upper(agent_match) .. " ===\n" .. agents[agent_match].system_prompt
        text_to_send = current_user_text:gsub("@" .. agent_match .. "%s*", "")
    end

    local sending_msg = "[Enviando requisição" .. (active_agent_name and (" via @" .. active_agent_name) or "") .. "...]"
    api.nvim_buf_set_lines(buf, -1, -1, false, { "", sending_msg })

    -- CORREÇÃO 2: Pega o contexto inteiro diretamente. Sem processamento letal byte-por-byte.
    local all_lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    local full_context = table.concat(all_lines, "\n")
    
    if active_agent_prompt ~= "" then
        full_context = full_context .. active_agent_prompt
    end
    
    local messages = {
        { role = "system", content = full_context },
        { role = "user", content = text_to_send }
    }

    local api_client = require('multi_context.api_client')
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
                if active_agent_name then
                    ia_title = ia_title .. "[@" .. active_agent_name .. "]"
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
            
            local next_prompt_lines = { "", "## API atual: " .. api_entry.name, user_prefix .. " " }
            
            if queued_user_text ~= "" then
                table.insert(next_prompt_lines, "> [Checkpoint] Avalie a resposta acima. Pressione <CR> para continuar a fila:")
                local queued_split = vim.split(queued_user_text, "\n")
                for _, q_line in ipairs(queued_split) do
                    table.insert(next_prompt_lines, q_line)
                end
            end
            
            api.nvim_buf_set_lines(buf, -1, -1, false, next_prompt_lines)
            
            require('multi_context.ui.highlights').apply_chat(buf)
            require('multi_context.ui.popup').create_folds(buf)
            
            if popup.popup_win and api.nvim_win_is_valid(popup.popup_win) then
                local count = api.nvim_buf_line_count(buf)
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

-- ======================================================
-- Executor de Ferramentas (Aprovação Manual)
-- ======================================================
function M.ExecuteTools()
    local p = require('multi_context.ui.popup')
    local buf = p.popup_buf
    
    -- Detecta se o atalho foi chamado do Popup ou do Workspace
    if not buf or not api.nvim_buf_is_valid(buf) then
        buf = api.nvim_get_current_buf()
        if vim.bo[buf].filetype ~= "multicontext_chat" then return end
    end

    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    local content = table.concat(lines, "\n")
    local has_changes = false

    -- Faz o parse de qualquer bloco <tool_call> na tela
    local new_content = content:gsub('<tool_call name="(.-)"(.-)>(.-)</tool_call>', function(name, args, inner)
        has_changes = true
        local tools = require('multi_context.tools')
        local result = ""
        
        -- Extrai o parâmetro path="x" se existir
        local path = args:match('path="(.-)"')
        if path then path = vim.trim(path) end
        
        if name == "list_files" then result = tools.list_files()
        elseif name == "read_file" then result = tools.read_file(path)
        elseif name == "edit_file" then result = tools.edit_file(path, inner)
        elseif name == "run_shell" then result = tools.run_shell(inner)
        else result = "Erro: Ferramenta [" .. name .. "] desconhecida." end
        
        -- Transforma a tag em "executed" e anexa a saída do comando!
        return string.format(
            '<tool_executed name="%s"%s>\n%s\n</tool_executed>\n\n>[Sistema]: Resultado da Ferramenta:\n```text\n%s\n```',
            name, args, inner, result
        )
    end)

    if has_changes then
        local new_lines = vim.split(new_content, "\n", {plain=true})
        api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
        vim.notify("Ferramentas executadas com sucesso!", vim.log.levels.INFO)
        -- Atualiza os folds e os highlights (o resultado ficará colorido)
        require('multi_context.ui.highlights').apply_chat(buf)
        require('multi_context.ui.popup').create_folds(buf)
    else
        vim.notify("Nenhuma <tool_call> pendente encontrada na tela.", vim.log.levels.WARN)
    end
end

-- Exporta a função
M.ExecuteTools = M.ExecuteTools

vim.cmd([[
  command! -range Context lua require('multi_context').ContextChatHandler(<line1>, <line2>)
  command! -nargs=0 ContextFolder lua require('multi_context').ContextChatFolder()
  command! -nargs=0 ContextRepo lua require('multi_context').ContextChatRepo()
  command! -nargs=0 ContextGit lua require('multi_context').ContextChatGit()
  command! -nargs=0 ContextApis lua require('multi_context').ContextApis()
  command! -nargs=0 ContextTree lua require('multi_context').ContextTree()
  command! -nargs=0 ContextBuffers lua require('multi_context').ContextBuffers()
  command! -nargs=0 ContextToggle lua require('multi_context').TogglePopup()
]])

return M
