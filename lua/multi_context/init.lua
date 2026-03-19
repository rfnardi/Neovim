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

M.setup = function(opts)
    if config and config.setup then
        config.setup(opts)
    end
end

M.ContextChatFull = commands.ContextChatFull
M.ContextChatSelection = commands.ContextChatSelection
M.ContextChatFolder = commands.ContextChatFolder
M.ContextChatHandler = commands.ContextChatHandler
M.ContextChatRepo = commands.ContextChatRepo
M.ContextChatGit = commands.ContextChatGit
M.ContextApis = commands.ContextApis
M.ContextTree = commands.ContextTree
M.ContextBuffers = commands.ContextBuffers

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

M.ToggleWorkspaceView = function()
    local ui_popup = require('multi_context.ui.popup')
    local is_popup = (ui_popup.popup_win and vim.api.nvim_win_is_valid(ui_popup.popup_win) and vim.api.nvim_get_current_win() == ui_popup.popup_win)

    if is_popup then
        local lines = vim.api.nvim_buf_get_lines(ui_popup.popup_buf, 0, -1, false)
        local content = table.concat(lines, "\n")
        vim.api.nvim_win_hide(ui_popup.popup_win)
        M.current_workspace_file = utils.export_to_workspace(content, M.current_workspace_file)
    else
        local cur_buf = vim.api.nvim_get_current_buf()
        local name = vim.api.nvim_buf_get_name(cur_buf)
        if name:match("multi_context_chats.*%.mctx$") then
            M.current_workspace_file = name
            ui_popup.create_popup(cur_buf)
        else
            vim.notify("Você não está em um arquivo de workspace (.mctx).", vim.log.levels.WARN)
        end
    end
end

