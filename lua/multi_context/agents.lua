-- lua/multi_context/agents.lua
local api = vim.api
local M = {}

M.agents_file = vim.fn.stdpath("config") .. "/lua/multi_context/agents/agents.json"

M.load_agents = function()
    local file = io.open(M.agents_file, 'r')
    if not file then return {} end
    local content = file:read('*a')
    file:close()
    local ok, parsed = pcall(vim.fn.json_decode, content)
    return ok and parsed or {}
end

M.get_agent_names = function()
    local agents = M.load_agents()
    local names = {}
    for name, _ in pairs(agents) do table.insert(names, name) end
    table.sort(names)
    return names
end

M.get_tools_manual = function()
    return [[
=== FERRAMENTAS DO SISTEMA (SYSTEM TOOLS) ===
Você é um Agente Autônomo rodando nativamente dentro do editor Neovim do usuário. Você tem a capacidade de interagir com o sistema de arquivos local e com o terminal (bash) do projeto atual.

REGRA ABSOLUTA DE FORMATO:
Para invocar uma ferramenta, você DEVE usar ESTRITAMENTE o formato de tags XML exemplificado abaixo. É ESTRITAMENTE PROIBIDO usar formato JSON.\nNÃO ENVOLVA os argumentos da ferramenta com tags extras (como <arg_value>, <content> ou <command>). Escreva o conteúdo ou script DIRETAMENTE dentro da tag <tool_call> principal.

=== MEMÓRIA DO PROJETO (CONTEXT.md) ===
Na raiz do projeto pode existir um arquivo chamado CONTEXT.md. Este arquivo é a SUA memória de longo prazo e atua como o cérebro da equipe.
Ele contém o resumo do projeto, escolhas de tecnologias, o que já foi feito e o que falta fazer.
- SEMPRE que você concluir uma funcionalidade importante ou tomar uma decisão relevante, ATUALIZE o CONTEXT.md usando as ferramentas edit_file ou replace_lines para que a sua memória não se perca no futuro.
- Se o arquivo não existir e for o início de um projeto, CRIE-O com um resumo inicial.

Ferramentas Disponíveis:
1. Listar Arquivos (list_files)
Formato: <tool_call name="list_files"></tool_call>

2. Buscar Código no Repositório (search_code)
Formato: <tool_call name="search_code" query="palavra_ou_funcao"></tool_call>

3. Ler Arquivo (read_file)
Formato: <tool_call name="read_file" path="caminho/do/arquivo.ext"></tool_call>

4. Substituir Bloco de Código (replace_lines) - RECOMENDADA
Formato:
<tool_call name="replace_lines" path="arquivo.cpp" start="10" end="15">
CÓDIGO NOVO AQUI
</tool_call>

5. Sobrescrever Arquivo Completo (edit_file)
Formato:
<tool_call name="edit_file" path="caminho.ext">
CÓDIGO INTEIRO AQUI
</tool_call>

6. Executar Terminal (run_shell)
Formato:
<tool_call name="run_shell">
comando bash aqui
</tool_call>

7. Reescrever e Comprimir o Chat (rewrite_chat_buffer) - EXCLUSIVO DO ENGENHEIRO DE PROMPT
Apaga TODO o histórico do chat atual e substitui apenas pelo conteúdo que você enviar dentro desta tag. Use para salvar tokens em chats massivos. VOCÊ DEVE manter a estrutura (## Usuario >> e ## IA >>) no novo texto.
Formato:
<tool_call name="rewrite_chat_buffer">
## Nome_Do_Usuario >> [Resumo do que foi pedido]
## IA >> [Resumo do estado atual do projeto]
</tool_call>

8. Obter Diagnósticos LSP (get_diagnostics)
Lê erros e avisos sintáticos e semânticos apontados pelo LSP em um arquivo específico.
Formato: <tool_call name="get_diagnostics" path="caminho/do/arquivo.lua"></tool_call>
</tool_call>
]]
end

M.selector_buf = nil; M.selector_win = nil; M.current_selection = 1; M.api_list = {}; M.parent_win = nil

M.open_agent_selector = function()
    M.api_list = M.get_agent_names()
    if #M.api_list == 0 then return end
    M.parent_win = api.nvim_get_current_win()
    M.current_selection = 1
    M.selector_buf = api.nvim_create_buf(false, true)
    M.selector_win = api.nvim_open_win(M.selector_buf, true, {
        relative = "cursor", row = 1, col = 0, width = 30, height = #M.api_list,
        style = "minimal", border = "rounded",
    })
    vim.bo[M.selector_buf].buftype = "nofile"
    M._render(); M._keymaps()
end

M._render = function()
    if not M.selector_buf or not api.nvim_buf_is_valid(M.selector_buf) then return end
    local lines = {}
    for i, name in ipairs(M.api_list) do
        local cursor = (i == M.current_selection) and "❯ " or "  "
        table.insert(lines, cursor .. name)
    end
    vim.bo[M.selector_buf].modifiable = true
    api.nvim_buf_set_lines(M.selector_buf, 0, -1, false, lines)
    local ns = api.nvim_create_namespace("mc_agents")
    api.nvim_buf_clear_namespace(M.selector_buf, ns, 0, -1)
    api.nvim_buf_add_highlight(M.selector_buf, ns, "ContextSelectorCurrent", M.current_selection - 1, 0, -1)
end

M._keymaps = function()
    if not M.selector_buf or not api.nvim_buf_is_valid(M.selector_buf) then return end
    local mk = function(k, fn) api.nvim_buf_set_keymap(M.selector_buf, "n", k, "", { callback = fn, noremap = true, silent = true }) end
    mk("j", function() M._move(1) end); mk("k", function() M._move(-1) end)
    mk("<CR>", M._select); mk("<Esc>", M._close); mk("q", M._close)
end

M._move = function(dir)
    local n = M.current_selection + dir
    if n >= 1 and n <= #M.api_list then M.current_selection = n; M._render() end
end

M._select = function()
    local name = M.api_list[M.current_selection]
    M._close_win_only()
    if M.parent_win and api.nvim_win_is_valid(M.parent_win) then
        api.nvim_set_current_win(M.parent_win)
        local row, col = unpack(api.nvim_win_get_cursor(0))
        local line = api.nvim_get_current_line()
        local new_line = string.sub(line, 1, col + 1) .. name .. string.sub(line, col + 2)
        api.nvim_set_current_line(new_line)
        api.nvim_win_set_cursor(0, {row, col + 1 + #name})
        api.nvim_feedkeys("a", "n", true)
    end
end

M._close_win_only = function()
    if M.selector_win and api.nvim_win_is_valid(M.selector_win) then api.nvim_win_close(M.selector_win, true) end
    M.selector_buf = nil; M.selector_win = nil
end
M._close = function()
    M._close_win_only()
    if M.parent_win and api.nvim_win_is_valid(M.parent_win) then api.nvim_set_current_win(M.parent_win); api.nvim_feedkeys("a", "n", true) end
end

return M
