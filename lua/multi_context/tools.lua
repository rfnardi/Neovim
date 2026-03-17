-- lua/multi_context/tools.lua
local M = {}

-- Segurança: Garante que estamos num repo Git e retorna a raiz
local function get_repo_root()
    vim.fn.system("git rev-parse --show-toplevel")
    if vim.v.shell_error ~= 0 then return nil end
    return vim.fn.system("git rev-parse --show-toplevel"):gsub("\n", "")
end

M.list_files = function()
    local root = get_repo_root()
    if not root then return "ERRO: O agente tentou listar arquivos fora de um repositório Git." end
    
    -- Usa o git ls-files para garantir que só vemos arquivos oficiais do projeto
    local files = vim.fn.system("git -C " .. vim.fn.shellescape(root) .. " ls-files")
    return "Arquivos rastreados pelo Git no repositório:\n" .. files
end

M.read_file = function(path)
    local root = get_repo_root() or vim.fn.getcwd()
    local full_path = root .. "/" .. path
    if vim.fn.filereadable(full_path) == 0 then 
        return "ERRO: Arquivo não encontrado (" .. full_path .. ")" 
    end
    return table.concat(vim.fn.readfile(full_path), "\n")
end

M.edit_file = function(path, content)
    local root = get_repo_root() or vim.fn.getcwd()
    local full_path = root .. "/" .. path
    
    -- Permite criar as pastas do caminho caso o agente esteja criando um arquivo novo
    local dir = vim.fn.fnamemodify(full_path, ":h")
    if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
    end

    local lines = vim.split(content, "\n", {plain=true})
    vim.fn.writefile(lines, full_path)
    return "SUCESSO: Arquivo " .. path .. " foi salvo/atualizado."
end

M.run_shell = function(cmd)
    local root = get_repo_root() or vim.fn.getcwd()
    -- Executa garantindo que estamos na raiz do projeto
    local out = vim.fn.system("cd " .. vim.fn.shellescape(root) .. " && " .. cmd)
    
    local status = "SUCESSO"
    if vim.v.shell_error ~= 0 then status = "FALHA (Código " .. vim.v.shell_error .. ")" end
    
    return string.format("Comando: %s\nStatus: %s\nSaída:\n%s", cmd, status, out)
end

return M
