-- ~/.config/nvim/lua/ollama_context.lua
local api = vim.api
local M = {}

M.popup_buf = nil
M.popup_win = nil
M.history = {}
M.context_text = nil

-- ======================================================
-- Utils
-- ======================================================
local function split_lines(str)
    local t = {}
    for line in str:gmatch("([^\n]*)\n?") do
        table.insert(t, line)
    end
    return t
end

local function insert_after(buf, line_idx, lines)
    api.nvim_buf_set_lines(buf, line_idx + 1, line_idx + 1, false, lines)
end

local function find_last_user_line(buf)
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    for i = #lines, 1, -1 do
        if lines[i]:match("^## Nardi >>") then
            return i - 1, lines[i]
        end
    end
    return nil
end

-- Função para carregar configurações das APIs
local function load_api_config()
    local config_path = vim.fn.expand('~/.config/nvim/ollama_apis.json')
    local file = io.open(config_path, 'r')
    if not file then
        return nil
    end
    local content = file:read('*a')
    file:close()
    return vim.fn.json_decode(content)
end

-- Função para aplicar highlights
local function apply_highlights(buf)
    vim.cmd("highlight ContextHeader gui=bold guifg=#FF4500 guibg=NONE")
    vim.cmd("highlight ContextUserAI gui=bold guifg=#FF6347 guibg=NONE")
    vim.cmd("highlight ContextUser gui=bold guifg=#B22222 guibg=NONE")
    vim.cmd("highlight ContextCurrentBuffer gui=bold guifg=#FFA500 guibg=NONE")
    vim.cmd("highlight ContextUpdateMessages gui=bold guifg=#FFA500 guibg=NONE")

    local total_lines = api.nvim_buf_line_count(buf)

    for i = 0, total_lines - 1 do
        local line = api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
        if line:match("^===") or line:match("^==") then
            api.nvim_buf_add_highlight(buf, -1, "ContextHeader", i, 0, -1)
        end

        if line and line:match("## buffer atual ##") then
            local start_idx, end_idx = line:find("## buffer atual ##")
            if start_idx then
                api.nvim_buf_add_highlight(buf, -1, "ContextCurrentBuffer", i, start_idx-1, end_idx)
            end
        end

        if line and line:match("%[mensagem enviada%]") then
            local start_idx, end_idx = line:find("%[mensagem enviada%]")
            if start_idx then
                api.nvim_buf_add_highlight(buf, -1, "ContextUpdateMessages", i, start_idx-1, end_idx)
            end
        end

        if line and line:match("^## Nardi >>") then
            local start_idx, end_idx = line:find("## Nardi >>")
            if start_idx then
                api.nvim_buf_add_highlight(buf, -1, "ContextUser", i, start_idx-1, end_idx)
            end
        end

        if line and line:match("^## IA >>") then
            local start_idx, end_idx = line:find("## IA >>")
            if start_idx then
                api.nvim_buf_add_highlight(buf, -1, "ContextUserAI", i, start_idx-1, end_idx)
            end
        end
    end
end

-- ======================================================
-- Obter conteúdo do buffer ou seleção
-- ======================================================
function M.get_full_buffer()
    local buf = api.nvim_get_current_buf()
    local line_count = api.nvim_buf_line_count(buf)
    local lines = api.nvim_buf_get_lines(buf, 0, line_count, false)
    return table.concat(lines, "\n")
end

function M.get_selection(start_line, end_line)
    local buf = api.nvim_get_current_buf()
    start_line = tonumber(start_line)
    end_line = tonumber(end_line)
    if not start_line or not end_line then
        vim.notify("Seleção inválida", vim.log.levels.WARN)
        return ""
    end
    local lines = api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
    return table.concat(lines, "\n")
end

-- ======================================================
-- Monta contexto da pasta
-- ======================================================
local function read_folder_context()
    local cur_file = api.nvim_buf_get_name(0)
    if cur_file == "" then return "" end
    local dir = vim.fn.fnamemodify(cur_file, ":h")
    local cur_fname = vim.fn.fnamemodify(cur_file, ":t")
    local context_lines = {}

    -- Seção ls
    table.insert(context_lines, "=== Arquivos na pasta " .. dir .. ":")
    local files = vim.fn.readdir(dir)
    table.insert(context_lines, table.concat(files, "\n"))
    table.insert(context_lines, "")

    -- Seção cat
    for _, fname in ipairs(files) do
        local full_path = dir .. "/" .. fname
        if vim.fn.isdirectory(full_path) == 0 then
            local lines = vim.fn.readfile(full_path)
            local header = "== Arquivo: " .. fname
            if fname == cur_fname then
                header = header .. " ## buffer atual ##"
            end
            table.insert(context_lines, header)
            vim.list_extend(context_lines, lines)
            table.insert(context_lines, "")
        end
    end
    return table.concat(context_lines, "\n")
