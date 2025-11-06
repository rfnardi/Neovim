local api = vim.api
local utils = require('multi_context.utils')
local popup = require('multi_context.popup')

local M = {}

M.ContextTree = function()
    local text = utils.read_tree_context() -- Cria funcao nova no utils
    if text == "" then
        return
    end
    popup.open_popup(text, text)
end

M.ContextChatFull = function()
	local text = utils.get_full_buffer()
	popup.open_popup(text, text)
end

M.ContextChatSelection = function(start_line, end_line)
	local text = utils.get_selection(start_line, end_line)
	popup.open_popup(text, text)
end

M.ContextChatFolder = function()
	local text = utils.read_folder_context()
	popup.open_popup(text, text)
end

M.ContextChatRepo = function()
    local text = utils.read_repo_context()
    if text == "" then
        return
    end
    popup.open_popup(text, text)
end


M.ContextChatGit = function()
	local diff_text, error_msg = utils.get_git_diff()
	if error_msg then
		vim.notify(error_msg, vim.log.levels.WARN)
		return
	end

	popup.open_popup(diff_text, diff_text)
end

M.ContextApis = function()
	-- Carregar o módulo api_selector de forma segura
	local status, api_selector = pcall(require, 'multi_context.api_selector')
	if not status then
		vim.notify("Erro ao carregar o seletor de APIs: " .. api_selector, vim.log.levels.ERROR)
		return
	end

	api_selector.open_api_selector()
end

M.ContextChatHandler = function(start_line, end_line)
	if start_line and end_line and tonumber(start_line) and tonumber(end_line) and tonumber(end_line) ~= tonumber(start_line) then
		-- seleção de múltiplas linhas
		M.ContextChatSelection(start_line, end_line)
	else
		-- modo normal ou range de uma linha
		M.ContextChatFull()
	end
end

M.TogglePopup = function()
  require('multi_context').TogglePopup()
end

M.ContextBuffers = function()
  local all_buffers_text = {}
  local buffers = api.nvim_list_bufs()

  for _, buf in ipairs(buffers) do
    if api.nvim_buf_is_loaded(buf) then
      local buf_name = api.nvim_buf_get_name(buf)
      if buf_name ~= "" then -- Ignora buffers "especiais"
        local line_count = api.nvim_buf_line_count(buf)
        local lines = api.nvim_buf_get_lines(buf, 0, line_count, false)
        local content = table.concat(lines, "\n")

        table.insert(all_buffers_text, "== Buffer: " .. buf_name .. " ==")
        table.insert(all_buffers_text, content)
        table.insert(all_buffers_text, "") -- Adiciona uma linha em branco entre os buffers
      end
    end
  end

  local combined_text = table.concat(all_buffers_text, "\n")
  popup.open_popup(combined_text, combined_text)
end


M.ToggleWorkspaceView = function(plugin)
	local api = vim.api
	local utils = require('multi_context.utils')
	local popup = require('multi_context.popup')

	local current_buf = api.nvim_get_current_buf()

	-- Cenário 1: Estamos no popup, queremos ir para o buffer de workspace
	if current_buf == plugin.popup_buf then
		-- Primeiro, sempre capturamos o conteúdo atual do popup
		local popup_lines = api.nvim_buf_get_lines(plugin.popup_buf, 0, -1, false)

		plugin.HidePopup()

		if plugin.workspace_buf and api.nvim_buf_is_valid(plugin.workspace_buf) then
			--- ALTERAÇÃO PRINCIPAL: Atualiza o conteúdo do workspace com o do popup
			api.nvim_buf_set_lines(plugin.workspace_buf, 0, -1, false, popup_lines)
			api.nvim_set_current_buf(plugin.workspace_buf)
		else
			-- Criar o buffer de workspace pela primeira vez (a lógica de cópia já estava aqui)
			local filename = utils.generate_chat_filename()
			local new_buf = api.nvim_create_buf(true, false)

			api.nvim_buf_set_name(new_buf, filename)
			api.nvim_buf_set_option(new_buf, 'filetype', 'markdown')
			api.nvim_buf_set_option(new_buf, 'buftype', 'nofile')
			api.nvim_buf_set_option(new_buf, 'bufhidden', 'hide')

			api.nvim_buf_set_lines(new_buf, 0, -1, false, popup_lines)

			api.nvim_buf_set_keymap(new_buf, "n", "<A-w>", "<Cmd>lua require('multi_context').ToggleWorkspaceView()<CR>", { noremap=true, silent=true })
			api.nvim_buf_set_keymap(new_buf, "i", "<A-w>", "<Cmd>lua require('multi_context').ToggleWorkspaceView()<CR>", { noremap=true, silent=true })

			plugin.workspace_buf = new_buf
			api.nvim_set_current_buf(plugin.workspace_buf)
			vim.notify("Visualização de workspace ativada. Pressione <A-w> para voltar ao popup.")
		end

		-- Posicionar o cursor no workspace (lógica já correta)
		vim.cmd('stopinsert')
		local last_line = api.nvim_buf_line_count(plugin.workspace_buf)
		local line_content = api.nvim_buf_get_lines(plugin.workspace_buf, last_line - 1, last_line, false)[1] or ""
		api.nvim_win_set_cursor(0, {last_line, #line_content})

	-- Cenário 2: Estamos no buffer de workspace, queremos voltar para o popup (já estava correto)
	elseif current_buf == plugin.workspace_buf then
		if not plugin.popup_buf or not api.nvim_buf_is_valid(plugin.popup_buf) then
			vim.notify("O buffer do popup não é mais válido.", vim.log.levels.ERROR)
			return
		end

		local workspace_lines = api.nvim_buf_get_lines(plugin.workspace_buf, 0, -1, false)
		api.nvim_buf_set_lines(plugin.popup_buf, 0, -1, false, workspace_lines)

		plugin.ShowPopup()
		api.nvim_win_set_buf(plugin.popup_win, plugin.popup_buf)

		utils.apply_highlights(plugin.popup_buf)
		popup.create_folds(plugin.popup_buf)

		-- Posicionar o cursor no popup (lógica já correta)
		vim.cmd('stopinsert')
		local last_line = api.nvim_buf_line_count(plugin.popup_buf)
		local line_content = api.nvim_buf_get_lines(plugin.popup_buf, last_line - 1, last_line, false)[1] or ""
		api.nvim_win_set_cursor(plugin.popup_win, {last_line, #line_content})

	else
		vim.notify("Comando <A-w> do MultiContext só funciona na janela do popup ou no buffer de workspace.", vim.log.levels.INFO)
	end
end

return M
