-- lua/multi_context/init.lua
local api = vim.api
local utils = require('multi_context.utils')
local popup = require('multi_context.ui.popup')
local commands = require('multi_context.commands')
local config = require('multi_context.config')

local tool_parser = require('multi_context.tool_parser')
local tool_runner = require('multi_context.tool_runner')
local react_loop = require('multi_context.react_loop')
local prompt_parser = require('multi_context.prompt_parser')
local scroller = require('multi_context.ui.scroller')

local M = {}
M.popup_buf = popup.popup_buf
M.popup_win = popup.popup_win
M.current_workspace_file = nil

M.setup = function(opts) if config and config.setup then config.setup(opts) end end

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
    if not buf or not api.nvim_buf_is_valid(buf) then buf = api.nvim_get_current_buf() end
    if react_loop.state.last_backup then
        api.nvim_buf_set_lines(buf, 0, -1, false, react_loop.state.last_backup)
        require('multi_context.ui.highlights').apply_chat(buf)
        p.create_folds(buf)
        p.update_title()
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
    react_loop.reset_turn()
    local p = require('multi_context.ui.popup')
    local buf = p.popup_buf
    if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
    
    local cfg = require('multi_context.config')
    local current_api = cfg.get_current_api()
    local user_prefix = "## " .. (cfg.options.user_name or "Nardi") .. " >>"
    
    local next_prompt_lines = { "", "## API atual: " .. current_api, user_prefix .. " " }
    
    if react_loop.state.queued_tasks and react_loop.state.queued_tasks ~= "" then
        table.insert(next_prompt_lines, "> [Checkpoint] Avalie a resposta acima. Pressione <CR> para continuar a fila:")
        for _, q_line in ipairs(vim.split(react_loop.state.queued_tasks, "\n")) do table.insert(next_prompt_lines, q_line) end
        react_loop.state.queued_tasks = nil
    end
    
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, next_prompt_lines)
    p.create_folds(buf)
    require('multi_context.ui.highlights').apply_chat(buf)
    p.update_title()
    
    if p.popup_win and vim.api.nvim_win_is_valid(p.popup_win) then
        vim.api.nvim_win_set_cursor(p.popup_win, { vim.api.nvim_buf_line_count(buf), #next_prompt_lines[#next_prompt_lines] })
        vim.cmd("normal! zz"); vim.cmd("startinsert!")
    end
end

local function get_context_md_content()
    local root = vim.fn.system("git rev-parse --show-toplevel")
    if vim.v.shell_error == 0 then root = root:gsub("\n", "") else root = vim.fn.getcwd() end
    local filepath = root .. "/CONTEXT.md"
    if vim.fn.filereadable(filepath) == 1 then return table.concat(vim.fn.readfile(filepath), "\n") end
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

    local raw_user_text = table.concat(current_task_lines, "\n"):gsub("^%s*", ""):gsub("%s*$", "")
    if #queued_tasks_lines > 0 then react_loop.state.queued_tasks = table.concat(queued_tasks_lines, "\n") end
    if raw_user_text == "" then vim.notify("Digite algo antes de enviar.", vim.log.levels.WARN); return end

    local parsed_intent = prompt_parser.parse_user_input(raw_user_text, agents)
    
    if parsed_intent.agent_name then
        if parsed_intent.agent_name == "reset" then react_loop.state.active_agent = nil
        else react_loop.state.active_agent = parsed_intent.agent_name end
    end
    if parsed_intent.is_autonomous then react_loop.state.is_autonomous = true end

    local text_to_send = parsed_intent.text_to_send
    local active_agent_name = react_loop.state.active_agent

    local sending_msg = "[Enviando requisição" .. (active_agent_name and (" via @" .. active_agent_name) or "") .. "...]"
    api.nvim_buf_set_lines(buf, -1, -1, false, { "", sending_msg })

    local history_lines = api.nvim_buf_get_lines(buf, 0, start_idx, false)
    local messages = require('multi_context.conversation').build_history(history_lines)
    
    local base_sys_prompt = "Você é um Engenheiro de Software Autônomo no Neovim."
    local memory_context = get_context_md_content()
    local system_prompt = prompt_parser.build_system_prompt(base_sys_prompt, memory_context, active_agent_name, agents)
    
    table.insert(messages, 1, { role = "system", content = system_prompt })
    
    if #messages > 1 and messages[#messages].role == "user" then
        messages[#messages].content = messages[#messages].content .. "\n\n" .. text_to_send
    else
        table.insert(messages, { role = "user", content = text_to_send })
    end

    local response_started = false
    local current_ia_start_idx = nil
    
    local function remove_sending_msg()
        local count = api.nvim_buf_line_count(buf)
        local last_line = api.nvim_buf_get_lines(buf, count - 1, count, false)[1]
        if last_line:match("%[Enviando requisi") then api.nvim_buf_set_lines(buf, count - 2, count, false, {}) end
    end

    -- ========================================================
    -- NOVA INTEGRAÇÃO: Inicia o rastreamento do Scroller
    -- ========================================================
    scroller.start_streaming(buf, popup.popup_win)

    require('multi_context.api_client').execute(messages, 
        function(chunk, api_entry)
            if not response_started then
                remove_sending_msg()
                local ia_title = "## IA (" .. api_entry.model .. ")" .. (active_agent_name and ("[@" .. active_agent_name .. "]") or "") .. " >> "
                local count_before = api.nvim_buf_line_count(buf)
                api.nvim_buf_set_lines(buf, -1, -1, false, { "", ia_title, "" })
                current_ia_start_idx = count_before + 2
                response_started = true
            end
            if type(chunk) == "string" and chunk ~= "" then
                local lines_to_add = vim.split(chunk, "\n", {plain = true})
                local count = api.nvim_buf_line_count(buf)
                local last_line = api.nvim_buf_get_lines(buf, count - 1, count, false)[1]
                lines_to_add[1] = last_line .. lines_to_add[1]
                api.nvim_buf_set_lines(buf, count - 1, count, false, lines_to_add)
                
                -- ========================================================
                -- NOVA INTEGRAÇÃO: Delega o controle de movimento da tela
                -- ========================================================
                scroller.on_chunk_received(buf, popup.popup_win)
                
                if popup.popup_win and api.nvim_win_is_valid(popup.popup_win) then
                    popup.update_title()
                end
            end
        end,
        function(api_entry, metrics)
            scroller.stop_streaming(buf) -- Desliga o monitor ao finalizar
            if not response_started then remove_sending_msg() end
            if metrics and (metrics.cache_read_input_tokens or 0) > 0 then
                vim.notify(string.format("⚡ Prompt Caching: %d tokens economizados!", metrics.cache_read_input_tokens), vim.log.levels.INFO)
            end
            
            local b_lines = api.nvim_buf_get_lines(buf, 0, -1, false)
            local has_tool = false
            local scan_start = current_ia_start_idx or 1
            for i = scan_start, #b_lines do
                if b_lines[i]:match("<tool_call") then has_tool = true; break end
            end

            if has_tool then vim.defer_fn(function() require('multi_context').ExecuteTools(current_ia_start_idx) end, 100)
            else M.TerminateTurn() end
        end,
        function(err_msg)
            scroller.stop_streaming(buf) -- Desliga o monitor se falhar
            remove_sending_msg()
            api.nvim_buf_set_lines(buf, -1, -1, false, { "", "**[ERRO]** " .. err_msg, "", user_prefix .. " " })
            react_loop.state.is_autonomous = false
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
        last_ia_idx = 0
        for i = #lines, 1, -1 do if lines[i]:match("^## IA %(") then last_ia_idx = i; break end end
        if last_ia_idx == 0 then
            for i = #lines, 1, -1 do if lines[i]:match("^## IA") then last_ia_idx = i; break end end
        end
    end
    if last_ia_idx == 0 then return end

    local prefix_lines = {}; for i = 1, last_ia_idx - 1 do table.insert(prefix_lines, lines[i]) end
    local process_lines = {}; for i = last_ia_idx, #lines do table.insert(process_lines, lines[i]) end
    
    local content_to_process = tool_parser.sanitize_payload(table.concat(process_lines, "\n"))

    local new_content = ""
    local cursor = 1
    local has_changes = false
    local abort_all = false
    local approve_all_ref = { value = false }
    local pending_rewrite_content = nil
    local should_continue_loop = false 

    while cursor <= #content_to_process do
        local parsed_tag = tool_parser.parse_next_tool(content_to_process, cursor)
        
        if not parsed_tag then
            new_content = new_content .. content_to_process:sub(cursor)
            break
        end

        new_content = new_content .. parsed_tag.text_before

        if parsed_tag.is_invalid or not parsed_tag.name or parsed_tag.name == "" then
            new_content = new_content .. parsed_tag.raw_tag .. (parsed_tag.inner or "") .. (parsed_tag.close_start and "</tool_call>" or "")
            cursor = parsed_tag.close_end + 1
            goto continue
        end

        if abort_all then
            new_content = new_content .. parsed_tag.raw_tag .. parsed_tag.inner .. "</tool_call>"
            cursor = parsed_tag.close_end + 1
            goto continue
        end

        has_changes = true

        do
            local tag_output, should_abort, cont_loop, rew_content, backup_made = tool_runner.execute(
                parsed_tag, 
                react_loop.state.is_autonomous, 
                approve_all_ref, 
                buf
            )

            if backup_made then react_loop.state.last_backup = backup_made end
            if rew_content then pending_rewrite_content = rew_content end
            if cont_loop then should_continue_loop = true end

            if should_abort then
                abort_all = true
                new_content = new_content .. parsed_tag.raw_tag .. parsed_tag.inner .. "</tool_call>"
            else
                new_content = new_content .. tag_output
                if tag_output:match(">%[Sistema%]: ERRO %- Ferramenta") then
                    react_loop.state.is_autonomous = false
                    should_continue_loop = false
                end
            end
        end

        ::continue::
        cursor = parsed_tag.close_end + 1
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

    if pending_rewrite_content or (not should_continue_loop and not react_loop.state.is_autonomous) then
        M.TerminateTurn(); return
    end

    if react_loop.check_circuit_breaker() then
        M.TerminateTurn(); return
    end

    local cfg = require('multi_context.config')
    local user_prefix = "## " .. (cfg.options.user_name or "Nardi") .. " >>"
    
    local sys_msg = "[Sistema]: Informação coletada. Analise o resultado e continue."
    if not should_continue_loop and react_loop.state.is_autonomous then
        sys_msg = "[Sistema]: Ação executada. Verifique se o passo foi concluído ou prossiga para a próxima ação."
    end

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
