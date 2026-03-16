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
        callback = function() M.popup_win = nil end,
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

    local last_ln  = api.nvim_buf_line_count(buf)
    local last_txt = api.nvim_buf_get_lines(buf, last_ln - 1, last_ln, false)[1] or ""
    api.nvim_win_set_cursor(win, { last_ln, #last_txt })

    hl.apply_chat(buf)
    
    -- Aqui os folds são aplicados de forma segura (sem referenciar o ID da janela diretamente)
    M.create_folds(buf)

    return buf, win
end

-- Função que dita AS REGRAS matemáticas de onde as dobras começam
-- Função que dita AS REGRAS matemáticas de onde as dobras começam
function M.fold_expr(lnum)
    local line = vim.fn.getline(lnum)
    local prev_line = vim.fn.getline(lnum - 1)
    local next_line = vim.fn.getline(lnum + 1)

    -- Padrões que identificam títulos e cabeçalhos
    local is_header = function(s)
        if not s then return false end
        -- Exceção: o rodapé da API não é um título principal
        if s:match("^## API atual:") then return false end
        
        return s:match("^===") or s:match("^== Arquivo:") or s:match("^## ")
    end

    -- 1. Cabeçalhos ficam SEMPRE visíveis (nível 0 de dobra)
    if is_header(line) then
        return "0"
    end

    -- 2. Se uma linha em branco antecede o próximo cabeçalho, ela encerra a dobra (nível 0)
    -- Isso garante que as dobras não se misturem
    if line == "" and is_header(next_line) then
        return "0"
    end

    -- 3. Se a linha de cima foi um cabeçalho, ESTA linha COMEÇA a dobra do conteúdo
    if is_header(prev_line) then
        return ">1"
    end

    -- 4. Todo o resto do texto acompanha a dobra atual
    return "="
end

-- Função para deixar o visual do texto ocultado bem elegante
function M.fold_text()
    local lines_count = vim.v.foldend - vim.v.foldstart + 1
    local first_line = vim.fn.getline(vim.v.foldstart)
    -- Mostra uma setinha, a quantidade de linhas ocultas, e a primeira linha do código
    return "    ↳ ⋯ [" .. lines_count .. " linhas ocultas] ⋯  " .. vim.trim(first_line)
end

function M.create_folds(buf)
    if not buf or not api.nvim_buf_is_valid(buf) then return end
    
    -- Aplica as regras matemáticas e blinda o buffer contra o Markdown
    vim.api.nvim_buf_call(buf, function()
        vim.opt_local.foldmethod = "expr"
        vim.opt_local.foldexpr = "v:lua.require('multi_context.ui.popup').fold_expr(v:lnum)"
        vim.opt_local.foldtext = "v:lua.require('multi_context.ui.popup').fold_text()"
        vim.opt_local.foldenable = true
        vim.opt_local.foldlevel = 0 -- Inicia fechando todos os conteúdos
    end)
    
    -- Abre estrategicamente apenas o seu prompt atual e a última resposta da IA
    vim.api.nvim_buf_call(buf, function()
        local total = vim.api.nvim_buf_line_count(buf)
        
        -- Tenta abrir a dobra da última linha (onde você vai digitar)
        pcall(vim.cmd, "silent! " .. total .. "foldopen!")
        
        -- Procura de baixo pra cima a última IA e mantém a resposta dela aberta
        for i = total, 1, -1 do
            local line = vim.api.nvim_buf_get_lines(buf, i-1, i, false)[1]
            if line and line:match("^## IA") then
                -- O título da IA (linha 'i') é nível 0, então abrimos a dobra do conteúdo (i+1)
                pcall(vim.cmd, "silent! " .. (i + 1) .. "foldopen!")
                break
            end
        end
    end)
end

function M.update_title()
    -- Vazio propositalmente para não sobrescrever o título fixo da janela
end

return M

