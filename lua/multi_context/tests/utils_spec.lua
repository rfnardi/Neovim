local utils = require('multi_context.utils')

describe("Utils Module:", function()
    it("Deve dividir strings por quebra de linha corretamente", function()
        local str = "linha1\nlinha2\nlinha3"
        local res = utils.split_lines(str)
        assert.are.same({"linha1", "linha2", "linha3"}, res)
    end)

    it("Deve estimar tokens corretamente (4 chars = 1 token)", function()
        local buf = vim.api.nvim_create_buf(false, true)
        -- Injeta 2 linhas. A lógica soma: (#linha + 1). Total: (5+1) + (5+1) = 12 chars
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"12345", "12345"})
        
        local tokens = utils.estimate_tokens(buf)
        -- 12 / 4 = 3 tokens
        assert.are.same(3, tokens)
    end)
end)
