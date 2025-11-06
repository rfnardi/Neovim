local api = vim.api
local utils = require('multi_context.utils')

local M = {}

M.popup_buf = nil
M.popup_win = nil
M.context_text = nil


M.open_popup = function(text, context_text)
	M.context_text = context_text
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
		title = " MultiContext - Chat ",
		title_pos = "center",
	})


	local lines = utils.split_lines(text)
	table.insert(lines, "")

	-- Adicionar informação da API atual
	local current_api = utils.get_current_api()
	table.insert(lines, "## API atual: " .. current_api)
	table.insert(lines, "## Nardi >> ")

	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	api.nvim_win_set_cursor(M.popup_win, { #lines, #"## Nardi >> " })
	vim.cmd('normal! zz')

	-- Apenas Ctrl+S para enviar
	api.nvim_buf_set_keymap(buf, "i", "<C-s>", "<Cmd>lua require('multi_context').SendFromPopup()<CR>", { noremap=true, silent=true })
	api.nvim_buf_set_keymap(buf, "n", "<C-s>", "<Cmd>lua require('multi_context').SendFromPopup()<CR>", { noremap=true, silent=true })

api.nvim_buf_set_keymap(buf, "i", "<A-w>", "<Cmd>lua require('multi_context').ToggleWorkspaceView()<CR>", { noremap=true, silent=true })
	api.nvim_buf_set_keymap(buf, "n", "<A-w>", "<Cmd>lua require('multi_context').ToggleWorkspaceView()<CR>", { noremap=true, silent=true })

	-- Aplicar highlights iniciais
	utils.apply_highlights(buf)

	-- Configuração de folds
	api.nvim_buf_set_option(buf, "foldmethod", "manual")
	api.nvim_buf_set_option(buf, "foldenable", true)
	api.nvim_buf_set_option(buf, "foldlevel", 1)

	M.create_folds(buf)
end

M.create_folds = function(buf)
	local total_lines = api.nvim_buf_line_count(buf)

	-- Primeiro, vamos limpar todas as folds existentes
	vim.cmd('normal! zE')

	-- Encontra todas as linhas de cabeçalho
	local headers = {}
	for i = 0, total_lines - 1 do
		local line = api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
		if line and (line:match("^## Nardi >>") or line:match("^## IA .* >>") or 
			line:match("^===") or line:match("^==")) then
			table.insert(headers, {line = i, type = "foldable"})
		elseif line and line:match("^## API atual:") then
			table.insert(headers, {line = i, type = "api_info"})
		end
	end

	-- Ordena por número de linha
	table.sort(headers, function(a, b) return a.line < b.line end)

	-- Encontra o índice da última resposta da IA
	local last_ia_header_index = nil
	for i = #headers, 1, -1 do
		if headers[i].type == "foldable" and headers[i].line and api.nvim_buf_get_lines(buf, headers[i].line, headers[i].line + 1, false)[1]:match("^## IA .* >>") then
			last_ia_header_index = i
			break
		end
	end

	-- Cria folds apenas para os cabeçalhos "foldable"
	for i = 1, #headers do
		local current_header = headers[i]

		-- Pular se for a linha da API atual
		if current_header.type == "api_info" then
			goto continue
		end

		local fold_start = current_header.line + 1
		local fold_end = total_lines - 1

		-- Encontrar o próximo cabeçalho (foldable ou api_info)
		for j = i + 1, #headers do
			local next_header = headers[j]
			fold_end = next_header.line - 1
			break
		end

		-- Só cria a fold se houver conteúdo após o cabeçalho
		if fold_start <= fold_end then
			vim.api.nvim_buf_call(buf, function()
				vim.cmd(string.format("%d,%dfold", fold_start + 1, fold_end + 1))
			end)
		end

		::continue::
	end

	-- Fecha todas as folds, exceto a última resposta da IA
	for i = 1, #headers do
		local current_header = headers[i]
		if current_header.type == "foldable" and i ~= last_ia_header_index then
			local fold_start = current_header.line + 1
			local fold_end = total_lines - 1

			for j = i + 1, #headers do
				local next_header = headers[j]
				fold_end = next_header.line - 1
				break
			end

			if fold_start <= fold_end then
				vim.api.nvim_buf_call(buf, function()
					vim.cmd(string.format("%d,%dfoldclose", fold_start + 1, fold_end + 1))
				end)
			end
		end
	end

	-- Abre a última fold da IA (se houver)
	if last_ia_header_index then
		local last_ia_header = headers[last_ia_header_index]
		local fold_start = last_ia_header.line + 1
		local fold_end = total_lines - 1

		for j = last_ia_header_index + 1, #headers do
			local next_header = headers[j]
			fold_end = next_header.line - 1
			break
		end

		if fold_start <= fold_end then
			vim.api.nvim_buf_call(buf, function()
				vim.cmd(string.format("%dfoldopen!", fold_start + 1)) -- Abre recursivamente
			end)
		end
	end

	vim.cmd('normal! G')
	vim.cmd('normal! zz')
end

M.update_api_display = function()
	if not M.popup_buf or not api.nvim_buf_is_valid(M.popup_buf) then
		return false
	end

	local utils = require('multi_context.utils')
	local current_api = utils.get_current_api()

	-- Encontrar e atualizar a linha da API
	local lines = api.nvim_buf_get_lines(M.popup_buf, 0, -1, false)
	for i, line in ipairs(lines) do
		if line:match("^## API atual:") then
			lines[i] = "## API atual: " .. current_api
			api.nvim_buf_set_lines(M.popup_buf, i-1, i, false, {lines[i]})

			-- Reaplicar highlights
			utils.apply_highlights(M.popup_buf)
			return true
		end
	end

	return false
end

return M
