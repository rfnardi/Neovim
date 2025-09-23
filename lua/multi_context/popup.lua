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
		title = "MultiContext - Chat",
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
	vim.cmd("startinsert")

	-- Apenas Ctrl+S para enviar
	api.nvim_buf_set_keymap(buf, "i", "<C-s>", "<Cmd>lua require('multi_context').SendFromPopup()<CR>", { noremap=true, silent=true })
	api.nvim_buf_set_keymap(buf, "n", "<C-s>", "<Cmd>lua require('multi_context').SendFromPopup()<CR>", { noremap=true, silent=true })

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
