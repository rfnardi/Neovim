#!/bin/bash

echo "Restaurando sistema de Highlights avançado, Folds clássicos e Título Estático..."

# --- 1. HIGHLIGHTS.LUA (Cores e Marcações Avançadas) ---
cat << 'EOF' > lua/multi_context/ui/highlights.lua
local api = vim.api
local M = {}

M.ns_id = api.nvim_create_namespace("multi_context_highlights")

M.define_groups = function()
    -- Grupos do seletor
    vim.cmd("highlight default ContextSelectorTitle    gui=bold guifg=#FFA500 guibg=NONE")
    vim.cmd("highlight default ContextSelectorCurrent  gui=bold guifg=#B22222 guibg=NONE")
    vim.cmd("highlight default ContextSelectorSelected gui=bold guifg=#FFFF00 guibg=NONE")
    
    -- Grupos avançados do chat (recuperados)
    vim.cmd("highlight default ContextHeader gui=bold guifg=#FF4500 guibg=NONE")
    vim.cmd("highlight default ContextUserAI gui=bold guifg=#0000CD guibg=NONE")
    vim.cmd("highlight default ContextUser gui=bold guifg=#B22222 guibg=NONE")
    vim.cmd("highlight default ContextCurrentBuffer gui=bold guifg=#FFA500 guibg=NONE")
    vim.cmd("highlight default ContextUpdateMessages gui=bold guifg=#FFA500 guibg=NONE")
    vim.cmd("highlight default ContextBoldText gui=bold guifg=#FFA500 guibg=NONE")
    vim.cmd("highlight default ContextApiInfo gui=bold guifg=#FFA500 guibg=NONE")
end

M.apply_chat = function(buf)
    if not api.nvim_buf_is_valid(buf) then return end
    local config = require('multi_context.config')
    local user_name = config.options.user_name or "User"
    
    api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)
    M.define_groups()

    local total_lines = api.nvim_buf_line_count(buf)
    for i = 0, total_lines - 1 do
        local line = api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
        if not line then goto continue end

        if line:match("^===") or line:match("^==") then
            api.nvim_buf_add_highlight(buf, M.ns_id, "ContextHeader", i, 0, -1)
        end
        if line:match("## buffer atual ##") then
            local s, e = line:find("## buffer atual ##")
            if s then api.nvim_buf_add_highlight(buf, M.ns_id, "ContextCurrentBuffer", i, s-1, e) end
        end
        if line:match("%[mensagem enviada%]") then
            local s, e = line:find("%[mensagem enviada%]")
            if s then api.nvim_buf_add_highlight(buf, M.ns_id, "ContextUpdateMessages", i, s-1, e) end
        end
        if line:match("%*%*.*%*%*") then
            local s, e = line:find("%*%*.*%*%*")
            if s then api.nvim_buf_add_highlight(buf, M.ns_id, "ContextBoldText", i, s-1, e) end
        end
        if line:match("^## " .. user_name .. " >>") then
            local s, e = line:find("## " .. user_name .. " >>")
            if s then api.nvim_buf_add_highlight(buf, M.ns_id, "ContextUser", i, s-1, e) end
        end
        if line:match("^## IA") then
            local s, e = line:find("## IA.*>>")
            if not s then s, e = line:find("## IA") end
            if s then api.nvim_buf_add_highlight(buf, M.ns_id, "ContextUserAI", i, s-1, e) end
        end
        if line:match("^## API atual:") then
            local s, e = line:find("## API atual:")
            if s then api.nvim_buf_add_highlight(buf, M.ns_id, "ContextApiInfo", i, s-1, e) end
        end

        ::continue::
    end
end

M.apply_selector = function(buf, api_list)
    if not api.nvim_buf_is_valid(buf) then return end
    api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)
    M.define_groups()

    api.nvim_buf_add_highlight(buf, M.ns_id, "ContextSelectorTitle", 0, 0, -1)
    api.nvim_buf_add_highlight(buf, M.ns_id, "ContextSelectorTitle", 1, 0, -1)

    for i = 3, 3 + #api_list - 1 do
        local line = api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
        if line then
            if line:match("^❯") then
                api.nvim_buf_add_highlight(buf, M.ns_id, "ContextSelectorCurrent", i, 0, -1)
            end
            if line:match("%(selecionada%)$") then
                api.nvim_buf_add_highlight(buf, M.ns_id, "ContextSelectorSelected", i, 0, -1)
            end
        end
    end

    local total = api.nvim_buf_line_count(buf)
    if total >= 2 then
        api.nvim_buf_add_highlight(buf, M.ns_id, "ContextSelectorTitle", total - 2, 0, -1)
    end
