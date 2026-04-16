-- lua/multi_context/tool_runner.lua
local M = {}
local tools = require('multi_context.tools')

local valid_tools = {
    list_files = true, read_file = true, search_code = true,
    edit_file = true, run_shell = true, replace_lines = true,
    rewrite_chat_buffer = true, get_diagnostics = true
}

local dangerous_commands = {"rm%s+-rf", "mkfs", "sudo ", ">%s*/dev", "chmod ", "chown "}
local function is_dangerous(cmd)
    if not cmd then return false end
    for _, pat in ipairs(dangerous_commands) do if cmd:match(pat) then return true end end
    return false
end

M.execute = function(tool_data, is_autonomous, approve_all_ref, buf)
    local name = tool_data.name
    local clean_inner = tool_data.inner

    if not valid_tools[name] then
        local err_msg = string.format("Ferramenta '%s' não existe. Consulte o manual de ferramentas.", tostring(name))
        local out = string.format('<tool_call name="%s">\n%s\n</tool_call>\n\n>[Sistema]: ERRO - %s', tostring(name), clean_inner, err_msg)
        return out, false, false, nil, nil
    end

    local choice = 1
    if not approve_all_ref.value then
        if is_autonomous then
            if name == "run_shell" and is_dangerous(clean_inner) then
                vim.notify("🛡️ Comando PERIGOSO detectado.", vim.log.levels.ERROR)
                choice = vim.fn.confirm("Permitir execução PERIGOSA: " .. clean_inner, "&Sim\n&Nao\n&Todos\n&Cancelar", 2)
            elseif name == "rewrite_chat_buffer" then
                choice = vim.fn.confirm("Agente solicitou DESTRUIR E COMPRIMIR o chat. Permitir?", "&Sim\n&Nao\n&Todos\n&Cancelar", 1)
            else choice = 3; approve_all_ref.value = true end
        else
            local target = tool_data.path and ("\nAlvo: " .. tool_data.path) or ""
            target = tool_data.query and (target .. "\nBusca: " .. tool_data.query) or target
            if name == "rewrite_chat_buffer" then target = "\n[ALERTA DESTRUTIVO: Isso reescreverá o buffer]" end
            choice = vim.fn.confirm(string.format("Agente requisitou [%s]. Permitir?%s", tostring(name), target), "&Sim\n&Nao\n&Todos\n&Cancelar", 1)
        end
    end

    if choice == 3 then approve_all_ref.value = true; choice = 1 end
    if choice == 4 or choice == 0 then
        local out = string.format('<tool_call name="%s">\n%s\n</tool_call>', tostring(tool_data.raw_tag), clean_inner)
        return out, true, false, nil, nil -- O `true` significa "abortar todo o resto do loop"
    end

    local result = ""
    local should_continue_loop = false
    local pending_rewrite_content = nil
    local backup_made = nil

    if choice == 2 then
        result = "Acesso NEGADO pelo usuario."
        local out = string.format('<tool_call name="%s">\n%s\n</tool_call>\n\n>[Sistema]: ERRO - %s', tostring(name), clean_inner, result)
        return out, false, false, nil, nil
    end

    -- Executor da Ferramenta de fato
    if name == "rewrite_chat_buffer" then
        backup_made = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local backup_file = vim.fn.stdpath("data") .. "/mctx_backup_" .. os.date("%Y%m%d_%H%M%S") .. ".mctx"
        vim.fn.writefile(backup_made, backup_file)
        vim.notify("💾 Backup pré-compressão salvo (use :ContextUndo para reverter)", vim.log.levels.INFO)
        pending_rewrite_content = clean_inner
        result = "Buffer reescrito."
    elseif name == "list_files" then 
        should_continue_loop = true; result = tools.list_files()
    elseif name == "read_file" then 
        should_continue_loop = true; result = tools.read_file(tool_data.path)
    elseif name == "search_code" then 
        should_continue_loop = true; result = tools.search_code(tool_data.query)
    elseif name == "edit_file" then 
        result = tools.edit_file(tool_data.path, clean_inner)
    elseif name == "run_shell" then 
        result = tools.run_shell(clean_inner)
    elseif name == "replace_lines" then 
        result = tools.replace_lines(tool_data.path, tool_data.start_line, tool_data.end_line, clean_inner)
    elseif name == "get_diagnostics" then 
        should_continue_loop = true
        if tools.get_diagnostics then result = tools.get_diagnostics(tool_data.path)
        else result = "ERRO: Ferramenta não implementada." end
    end
    
    local output = ""
    if not pending_rewrite_content then
        output = string.format('<tool_call name="%s" path="%s">\n%s\n</tool_call>\n\n>[Sistema]: Resultado:\n```text\n%s\n```', tostring(name), tostring(tool_data.path or ""), clean_inner, result)
    end

    -- Devolve a formatação pronta e os comandos de ação para o loop pai
    return output, false, should_continue_loop, pending_rewrite_content, backup_made
end

return M
