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

function M.clean_text(text)
	return text:gsub('[^\0-\127\192-\255][\128-\191]*', '') -- Remove caracteres não-UTF8
end

function M.should_include_file(filepath)
	-- Lista de extensões e padrões a excluir
	local exclude_patterns = {
		-- Arquivos compilados/python
		"%.pyc$", "%.pyo$", "__pycache__",
		-- Arquivos objeto e binários
		"%.o$", "%.so$", "%.dll$", "%.exe$", "%.bin$",
		-- Arquivos de cache e temporários
		"%.cache$", "%.tmp$", "%.temp$", "%.swp$", "%.swo$",
		-- Arquivos de log
		"%.log$", "%.logs?$",
		-- Diretórios de sistema
		"%.git/", "node_modules/", "%.svn/", "%.hg/",
		-- Arquivos compactados
		"%.zip$", "%.tar%..*", "%.rar$", "%.7z$", "%.gz$",
		-- Imagens
		"%.png$", "%.jpg$", "%.jpeg$", "%.gif$", "%.bmp$", "%.ico$", "%.svg$",
		-- Vídeos e áudios
		"%.mp4$", "%.avi$", "%.mov$", "%.mp3$", "%.wav$", "%.flac$",
		-- Documentos
		"%.pdf$", "%.docx?$", "%.pptx?$", "%.xlsx?$",
		-- Outros binários
		"%.class$", "%.jar$", "%.war$", "%.ear$",
		-- Arquivos de sistema
		"%.DS_Store$", "Thumbs%.db$", "%.spotlight%-v100$",
		-- Backups
		"%.bak$", "%.backup$", "%~$",
	}

	for _, pattern in ipairs(exclude_patterns) do
		if filepath:match(pattern) then
			return false
		end
	end

	return true
end

