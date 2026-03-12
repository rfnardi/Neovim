-- init.lua
-- Ponto de entrada do plugin.
-- Responsabilidades: setup(), API pública e registro de comandos Vim.
-- Sem lógica de negócio — tudo delega aos módulos específicos.
local M = {}

local config       = require('multi_context.config')
local commands     = require('multi_context.commands')
local ui_popup     = require('multi_context.ui.popup')
local utils        = require('multi_context.utils')
local api_client   = require('multi_context.api_client')
local conversation = require('multi_context.conversation')

-- ── Setup ─────────────────────────────────────────────────────────────────────

M.setup = function(opts)
    config.setup(opts)
end

-- ── API pública ───────────────────────────────────────────────────────────────

M.Context            = commands.ContextChatHandler
M.ContextChatFull    = commands.ContextChatFull
M.ContextChatHandler = commands.ContextChatHandler
M.ContextBuffers     = commands.ContextBuffers
M.ContextChatFolder  = commands.ContextTree
M.ContextFolder      = commands.ContextTree
M.ContextChatGit     = commands.ContextChatGit
M.ContextGit         = commands.ContextChatGit
M.ContextTree        = commands.ContextTree
M.ContextRepo        = commands.ContextTree
M.ContextChatRepo    = commands.ContextTree
M.ContextApis        = commands.ContextApis
M.ContextQueue       = function() require('multi_context.queue_editor').open_editor() end

M.TogglePopup = function()
    if ui_popup.popup_win and vim.api.nvim_win_is_valid(ui_popup.popup_win) then
        vim.api.nvim_win_close(ui_popup.popup_win, true)
    else
        commands.ContextChatHandler()
    end
end

-- Abre o contexto do projeto como workspace (atalho <A-w>)

-- Variável para rastrear se este chat já pertence a um arquivo
M.current_workspace_file = nil

M.ToggleWorkspaceView = function()
    local ui_popup = require('multi_context.ui.popup')
    local win = vim.api.nvim_get_current_win()
    local config = vim.api.nvim_win_get_config(win)

    -- CENÁRIO A: Saindo do Popup para o Workspace
    if config.relative ~= "" then
        if ui_popup.popup_buf and vim.api.nvim_buf_is_valid(ui_popup.popup_buf) then
            local lines = vim.api.nvim_buf_get_lines(ui_popup.popup_buf, 0, -1, false)
            local content = table.concat(lines, "\n")
            
            -- Fecha o popup
            vim.api.nvim_win_close(ui_popup.popup_win, true)
            
            -- Exporta usando o nome salvo (se existir) para não duplicar
            M.current_workspace_file = require('multi_context.utils').export_to_workspace(content, M.current_workspace_file)
        end

    -- CENÁRIO B: Voltando do Workspace para o Popup
    else
        local cur_buf = vim.api.nvim_get_current_buf()
        local lines = vim.api.nvim_buf_get_lines(cur_buf, 0, -1, false)
        local content = table.concat(lines, "\n")
        
        -- Salva o nome do arquivo atual para que o próximo <A-w> volte para ele
        local name = vim.api.nvim_buf_get_name(cur_buf)
        if name:match("multi_context_chats") then
            M.current_workspace_file = name
        end
        
        if content ~= "" then
            ui_popup.create_popup(content)
        end
    end
end
-- ── SendFromPopup ─────────────────────────────────────────────────────────────

M.SendFromPopup = function()
    local buf = ui_popup.popup_buf
    if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

    local user_prefix = "## " .. config.options.user_name .. " >> "
    local hl          = require('multi_context.ui.highlights')

    -- Monta histórico completo da sessão
    local messages = conversation.build_history(buf)

    -- Valida: última mensagem deve ser do usuário e não vazia
    if #messages == 0
        or messages[#messages].role    ~= "user"
        or messages[#messages].content == "" then
        return
    end

    -- Reserva bloco de resposta no buffer
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "", "## IA >> ", "" })
    local resp_start  = vim.api.nvim_buf_line_count(buf) - 1
    local accumulated = ""
		local last_render = 0

		vim.bo[buf].modifiable = false  -- bloqueia durante a resposta da IA

    api_client.execute(
        messages,

        -- on_chunk: acumula e renderiza em tempo real
				function(chunk, _)
					accumulated = accumulated .. chunk
					local now = vim.loop.now()
						if now - last_render > 50 then
								last_render = now
								vim.schedule(function()
										if vim.api.nvim_buf_is_valid(buf) then
												vim.bo[buf].modifiable = true
												vim.api.nvim_buf_set_lines(buf, resp_start, -1, false,
														utils.split_lines(accumulated))
										end
										vim.notify("MultiContext: " .. msg, vim.log.levels.ERROR)
								end)
						end
				end,

        -- on_done: insere rodapé e posiciona cursor no próximo prompt
        function(entry)
            utils.insert_after(buf, -1, {
                "",
                "## API atual: " .. entry.name,
                user_prefix,
            })
            hl.apply_chat(buf)
            local last = vim.api.nvim_buf_line_count(buf)
            if ui_popup.popup_win and vim.api.nvim_win_is_valid(ui_popup.popup_win) then
                vim.api.nvim_win_set_cursor(ui_popup.popup_win, { last, #user_prefix })
                vim.cmd("startinsert!")
            end
        end,

        -- on_error
        function(msg)
            vim.notify("MultiContext: " .. msg, vim.log.levels.ERROR)
        end
    )
end

-- ── Comandos Vim ──────────────────────────────────────────────────────────────

vim.cmd([[
  command! Context        lua require('multi_context').Context()
  command! ContextBuffers lua require('multi_context').ContextBuffers()
  command! ContextTree    lua require('multi_context').ContextTree()
  command! ContextRepo    lua require('multi_context').ContextRepo()
  command! ContextApis    lua require('multi_context').ContextApis()
  command! ContextQueue   lua require('multi_context').ContextQueue()
]])

return M
