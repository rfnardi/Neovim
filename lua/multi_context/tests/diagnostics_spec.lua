



local tools = require('multi_context.tools')
local popup = require('multi_context.ui.popup')
local api = vim.api

describe("Tools Module (get_diagnostics):", function()
    local test_buf

    before_each(function()
        -- Cria buffer de teste em memória
        test_buf = api.nvim_create_buf(false, true)
        api.nvim_buf_set_name(test_buf, "test_diagnostics_file.lua")
        api.nvim_buf_set_lines(test_buf, 0, -1, false, {"local x = 1", "local y = 2"})
    end)

    after_each(function()
        -- Limpa diagnósticos e buffer
        pcall(vim.diagnostic.reset, nil, test_buf)
        pcall(api.nvim_buf_delete, test_buf, { force = true })
        popup.code_buf_before_popup = nil
    end)

    it("Deve retornar diagnósticos via path para buffer carregado", function()
        -- Mock de diagnósticos via API nativa
        vim.diagnostic.set(test_buf, {
            { lnum = 0, col = 6, severity = 1, message = "Unused variable 'x'", source = "lua_ls" },
            { lnum = 1, col = 6, severity = 2, message = "Unused variable 'y'", source = "lua_ls" },
        })

        local res = tools.get_diagnostics("test_diagnostics_file.lua")
        assert.truthy(res:match("Unused variable 'x'"))
        assert.truthy(res:match("ERROR"))
        assert.truthy(res:match("WARN"))
        assert.truthy(res:match("lua_ls"))
    end)

    it("Deve retornar diagnósticos via buffer rastreado (sem path)", function()
        -- Simula o popup tendo capturado o buffer de código
        popup.code_buf_before_popup = test_buf

        vim.diagnostic.set(test_buf, {
            { lnum = 0, col = 0, severity = 1, message = "Undefined global", source = "lua_ls" },
        })

        local res = tools.get_diagnostics(nil)
        assert.truthy(res:match("Undefined global"))
    end)

    it("Deve retornar mensagem informativa para buffer sem LSP", function()
        -- Buffer sem clientes LSP e sem diagnósticos
        local res = tools.get_diagnostics("test_diagnostics_file.lua")
        assert.truthy(res:match("Nenhum") or res:match("indisponíveis") or res:match("LSP"))
    end)

    it("Deve truncar saída quando há muitos diagnósticos", function()
        -- Injeta 60 diagnósticos para testar truncamento
        local many = {}
        for i = 1, 60 do
            table.insert(many, { lnum = i, col = 0, severity = 1, message = "Error number " .. i, source = "test_lsp" })
        end
        vim.diagnostic.set(test_buf, many)

        local res = tools.get_diagnostics("test_diagnostics_file.lua")
        assert.truthy(res:match("TRUNCADO") or res:match("AVISO"))
        -- Verifica que a saída não explodiu
        assert.truthy(#res <= 4500)
    end)

    it("Deve retornar erro para path inexistente", function()
        local res = tools.get_diagnostics("caminho_inexistente_absurdo_12345.lua")
        assert.truthy(res:match("ERRO"))
    end)

    it("Deve retornar erro quando não há path nem buffer rastreado", function()
        popup.code_buf_before_popup = nil
        local res = tools.get_diagnostics(nil)
        assert.truthy(res:match("ERRO"))
    end)
end)
</arg_value>