M.apply_highlights = function(buf)
	-- Verificar se o buffer ainda é válido
	if not api.nvim_buf_is_valid(buf) then
		return
	end

	-- Aplicar apenas se for o buffer do nosso popup
	local buf_name = api.nvim_buf_get_name(buf)
	if buf_name ~= "" then
		return -- Não é um buffer anônimo (provavelmente é um arquivo real)
	end

	vim.cmd("highlight ContextHeader gui=bold guifg=#FF4500 guibg=NONE")
	vim.cmd("highlight ContextUserAI gui=bold guifg=#0000CD guibg=NONE")
	vim.cmd("highlight ContextUser gui=bold guifg=#B22222 guibg=NONE")
	vim.cmd("highlight ContextCurrentBuffer gui=bold guifg=#FFA500 guibg=NONE")
	vim.cmd("highlight ContextUpdateMessages gui=bold guifg=#FFA500 guibg=NONE")
	vim.cmd("highlight ContextBoldText gui=bold guifg=#FFA500 guibg=NONE")
	vim.cmd("highlight ContextApiInfo gui=bold guifg=#FFA500 guibg=NONE")

	local total_lines = api.nvim_buf_line_count(buf)

	for i = 0, total_lines - 1 do
		local line = api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
		if not line then goto continue end

		if line:match("^===") or line:match("^==") then
			api.nvim_buf_add_highlight(buf, -1, "ContextHeader", i, 0, -1)
		end

		if line:match("## buffer atual ##") then
			local start_idx, end_idx = line:find("## buffer atual ##")
			if start_idx then
				api.nvim_buf_add_highlight(buf, -1, "ContextCurrentBuffer", i, start_idx-1, end_idx)
			end
		end

		if line:match("%[mensagem enviada%]") then
			local start_idx, end_idx = line:find("%[mensagem enviada%]")
			if start_idx then
				api.nvim_buf_add_highlight(buf, -1, "ContextUpdateMessages", i, start_idx-1, end_idx)
			end
		end

		if line:match("%*%*.*%*%*") then
			local start_idx, end_idx = line:find("%*%*.*%*%*")
			if start_idx then
				api.nvim_buf_add_highlight(buf, -1, "ContextBoldText", i, start_idx-1, end_idx)
			end
		end

		if line:match("^## Nardi >>") then
			local start_idx, end_idx = line:find("## Nardi >>")
			if start_idx then
				api.nvim_buf_add_highlight(buf, -1, "ContextUser", i, start_idx-1, end_idx)
			end
		end

		if line:match("^## IA .* >>") then
			local start_idx, end_idx = line:find("## IA .* >>")
			if start_idx then
				api.nvim_buf_add_highlight(buf, -1, "ContextUserAI", i, start_idx-1, end_idx)
			end
		end

		if line:match("^## API atual:") then
			local start_idx, end_idx = line:find("## API atual:")
			if start_idx then
				api.nvim_buf_add_highlight(buf, -1, "ContextApiInfo", i, start_idx-1, end_idx)
			end
		end

		::continue::
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

	-- Filtrar arquivos indesejados
	local filtered_files = {}
	for _, fname in ipairs(files) do
		if M.should_include_file(fname) then
			table.insert(filtered_files, fname)
		end
	end

	table.insert(context_lines, table.concat(filtered_files, "\n"))
	table.insert(context_lines, "")

	-- Seção cat - apenas para arquivos filtrados
	for _, fname in ipairs(filtered_files) do
		local full_path = dir .. "/" .. fname
		if vim.fn.isdirectory(full_path) == 0 then
			-- Verificar se é arquivo binário antes de ler
			local extension = vim.fn.fnamemodify(fname, ':e')
			local binary_extensions = {
				'png', 'jpg', 'jpeg', 'gif', 'pdf', 'zip', 'tar', 'gz', 'rar', '7z',
				'mp3', 'mp4', 'avi', 'mkv', 'ico', 'woff', 'woff2', 'ttf', 'exe', 'dll', 'so', 'o'
			}

			local is_binary = false
			for _, ext in ipairs(binary_extensions) do
				if extension:lower() == ext then
					is_binary = true
					break
				end
			end

			local header = "== Arquivo: " .. fname
			if fname == cur_fname then
				header = header .. " ## buffer atual ##"
			end
			table.insert(context_lines, header)

			if not is_binary then
				local success, lines = pcall(vim.fn.readfile, full_path)
				if success then
					vim.list_extend(context_lines, lines)
				else
					table.insert(context_lines, "-- Não foi possível ler o arquivo --")
				end
			else
				table.insert(context_lines, "-- Arquivo binário ignorado --")
			end
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

	-- Função recursiva para listar arquivos, ignorando a pasta .git e arquivos indesejados
	local function list_files(dir, prefix)
		local files = {}
		local items = vim.fn.readdir(dir)

		-- Ordenar: diretórios primeiro, depois arquivos
		local dirs = {}
		local files_list = {}

		for _, item in ipairs(items) do
			if item ~= ".git" and M.should_include_file(item) then  -- Filtro adicionado aqui
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

	local max_files = 50  -- Limite reduzido para evitar sobrecarga

	-- Adicionar conteúdo dos arquivos - COM FILTRO
	local function add_file_contents(dir)
		local items = vim.fn.readdir(dir)
		local file_count = 0

		for _, item in ipairs(items) do
			if file_count >= max_files then break end

			if item ~= ".git" and M.should_include_file(item) then  -- Filtro adicionado aqui
				local full_path = dir .. '/' .. item
				if vim.fn.isdirectory(full_path) == 1 then
					add_file_contents(full_path)
				else
					-- Verificar se é um arquivo de texto (ignorar binários)
					local extension = vim.fn.fnamemodify(item, ':e')
					local binary_extensions = {
						'png', 'jpg', 'jpeg', 'gif', 'pdf', 'zip', 'tar', 'gz', 'rar', '7z',
						'mp3', 'mp4', 'avi', 'mkv', 'ico', 'woff', 'woff2', 'ttf', 'exe', 'dll', 'so', 'o',
						'pyc', 'pyo'  -- Adicionados específicos do Python
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
							-- Limitar tamanho do arquivo (primeiras 200 linhas)
							local max_lines = 200
							if #file_lines > max_lines then
								vim.list_extend(context_lines, {unpack(file_lines, 1, max_lines)})
								table.insert(context_lines, "-- ... arquivo truncado ... --")
							else
								vim.list_extend(context_lines, file_lines)
							end
							file_count = file_count + 1
						else
							table.insert(context_lines, "-- Não foi possível ler o arquivo --")
						end
						table.insert(context_lines, "")
					end
				end
			end
		end
	end

	table.insert(context_lines, "=== Conteúdo dos Arquivos (limitado a " .. max_files .. " arquivos):")
	add_file_contents(git_root)

	return table.concat(context_lines, "\n")
end

M.get_git_diff = function()
	-- Verifica se estamos em um repositório git
	local git_dir = vim.fn.finddir('.git', '.;')
	if git_dir == '' then
		return nil, "Não é um repositório git"
	end

	-- Comando git diff que ignora arquivos binários e .pyc
	local exclude_patterns = {
		"*.pyc", "*.pyo", "*.png", "*.jpg", "*.jpeg", "*.gif", "*.pdf",
		"*.zip", "*.tar.*", "*.rar", "*.7z", "*.mp3", "*.mp4", "*.avi", "*.mkv"
	}

	local exclude_args = ""
	for _, pattern in ipairs(exclude_patterns) do
		exclude_args = exclude_args .. " ':!" .. pattern .. "'"
	end

	-- Obtém informações do branch atual
	local branch_name = vim.fn.system('git branch --show-current'):gsub('%s+', '')
	if vim.v.shell_error ~= 0 then
		branch_name = "desconhecido"
	end

	-- Executa git status para obter informações resumidas
	local status_result = vim.fn.system('git status --porcelain -- .' .. exclude_args)
	local status_lines = {}
	for line in status_result:gmatch("[^\r\n]+") do
		table.insert(status_lines, line)
	end

	-- Executa git diff para obter as mudanças detalhadas
	local diff_result = vim.fn.system('git diff HEAD -- .' .. exclude_args)

	if vim.v.shell_error ~= 0 then
		return nil, "Erro ao executar git diff"
	end

	if diff_result == '' and #status_lines == 0 then
		return nil, "Nenhuma mudança não commitada encontrada"
	end

	local context_text = "=== Git Status (Branch: " .. branch_name .. "):\n"

	if #status_lines > 0 then
		context_text = context_text .. "Arquivos modificados:\n"
		for _, line in ipairs(status_lines) do
			context_text = context_text .. "  " .. line .. "\n"
		end
		context_text = context_text .. "\n"
	else
		context_text = context_text .. "Nenhum arquivo modificado\n\n"
	end

	if diff_result ~= '' then
		context_text = context_text .. "=== Git Diff (mudanças detalhadas):\n" .. diff_result
	else
		context_text = context_text .. "=== Git Diff: Nenhuma diferença detalhada (arquivos novos ou deletados)"
	end

	return context_text, nil
end

-- Adicione estas funções ao final do utils.lua

M.get_api_names = function()
	local api_config = M.load_api_config()
	if not api_config or not api_config.apis then
		return {}
	end

	local api_names = {}
	for _, api in ipairs(api_config.apis) do
		table.insert(api_names, api.name)
	end
	return api_names
end

M.set_selected_api = function(api_name)
	local api_config = M.load_api_config()
	if not api_config then
		return false
	end

	-- Verifica se a API existe
	local api_exists = false
	for _, api in ipairs(api_config.apis or {}) do
		if api.name == api_name then
			api_exists = true
			break
		end
	end

	if api_exists then
		api_config.default_api = api_name
		-- Salva a configuracao atualizada
		local config_path = vim.fn.expand('~/.config/nvim/context_apis.json')
		local file = io.open(config_path, 'w')
		if file then
			-- Tenta codificar com formatacao. Em versoes mais antigas do Neovim,
			-- isso pode nao ser suportado, entao usamos um pcall para segurança.
			local ok, json_string = pcall(vim.fn.json_encode, api_config, { pretty = true, indent = "  " })
			if not ok then
				-- Fallback para o metodo sem formatacao se o primeiro falhar
				json_string = vim.fn.json_encode(api_config)
			end
			file:write(json_string)
			file:close()
			return true
		end
	end

	return false
end

M.get_current_api = function()
	local api_config = M.load_api_config()
	if not api_config then
		return "Nenhuma API configurada"
	end
	return api_config.default_api or "Nenhuma API selecionada"
end


M.read_tree_context = function()
	local cur_file = api.nvim_buf_get_name(0)
	if cur_file == "" then return "" end
	local start_dir = vim.fn.fnamemodify(cur_file, ":h")

	local context_lines = {}

	-- Adicionar a estrutura de diretórios (árvore)
	table.insert(context_lines, "=== Estrutura de diretórios a partir de " .. start_dir .. ":")

	local function list_files(dir, indent)
		local files = {}
		local items = vim.fn.readdir(dir)

		-- Ordenar: diretorios primeiro, depois arquivos
		local dirs = {}
		local files_list = {}

		for _, item in ipairs(items) do
			if item ~= ".git" and M.should_include_file(item) then
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

		-- Adicionar diretorios
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

	local function build_tree(dir, indent, base_indent)
		indent = indent or ""
		base_indent = base_indent or ""
		local files = list_files(dir)

		for i, item in ipairs(files) do
			local is_last = i == #files
			local connector = is_last and " " or " "

			if item.is_dir then
				table.insert(context_lines, base_indent .. indent .. connector .. item.name .. "/")
				local new_indent = indent .. (is_last and "    " or "   ")
				build_tree(item.path, new_indent, base_indent)
			else
				table.insert(context_lines, base_indent .. indent .. connector .. item.name)
			end
		end
	end

	build_tree(start_dir, "", "")
	table.insert(context_lines, "")

	-- Adicionar o conteúdo dos arquivos
    table.insert(context_lines, "=== Conteúdo dos arquivos na árvore:")

    local function read_file_contents(dir)
        local files = list_files(dir) -- Obtem arquivos filtrados

        for _, item in ipairs(files) do
            if not item.is_dir then
                local full_path = item.path
                local header = "== Arquivo: " .. item.name
                table.insert(context_lines, header)

                local success, lines = pcall(vim.fn.readfile, full_path)
                if success then
                    vim.list_extend(context_lines, lines)
                else
                    table.insert(context_lines, "-- Nao foi possivel ler o arquivo --")
                end
                table.insert(context_lines, "")
            elseif item.is_dir then
                read_file_contents(item.path) -- Recursivamente ler o conteudo dos arquivos
            end
        end
    end

    read_file_contents(start_dir)

    return table.concat(context_lines, "\n")
end

M.generate_chat_filename = function()
	local date_str = os.date("%d_%m_%Y")
	local i = 1
	local filename

	while true do
		filename = string.format("chat_%s_%d.md", date_str, i)
		-- Procura o arquivo no diretório de trabalho atual
		if vim.fn.filereadable(vim.fn.getcwd() .. "/" .. filename) == 0 then
			return filename
		end
		i = i + 1
	end
end

return M