end

-- ======================================================
-- Abre popup interativo
-- ======================================================
function M.open_popup(text)
    M.context_text = text
    local buf = api.nvim_create_buf(false, true)
    M.popup_buf = buf

    local width = math.floor(vim.o.columns * 0.7)
    local height = math.floor(vim.o.lines * 0.7)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    M.popup_win = api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
    })

    local lines = split_lines(text)
    table.insert(lines, "")
    table.insert(lines, "## Nardi >> ")
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    api.nvim_win_set_cursor(M.popup_win, { #lines, #"## Nardi >> " })
    vim.cmd("startinsert")

    -- Ctrl+S
    api.nvim_buf_set_keymap(buf, "i", "<C-s>", "<Cmd>lua require('ollama_context').SendFromPopup()<CR>", { noremap=true, silent=true })
    api.nvim_buf_set_keymap(buf, "n", "<C-s>", "<Cmd>lua require('ollama_context').SendFromPopup()<CR>", { noremap=true, silent=true })

    -- Aplicar highlights iniciais
    apply_highlights(buf)

    -- ======================================================
    -- Criação manual de folds hierárquicas
    -- ======================================================
    vim.api.nvim_buf_set_option(buf, "foldmethod", "manual")
    vim.api.nvim_buf_set_option(buf, "foldenable", true)
    vim.api.nvim_buf_set_option(buf, "foldlevel", 1)

    -- ======================================================
    -- Nova lógica simplificada para criar folds
    -- ======================================================
    local function create_folds()
        local buf = M.popup_buf
        local total_lines = api.nvim_buf_line_count(buf)
        
        -- Primeiro, vamos limpar todas as folds existentes
        vim.cmd('normal! zE')
        
        -- Encontra todas as linhas de cabeçalho
        local headers = {}
        for i = 0, total_lines - 1 do
            local line = api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
            if line and (line:match("^## Nardi >>") or line:match("^## IA >>") or 
                       line:match("^===") or line:match("^==")) then
                table.insert(headers, i)
            end
        end
        
        -- Ordena por número de linha
        table.sort(headers)
        
        -- Cria folds para o conteúdo após cada cabeçalho
        for i = 1, #headers do
            local header_line = headers[i]
            local fold_start = header_line + 1
            local fold_end = total_lines - 1
            
            -- Encontra o próximo cabeçalho ou usa o final do buffer
            if i < #headers then
                fold_end = headers[i + 1] - 1
            end
            
            -- Só cria a fold se houver conteúdo após o cabeçalho
            if fold_start <= fold_end then
                vim.api.nvim_buf_call(buf, function()
                    vim.cmd(string.format("%d,%dfold", fold_start + 1, fold_end + 1))
                end)
            end
        end
        
        -- Fecha todas as folds
        vim.cmd('normal! zM')
        vim.cmd('normal! G')
        vim.cmd('normal! zz')
    end

    create_folds()
end

-- ======================================================
-- Funções públicas para abrir popup
-- ======================================================
function M.ContextChatFull()
    local text = M.get_full_buffer()
    M.open_popup(text)
end

function M.ContextChatSelection(start_line, end_line)
    local text = M.get_selection(start_line, end_line)
    M.open_popup(text)
end

function M.ContextChatFolder()
    local text = read_folder_context()
    M.open_popup(text)
end

-- ======================================================
-- Handler unificado
-- ======================================================
function M.ContextChatHandler(start_line, end_line)
    if start_line and end_line and tonumber(start_line) and tonumber(end_line) and tonumber(end_line) ~= tonumber(start_line) then
        -- seleção de múltiplas linhas
        M.ContextChatSelection(start_line, end_line)
    else
        -- modo normal ou range de uma linha
        M.ContextChatFull()
    end
end

-- ======================================================
-- Envio para LLM
-- ======================================================
function M.SendFromPopup()
    if not M.popup_buf or not api.nvim_buf_is_valid(M.popup_buf) then
        vim.notify("Popup não está aberto. Use :Context, :ContextRange ou :ContextFolder", vim.log.levels.WARN)
        return
    end

    local buf = M.popup_buf
    local start_idx, _ = find_last_user_line(buf)
    if not start_idx then
        vim.notify("Nenhuma linha '## Nardi >>' encontrada.", vim.log.levels.WARN)
        return
    end

    local lines = api.nvim_buf_get_lines(buf, start_idx, -1, false)
    local user_text = table.concat(lines, "\n"):gsub("^## Nardi >>%s*", "")
    if user_text == "" then
        vim.notify("Digite algo após '## Nardi >>' antes de enviar.", vim.log.levels.WARN)
        return
    end

    -- marca envio
    api.nvim_buf_set_lines(buf, -1, -1, false, { "[mensagem enviada]" })
    vim.notify("mensagem enviada", vim.log.levels.INFO)

    table.insert(M.history, { user = user_text, ai = nil })

    local messages = {}
    table.insert(messages, { role = "system", content = "Context:\n" .. (M.context_text or "") })
    for _, pair in ipairs(M.history) do
        table.insert(messages, { role = "user", content = pair.user })
        if pair.ai then table.insert(messages, { role = "assistant", content = pair.ai }) end
    end

    -- Carregar configurações das APIs
    local api_config = load_api_config()
    if not api_config then
        vim.notify("Arquivo de configuração das APIs não encontrado", vim.log.levels.ERROR)
        return
    end

    local selected_api = api_config.default_api
    local fallback_mode = api_config.fallback_mode or false
    local apis = api_config.apis or {}

    -- Função para fazer a requisição
    local function make_request(api_config, callback)
        local json_payload = vim.fn.json_encode({
            model = api_config.model,
            messages = messages
        })

        local headers = {}
        for k, v in pairs(api_config.headers or {}) do
            table.insert(headers, "-H")
            table.insert(headers, k .. ": " .. v)
        end

        local cmd = vim.list_extend({"curl", "-s", "-X", "POST", api_config.url}, headers)
        table.insert(cmd, "-d")
        table.insert(cmd, json_payload)

        local stdout_accum = {}
        local stderr_accum = {}

        vim.fn.jobstart(cmd, {
            stdout_buffered = true,
            on_stdout = function(_, data, _)
                if data then
                    for _, d in ipairs(data) do
                        if d and d ~= "" then
                            table.insert(stdout_accum, d)
                        end
                    end
                end
            end,
            on_stderr = function(_, data, _)
                if data then
                    for _, d in ipairs(data) do
                        if d and d ~= "" then
                            table.insert(stderr_accum, d)
                        end
                    end
                end
            end,
            on_exit = function(_, code, _)
                if code == 0 then
                    callback(true, table.concat(stdout_accum, "\n"))
                else
                    callback(false, table.concat(stderr_accum, "\n"))
                end
            end
        })
    end

    -- Função para tentar a próxima API em caso de falha
    local function try_apis(api_list, index)
        if index > #api_list then
            vim.notify("Todas as APIs falharam", vim.log.levels.ERROR)
            return
        end

        local current_api = api_list[index]
        make_request(current_api, function(success, result)
            if success then
                local ok, decoded = pcall(vim.fn.json_decode, result)
                if not ok or not decoded or not decoded.choices or not decoded.choices[1] then
                    vim.notify("Erro ao decodificar JSON:\n" .. result, vim.log.levels.ERROR)
                    if fallback_mode then
                        try_apis(api_list, index + 1)
                    end
                    return
                end

                local ai_content = decoded.choices[1].message.content or ""
                ai_content = "## IA >> " .. ai_content
                M.history[#M.history].ai = ai_content

                vim.schedule(function()
                    local last_line = api.nvim_buf_line_count(buf) - 1
                    local ai_lines = split_lines(ai_content)
                    api.nvim_buf_set_lines(buf, -1, -1, false, ai_lines)
                    api.nvim_buf_set_lines(buf, -1, -1, false, { "", "## Nardi >> " })
                    
                    -- Aplicar highlights novamente para incluir as novas linhas
                    apply_highlights(buf)
                    
                    if M.popup_win and api.nvim_win_is_valid(M.popup_win) then
                        api.nvim_win_set_cursor(M.popup_win, { api.nvim_buf_line_count(buf), #"## Nardi >> " })
                    end
                    vim.cmd("startinsert")
                    vim.notify("mensagem recebida de " .. current_api.name, vim.log.levels.INFO)
                end)
            else
                vim.notify("API " .. current_api.name .. " falhou: " .. result, vim.log.levels.WARN)
                if fallback_mode then
                    try_apis(api_list, index + 1)
                end
            end
        end)
    end

    -- Determinar qual API(s) usar
    local api_list = {}
    if fallback_mode then
        api_list = apis
    else
        -- Encontrar a API pelo nome
        for _, api in ipairs(apis) do
            if api.name == selected_api then
                api_list = {api}
                break
            end
        end
        if #api_list == 0 and #apis > 0 then
            api_list = {apis[1]}
        end
    end

    -- Fazer a requisição
    if #api_list > 0 then
        try_apis(api_list, 1)
    else
        vim.notify("Nenhuma API configurada", vim.log.levels.ERROR)
    end
end

return M
