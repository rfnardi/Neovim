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
M.current_workspace_file = nil

M.is_autonomous = false
M.active_agent = nil
M.auto_loop_count = 0
M.queued_tasks = nil
M.last_backup = nil

M.setup = function(opts)
    if config and config.setup then config.setup(opts) end
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
M.TogglePopup = commands.TogglePopup

M.ContextUndo = function()
    local p = require('multi_context.ui.popup')
    local buf = p.popup_buf
    if not buf or not vim.api.nvim_buf_is_valid(buf) then buf = vim.api.nvim_get_current_buf() end
    if M.last_backup then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.last_backup)
        require('multi_context.ui.highlights').apply_chat(buf)
        require('multi_context.ui.popup').create_folds(buf)
        require('multi_context.ui.popup').update_title()
        vim.notify("✅ Chat restaurado do último backup com sucesso!", vim.log.levels.INFO)
    else
        vim.notify("Nenhum backup de compressão encontrado nesta sessão.", vim.log.levels.WARN)
    end
end

M.ToggleWorkspaceView = function()
    local ui_popup = require('multi_context.ui.popup')
    local is_popup = (ui_popup.popup_win and vim.api.nvim_win_is_valid(ui_popup.popup_win) and vim.api.nvim_get_current_win() == ui_popup.popup_win)
    if is_popup then
        local lines = vim.api.nvim_buf_get_lines(ui_popup.popup_buf, 0, -1, false)
        vim.api.nvim_win_hide(ui_popup.popup_win)
        M.current_workspace_file = utils.export_to_workspace(table.concat(lines, "\n"), M.current_workspace_file)
    else
        local cur_buf = vim.api.nvim_get_current_buf()
        if vim.api.nvim_buf_get_name(cur_buf):match("%.mctx$") then
            M.current_workspace_file = vim.api.nvim_buf_get_name(cur_buf)
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

