local api = vim.api
local utils = require('multi_context.utils')

local M = {}

M.selector_buf = nil
M.selector_win = nil
M.api_list = {}
M.current_selection = 1

M.open_api_selector = function()
	-- Carregar lista de APIs
	M.api_list = utils.get_api_names()
	if #M.api_list == 0 then
		vim.notify("Nenhuma API configurada", vim.log.levels.WARN)
		return
	end

	-- Encontrar a seleção atual
	local current_api = utils.get_current_api()
	M.current_selection = 1
	for i, api_name in ipairs(M.api_list) do
		if api_name == current_api then
			M.current_selection = i
			break
		end
	end

	-- Criar buffer
	M.selector_buf = api.nvim_create_buf(false, true)

	-- Configurar janela
	local width = 60
	local height = math.min(#M.api_list + 4, 20)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	M.selector_win = api.nvim_open_win(M.selector_buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = "Selecionar API",
		title_pos = "center",
	})

	-- Configurar buffer
	api.nvim_buf_set_option(M.selector_buf, "filetype", "multi_context_selector")
	api.nvim_buf_set_option(M.selector_buf, "buftype", "nofile")
	api.nvim_buf_set_option(M.selector_buf, "modifiable", true)

	-- Renderizar conteúdo
	M.render_selector()

	-- Configurar mapeamentos de teclas
	M.setup_keymaps()
end

M.render_selector = function()
	if not M.selector_buf or not api.nvim_buf_is_valid(M.selector_buf) then
		return
	end

	local lines = {
		"Selecione a API para usar nas requisições:",
		"Use j/k para navegar, Enter para selecionar, q para sair",
		""
	}

	local current_api = utils.get_current_api()

	for i, api_name in ipairs(M.api_list) do
		local prefix = "  "
		if i == M.current_selection then
			prefix = "❯ "
		end

		local suffix = ""
		if api_name == current_api then
			suffix = " (selecionada)"
		end

		table.insert(lines, prefix .. api_name .. suffix)
	end

	table.insert(lines, "")
	table.insert(lines, "API atual: " .. current_api)

	api.nvim_buf_set_lines(M.selector_buf, 0, -1, false, lines)
	M.apply_selector_highlights()
end

M.apply_selector_highlights = function()
	if not M.selector_buf or not api.nvim_buf_is_valid(M.selector_buf) then
		return
	end

	-- Definir highlights
	vim.cmd("highlight ContextSelectorTitle gui=bold guifg=#FFA500 guibg=NONE")
	vim.cmd("highlight ContextSelectorCurrent gui=bold guifg=#B22222 guibg=NONE")
	vim.cmd("highlight ContextSelectorSelected gui=bold guifg=#FFFF00 guibg=NONE")

	-- Aplicar highlights
	api.nvim_buf_add_highlight(M.selector_buf, -1, "ContextSelectorTitle", 0, 0, -1)
	api.nvim_buf_add_highlight(M.selector_buf, -1, "ContextSelectorTitle", 1, 0, -1)

	for i = 3, 3 + #M.api_list - 1 do
		local line = api.nvim_buf_get_lines(M.selector_buf, i, i + 1, false)[1]
		if line and line:match("^❯") then
			api.nvim_buf_add_highlight(M.selector_buf, -1, "ContextSelectorCurrent", i, 0, -1)
		end

		if line and line:match("%(selecionada%)$") then
			api.nvim_buf_add_highlight(M.selector_buf, -1, "ContextSelectorSelected", i, 0, -1)
		end
	end

	-- Highlight da API atual
	local last_line = api.nvim_buf_line_count(M.selector_buf) - 2
	api.nvim_buf_add_highlight(M.selector_buf, -1, "ContextSelectorTitle", last_line, 0, -1)
end

M.setup_keymaps = function()
	if not M.selector_buf or not api.nvim_buf_is_valid(M.selector_buf) then
		return
	end

	-- Navegação
	api.nvim_buf_set_keymap(M.selector_buf, "n", "j", "", {
		callback = function() M.move_selection(1) end,
		noremap = true, silent = true
	})

	api.nvim_buf_set_keymap(M.selector_buf, "n", "k", "", {
		callback = function() M.move_selection(-1) end,
		noremap = true, silent = true
	})

	-- Seleção
	api.nvim_buf_set_keymap(M.selector_buf, "n", "<CR>", "", {
		callback = function() M.select_api() end,
		noremap = true, silent = true
	})

	-- Saída
	api.nvim_buf_set_keymap(M.selector_buf, "n", "q", "", {
		callback = function() M.close_selector() end,
		noremap = true, silent = true
	})

	api.nvim_buf_set_keymap(M.selector_buf, "n", "<Esc>", "", {
		callback = function() M.close_selector() end,
		noremap = true, silent = true
	})
end

M.move_selection = function(direction)
	local new_selection = M.current_selection + direction

	if new_selection >= 1 and new_selection <= #M.api_list then
		M.current_selection = new_selection
		M.render_selector()
	end
end

M.select_api = function()
	local selected_api = M.api_list[M.current_selection]

	if utils.set_selected_api(selected_api) then
		vim.notify("API selecionada: " .. selected_api, vim.log.levels.INFO)

		-- Atualizar o popup se estiver aberto
		M.update_popup_api_display()

		M.close_selector()
	else
		vim.notify("Erro ao selecionar a API: " .. selected_api, vim.log.levels.ERROR)
	end
end

M.update_popup_api_display = function()
	local status, popup_module = pcall(require, 'multi_context.popup')
	if status and popup_module.popup_buf and api.nvim_buf_is_valid(popup_module.popup_buf) then
		local current_api = utils.get_current_api()
		local buf = popup_module.popup_buf

		-- Obter todas as linhas
		local lines = api.nvim_buf_get_lines(buf, 0, -1, false)

		-- Encontrar e remover a linha antiga da API atual
		local new_lines = {}
		local api_line_found = false

		for _, line in ipairs(lines) do
			if not line:match("^## API atual:") then
				table.insert(new_lines, line)
			else
				api_line_found = true
			end
		end

		-- Se não encontrou a linha da API, inseri-la antes da última linha (que deve ser o prompt)
		if not api_line_found and #new_lines > 0 then
			table.insert(new_lines, #new_lines, "## API atual: " .. current_api)
		else
			-- Encontrar a posição do último prompt para inserir antes dele
			local insert_pos = #new_lines
			for i = #new_lines, 1, -1 do
				if new_lines[i]:match("^## Nardi >>") then
					insert_pos = i
					break
				end
			end
			table.insert(new_lines, insert_pos, "## API atual: " .. current_api)
		end

		-- Atualizar o buffer
		api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)

		-- Reaplicar highlights
		local utils = require('multi_context.utils')
		utils.apply_highlights(buf)

		-- Recriar as folds
		if popup_module.create_folds then
			popup_module.create_folds(buf)
		end

		-- Reposicionar o cursor no final
		local last_line = #new_lines
		if popup_module.popup_win and api.nvim_win_is_valid(popup_module.popup_win) then
			api.nvim_win_set_cursor(popup_module.popup_win, {last_line, #"## Nardi >> "})
			vim.cmd("startinsert")
		end
	end
end

M.close_selector = function()
	if M.selector_win and api.nvim_win_is_valid(M.selector_win) then
		api.nvim_win_close(M.selector_win, true)
	end
	M.cleanup()
end

M.cleanup = function()
	M.selector_buf = nil
	M.selector_win = nil
	M.api_list = {}
	M.current_selection = 1
end

return M
