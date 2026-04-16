-- lua/multi_context/tests/prompt_parser_spec.lua
local prompt_parser = require('multi_context.prompt_parser')

describe("Prompt Parser Module:", function()
    local mock_agents = {
        coder = { system_prompt = "Você programa.", use_tools = true }
    }

    it("Deve extrair a flag --auto e o agente corretamente", function()
        local raw = "Me faça um script @coder --auto"
        local parsed = prompt_parser.parse_user_input(raw, mock_agents)
        
        -- Agora esperamos o texto perfeitamente limpo, sem os espaços residuais
        assert.are.same("Me faça um script", parsed.text_to_send)
        assert.are.same("coder", parsed.agent_name)
        assert.is_true(parsed.is_autonomous)
    end)

    it("Deve tratar @reset corretamente limpando o agente ativo", function()
        local raw = "Esqueça sua persona @reset"
        local parsed = prompt_parser.parse_user_input(raw, mock_agents)
        
        assert.are.same("reset", parsed.agent_name)
        assert.are.same("Esqueça sua persona", parsed.text_to_send)
    end)

    it("Deve compor o system prompt com memória e instruções do agente", function()
        local base = "Você é uma IA."
        local memory = "Projeto usa Lua."
        
        local final_prompt = prompt_parser.build_system_prompt(base, memory, "coder", mock_agents)
        
        assert.truthy(final_prompt:match("Você é uma IA."))
        assert.truthy(final_prompt:match("ESTADO ATUAL DO PROJETO"))
        assert.truthy(final_prompt:match("Projeto usa Lua."))
        assert.truthy(final_prompt:match("INSTRUÇÕES DO AGENTE: CODER"))
        assert.truthy(final_prompt:match("Você programa."))
        assert.truthy(final_prompt:match("FERRAMENTAS DO SISTEMA"))
    end)
end)
