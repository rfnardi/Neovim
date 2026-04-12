#!/bin/bash

PLUGIN_DIR="$HOME/.config/nvim/lua/multi_context"
TESTS_DIR="$PLUGIN_DIR/tests"

echo "🧪 Ampliando a cobertura de testes (Contexto, Shell e JSON)..."

# 1. Testes do Context Builders
cat << 'EOF' > "$TESTS_DIR/context_builders_spec.lua"
local ctx = require('multi_context.context_builders')

describe("Context Builders Module:", function()
    it("Deve extrair o contexto do buffer atual corretamente", function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"linhaA", "linhaB"})
        vim.api.nvim_set_current_buf(buf)
        
        local res = ctx.get_current_buffer()
        assert.truthy(res:match("=== BUFFER ATUAL ==="))
        assert.truthy(res:match("linhaA"))
        assert.truthy(res:match("linhaB"))
    end)

    it("Deve extrair apenas as linhas da selecao visual (com range)", function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"L1", "L2", "L3", "L4"})
        vim.api.nvim_set_current_buf(buf)
        
        local res = ctx.get_visual_selection(2, 3)
        assert.truthy(res:match("SELEÇÃO %(linhas 2%-3%)"))
        assert.truthy(res:match("L2"))
        assert.truthy(res:match("L3"))
        assert.falsy(res:match("L1"))
        assert.falsy(res:match("L4"))
    end)
    
    it("Deve corrigir a ordem se o range for passado invertido (baixo pra cima)", function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"A", "B", "C"})
        vim.api.nvim_set_current_buf(buf)
        
        -- Selecionou da linha 3 até a 1
        local res = ctx.get_visual_selection(3, 1)
        assert.truthy(res:match("SELEÇÃO %(linhas 1%-3%)"))
    end)
end)
EOF

# 2. Testes de Leitura/Escrita de Configuração (JSON Mock)
cat << 'EOF' >> "$TESTS_DIR/config_spec.lua"

describe("Config Module (Manipulacao de Arquivo JSON):", function()
    local config = require('multi_context.config')

    it("Deve ler e alterar APIs usando um JSON em disco", function()
        local tmp_json = os.tmpname()
        
        -- Simulando o arquivo JSON criado pelo usuario
        local mock_cfg = {
            default_api = "api_A",
            apis = {
                { name = "api_A" },
                { name = "api_B" }
            }
        }
        
        local f = io.open(tmp_json, "w")
        f:write(vim.fn.json_encode(mock_cfg))
        f:close()
        
        -- Força o plugin a olhar para o nosso arquivo falso
        config.options.config_path = tmp_json
        
        -- Testa extração de nomes
        local names = config.get_api_names()
        assert.are.same({"api_A", "api_B"}, names)
        
        -- Testa buscar a default atual
        assert.are.same("api_A", config.get_current_api())
        
        -- Testa trocar a API via código
        config.set_selected_api("api_B")
        assert.are.same("api_B", config.get_current_api())
        
        os.remove(tmp_json)
    end)
end)
EOF

# 3. Teste de Execução de Terminal na Tools
cat << 'EOF' >> "$TESTS_DIR/tools_spec.lua"

describe("Tools Module (Execucao de Shell):", function()
    local tools = require('multi_context.tools')

    it("Deve executar run_shell e retornar SUCESSO com a saida do terminal", function()
        local res = tools.run_shell("echo 'Testando_Terminal_123'")
        assert.truthy(res:match("SUCESSO"))
        assert.truthy(res:match("Testando_Terminal_123"))
    end)

    it("Deve retornar status de FALHA se o comando shell nao existir", function()
        local res = tools.run_shell("comando_bizarro_que_nao_existe_123")
        assert.truthy(res:match("FALHA"))
        -- O erro exato do bash varia entre sistemas, mas a tag FALHA deve estar lá.
    end)
end)
EOF

echo "✅ Testes de Cobertura Final implementados com sucesso!"
