#!/bin/bash

# Garante que estamos criando os arquivos no lugar certo
TARGET_DIR="lua/multi_context"

if [ ! -d "$TARGET_DIR" ]; then
    echo "❌ Erro: Diretório $TARGET_DIR não encontrado."
    echo "Certifique-se de rodar este script na raiz do projeto (ex: ~/.config/nvim/)."
    exit 1
fi

echo "🚀 Iniciando criação dos módulos desacoplados na Fase 13..."

# 1. tool_parser.lua (Extração funcional e segura das tags XML)
cat << 'EOF' > "$TARGET_DIR/tool_parser.lua"
-- lua/multi_context/tool_parser.lua
-- Responsabilidade: Puramente funcional. Recebe uma string (texto da IA) 
-- e extrai de forma segura e limpa as ferramentas (XML/JSON), 
-- lidando com crases, lixo e tags mal fechadas.

local M = {}

M.parse_tool_calls = function(content)
    -- TODO: Trazer a lógica de regex e sanitização anti-alucinação do ExecuteTools()
    return {}
end

return M
EOF
echo "✅ Criado: $TARGET_DIR/tool_parser.lua"

# 2. tool_runner.lua (Roteamento e Segurança)
cat << 'EOF' > "$TARGET_DIR/tool_runner.lua"
-- lua/multi_context/tool_runner.lua
-- Responsabilidade: Avaliar a segurança (confirmações do usuário/perigos de shell)
-- e executar a ferramenta roteando para tools.lua.

local M = {}

M.execute = function(tool_name, args, is_autonomous)
    -- TODO: Trazer a lógica de vim.fn.confirm e chamada aos scripts do tools.lua
    return "Resultado da execução"
end

return M
EOF
echo "✅ Criado: $TARGET_DIR/tool_runner.lua"

# 3. react_loop.lua (Gerência do Estado Autônomo)
cat << 'EOF' > "$TARGET_DIR/react_loop.lua"
-- lua/multi_context/react_loop.lua
-- Responsabilidade: Gerenciar o estado do loop (Circuit breaker de 15 passos),
-- chamadas em cadeia e recursividade.

local M = {}

M.state = {
    is_autonomous = false,
    auto_loop_count = 0,
    active_agent = nil,
    queued_tasks = nil,
}

M.step = function()
    -- TODO: Trazer o controle de loop e o Circuit Breaker do init.lua
end

M.reset = function()
    M.state.is_autonomous = false
    M.state.auto_loop_count = 0
    M.state.active_agent = nil
end

return M
EOF
echo "✅ Criado: $TARGET_DIR/react_loop.lua"

# 4. prompt_parser.lua (Detecção de intenções do usuário)
cat << 'EOF' > "$TARGET_DIR/prompt_parser.lua"
-- lua/multi_context/prompt_parser.lua
-- Responsabilidade: Interpretar a entrada crua do usuário, 
-- resolver menções a agentes (@coder), flags (--auto) e formatar o payload.

local M = {}

M.parse = function(raw_text)
    -- TODO: Trazer a detecção de '@agente' e '--auto' do SendFromPopup()
    return {
        text = raw_text,
        agent = nil,
        is_auto = false
    }
end

return M
EOF
echo "✅ Criado: $TARGET_DIR/prompt_parser.lua"

echo "🎉 Scaffold finalizado! Novos módulos criados com sucesso."
echo "Próximo passo: Extrair as funções do init.lua para preencher estes módulos."
