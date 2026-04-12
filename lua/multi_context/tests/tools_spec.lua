local tools = require('multi_context.tools')

describe("Tools Module (Agentes Autônomos):", function()
    local tmp_file = os.tmpname()

    after_each(function()
        os.remove(tmp_file) -- Limpa lixo após os testes
    end)

    it("Deve criar e sobrescrever um arquivo (edit_file)", function()
        local res = tools.edit_file(tmp_file, "ola mundo\nteste")
        assert.truthy(res:match("SUCESSO"))
        
        local lines = vim.fn.readfile(tmp_file)
        assert.are.same({"ola mundo", "teste"}, lines)
    end)

    it("Deve editar cirurgicamente um arquivo mantendo as pontas (replace_lines)", function()
        -- Preparando arquivo inicial
        tools.edit_file(tmp_file, "Linha 1\nLinha 2\nLinha 3\nLinha 4")
        
        -- Substituindo as linhas 2 e 3
        local res = tools.replace_lines(tmp_file, 2, 3, "NOVA 2\nNOVA 3")
        assert.truthy(res:match("SUCESSO"))
        
        local lines = vim.fn.readfile(tmp_file)
        assert.are.same({"Linha 1", "NOVA 2", "NOVA 3", "Linha 4"}, lines)
    end)

    it("Deve limpar Markdown intruso do código fonte ao salvar arquivos", function()
        -- Simula a IA enviando ```lua\n...\n```
        local payload_sujo = "```lua\nlocal a = 1\n```"
        tools.edit_file(tmp_file, payload_sujo)
        
        local lines = vim.fn.readfile(tmp_file)
        -- O parser da ferramenta deve ter removido as crases
        assert.are.same({"local a = 1"}, lines)
    end)
end)
