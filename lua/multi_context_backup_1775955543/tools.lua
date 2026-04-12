-- lua/multi_context/tools.lua
local M = {}

-- Segurança: Garante que estamos num repo Git e retorna a raiz
local function get_repo_root()
    vim.fn.system("git rev-parse --show-toplevel")
    if vim.v.shell_error ~= 0 then return nil end
    return vim.fn.system("git rev-parse --show-toplevel"):gsub("\n", "")
end

-- Resolve o caminho de forma inteligente (Absoluto vs Relativo)
local function resolve_path(path)
    -- BLINDAGEM: Se o parâmetro for nulo (a IA esqueceu), interrompe com graciosidade
    if not path or path == "" then return nil end
    
    path = vim.trim(path)
    if path:sub(1, 1) == "/" then return path end
    local root = get_repo_root() or vim.fn.getcwd()
    return root .. "/" .. path
end

M.list_files = function()
    local root = get_repo_root()
    if not root then return "ERRO: O agente tentou listar arquivos fora de um repositório Git." end
    local files = vim.fn.system("git -C " .. vim.fn.shellescape(root) .. " ls-files")
    return "Arquivos rastreados pelo Git no repositório:\n" .. files
end

M.read_file = function(path)
    local full_path = resolve_path(path)
    if not full_path then return "ERRO: O atributo 'path' é obrigatório e não foi fornecido na tag." end
    
    if vim.fn.filereadable(full_path) == 0 then return "ERRO: Arquivo não encontrado (" .. full_path .. ")" end
    return table.concat(vim.fn.readfile(full_path), "\n")
end

M.edit_file = function(path, content)
    local full_path = resolve_path(path)
    if not full_path then return "ERRO: O atributo 'path' é obrigatório para editar arquivos." end
    
    local dir = vim.fn.fnamemodify(full_path, ":h")
    if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, "p") end

    content = content:gsub("\r", ""):gsub("^\n", ""):gsub("\n$", "")
    local lines = vim.split(content, "\n", {plain=true})
    local bufnr = vim.fn.bufnr(full_path)
    
    if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        vim.api.nvim_buf_call(bufnr, function() vim.cmd("silent! write") end)
    else
        if vim.fn.writefile(lines, full_path) == -1 then
            return "ERRO: Falha de permissão ao tentar salvar o arquivo " .. full_path
        end
    end
    return "SUCESSO: Arquivo " .. full_path .. " foi sobrescrito."
end

M.run_shell = function(cmd)
    if not cmd or cmd == "" then return "ERRO: O comando do terminal não foi fornecido." end
    
    local root = get_repo_root() or vim.fn.getcwd()
    cmd = vim.trim(cmd)
    local bash_script = string.format("cd %s && %s", vim.fn.shellescape(root), cmd)
    local out = vim.fn.system({'bash', '-c', bash_script})
    local status = "SUCESSO"
    if vim.v.shell_error ~= 0 then status = "FALHA (Código " .. vim.v.shell_error .. ")" end
    return string.format("Comando executado:\n%s\n\nStatus: %s\nSaída:\n%s", cmd, status, out)
end

-- =========================================================
-- NOVAS FERRAMENTAS AVANÇADAS: Busca em Lote e Edição Cirúrgica
-- =========================================================

M.search_code = function(query)
    local root = get_repo_root()
    if not root then return "ERRO: O agente tentou buscar código fora de um repositório Git." end
    if not query or query == "" then return "ERRO: O atributo 'query' é obrigatório para a busca." end
    
    -- Roda 'git grep -n -i -I' (ignora case, mostra nº da linha, ignora binários)
    local cmd = string.format("git -C %s grep -n -i -I %s", vim.fn.shellescape(root), vim.fn.shellescape(query))
    local out = vim.fn.system(cmd)
    
    if vim.v.shell_error ~= 0 or out == "" then
        return "Nenhum resultado encontrado para a busca: " .. query
    end
    
    -- Blindagem: Trunca saídas massivas para não estourar os tokens da API
    if #out > 3000 then
        out = out:sub(1, 3000) .. "\n\n... [AVISO: RESULTADO TRUNCADO DEVIDO AO TAMANHO MASSIVO] ..."
    end
    
    return "Resultados da busca por '" .. query .. "':\n" .. out
end

M.replace_lines = function(path, start_line, end_line, content)
    local full_path = resolve_path(path)
    if not full_path then return "ERRO: O atributo 'path' é obrigatório." end
    
    start_line = tonumber(start_line)
    end_line = tonumber(end_line)
    
    if not start_line or not end_line then
        return "ERRO: Atributos 'start' e 'end' devem ser números válidos."
    end
    
    local bufnr = vim.fn.bufnr(full_path)
    local lines = {}
    
    -- Carrega o estado mais recente (da Memória ou do Disco)
    if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
        lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    else
        if vim.fn.filereadable(full_path) == 0 then return "ERRO: Arquivo " .. path .. " não encontrado." end
        lines = vim.fn.readfile(full_path)
    end
    
    if start_line < 1 then start_line = 1 end
    if end_line > #lines then end_line = #lines end
    if start_line > end_line then return "ERRO: Linha de início maior que a linha de fim." end
    
    -- Limpa sujeira de quebra de linha da tag XML
    content = content:gsub("\r", ""):gsub("^\n", ""):gsub("\n$", "")
    local new_lines = content == "" and {} or vim.split(content, "\n", {plain=true})
    
    -- Matemática de Edição do Array: Mantém o Topo + Insere Novo + Mantém o Fundo
    local final_lines = {}
    for i = 1, start_line - 1 do table.insert(final_lines, lines[i]) end
    for _, l in ipairs(new_lines) do table.insert(final_lines, l) end
    for i = end_line + 1, #lines do table.insert(final_lines, lines[i]) end
    
    -- Salva de volta (usando o mecanismo inteligente de memória e undo)
    if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, final_lines)
        vim.api.nvim_buf_call(bufnr, function() vim.cmd("silent! write") end)
    else
        if vim.fn.writefile(final_lines, full_path) == -1 then
            return "ERRO: Falha ao salvar."
        end
    end
    
    return "SUCESSO: Edição cirúrgica concluída nas linhas " .. start_line .. " a " .. end_line .. " do arquivo " .. path
end

return M
