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
        local lines = vim.api.nvim_buf_get_lines(ui_popup.popup_buf, 0, -1, false)
        local content = table.concat(lines, "\n")
        vim.api.nvim_win_hide(ui_popup.popup_win) -- hide para preservar memória
        M.current_workspace_file = utils.export_to_workspace(content, M.current_workspace_file)
    else
        local cur_buf = vim.api.nvim_get_current_buf()
        local name = vim.api.nvim_buf_get_name(cur_buf)
        if name:match("multi_context_chats.*%.mctx$") then
            M.current_workspace_file = name
            local lines = vim.api.nvim_buf_get_lines(cur_buf, 0, -1, false)
            local content = table.concat(lines, "\n")
            ui_popup.create_popup(content)
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
-- Envio para LLM
-- ======================================================
function M.SendFromPopup()
    if not popup.popup_buf or not api.nvim_buf_is_valid(popup.popup_buf) then
        vim.notify("Popup não está aberto. Use :Context, :ContextTree etc.", vim.log.levels.WARN)
        return
    end

    local buf = popup.popup_buf
    local start_idx, _ = utils.find_last_user_line(buf)
    
    if not start_idx then
        vim.notify("Nenhuma linha de usuário encontrada.", vim.log.levels.WARN)
        return
    end

    -- Pega o texto do usuário
    local lines = api.nvim_buf_get_lines(buf, start_idx, -1, false)
    local config = require('multi_context.config')
    local user_prefix = "## " .. (config.options.user_name or "Nardi") .. " >>"
    local user_text = table.concat(lines, "\n"):gsub("^" .. user_prefix .. "%s*", "")
    
    if user_text == "" then
        vim.notify("Digite algo antes de enviar.", vim.log.levels.WARN)
        return
    end

    -- Avisa visualmente que está processando
    api.nvim_buf_set_lines(buf, -1, -1, false, { "", "[Enviando requisição para IA...]" })

    -- Função de limpeza de caracteres especiais
    local function clean_text(text)
        if not text then return "" end
        local result = {}
        for i = 1, #text do
            local char = text:sub(i, i)
            local byte = char:byte()
            if byte >= 32 and byte <= 126 or byte == 10 or byte == 13 or byte == 9 then
                table.insert(result, char)
            elseif byte == 195 then 
                local next_byte = text:sub(i+1, i+1):byte()
                local mapping = {
                    [128]="A", [129]="A", [130]="A", [131]="A", [132]="A", [133]="A", [134]="A", [135]="C", [136]="E", [137]="E", [138]="E", [139]="E", [140]="I", [141]="I", [142]="I", [143]="I", [144]="D", [145]="N", [146]="O", [147]="O", [148]="O", [149]="O", [150]="O", [151]="O", [152]="U", [153]="U", [154]="U", [155]="U", [160]="a", [161]="a", [162]="a", [163]="a", [164]="a", [165]="a", [166]="a", [167]="c", [168]="e", [169]="e", [170]="e", [171]="e", [172]="i", [173]="i", [174]="i", [175]="i", [176]="d", [177]="n", [178]="o", [179]="o", [180]="o", [181]="o", [182]="o", [183]="o", [184]="u", [185]="u", [186]="u", [187]="u"
                }
                if mapping[next_byte] then table.insert(result, mapping[next_byte]) end
                i = i + 1 
            end
        end
        return table.concat(result)
    end

    -- Pega todo o texto do buffer sem precisar de função externa
    local all_lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    local full_context = clean_text(table.concat(all_lines, "\n"))
    
    local messages = {
        { role = "system", content = full_context },
        { role = "user", content = user_text }
    }

    local api_client = require('multi_context.api_client')
    local response_started = false

    -- Remove o aviso "[Enviando requisição...]"
    local function remove_sending_msg()
        local count = api.nvim_buf_line_count(buf)
        local last_line = api.nvim_buf_get_lines(buf, count - 1, count, false)[1]
        if last_line:match("%[Enviando requisi") then
            api.nvim_buf_set_lines(buf, count - 2, count, false, {})
        end
    end

    -- Delega o envio para o api_client (Streaming e Fallback embutidos)
    api_client.execute(messages, 
        -- 1. on_chunk (Recebendo os pedaços de texto da IA)
        function(chunk, api_entry)
            if not response_started then
                remove_sending_msg()
                api.nvim_buf_set_lines(buf, -1, -1, false, { "", "## IA (" .. api_entry.model .. ") >> ", "" })
                response_started = true
            end
            
            if chunk and chunk ~= "" then
                local lines_to_add = vim.split(chunk, "\n", {plain = true})
                local count = api.nvim_buf_line_count(buf)
                local last_line = api.nvim_buf_get_lines(buf, count - 1, count, false)[1]
                
                -- Concatena o novo chunk na última linha do buffer
                lines_to_add[1] = last_line .. lines_to_add[1]
                api.nvim_buf_set_lines(buf, count - 1, count, false, lines_to_add)
                
                -- Faz o scroll acompanhar o texto
                if popup.popup_win and api.nvim_win_is_valid(popup.popup_win) then
                    local new_count = api.nvim_buf_line_count(buf)
                    api.nvim_win_set_cursor(popup.popup_win, { new_count, 0 })
                    vim.cmd("normal! zz")
                end
            end
        end,
        -- 2. on_done (IA terminou de responder)
        function(api_entry)
            if not response_started then remove_sending_msg() end
            
            api.nvim_buf_set_lines(buf, -1, -1, false, { 
                "", 
                "## API atual: " .. api_entry.name, 
                user_prefix .. " " 
            })
            
            utils.apply_highlights(buf)
            popup.create_folds(buf)
            
            if popup.popup_win and api.nvim_win_is_valid(popup.popup_win) then
                local count = api.nvim_buf_line_count(buf)
                api.nvim_win_set_cursor(popup.popup_win, { count, #user_prefix + 1 })
                vim.cmd("normal! zz")
                vim.cmd("startinsert!") -- Volta pro modo de digitação pra próxima pergunta
            end
        end,
        -- 3. on_error (Erro em todas as APIs da fila)
        function(err_msg)
            remove_sending_msg()
            api.nvim_buf_set_lines(buf, -1, -1, false, { 
                "", 
                "**[ERRO]** " .. err_msg, 
                "", 
                user_prefix .. " " 
            })
            if popup.popup_win and api.nvim_win_is_valid(popup.popup_win) then
                local count = api.nvim_buf_line_count(buf)
                api.nvim_win_set_cursor(popup.popup_win, { count, #user_prefix + 1 })
            end
        end
    )
end

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
