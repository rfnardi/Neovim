#!/bin/bash

# Define a pasta do plugin
PLUGIN_DIR="lua/multi_context"

echo "🚀 Iniciando refatoração para configurabilidade..."

# 1. Criar o arquivo de configuração padrão
cat << 'EOF' > "$PLUGIN_DIR/config.lua"
local M = {}

M.defaults = {
    user_name = "Nardi",
    config_path = vim.fn.stdpath("config") .. "/context_apis.json",
    api_keys_path = vim.fn.stdpath("config") .. "/api_keys.json",
    default_api = nil, -- Se nil, usa o do JSON
    appearance = {
        border = "rounded",
        width = 0.7,
        height = 0.7,
        title = " MultiContext - Chat ",
    }
}

M.options = {}

function M.setup(user_opts)
    M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
EOF

echo "✅ Arquivo config.lua criado."

# 2. Injetar a lógica de setup no init.lua e atualizar referências
# Vamos reconstruir o topo do init.lua para incluir o config
cat << 'EOF' > "$PLUGIN_DIR/init.lua.new"
local api = vim.api
local config = require('multi_context.config')
local utils = require('multi_context.utils')
local popup = require('multi_context.popup')
local commands = require('multi_context.commands')
local api_handlers = require('multi_context.api_handlers')

local M = {}

M.popup_buf = popup.popup_buf
M.popup_win = popup.popup_win
M.history = {}
M.context_text = nil
M.workspace_buf = nil
M.popup_visible = false

-- Função de configuração
function M.setup(opts)
    config.setup(opts)
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
M.TogglePopup = commands.TogglePopup
M.ContextBuffers = commands.ContextBuffers
M.ToggleWorkspaceView = function() commands.ToggleWorkspaceView(M) end

M.TogglePopup = function()
    if M.popup_visible then M.HidePopup() else M.ShowPopup() end
end

M.HidePopup = function()
    if M.popup_win and api.nvim_win_is_valid(M.popup_win) then
        api.nvim_win_hide(M.popup_win)
        M.popup_visible = false
    end
end

