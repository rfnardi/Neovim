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
    path = vim.trim(path)
    if path:sub(1, 1) == "/" then
        return path
    end
    
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
    if vim.fn.filereadable(full_path) == 0 then 
        return "ERRO: Arquivo não encontrado (" .. full_path .. ")" 
    end
    return table.concat(vim.fn.readfile(full_path), "\n")
end

M.edit_file = function(path, content)
    local full_path = resolve_path(path)
    
    -- Permite criar as pastas do caminho caso o agente esteja criando um arquivo novo
    local dir = vim.fn.fnamemodify(full_path, ":h")
    if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
    end

    -- Remove as quebras de linha sujas do XML
    content = content:gsub("\r", "")
    content = content:gsub("^\n", "")
    content = content:gsub("\n$", "")

    local lines = vim.split(content, "\n", {plain=true})
    
    -- MÁGICA: Verifica se o Neovim já tem esse arquivo aberto em alguma aba/janela
    local bufnr = vim.fn.bufnr(full_path)
    
    if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
        -- Se estiver aberto, atualiza a MEMÓRIA do Neovim (Permite dar 'Undo' depois!)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        -- Salva o buffer no disco silenciosamente
        vim.api.nvim_buf_call(bufnr, function()
            vim.cmd("silent! write")
        end)
    else
        -- Se o arquivo estiver fechado, escreve direto no disco rígido
        local success = vim.fn.writefile(lines, full_path)
        if success == -1 then
            return "ERRO: Falha de permissão ao tentar salvar o arquivo " .. full_path
        end
    end
    
    return "SUCESSO: Arquivo " .. full_path .. " foi salvo/atualizado."
end

M.run_shell = function(cmd)
    local root = get_repo_root() or vim.fn.getcwd()
    
    -- Limpa espaços e quebras indesejadas
    cmd = vim.trim(cmd)
    
    -- A SUA IDEIA: Constrói um comando Bash puro (Posix Compliance)
    -- Junta o CD e o comando da IA usando &&
    local bash_script = string.format("cd %s && %s", vim.fn.shellescape(root), cmd)
    
    -- Ao passar uma Tabela {} para o vim.fn.system, o Neovim ignora a configuração
    -- :set shell=/bin/fish e invoca o binário solicitado diretamente (bash -c).
    local out = vim.fn.system({'bash', '-c', bash_script})
    
    local status = "SUCESSO"
    if vim.v.shell_error ~= 0 then status = "FALHA (Código " .. vim.v.shell_error .. ")" end
    
    return string.format("Comando executado:\n%s\n\nStatus: %s\nSaída:\n%s", cmd, status, out)
end

return M
