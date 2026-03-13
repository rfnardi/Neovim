#!/bin/bash

echo "Desfazendo o erro de sintaxe e restaurando os arquivos..."

# 1. Limpar o utils.lua
awk '/^M\.log_debug = function/ {exit} {print}' lua/multi_context/utils.lua > tmp_utils.lua && mv tmp_utils.lua lua/multi_context/utils.lua

# 2. Restaurar o ui/popup.lua
awk '
/local user_prefix = "## " \.\. config\.options\.user_name \.\. " >> "/ {
    print "    local user_prefix = \"## \" .. config.options.user_name .. \" >> \""
    print "    if initial_content and initial_content ~= \"\" then"
    print "        local init_lines = vim.split(initial_content, \"\\n\", { plain = true })"
    print "        api.nvim_buf_set_lines(buf, 0, -1, false, init_lines)"
    print "        api.nvim_buf_set_lines(buf, -1, -1, false, { \"\", user_prefix })"
    print "    else"
    print "        api.nvim_buf_set_lines(buf, 0, -1, false, { user_prefix })"
    print "    end"
    skip = 1
    next
}
skip && /api.nvim_buf_set_lines\(buf, 0, -1, false, { user_prefix }\)/ {
    skip = 0
    next
}
!skip { print }
' lua/multi_context/ui/popup.lua > tmp_popup.lua && mv tmp_popup.lua lua/multi_context/ui/popup.lua

# 3. Restaurar o api_handlers.lua
awk '
/on_stdout = function\(_, data\)/ {
    print "            on_stdout = function(_, data)"
    print "                if not data then return end"
    print "                local raw = table.concat(data, \"\")"
    print "                if raw == \"\" then return end"
    print "                buffer = buffer .. raw"
    print "                local chunks, rest = extract_text_chunks(buffer)"
    print "                for _, txt in ipairs(chunks) do"
    print "                    callback(txt, nil, false)"
    print "                end"
    print "                buffer = rest"
    print "            end,"
    skip = 1
    next
}
skip && /on_stderr = function/ { skip = 0 }
/on_stderr = function\(_, data\)/ {
    print "            on_stderr = function(_, data)"
    print "                local err = table.concat(data, \"\")"
    print "                if err ~= \"\" and not err:match(\"%%\") then"
    print "                    print(\"DEBUG CURL ERR: \" .. err)"
    print "                end"
    print "            end,"
    skip = 1
    next
}
skip && /on_exit = function/ { skip = 0 }
!skip { print }
' lua/multi_context/api_handlers.lua > tmp_api.lua && mv tmp_api.lua lua/multi_context/api_handlers.lua

# 4. Restaurar o init.lua
awk '
/function\(chunk, _\)/ {
    print "        function(chunk, _)"
    print "            if chunk and chunk ~= \"\" then"
    print "                accumulated = accumulated .. chunk"
    print "                local now = vim.loop.now()"
    print "                if now - last_render > 50 then"
    print "                    last_render = now"
    print "                    vim.schedule(function()"
    print "                        if vim.api.nvim_buf_is_valid(buf) then"
    print "                            vim.bo[buf].modifiable = true"
    print "                            vim.api.nvim_buf_set_lines(buf, resp_start, -1, false, utils.split_lines(accumulated))"
    print "                        end"
    print "                    end)"
    print "                end"
    print "            end"
    print "        end,"
    skip = 1
    next
}
skip && /-- on_done:/ { skip = 0 }
!skip { print }
' lua/multi_context/init.lua > tmp_init.lua && mv tmp_init.lua lua/multi_context/init.lua

echo "Restauração concluída. O Neovim deve abrir normalmente agora!"
