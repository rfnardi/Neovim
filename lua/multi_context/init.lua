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
        if name:match("multi_context_chats.*%.md$") then
            M.current_workspace_file = name
            local lines = vim.api.nvim_buf_get_lines(cur_buf, 0, -1, false)
            local content = table.concat(lines, "\n")
            ui_popup.create_popup(content)
        end
    end
end

local original_open_popup = popup.create_popup
popup.create_popup = function(initial_content)
    original_open_popup(initial_content)
    M.popup_buf = popup.popup_buf
    M.popup_win = popup.popup_win
end

-- ======================================================
-- Envio para LLM
-- ======================================================
function M.SendFromPopup()
    if not popup.popup_buf or not api.nvim_buf_is_valid(popup.popup_buf) then
        vim.notify("Popup não está aberto. Use :Context, :ContextRange ou :ContextFolder", vim.log.levels.WARN)
        return
    end

    local buf = popup.popup_buf
    local start_idx, _ = utils.find_last_user_line(buf)
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

    api.nvim_buf_set_lines(buf, -1, -1, false, { "[Enviando requisição...]" })

    table.insert(M.history, { user = user_text, ai = nil })
    
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

    local full_context = clean_text(utils.get_popup_content(buf))
    local messages = {
        { role = "system", content = full_context },
        { role = "user", content = user_text }
    }
    
    local api_config = utils.load_api_config()
    if not api_config then
        vim.notify("Arquivo de configuração das APIs não encontrado", vim.log.levels.ERROR)
        return
    end

    local api_keys = utils.load_api_keys()
    local selected_api = api_config.default_api
    local fallback_mode = api_config.fallback_mode or false
    local apis = api_config.apis or {}

    local function try_apis(api_list, index)
        if index > #api_list then
            vim.notify("Todas as APIs falharam.", vim.log.levels.ERROR)
            vim.schedule(function()
                local last_line_idx = api.nvim_buf_line_count(buf) - 1
                api.nvim_buf_set_lines(buf, last_line_idx, last_line_idx + 1, false, {"## Nardi >> "})
            end)
            return
        end

        local current_api = api_list[index]
        local handler = api_handlers[current_api.api_type or "openai"]

        if not handler then
            vim.notify("Tipo de API não suportado para " .. current_api.name .. ". Pulando.", vim.log.levels.ERROR)
            if fallback_mode then try_apis(api_list, index + 1) end
            return
        end
        
        local attempt_message = "Mensagem enviada para " .. current_api.name
        if fallback_mode and #api_list > 1 then
            attempt_message = attempt_message .. " (" .. index .. "/" .. #api_list .. ")"
        end
        vim.notify(attempt_message, vim.log.levels.INFO)

        handler.make_request(current_api, messages, api_keys, function(success, result)
            if success then
                local ai_content, error_msg = handler.parse_response(result)
                if not ai_content then
                    vim.notify("Erro ao processar resposta da " .. current_api.name .. ": " .. error_msg, vim.log.levels.ERROR)
                    if fallback_mode then try_apis(api_list, index + 1) end
                    return
                end

                ai_content = "## IA (" .. current_api.model .. ") >> \n" .. ai_content
                table.insert(M.history, {ai = ai_content})

                vim.schedule(function()
                    local final_line_idx = api.nvim_buf_line_count(buf) - 1
                    local ai_lines = utils.split_lines(ai_content)
                    
                    api.nvim_buf_set_lines(buf, final_line_idx, final_line_idx + 1, false, ai_lines)
                    utils.insert_after(buf, -1, { "## API atual: " .. current_api.name, "## Nardi >> " })
                    
                    utils.apply_highlights(buf)
                    popup.create_folds(buf)

                    if popup.popup_win and api.nvim_win_is_valid(popup.popup_win) then
                        api.nvim_win_set_cursor(popup.popup_win, { api.nvim_buf_line_count(buf), #"## Nardi >> " })
                    end
                    vim.cmd("normal! zz")
                    vim.notify("Mensagem recebida de " .. current_api.name, vim.log.levels.INFO)
                end)
            else
                vim.notify("API " .. current_api.name .. " falhou: " .. result, vim.log.levels.WARN)
                if fallback_mode then
                    try_apis(api_list, index + 1)
                end
            end
        end)
    end

    local api_list = {}
    if fallback_mode then
        for _, api in ipairs(apis) do
            if api['include_in_fall-back_mode'] == true then
                table.insert(api_list, api)
            end
        end
    else
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

    if #api_list > 0 then
        try_apis(api_list, 1)
    else
        vim.notify("Nenhuma API configurada ou disponível.", vim.log.levels.ERROR)
    end
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