M.ShowPopup = function()
    if M.popup_buf and api.nvim_buf_is_valid(M.popup_buf) then
        if not M.popup_win or not api.nvim_win_is_valid(M.popup_win) then
            local opts = config.options.appearance
            local width = math.floor(vim.o.columns * opts.width)
            local height = math.floor(vim.o.lines * opts.height)
            local row = math.floor((vim.o.lines - height) / 2)
            local col = math.floor((vim.o.columns - width) / 2)

            M.popup_win = api.nvim_open_win(M.popup_buf, true, {
                relative = "editor",
                width = width,
                height = height,
                row = row,
                col = col,
                style = "minimal",
                border = opts.border,
                title = opts.title,
                title_pos = "center",
            })

            local lines = api.nvim_buf_get_lines(M.popup_buf, 0, -1, false)
            api.nvim_win_set_cursor(M.popup_win, { #lines, #(string.format("## %s >> ", config.options.user_name)) })
            vim.cmd('normal! zz')
        else
            api.nvim_win_set_config(M.popup_win, { focusable = true })
        end
        M.popup_visible = true
    else
        vim.notify("Use um comando de contexto primeiro.", vim.log.levels.WARN)
    end
end

-- Modificar a função open_popup para atualizar o estado
local original_open_popup = popup.open_popup
popup.open_popup = function(text, context_text)
    original_open_popup(text, context_text)
    M.popup_buf = popup.popup_buf
    M.popup_win = popup.popup_win
    M.popup_visible = true
end

function M.SendFromPopup()
    if not popup.popup_buf or not api.nvim_buf_is_valid(popup.popup_buf) then return end

    local buf = popup.popup_buf
    local user_prompt_prefix = string.format("## %s >>", config.options.user_name)
    
    local start_idx, _ = utils.find_last_user_line(buf)
    if not start_idx then
        vim.notify("Marcador de usuário não encontrado.", vim.log.levels.WARN)
        return
    end

    local lines = api.nvim_buf_get_lines(buf, start_idx, -1, false)
    local user_text = table.concat(lines, "\n"):gsub("^" .. user_prompt_prefix .. "%s*", "")
    
    if user_text == "" then
        vim.notify("Digite algo antes de enviar.", vim.log.levels.WARN)
        return
    end

    api.nvim_buf_set_lines(buf, -1, -1, false, { "[Enviando requisição...]" })
    table.insert(M.history, { user = user_text, ai = nil })

    local full_context = utils.get_popup_content(buf)
    local messages = {
        { role = "system", content = full_context },
        { role = "user", content = user_text }
    }
    
    local api_config = utils.load_api_config()
    local api_keys = utils.load_api_keys()
    
    local selected_api = config.options.default_api or api_config.default_api
    local fallback_mode = api_config.fallback_mode or false
    local apis = api_config.apis or {}

    local function try_apis(api_list, index, attempt_num)
        if index > #api_list then
            vim.notify("Todas as APIs falharam.", vim.log.levels.ERROR)
            vim.schedule(function()
                local last_line_idx = api.nvim_buf_line_count(buf) - 1
                api.nvim_buf_set_lines(buf, last_line_idx, last_line_idx + 1, false, {user_prompt_prefix .. " "})
            end)
            return
        end

        attempt_num = attempt_num or 1
        local current_api = api_list[index]
        local handler = api_handlers[current_api.api_type or "openai"]

        handler.make_request(current_api, messages, api_keys, function(success, result)
            if success then
                local ai_content, error_msg = handler.parse_response(result)
                if ai_content then
                    ai_content = "## IA (" .. current_api.model .. ") >> \n" .. ai_content
                    vim.schedule(function()
                        local final_line_idx = api.nvim_buf_line_count(buf) - 1
                        api.nvim_buf_set_lines(buf, final_line_idx, final_line_idx + 1, false, utils.split_lines(ai_content))
                        utils.insert_after(buf, -1, { "## API atual: " .. current_api.name, user_prompt_prefix .. " " })
                        utils.apply_highlights(buf)
                        popup.create_folds(buf)
                        if popup.popup_win and api.nvim_win_is_valid(popup.popup_win) then
                            api.nvim_win_set_cursor(popup.popup_win, { api.nvim_buf_line_count(buf), #user_prompt_prefix + 1 })
                        end
                    end)
                end
            elseif fallback_mode then
                try_apis(api_list, index + 1, 1)
            end
        end)
    end

    local api_list = {}
    if fallback_mode then
        for _, a in ipairs(apis) do if a['include_in_fall-back_mode'] then table.insert(api_list, a) end end
    else
        for _, a in ipairs(apis) do if a.name == selected_api then table.insert(api_list, a) break end end
    end
    
    try_apis(#api_list > 0 and api_list or {apis[1]}, 1, 1)
end

return M
EOF

mv "$PLUGIN_DIR/init.lua.new" "$PLUGIN_DIR/init.lua"
echo "✅ init.lua refatorado."

# 3. Atualizar utils.lua para ler do config
sed -i "s|vim.fn.expand('\~/.config/nvim/context_apis.json')|require('multi_context.config').options.config_path|g" "$PLUGIN_DIR/utils.lua"
sed -i "s|vim.fn.expand('\~/.config/nvim/api_keys.json')|require('multi_context.config').options.api_keys_path|g" "$PLUGIN_DIR/utils.lua"
sed -i "s|## Nardi >>|## \" .. require('multi_context.config').options.user_name .. \" >>|g" "$PLUGIN_DIR/utils.lua"

echo "✅ utils.lua atualizado."

echo "🎉 Refatoração concluída! Lembre-se de chamar require('multi_context').setup({}) no seu init.lua/vim"