M.TerminateTurn = function()
    M.auto_loop_count = 0
    M.is_autonomous = false
    
    local p = require('multi_context.ui.popup')
    local buf = p.popup_buf
    if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
    
    local cfg = require('multi_context.config')
    local current_api = cfg.get_current_api()
    local user_prefix = "## " .. (cfg.options.user_name or "Nardi") .. " >>"
    
    local next_prompt_lines = { "", "## API atual: " .. current_api, user_prefix .. " " }
    
    if M.queued_tasks and M.queued_tasks ~= "" then
        table.insert(next_prompt_lines, "> [Checkpoint] Avalie a resposta acima. Pressione <CR> para continuar a fila:")
        for _, q_line in ipairs(vim.split(M.queued_tasks, "\n")) do table.insert(next_prompt_lines, q_line) end
        M.queued_tasks = nil
    end
    
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, next_prompt_lines)
    require('multi_context.ui.popup').create_folds(buf)
    require('multi_context.ui.highlights').apply_chat(buf)
    require('multi_context.ui.popup').update_title()
    
    if p.popup_win and vim.api.nvim_win_is_valid(p.popup_win) then
        vim.api.nvim_win_set_cursor(p.popup_win, { vim.api.nvim_buf_line_count(buf), #next_prompt_lines[#next_prompt_lines] })
        vim.cmd("normal! zz"); vim.cmd("startinsert!")
    end
end

local function get_context_md_content()
    local root = vim.fn.system("git rev-parse --show-toplevel")
    if vim.v.shell_error == 0 then root = root:gsub("\n", "") else root = vim.fn.getcwd() end
    local filepath = root .. "/CONTEXT.md"
    if vim.fn.filereadable(filepath) == 1 then
        return table.concat(vim.fn.readfile(filepath), "\n")
    end
    return nil
end

function M.SendFromPopup()
    if not popup.popup_buf or not api.nvim_buf_is_valid(popup.popup_buf) then return end
    local buf = popup.popup_buf
    local start_idx, _ = utils.find_last_user_line(buf)
    if not start_idx then return end

    local cfg = require('multi_context.config')
    local user_prefix = "## " .. (cfg.options.user_name or "Nardi") .. " >>"
    local lines = api.nvim_buf_get_lines(buf, start_idx, -1, false)
    if lines[1] then lines[1] = lines[1]:gsub("^" .. user_prefix .. "%s*", "") end

    local agents = require('multi_context.agents').load_agents()
    local current_task_lines = {}; local queued_tasks_lines = {}; local found_agent_count = 0

    for _, line in ipairs(lines) do
        if not line:match("^> %[Checkpoint%]") then
            local possible_agent = line:match("@([%w_]+)")
            if possible_agent and agents[possible_agent] then found_agent_count = found_agent_count + 1 end
            if found_agent_count <= 1 then table.insert(current_task_lines, line) else table.insert(queued_tasks_lines, line) end
        end
    end

    local current_user_text = table.concat(current_task_lines, "\n"):gsub("^%s*", ""):gsub("%s*$", "")
    if #queued_tasks_lines > 0 then M.queued_tasks = table.concat(queued_tasks_lines, "\n") end

    if current_user_text == "" then vim.notify("Digite algo antes de enviar.", vim.log.levels.WARN); return end

    local active_agent_name = nil
    local active_agent_prompt = ""
    local text_to_send = current_user_text

    local agent_match = text_to_send:match("@([%w_]+)")
    if agent_match then
        if agent_match == "reset" then
            M.active_agent = nil
            text_to_send = text_to_send:gsub("@reset%s*", "")
        elseif agents[agent_match] then
            M.active_agent = agent_match
            text_to_send = text_to_send:gsub("@" .. agent_match .. "%s*", "")
        end
    end

    if text_to_send:match("%-%-auto") then
        M.is_autonomous = true
        text_to_send = text_to_send:gsub("%-%-auto%s*", "")
    end

    if M.active_agent and agents[M.active_agent] then
        active_agent_name = M.active_agent
        active_agent_prompt = "\n\n=== INSTRUÇÕES DO AGENTE: " .. string.upper(M.active_agent) .. " ===\n" .. agents[M.active_agent].system_prompt
        if agents[M.active_agent].use_tools then
            active_agent_prompt = active_agent_prompt .. "\n\n" .. require('multi_context.agents').get_tools_manual()
        end
    end

    local sending_msg = "[Enviando requisição" .. (active_agent_name and (" via @" .. active_agent_name) or "") .. "...]"
    api.nvim_buf_set_lines(buf, -1, -1, false, { "", sending_msg })

    local history_lines = api.nvim_buf_get_lines(buf, 0, start_idx, false)
    local messages = require('multi_context.conversation').build_history(history_lines)
    
    local system_prompt = "Você é um Engenheiro de Software Autônomo no Neovim."
    local memory_context = get_context_md_content()
    if memory_context then
        system_prompt = system_prompt .. "\n\n=== ESTADO ATUAL DO PROJETO (MEMÓRIA) ===\n" .. memory_context
    end
    if active_agent_prompt ~= "" then system_prompt = system_prompt .. "\n\n" .. active_agent_prompt end
    
    table.insert(messages, 1, { role = "system", content = system_prompt })
    table.insert(messages, { role = "user", content = text_to_send })

    local response_started = false
    local current_ia_start_idx = nil
    
    local function remove_sending_msg()
        local count = api.nvim_buf_line_count(buf)
        local last_line = api.nvim_buf_get_lines(buf, count - 1, count, false)[1]
        if last_line:match("%[Enviando requisi") then api.nvim_buf_set_lines(buf, count - 2, count, false, {}) end
    end

    require('multi_context.api_client').execute(messages, 
        function(chunk, api_entry)
            if not response_started then
                remove_sending_msg()
                local ia_title = "## IA (" .. api_entry.model .. ")" .. (active_agent_name and ("[@" .. active_agent_name .. "]") or "") .. " >> "
                local count_before = api.nvim_buf_line_count(buf)
                api.nvim_buf_set_lines(buf, -1, -1, false, { "", ia_title, "" })
                
                -- SALVA O NUMERO DA LINHA EXATA DAQUI PRA FRENTE (1-based index)
                current_ia_start_idx = count_before + 2
                response_started = true
            end
            if chunk and chunk ~= "" then
                local lines_to_add = vim.split(chunk, "\n", {plain = true})
                local count = api.nvim_buf_line_count(buf)
                local last_line = api.nvim_buf_get_lines(buf, count - 1, count, false)[1]
                lines_to_add[1] = last_line .. lines_to_add[1]
                api.nvim_buf_set_lines(buf, count - 1, count, false, lines_to_add)
                if popup.popup_win and api.nvim_win_is_valid(popup.popup_win) then
                    api.nvim_win_set_cursor(popup.popup_win, { api.nvim_buf_line_count(buf), 0 })
                    vim.cmd("normal! zz"); popup.update_title()
                end
            end
        end,
        function(api_entry, metrics)
            if not response_started then remove_sending_msg() end
            
            if metrics and (metrics.cache_read_input_tokens or 0) > 0 then
                vim.notify(string.format("⚡ Prompt Caching: %d tokens economizados!", metrics.cache_read_input_tokens), vim.log.levels.INFO)
            end
            
            local b_lines = api.nvim_buf_get_lines(buf, 0, -1, false)
            local has_tool = false
            
            -- AGORA ELE LÊ APENAS O TEXTO DESTA ITERAÇÃO (Isolado de fraudes da IA)
            local scan_start = current_ia_start_idx or 1
            for i = scan_start, #b_lines do
                if b_lines[i]:match("<tool_call") then has_tool = true; break end
            end

            if has_tool then vim.defer_fn(function() require('multi_context').ExecuteTools(current_ia_start_idx) end, 100)
            else M.TerminateTurn() end
        end,
        function(err_msg)
            remove_sending_msg()
            api.nvim_buf_set_lines(buf, -1, -1, false, { "", "**[ERRO]** " .. err_msg, "", user_prefix .. " " })
            M.is_autonomous = false
        end
    )
end

function M.ExecuteTools(ia_idx)
    local p = require('multi_context.ui.popup')
    local buf = p.popup_buf
    if not buf or not vim.api.nvim_buf_is_valid(buf) then buf = vim.api.nvim_get_current_buf() end

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local last_ia_idx = ia_idx
    
    if not last_ia_idx then
        -- Fallback seguro para chamadas manuais (Atalho do Teclado)
        last_ia_idx = 0
        for i = #lines, 1, -1 do if lines[i]:match("^## IA %(") then last_ia_idx = i; break end end
        if last_ia_idx == 0 then
            for i = #lines, 1, -1 do if lines[i]:match("^## IA") then last_ia_idx = i; break end end
        end
    end
    if last_ia_idx == 0 then return end

    local prefix_lines = {}; for i = 1, last_ia_idx - 1 do table.insert(prefix_lines, lines[i]) end
    local process_lines = {}; for i = last_ia_idx, #lines do table.insert(process_lines, lines[i]) end
    local content_to_process = table.concat(process_lines, "\n")
    
    local new_content = ""; local cursor = 1; local has_changes = false
    local abort_all = false; local approve_all = false
    local pending_rewrite_content = nil

    local dangerous_commands = {"rm%s+-rf", "mkfs", "sudo ", ">%s*/dev", "chmod ", "chown "}
    local function is_dangerous(cmd)
        if not cmd then return false end
        for _, pat in ipairs(dangerous_commands) do if cmd:match(pat) then return true end end
        return false
    end

    while cursor <= #content_to_process do
        local tag_start, tag_end = content_to_process:find("<tool_call[^>]*>", cursor)
        if not tag_start then new_content = new_content .. content_to_process:sub(cursor); break end

        new_content = new_content .. content_to_process:sub(cursor, tag_start - 1)
        local tag_str = content_to_process:sub(tag_start, tag_end)
        local close_start, close_end = content_to_process:find("</tool_call%s*>", tag_end + 1)
        
        local inner = ""
        if not close_start then inner = content_to_process:sub(tag_end + 1); close_end = #content_to_process
        else inner = content_to_process:sub(tag_end + 1, close_start - 1) end
        
        local attrs_str = tag_str:sub(11, -2)
        local function get_attr(n) return attrs_str:match(n .. '%s*=%s*["\']([^"\']+)["\']') end
        local name = get_attr("name"); local path = get_attr("path"); local query = get_attr("query")
        local start_line = get_attr("start"); local end_line = get_attr("end")

        if not name or name == "" then
            local ok, json = pcall(vim.fn.json_decode, vim.trim(inner))
            if ok and type(json) == "table" then
                name = json.name
                if type(json.arguments) == "table" then
                    path = json.arguments.path; query = json.arguments.query
                    start_line = json.arguments.start or json.arguments.start_line
                    end_line = json.arguments["end"] or json.arguments.end_line
                    inner = json.arguments.command or json.arguments.content or json.arguments.code or inner
                end
            end
        end

        local clean_inner = inner:gsub("^%s*```[%w_]*\n", ""):gsub("\n%s*```%s*$", "")
        
        if abort_all then
            new_content = new_content .. tag_str .. clean_inner .. "</tool_call>"; cursor = close_end + 1
        else
            has_changes = true
            local choice = 1
            if not approve_all then
                if M.is_autonomous then
                    if name == "run_shell" and is_dangerous(clean_inner) then
                        vim.notify("🛡️ Comando PERIGOSO detectado.", vim.log.levels.ERROR)
                        choice = vim.fn.confirm("Permitir execução PERIGOSA: " .. clean_inner, "&Sim\n&Nao\n&Todos\n&Cancelar", 2)
                    elseif name == "rewrite_chat_buffer" then
                        choice = vim.fn.confirm("Agente solicitou DESTRUIR E COMPRIMIR o chat. Permitir?", "&Sim\n&Nao\n&Todos\n&Cancelar", 1)
                    else choice = 3; approve_all = true end
                else
                    local target = path and ("\nAlvo: " .. path) or ""
                    target = query and (target .. "\nBusca: " .. query) or target
                    if name == "rewrite_chat_buffer" then target = "\n[ALERTA DESTRUTIVO: Isso reescreverá o buffer]" end
                    choice = vim.fn.confirm(string.format("Agente requisitou [%s]. Permitir?%s", tostring(name), target), "&Sim\n&Nao\n&Todos\n&Cancelar", 1)
                end
            end

            if choice == 3 then approve_all = true; choice = 1
            elseif choice == 4 or choice == 0 then abort_all = true; new_content = new_content .. tag_str .. clean_inner .. "</tool_call>"; cursor = close_end + 1; goto continue end

            local result = ""
            if choice == 2 then
                result = "Acesso NEGADO pelo usuario."
                new_content = new_content .. string.format('<tool_rejected name="%s">\n%s\n</tool_rejected>\n\n>[Sistema]: %s', tostring(name), clean_inner, result)
            else
                local tools = require('multi_context.tools')
                if name == "rewrite_chat_buffer" then
                    M.last_backup = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                    local backup_file = vim.fn.stdpath("data") .. "/mctx_backup_" .. os.date("%Y%m%d_%H%M%S") .. ".mctx"
                    vim.fn.writefile(M.last_backup, backup_file)
                    vim.notify("💾 Backup pré-compressão salvo (use :ContextUndo para reverter)", vim.log.levels.INFO)
                    pending_rewrite_content = clean_inner
                    result = "Buffer reescrito."
                elseif name == "list_files" then result = tools.list_files()
                elseif name == "read_file" then result = tools.read_file(path)
                elseif name == "edit_file" then result = tools.edit_file(path, clean_inner)
                elseif name == "run_shell" then result = tools.run_shell(clean_inner)
                elseif name == "search_code" then result = tools.search_code(query)
                elseif name == "replace_lines" then result = tools.replace_lines(path, start_line, end_line, clean_inner)
                else result = "Erro: Ferramenta desconhecida." end
                
                if not pending_rewrite_content then
                    new_content = new_content .. string.format('<tool_executed name="%s" path="%s">\n%s\n</tool_executed>\n\n>[Sistema]: Resultado:\n```text\n%s\n```', tostring(name), tostring(path), clean_inner, result)
                end
            end
        end
        ::continue::
        cursor = close_end + 1
    end

    if not has_changes or abort_all then M.TerminateTurn(); return end

    if pending_rewrite_content then
        local rewrite_lines = vim.split(pending_rewrite_content, "\n", {plain=true})
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, rewrite_lines)
    else
        local final_lines = {}
        for _, l in ipairs(prefix_lines) do table.insert(final_lines, l) end
        for _, l in ipairs(vim.split(new_content, "\n", {plain=true})) do table.insert(final_lines, l) end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, final_lines)
    end

    M.auto_loop_count = M.auto_loop_count + 1
    if M.auto_loop_count >= 15 then
        vim.notify("Limite de 15 loops atingido. Pausando por segurança.", vim.log.levels.WARN)
        M.TerminateTurn(); return
    end

    local cfg = require('multi_context.config')
    local user_prefix = "## " .. (cfg.options.user_name or "Nardi") .. " >>"
    local sys_msg = "[Sistema]: Ferramentas executadas. Leia o resultado. Se a tarefa foi concluída, informe o resultado final."

    local b_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    table.insert(b_lines, ""); table.insert(b_lines, user_prefix .. " " .. sys_msg)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, b_lines)
    require('multi_context.ui.highlights').apply_chat(buf)

    vim.defer_fn(function() require('multi_context').SendFromPopup() end, 100)
end

vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
        if _G.MultiContextTempFiles then for _, f in ipairs(_G.MultiContextTempFiles) do pcall(os.remove, f) end end
    end
})

vim.cmd([[
  command! -range Context lua require('multi_context').ContextChatHandler(<line1>, <line2>)
  command! -nargs=0 ContextUndo lua require('multi_context').ContextUndo()
  command! -nargs=0 ContextFolder lua require('multi_context').ContextChatFolder()
  command! -nargs=0 ContextRepo lua require('multi_context').ContextChatRepo()
  command! -nargs=0 ContextGit lua require('multi_context').ContextChatGit()
  command! -nargs=0 ContextApis lua require('multi_context').ContextApis()
  command! -nargs=0 ContextTree lua require('multi_context').ContextTree()
  command! -nargs=0 ContextBuffers lua require('multi_context').ContextBuffers()
  command! -nargs=0 ContextToggle lua require('multi_context').TogglePopup()
]])

return M
