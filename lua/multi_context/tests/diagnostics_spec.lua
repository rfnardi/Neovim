local tools = require('multi_context.tools')
local api = vim.api

describe("Tools Module (get_diagnostics):", function()
    local test_buf
    -- Usamos um arquivo temporário real para satisfazer a checagem 'filereadable'
    local test_path = vim.fn.tempname() .. ".lua"
    local ns = api.nvim_create_namespace("mctx_test_diag")

    before_each(function()
        -- Cria o arquivo em disco
        vim.fn.writefile({"local x = 1", "local y = 2"}, test_path)
        -- Adiciona ao Neovim
        test_buf = vim.fn.bufadd(test_path)
        vim.fn.bufload(test_buf)
    end)

    after_each(function()
        -- Limpa ambiente
        pcall(vim.diagnostic.reset, ns, test_buf)
        pcall(api.nvim_buf_delete, test_buf, { force = true })
        vim.fn.delete(test_path)
    end)

    it("Deve retornar diagnósticos para arquivo existente", function()
        -- Mock de diagnósticos via API nativa (Agora passando o namespace correto!)
        vim.diagnostic.set(ns, test_buf, {
            { lnum = 0, col = 6, severity = 1, message = "Unused variable 'x'", source = "lua_ls" },
            { lnum = 1, col = 6, severity = 2, message = "Unused variable 'y'", source = "lua_ls" },
        })

        local res = tools.get_diagnostics(test_path)
        assert.truthy(res:match("Unused variable 'x'"))
        assert.truthy(res:match("ERROR"))
        assert.truthy(res:match("WARN"))
        assert.truthy(res:match("lua_ls"))
    end)

    it("Deve retornar mensagem informativa para arquivo sem problemas ou sem LSP", function()
        local res = tools.get_diagnostics(test_path)
        -- Retorna sucesso se achar a mensagem de que não há erros ou não há LSP
        assert.truthy(res:match("Nenhum") or res:match("AVISO"))
    end)

    it("Deve truncar saída quando há muitos diagnósticos", function()
        -- Injeta 60 diagnósticos para testar limite de tokens
        local many = {}
        for i = 1, 60 do
            table.insert(many, { lnum = i, col = 0, severity = 1, message = "Error number " .. i, source = "test_lsp" })
        end
        vim.diagnostic.set(ns, test_buf, many)

        local res = tools.get_diagnostics(test_path)
        assert.truthy(res:match("TRUNCADO") or res:match("exibindo os primeiros"))
        -- Verifica se não ultrapassou o limite absurdo
        assert.truthy(#res <= 4500)
    end)

    it("Deve retornar erro para path inexistente", function()
        local res = tools.get_diagnostics("/tmp/caminho_inexistente_absurdo_12345.lua")
        assert.truthy(res:match("ERRO"))
    end)

    it("Deve retornar erro quando o path não é fornecido (regra estrita)", function()
        -- Testa se o plugin bloqueia tentativa de adivinhar arquivo
        local res_nil = tools.get_diagnostics(nil)
        assert.truthy(res_nil:match("OBRIGATÓRIO"))
        
        local res_empty = tools.get_diagnostics("")
        assert.truthy(res_empty:match("OBRIGATÓRIO"))
    end)
end)
