#!/bin/bash

PLUGIN_DIR="$HOME/.config/nvim/lua/multi_context"
echo "🛡️ Aplicando Blindagem do Parser e Atualizando Tools..."

cat << 'EOF' > "$PLUGIN_DIR/tools.lua"
-- lua/multi_context/tools.lua
local M = {}

local function get_repo_root()
    vim.fn.system("git rev-parse --show-toplevel")
    if vim.v.shell_error ~= 0 then return nil end
    return vim.fn.system("git rev-parse --show-toplevel"):gsub("\n", "")
end

local function resolve_path(path)
    if not path or path == "" then return nil end
    path = vim.trim(path)
    if path:sub(1, 1) == "/" then return path end
    local root = get_repo_root() or vim.fn.getcwd()
    return root .. "/" .. path
end

M.list_files = function()
    local root = get_repo_root()
    if not root then return "ERRO: Fora de um repositório Git." end
    local files = vim.fn.system("git -C " .. vim.fn.shellescape(root) .. " ls-files")
    return "Arquivos rastreados pelo Git:\n" .. files
end

M.read_file = function(path)
    local full_path = resolve_path(path)
    if not full_path then return "ERRO: Atributo 'path' obrigatório." end
    if vim.fn.filereadable(full_path) == 0 then return "ERRO: Arquivo não encontrado (" .. full_path .. ")" end
    return table.concat(vim.fn.readfile(full_path), "\n")
end

M.edit_file = function(path, content)
    local full_path = resolve_path(path)
    if not full_path then return "ERRO: O atributo 'path' é obrigatório." end
    
    local dir = vim.fn.fnamemodify(full_path, ":h")
    if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, "p") end

    -- Blindagem: Limpa lixo de formatação da IA
    content = content:gsub("\r", "")
    content = content:gsub("^%s*```[%w_]*\n", ""):gsub("\n%s*```%s*$", "")
    
    local lines = vim.split(content, "\n", {plain=true})
    local bufnr = vim.fn.bufnr(full_path)
    
    if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        vim.api.nvim_buf_call(bufnr, function() vim.cmd("silent! write") end)
    else
        if vim.fn.writefile(lines, full_path) == -1 then
            return "ERRO: Falha de permissão ao salvar " .. full_path
        end
    end
    vim.notify("✅ Arquivo criado/salvo: " .. full_path, vim.log.levels.INFO)
    return "SUCESSO: Arquivo " .. full_path .. " foi sobrescrito/criado."
end

M.run_shell = function(cmd)
    if not cmd or cmd == "" then return "ERRO: Comando não fornecido." end
    local root = get_repo_root() or vim.fn.getcwd()
    cmd = vim.trim(cmd)
    local bash_script = string.format("cd %s && %s", vim.fn.shellescape(root), cmd)
    local out = vim.fn.system({'bash', '-c', bash_script})
    local status = vim.v.shell_error ~= 0 and ("FALHA (Código " .. vim.v.shell_error .. ")") or "SUCESSO"
    return string.format("Comando:\n%s\n\nStatus: %s\nSaída:\n%s", cmd, status, out)
end

M.search_code = function(query)
    local root = get_repo_root()
    if not root then return "ERRO: Fora de repositório Git." end
    if not query or query == "" then return "ERRO: 'query' obrigatória." end
    local cmd = string.format("git -C %s grep -n -i -I %s", vim.fn.shellescape(root), vim.fn.shellescape(query))
    local out = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 or out == "" then return "Nenhum resultado para: " .. query end
    if #out > 3000 then out = out:sub(1, 3000) .. "\n\n... [AVISO: TRUNCADO] ..." end
    return "Resultados da busca:\n" .. out
end

M.replace_lines = function(path, start_line, end_line, content)
    local full_path = resolve_path(path)
    if not full_path then return "ERRO: 'path' obrigatório." end
    start_line, end_line = tonumber(start_line), tonumber(end_line)
    if not start_line or not end_line then return "ERRO: 'start' e 'end' devem ser números." end
    
    local bufnr = vim.fn.bufnr(full_path)
    local lines = {}
    if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
        lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    else
        if vim.fn.filereadable(full_path) == 0 then return "ERRO: Arquivo não encontrado." end
        lines = vim.fn.readfile(full_path)
    end
    
    if start_line < 1 then start_line = 1 end
    if end_line > #lines then end_line = #lines end
    
    content = content:gsub("\r", "")
    content = content:gsub("^%s*```[%w_]*\n", ""):gsub("\n%s*```%s*$", "")
    local new_lines = content == "" and {} or vim.split(content, "\n", {plain=true})
    
    local final_lines = {}
    for i = 1, start_line - 1 do table.insert(final_lines, lines[i]) end
    for _, l in ipairs(new_lines) do table.insert(final_lines, l) end
    for i = end_line + 1, #lines do table.insert(final_lines, lines[i]) end
    
    if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, final_lines)
        vim.api.nvim_buf_call(bufnr, function() vim.cmd("silent! write") end)
    else
        vim.fn.writefile(final_lines, full_path)
    end
    vim.notify("✅ Edição aplicada: " .. full_path, vim.log.levels.INFO)
    return "SUCESSO: Edição nas linhas " .. start_line .. " a " .. end_line