end

return M
EOF
echo "[OK] ui/highlights.lua"

# --- 2. POPUP.LUA (Título Fixo e Folds Manuais Clássicos) ---
cat << 'EOF' > lua/multi_context/ui/popup.lua
local api = vim.api
local M   = {}

M.popup_buf = nil
M.popup_win = nil

function M.create_popup(initial_content)
    if M.popup_win and api.nvim_win_is_valid(M.popup_win) then
        api.nvim_set_current_win(M.popup_win)
        return M.popup_buf, M.popup_win
    end

    local config = require('multi_context.config')
    local hl     = require('multi_context.ui.highlights')

    local buf = api.nvim_create_buf(false, true)
    M.popup_buf = buf

    vim.bo[buf].buftype   = 'nofile'
    vim.bo[buf].filetype  = 'markdown'
    vim.bo[buf].bufhidden = 'hide'
    vim.bo[buf].swapfile  = false

    local km = { noremap = true, silent = true }
    api.nvim_buf_set_keymap(buf, "n", "<CR>", "<Cmd>lua require('multi_context').SendFromPopup()<CR>", km)
    api.nvim_buf_set_keymap(buf, "i", "<C-CR>", "<Esc><Cmd>lua require('multi_context').SendFromPopup()<CR>", km)
    api.nvim_buf_set_keymap(buf, "n", "<C-CR>", "<Cmd>lua require('multi_context').SendFromPopup()<CR>", km)
    api.nvim_buf_set_keymap(buf, "i", "<S-CR>", "<Esc><Cmd>lua require('multi_context').SendFromPopup()<CR>", km)
    api.nvim_buf_set_keymap(buf, "n", "<S-CR>", "<Cmd>lua require('multi_context').SendFromPopup()<CR>", km)

    api.nvim_buf_set_keymap(buf, "n", "<A-b>", "<Cmd>lua require('multi_context.utils').copy_code_block()<CR>", km)
    api.nvim_buf_set_keymap(buf, "i", "<A-b>", "<Esc><Cmd>lua require('multi_context.utils').copy_code_block()<CR>a", km)
    api.nvim_buf_set_keymap(buf, "n", "q", "<Cmd>q<CR>", km)

    local width  = math.ceil(vim.o.columns * 0.8)
    local height = math.ceil(vim.o.lines   * 0.8)
    local row    = math.ceil((vim.o.lines   - height) / 2)
    local col    = math.ceil((vim.o.columns - width)  / 2)

    -- >>> TÍTULO FIXO REQUISITADO <<<
    local title = " Multi_Context_Chat "

    local win = api.nvim_open_win(buf, true, {
        relative  = 'editor',
        width     = width,
        height    = height,
        row       = row,
        col       = col,
        style     = 'minimal',
        border    = 'rounded',
        title     = title,
        title_pos = 'center',
    })
    M.popup_win = win

    api.nvim_create_autocmd("WinClosed", {
        pattern  = tostring(win),
        once     = true,
        callback = function() M.popup_win = nil; M.popup_buf = nil end,
    })

    api.nvim_create_autocmd("BufWipeout", {
        buffer   = buf,
        once     = true,
        callback = function()
            if vim.api.nvim_buf_is_valid(buf) then
                vim.bo[buf].modifiable = true
            end
        end,
    })

    local user_prefix = "## " .. config.options.user_name .. " >> "
    if initial_content and initial_content ~= "" then
        local init_lines = vim.split(initial_content, "\n", { plain = true })
        api.nvim_buf_set_lines(buf, 0, -1, false, init_lines)
        local last_line = init_lines[#init_lines] or ""
        if not last_line:match("^## " .. config.options.user_name .. " >>") then
            api.nvim_buf_set_lines(buf, -1, -1, false, { "", user_prefix })
        end
    else
        api.nvim_buf_set_lines(buf, 0, -1, false, { user_prefix })
    end

    -- Configuração de folds manual antes de aplicar a varredura
    api.nvim_buf_set_option(buf, "foldmethod", "manual")
    api.nvim_buf_set_option(buf, "foldenable", true)
    api.nvim_buf_set_option(buf, "foldlevel", 1)

    local last_ln  = api.nvim_buf_line_count(buf)
    local last_txt = api.nvim_buf_get_lines(buf, last_ln - 1, last_ln, false)[1] or ""
    api.nvim_win_set_cursor(win, { last_ln, #last_txt })

    hl.apply_chat(buf)
    M.create_folds(buf)

    return buf, win
end

-- >>> FUNÇÃO DE FOLDS CLÁSSICA RECUPERADA <<<
function M.create_folds(buf)
    if not buf or not api.nvim_buf_is_valid(buf) then return end
    local config = require('multi_context.config')
    local user_name = config.options.user_name or "User"
    local total_lines = api.nvim_buf_line_count(buf)

    -- Limpar folds existentes
    vim.api.nvim_buf_call(buf, function() pcall(vim.cmd, 'normal! zE') end)

    local headers = {}
    for i = 0, total_lines - 1 do
        local line = api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
        if line and (line:match("^## " .. user_name .. " >>") or line:match("^## IA") or 
            line:match("^===") or line:match("^==")) then
            table.insert(headers, {line = i, type = "foldable"})
        elseif line and line:match("^## API atual:") then
            table.insert(headers, {line = i, type = "api_info"})
        end
    end

    table.sort(headers, function(a, b) return a.line < b.line end)

    local last_ia_header_index = nil
    for i = #headers, 1, -1 do
        if headers[i].type == "foldable" and headers[i].line and api.nvim_buf_get_lines(buf, headers[i].line, headers[i].line + 1, false)[1]:match("^## IA") then
            last_ia_header_index = i
            break
        end
    end

    for i = 1, #headers do
        local current_header = headers[i]
        if current_header.type ~= "api_info" then
            local fold_start = current_header.line + 1
            local fold_end = total_lines - 1

            for j = i + 1, #headers do
                fold_end = headers[j].line - 1
                break
            end

            if fold_start <= fold_end then
                vim.api.nvim_buf_call(buf, function()
                    pcall(vim.cmd, string.format("%d,%dfold", fold_start + 1, fold_end + 1))
                end)
            end
        end
    end

    for i = 1, #headers do
        local current_header = headers[i]
        if current_header.type == "foldable" and i ~= last_ia_header_index then
            local fold_start = current_header.line + 1
            local fold_end = total_lines - 1

            for j = i + 1, #headers do
                fold_end = headers[j].line - 1
                break
            end

            if fold_start <= fold_end then
                vim.api.nvim_buf_call(buf, function()
                    pcall(vim.cmd, string.format("%d,%dfoldclose", fold_start + 1, fold_end + 1))
                end)
            end
        end
    end

    if last_ia_header_index then
        local last_ia_header = headers[last_ia_header_index]
        local fold_start = last_ia_header.line + 1
        local fold_end = total_lines - 1

        for j = last_ia_header_index + 1, #headers do
            fold_end = headers[j].line - 1
            break
        end

        if fold_start <= fold_end then
            vim.api.nvim_buf_call(buf, function()
                pcall(vim.cmd, string.format("%dfoldopen!", fold_start + 1))
            end)
        end
    end
end

function M.update_title()
    -- Função agora vazia: impede que a API dinâmica mude o título fixo.
end

return M
EOF
echo "[OK] ui/popup.lua"

# --- 3. INIT.LUA (Garantir que as Folds são re-calculadas pós-mensagem) ---
cat << 'EOF' > patch_init_folds.awk
/hl.apply_chat\(buf\)/ {
    print "            hl.apply_chat(buf)"
    print "            ui_popup.create_folds(buf)"
    next
}
{ print }
EOF
awk -f patch_init_folds.awk lua/multi_context/init.lua > tmp_init.lua && mv tmp_init.lua lua/multi_context/init.lua
rm patch_init_folds.awk
echo "[OK] init.lua"

echo "Tudo perfeitamente restaurado! Teste o plugin novamente!"
