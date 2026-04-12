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
