local conv = require('multi_context.conversation')
local config = require('multi_context.config')

describe("Conversation Module:", function()
    before_each(function()
        config.options.user_name = "Nardi"
    end)

    it("Deve encontrar a última linha de comando do usuário", function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "## Nardi >> primeirao",
            "## IA >> resposta",
            "## Nardi >> ultimo comando"
        })
        
        local idx, line = conv.find_last_user_line(buf)
        assert.are.same(2, idx) -- Neovim usa indexação 0-based via API
        assert.are.same("## Nardi >> ultimo comando", line)
    end)

    it("Deve ignorar mensagens de [Sistema] na hora de ler o último comando", function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "## Nardi >> faça algo",
            "## IA >> <tool_call...",
            "## Nardi >> [Sistema]: Ferramentas executadas"
        })
        -- O parser precisa enxergar a linha do sistema também, pois ela é a retroalimentação.
        local idx, line = conv.find_last_user_line(buf)
        assert.are.same(2, idx)
        assert.truthy(line:match("%[Sistema%]"))
    end)
end)