local original_open_popup = popup.create_popup
popup.create_popup = function(initial_content)
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
    
    local current_task_lines = {}
    local queued_tasks_lines = {}
    local found_agent_count = 0

    for _, line in ipairs(lines) do
        if not line:match("^> %[Checkpoint%]") then
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

    local agent_match = current_user_text:match("@([%w_]+)")
    if agent_match and agents[agent_match] then
        active_agent_name = agent_match
        active_agent_prompt = "\n\n=== INSTRUÇÕES DO AGENTE: " .. string.upper(agent_match) .. " ===\n" .. agents[agent_match].system_prompt
        
        if agents[agent_match].use_tools then
            local tools_manual = require('multi_context.agents').get_tools_manual()
            active_agent_prompt = active_agent_prompt .. "\n\n" .. tools_manual
        end
        
        text_to_send = current_user_text:gsub("@" .. agent_match .. "%s*", "")
    end

    local sending_msg = "[Enviando requisição" .. (active_agent_name and (" via @" .. active_agent_name) or "") .. "...]"
    api.nvim_buf_set_lines(buf, -1, -1, false, { "", sending_msg })

    local history_lines = api.nvim_buf_get_lines(buf, 0, start_idx, false)
    local history_text = table.concat(history_lines, "\n")
    
    local system_prompt = "Você é um Engenheiro de Software Autônomo operando dentro do Neovim. Você tem acesso ao código do projeto no histórico do chat e pode interagir com o sistema do usuário."
    if active_agent_prompt ~= "" then
        system_prompt = system_prompt .. "\n\n" .. active_agent_prompt
    end
    
    local full_user_content = ""
    if history_text ~= "" then
        full_user_content = history_text .. "\n\n"
    end
    full_user_content = full_user_content .. user_prefix .. " " .. text_to_send
    
    local messages = {
        { role = "system", content = system_prompt },
        { role = "user", content = full_user_content }
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
                    popup.update_title() -- O TAXÍMETRO: Atualiza tokens durante streaming!
                end
            end
        end,
        function(api_entry)
            if not response_started then remove_sending_msg() end
            
            local next_prompt_lines = { "", "## API atual: " .. api_entry.name, user_prefix .. " " }
            
            if queued_user_text ~= "" then
                table.insert(next_prompt_lines, ">[Checkpoint] Avalie a resposta acima. Pressione <CR> para continuar a fila:")
                local queued_split = vim.split(queued_user_text, "\n")
                for _, q_line in ipairs(queued_split) do
                    table.insert(next_prompt_lines, q_line)
                end
            end
            
            api.nvim_buf_set_lines(buf, -1, -1, false, next_prompt_lines)
            
            require('multi_context.ui.highlights').apply_chat(buf)
            require('multi_context.ui.popup').create_folds(buf)
            popup.update_title() -- Atualiza tokens ao finalizar
            
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
-- Executor de Ferramentas (Aprovação Manual e Seletiva)
-- ======================================================
function M.ExecuteTools()
    local p = require('multi_context.ui.popup')
    local buf = p.popup_buf
    
    if not buf or not api.nvim_buf_is_valid(buf) then
        buf = api.nvim_get_current_buf()
        if vim.bo[buf].filetype ~= "multicontext_chat" then return end
    end

    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    
    local last_ia_idx = 0
    for i = #lines, 1, -1 do
        if lines[i]:match("^## IA") then
            last_ia_idx = i
            break
        end
    end
    
    if last_ia_idx == 0 then
        vim.notify("Nenhuma resposta da IA encontrada para executar ferramentas.", vim.log.levels.WARN)
        return
    end

    local prefix_lines = {}
    for i = 1, last_ia_idx - 1 do
        table.insert(prefix_lines, lines[i])
    end
    
    local process_lines = {}
    for i = last_ia_idx, #lines do
        table.insert(process_lines, lines[i])
    end
    
    local content_to_process = table.concat(process_lines, "\n")
    local has_changes = false
    local approve_all = false
    local abort_all = false

local new_content = content:gsub('<tool_call(.-)>(.-)</tool_call>', function(attrs, inner)
        if abort_all then
            return '<tool_call' .. attrs .. '>' .. inner .. '</tool_call>'
        end

        local tools = require('multi_context.tools')
        local result = ""
        
        local name = attrs:match('name="([^"]+)"')
        local path = attrs:match('path="([^"]+)"')
        local query = attrs:match('query="([^"]+)"')
        local start_line = attrs:match('start="([^"]+)"')
        local end_line = attrs:match('end="([^"]+)"')
        local payload = inner
        
        -- Fallback JSON caso a IA erre a tag
        if not name or name == "" then
            local ok, json = pcall(vim.fn.json_decode, vim.trim(inner))
            if ok and type(json) == "table" then
                name = json.name
                if type(json.arguments) == "table" then
                    path = json.arguments.path
                    query = json.arguments.query
                    start_line = json.arguments.start or json.arguments.start_line
                    end_line = json.arguments.end or json.arguments.end_line
                    payload = json.arguments.command or json.arguments.content or json.arguments.code or ""
                end
            end
        end
        if path then path = vim.trim(path) end
        
        -- Monta os atributos limpos para devolver à interface
        local clean_attrs = string.format(' name="%s"', tostring(name))
        if path and path ~= "" then clean_attrs = clean_attrs .. string.format(' path="%s"', path) end
        if query and query ~= "" then clean_attrs = clean_attrs .. string.format(' query="%s"', query) end
        if start_line and start_line ~= "" then clean_attrs = clean_attrs .. string.format(' start="%s"', start_line) end
        if end_line and end_line ~= "" then clean_attrs = clean_attrs .. string.format(' end="%s"', end_line) end

        local choice = 1
        if not approve_all then
            local target = path and ("\nAlvo: " .. path) or ""
            target = query and (target .. "\nBusca: " .. query) or target
            local msg = string.format("Permitir execução de [%s]?%s", tostring(name), target)
            choice = vim.fn.confirm(msg, "&Sim\n&Nao\n&Todos\n&Cancelar", 1)
        end

        if choice == 3 then
            approve_all = true
            choice = 1
        elseif choice == 4 or choice == 0 then
            abort_all = true
            return '<tool_call' .. attrs .. '>' .. inner .. '</tool_call>'
        end

        has_changes = true

        if choice == 2 then
            return string.format(
                '<tool_rejected%s>\n%s\n</tool_rejected>\n\n>[Sistema]: Acesso NEGADO pelo usuario. A ferramenta não foi executada.',
                clean_attrs, inner
            )
        end

        -- ROTEAMENTO DAS FERRAMENTAS: Inclui as duas novas!
        if name == "list_files" then result = tools.list_files()
        elseif name == "read_file" then result = tools.read_file(path)
        elseif name == "edit_file" then result = tools.edit_file(path, payload)
        elseif name == "run_shell" then result = tools.run_shell(payload)
        elseif name == "search_code" then result = tools.search_code(query)
        elseif name == "replace_lines" then result = tools.replace_lines(path, start_line, end_line, payload)
        else result = "Erro: Ferramenta [" .. tostring(name) .. "] desconhecida ou mal formatada." end
        
        return string.format(
            '<tool_executed%s>\n%s\n</tool_executed>\n\n>[Sistema]: Resultado da Ferramenta:\n```text\n%s\n```',
            clean_attrs, inner, result
        )
    end)

    if has_changes then
        local new_process_lines = vim.split(new_content, "\n", {plain=true})
        
        local final_lines = {}
        for _, l in ipairs(prefix_lines) do table.insert(final_lines, l) end
        for _, l in ipairs(new_process_lines) do table.insert(final_lines, l) end
        
        api.nvim_buf_set_lines(buf, 0, -1, false, final_lines)
        
        if abort_all then
            vim.notify("Execução em lote cancelada.", vim.log.levels.WARN)
        else
            vim.notify("Ferramentas processadas!", vim.log.levels.INFO)
        end
        
        vim.cmd("silent! checktime")
        require('multi_context.ui.highlights').apply_chat(buf)
        require('multi_context.ui.popup').create_folds(buf)
        require('multi_context.ui.popup').update_title() -- ATUALIZA TOKENS após executar ferramentas
    else
        vim.notify("Nenhuma <tool_call> pendente encontrada na última resposta da IA.", vim.log.levels.WARN)
    end
end

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