end

return M
EOF

echo "🛠️ Atualizando init.lua (Parser Ultra-Tolerante)..."
sed -i '/function M.ExecuteTools()/,$d' "$PLUGIN_DIR/init.lua"
cat << 'EOF' >> "$PLUGIN_DIR/init.lua"
function M.ExecuteTools()
    local p = require('multi_context.ui.popup')
    local buf = p.popup_buf
    if not buf or not vim.api.nvim_buf_is_valid(buf) then buf = vim.api.nvim_get_current_buf() end

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local last_ia_idx = 0
    for i = #lines, 1, -1 do if lines[i]:match("^## IA") then last_ia_idx = i; break end end
    if last_ia_idx == 0 then return end

    local prefix_lines = {}; for i = 1, last_ia_idx - 1 do table.insert(prefix_lines, lines[i]) end
    local process_lines = {}; for i = last_ia_idx, #lines do table.insert(process_lines, lines[i]) end
    local content_to_process = table.concat(process_lines, "\n")
    
    local new_content = ""; local cursor = 1; local has_changes = false
    local abort_all = false; local approve_all = false

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
        -- BLINDAGEM 1: Se a IA esqueceu de fechar a tag, fechamos forçadamente.
        if not close_start then 
            inner = content_to_process:sub(tag_end + 1)
            close_end = #content_to_process
        else
            inner = content_to_process:sub(tag_end + 1, close_start - 1)
        end
        
        -- BLINDAGEM 2: Fallback para IAs que cospem JSON
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

        -- BLINDAGEM 3: Limpa Markdown intruso dentro da tag
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
                    else choice = 3; approve_all = true end
                else
                    local target = path and ("\nAlvo: " .. path) or ""
                    target = query and (target .. "\nBusca: " .. query) or target
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
                if name == "list_files" then result = tools.list_files()
                elseif name == "read_file" then result = tools.read_file(path)
                elseif name == "edit_file" then result = tools.edit_file(path, clean_inner)
                elseif name == "run_shell" then result = tools.run_shell(clean_inner)
                elseif name == "search_code" then result = tools.search_code(query)
                elseif name == "replace_lines" then result = tools.replace_lines(path, start_line, end_line, clean_inner)
                else result = "Erro: Ferramenta desconhecida." end
                
                new_content = new_content .. string.format('<tool_executed name="%s" path="%s">\n%s\n</tool_executed>\n\n>[Sistema]: Resultado:\n```text\n%s\n```', tostring(name), tostring(path), clean_inner, result)
            end
        end
        ::continue::
        cursor = close_end + 1
    end

    if not has_changes or abort_all then M.TerminateTurn(); return end

    local final_lines = {}
    for _, l in ipairs(prefix_lines) do table.insert(final_lines, l) end
    for _, l in ipairs(vim.split(new_content, "\n", {plain=true})) do table.insert(final_lines, l) end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, final_lines)

    M.auto_loop_count = M.auto_loop_count + 1
    if M.auto_loop_count >= 15 then
        vim.notify("Limite de 15 loops atingido. Pausando por segurança.", vim.log.levels.WARN)
        M.TerminateTurn(); return
    end

    local cfg = require('multi_context.config')
    local user_prefix = "## " .. (cfg.options.user_name or "Nardi") .. " >>"
    local sys_msg = "[Sistema]: Ferramentas executadas. Leia o resultado acima. Se a tarefa foi concluída, informe o resultado final e atualize o CONTEXT.md se necessário."

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
  command! -nargs=0 ContextFolder lua require('multi_context').ContextChatFolder()
  command! -nargs=0 ContextRepo lua require('multi_context').ContextChatRepo()
  command! -nargs=0 ContextGit lua require('multi_context').ContextChatGit()
  command! -nargs=0 ContextApis lua require('multi_context').ContextApis()
  command! -nargs=0 ContextTree lua require('multi_context').ContextTree()
  command! -nargs=0 ContextBuffers lua require('multi_context').ContextBuffers()
  command! -nargs=0 ContextToggle lua require('multi_context').TogglePopup()
]])

return M
EOF

echo "✅ Parser blindado e Tools atualizados!"
