local api = vim.api

local M = {}

M.split_lines = function(str)
	local t = {}
	for line in str:gmatch("([^\n]*)\n?") do
		table.insert(t, line)
	end
	return t
end

M.insert_after = function(buf, line_idx, lines)
	if line_idx == -1 then
		line_idx = api.nvim_buf_line_count(buf) - 1
	end
	api.nvim_buf_set_lines(buf, line_idx + 1, line_idx + 1, false, lines)
end

M.find_last_user_line = function(buf)
	local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
	for i = #lines, 1, -1 do
		if lines[i]:match("^## Nardi >>") then
			return i - 1, lines[i]
		end
	end
	return nil
end

M.load_api_config = function()
	local config_path = vim.fn.expand('~/.config/nvim/context_apis.json')
	local file = io.open(config_path, 'r')
	if not file then
		return nil
	end
	local content = file:read('*a')
	file:close()
	return vim.fn.json_decode(content)
end

M.load_api_keys = function()
	local keys_path = vim.fn.expand('~/.config/nvim/api_keys.json')
	local file = io.open(keys_path, 'r')
	if not file then
		return {}
	end
	local content = file:read('*a')
	file:close()
	return vim.fn.json_decode(content) or {}
end

M.apply_highlights = function(buf)
	vim.cmd("highlight ContextHeader gui=bold guifg=#FF4500 guibg=NONE")
	vim.cmd("highlight ContextUserAI gui=bold guifg=#32CD32 guibg=NONE")
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

		if line and line:match("^## IA .* >>") then
			local start_idx, end_idx = line:find("## IA .* >>")
			if start_idx then
				api.nvim_buf_add_highlight(buf, -1, "ContextUserAI", i, start_idx-1, end_idx)
			end
		end
	end
end

M.get_full_buffer = function()
	local buf = api.nvim_get_current_buf()
	local line_count = api.nvim_buf_line_count(buf)
	local lines = api.nvim_buf_get_lines(buf, 0, line_count, false)
	return table.concat(lines, "\n")
end

M.get_selection = function(start_line, end_line)
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

M.read_folder_context = function()
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

M.get_popup_content = function(buf)
	local line_count = api.nvim_buf_line_count(buf)
	local lines = api.nvim_buf_get_lines(buf, 0, line_count - 1, false)  -- Exclui a última linha (## Nardi >>)
	return table.concat(lines, "\n")
end

M.find_git_root = function(start_path)
	local path = start_path or vim.fn.expand('%:p:h')
	local current = path
	while current ~= '/' do
		local git_dir = current .. '/.git'
		if vim.fn.isdirectory(git_dir) == 1 then
			return current
		end
		current = vim.fn.fnamemodify(current, ':h')
	end
	return nil
end

M.read_repo_context = function()
	local cur_file = api.nvim_buf_get_name(0)
	if cur_file == '' then return "" end

	local git_root = M.find_git_root()
	if not git_root then
		vim.notify("Não foi possível encontrar a raiz do repositório Git", vim.log.levels.WARN)
		return ""
	end

	local context_lines = {}
	table.insert(context_lines, "=== Estrutura do Repositório Git em " .. git_root .. ":")

	-- Função recursiva para listar arquivos, ignorando a pasta .git
	local function list_files(dir, prefix)
		local files = {}
		local items = vim.fn.readdir(dir)

		-- Ordenar: diretórios primeiro, depois arquivos
		local dirs = {}
		local files_list = {}

		for _, item in ipairs(items) do
			if item ~= ".git" then  -- Ignorar pasta .git
				local full_path = dir .. '/' .. item
				if vim.fn.isdirectory(full_path) == 1 then
					table.insert(dirs, item)
				else
					table.insert(files_list, item)
				end
			end
		end

		-- Ordenar alfabeticamente
		table.sort(dirs)
		table.sort(files_list)

		-- Adicionar diretórios
		for _, dir_name in ipairs(dirs) do
			local full_path = dir .. '/' .. dir_name
			table.insert(files, {name = dir_name, is_dir = true, path = full_path})
		end

		-- Adicionar arquivos
		for _, file_name in ipairs(files_list) do
			local full_path = dir .. '/' .. file_name
			table.insert(files, {name = file_name, is_dir = false, path = full_path})
		end

		return files
	end

	-- Listar estrutura de arquivos
	local function build_tree(dir, indent, base_indent)
		indent = indent or ""
		base_indent = base_indent or ""
		local files = list_files(dir)

		for i, item in ipairs(files) do
			local is_last = i == #files
			local connector = is_last and "└── " or "├── "

			if item.is_dir then
				table.insert(context_lines, base_indent .. indent .. connector .. item.name .. "/")
				local new_indent = indent .. (is_last and "    " or "│   ")
				build_tree(item.path, new_indent, base_indent)
			else
				table.insert(context_lines, base_indent .. indent .. connector .. item.name)
			end
		end
	end

	build_tree(git_root, "", "")
	table.insert(context_lines, "")

	-- Adicionar conteúdo dos arquivos
	local function add_file_contents(dir)
		local items = vim.fn.readdir(dir)

		for _, item in ipairs(items) do
			if item ~= ".git" then
				local full_path = dir .. '/' .. item
				if vim.fn.isdirectory(full_path) == 1 then
					add_file_contents(full_path)
				else
					-- Verificar se é um arquivo de texto (ignorar binários)
					local extension = vim.fn.fnamemodify(item, ':e')
					local binary_extensions = {
						'png', 'jpg', 'jpeg', 'gif', 'pdf', 'zip', 'tar', 'gz',
						'mp3', 'mp4', 'avi', 'mkv', 'ico', 'woff', 'woff2', 'ttf'
					}

					local is_binary = false
					for _, ext in ipairs(binary_extensions) do
						if extension:lower() == ext then
							is_binary = true
							break
						end
					end

					if not is_binary then
						local relative_path = full_path:sub(#git_root + 2)
						local is_current_file = cur_file == full_path

						local header = "== Arquivo: " .. relative_path
						if is_current_file then
							header = header .. " ## buffer atual ##"
						end

						table.insert(context_lines, header)

						local success, file_lines = pcall(vim.fn.readfile, full_path)
						if success then
							vim.list_extend(context_lines, file_lines)
						else
							table.insert(context_lines, "-- Não foi possível ler o arquivo --")
						end
						table.insert(context_lines, "")
					end
				end
			end
		end
	end

	table.insert(context_lines, "=== Conteúdo dos Arquivos:")
	add_file_contents(git_root)

	return table.concat(context_lines, "\n")
end

return M
